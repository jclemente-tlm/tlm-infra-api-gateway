# Guía de Integración Keycloak + Kong

Guía paso a paso para configurar autenticación JWT con Keycloak y Kong API Gateway.

**Prerequisitos:**

- Keycloak instalado y accesible
- Kong Gateway 3.x configurado y funcionando
- Acceso administrativo a ambos sistemas

**Relacionado:** Ver [KEYCLOAK_NAMING_STANDARD.md](./KEYCLOAK_NAMING_STANDARD.md) para nomenclatura de clients y realms.

---

## Paso 1: Configuración en Keycloak

### A. Crear Realm (si no existe)

**Ejemplo para Perú:**

1. Login a Keycloak Admin Console
2. Hover sobre el realm actual (parte superior izquierda) → **Add realm**
3. Name: `tlm-pe`
4. Click **Create**

**Ejemplo para Corporativo:**

- Name: `tlm-corp`

---

### B. Configurar Realm Settings

**Para cada realm creado:**

1. Ir a **Realm Settings** → **General**
   - User-Managed Access: `OFF` (a menos que uses UMA)
   - Endpoints: Anotar el issuer URL (ej: `https://keycloak.tudominio.com/realms/tlm-pe`)

2. Ir a **Realm Settings** → **Keys**
   - Copiar el certificado público RSA256 (lo necesitarás para Kong)
   - Click en **Public key** del algoritmo RS256
   - Copia el valor completo

3. Ir a **Realm Settings** → **Tokens**
   - Access Token Lifespan: `5 minutes` (recomendado)
   - Client login timeout: `1 minute`

---

### C. Crear Client para API (Bearer-only)

**Ejemplo: gestal-api (servicio local)**

1. Ir a **Clients** → **Create**

**Settings Tab:**

```yaml
Client ID: gestal-api
Name: Gestal API Gateway
Description: Kong API Gateway para servicio Gestal
Enabled: ON
Client Protocol: openid-connect
Access Type: bearer-only
Standard Flow Enabled: OFF
Implicit Flow Enabled: OFF
Direct Access Grants Enabled: OFF
Service Accounts Enabled: OFF
Authorization Enabled: OFF
```

2. Click **Save**

**Ejemplo: sisbon-api (servicio corporativo en tlm-corp)**

```yaml
Client ID: sisbon-api
Access Type: bearer-only
# Resto igual que gestal-api
```

---

### D. Crear Client para Consumidor (Confidential)

**Ejemplo: gestal-pe-dev**

1. Ir a **Clients** → **Create**

**Settings Tab:**

```yaml
Client ID: gestal-pe-dev
Name: Gestal Consumidor DEV (Perú)
Description: Cliente para aplicación backend de Gestal en DEV
Enabled: ON
Client Protocol: openid-connect
Access Type: confidential
Standard Flow Enabled: OFF
Implicit Flow Enabled: OFF
Direct Access Grants Enabled: OFF
Service Accounts Enabled: ON
Authorization Enabled: OFF
Root URL: (vacío)
Valid Redirect URIs: (vacío - no usa flows interactivos)
Web Origins: (vacío)
```

2. Click **Save**

3. Ir a **Credentials Tab**
   - Copiar el **Secret** (lo usarás en tu aplicación)
   - Regenerate Secret si es necesario

4. Ir a **Service Account Roles Tab**
   - Aquí puedes asignar roles específicos si los has creado

**Repetir para:**

- `gestal-pe-qa`
- `gestal-pe-prod`
- `gestal-ext-ats` (integración externa)

---

### E. Crear Roles (Opcional pero recomendado)

**En el realm apropiado (ej: tlm-pe para gestal):**

1. Ir a **Roles** → **Add Role**

**Crear roles:**

```yaml
Role Name: gestal:read
Description: Permiso de lectura para Gestal

Role Name: gestal:write
Description: Permiso de escritura para Gestal

Role Name: gestal:admin
Description: Permiso administrativo para Gestal
```

2. Asignar roles a clients:
   - Ir a **Clients** → Seleccionar `gestal-pe-dev`
   - **Service Account Roles** tab
   - Client Roles: Seleccionar el realm
   - Available Roles: Seleccionar `gestal:read`, `gestal:write`
   - Click **Add selected**

**Para producción:**

- `gestal-pe-prod`: Solo `gestal:read` y `gestal:write`

**Para integraciones externas:**

- `gestal-ext-ats`: Solo `gestal:write` (pueden escribir pero no leer)

---

### F. Obtener Información para Kong

**Para cada realm que usarás:**

1. **Issuer URL:**

   ```text
   https://keycloak.tudominio.com/realms/tlm-pe
   ```

2. **Public Key (RS256):**
   - Realm Settings → Keys → Public key (botón)
   - Formato PEM completo:

   ```text
   -----BEGIN PUBLIC KEY-----
   MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
   -----END PUBLIC KEY-----
   ```

3. **JWKS URI (alternativa):**

   ```text
   https://keycloak.tudominio.com/realms/tlm-pe/protocol/openid-connect/certs
   ```

---

## Paso 2: Configuración en Kong

### A. Crear Service en Kong

**Para servicio con múltiples ambientes:**

```bash
# DEV
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "gestal-dev",
    "url": "https://backend-dev.tudominio.com"
  }'

# QA
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "gestal-qa",
    "url": "https://backend-qa.tudominio.com"
  }'

# PROD
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "gestal-prod",
    "url": "https://backend-prod.tudominio.com"
  }'
```

---

### B. Crear Routes en Kong

**Para cada servicio:**

```bash
# Route para DEV
curl -X POST http://localhost:8001/services/gestal-dev/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "gestal-dev-route",
    "paths": ["/api-dev/gestal"],
    "strip_path": true,
    "preserve_host": false
  }'

# Route para QA
curl -X POST http://localhost:8001/services/gestal-qa/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "gestal-qa-route",
    "paths": ["/api-qa/gestal"],
    "strip_path": true,
    "preserve_host": false
  }'

# Route para PROD
curl -X POST http://localhost:8001/services/gestal-prod/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "gestal-prod-route",
    "paths": ["/api/gestal"],
    "strip_path": true,
    "preserve_host": false
  }'
```

**Opciones importantes:**

- `strip_path: true` → Elimina `/api/gestal` antes de enviar al backend
- `preserve_host: false` → Usa el hostname del backend (importante para SSL/SNI)

---

### C. Crear Consumer en Kong para cada Realm

**Un consumer representa un issuer (realm) de Keycloak:**

```bash
# Consumer para tlm-pe realm
curl -X POST http://localhost:8001/consumers \
  -d "username=tlm-pe-realm"

# Consumer para tlm-corp realm (si tienes servicios corporativos)
curl -X POST http://localhost:8001/consumers \
  -d "username=tlm-corp-realm"
```

---

### D. Agregar Credencial JWT al Consumer

**Método 1: Usando Public Key directamente**

```bash
curl -X POST http://localhost:8001/consumers/tlm-pe-realm/jwt \
  -H "Content-Type: application/json" \
  -d '{
    "key": "https://keycloak.tudominio.com/realms/tlm-pe",
    "algorithm": "RS256",
    "rsa_public_key": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n-----END PUBLIC KEY-----"
  }'
```

**Importante:**

- `key`: Debe ser exactamente el issuer (`iss`) que viene en el JWT
- `algorithm`: Debe ser `RS256` (el más común en Keycloak)
- `rsa_public_key`: La clave pública en formato PEM con `\n` para saltos de línea

**Método 2: Kong obtiene la clave automáticamente vía JWKS (Recomendado)**

Kong puede obtener las claves públicas dinámicamente desde el endpoint JWKS de Keycloak (recomendado para rotación automática):

```bash
curl -X POST http://localhost:8001/consumers/tlm-pe-realm/jwt \
  -H "Content-Type: application/json" \
  -d '{
    "key": "https://keycloak.tudominio.com/realms/tlm-pe",
    "algorithm": "RS256"
  }'
```

Y luego configurar el plugin JWT para usar JWKS (ver siguiente sección).

---

### E. Instalar Plugin JWT en el Service

**Para servicio local (un solo realm):**

```bash
curl -X POST http://localhost:8001/services/gestal-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "uri_param_names": ["jwt"],
      "cookie_names": [],
      "claims_to_verify": ["exp"],
      "key_claim_name": "iss",
      "secret_is_base64": false,
      "anonymous": "",
      "run_on_preflight": true,
      "maximum_expiration": 0
    }
  }'
```

**Para servicio corporativo (múltiples realms/issuers):**

```bash
curl -X POST http://localhost:8001/services/sisbon-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "uri_param_names": ["jwt"],
      "claims_to_verify": ["exp", "azp"],
      "key_claim_name": "iss",
      "secret_is_base64": false,
      "anonymous": "",
      "run_on_preflight": true
    }
  }'
```

**Configuración importante:**

- `claims_to_verify: ["exp"]` → Verifica que el token no haya expirado
- `key_claim_name: "iss"` → Kong busca el consumer usando el claim `iss` (issuer)
- `run_on_preflight: true` → Permite OPTIONS requests (CORS)

---

### F. Plugin JWT con JWKS (Recomendado para Producción)

**Para rotación automática de claves:**

```bash
curl -X POST http://localhost:8001/services/gestal-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "claims_to_verify": ["exp"],
      "key_claim_name": "iss",
      "run_on_preflight": true,
      "header_names": ["Authorization"],
      "uri_param_names": ["jwt"]
    }
  }'
```

Y agregar la credencial JWT con soporte JWKS:

```bash
curl -X POST http://localhost:8001/consumers/tlm-pe-realm/jwt \
  -H "Content-Type: application/json" \
  -d '{
    "key": "https://keycloak.tudominio.com/realms/tlm-pe",
    "algorithm": "RS256",
    "secret_is_base64": false
  }'
```

Kong automáticamente consultará:

```text
https://keycloak.tudominio.com/realms/tlm-pe/protocol/openid-connect/certs
```

---

## Paso 3: Probar la Integración

### A. Obtener Token desde Keycloak

```bash
# Obtener token usando client_credentials grant
curl -X POST https://keycloak.tudominio.com/realms/tlm-pe/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=gestal-pe-dev" \
  -d "client_secret=TU_CLIENT_SECRET_AQUI"
```

**Respuesta esperada:**

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "token_type": "Bearer",
  "not-before-policy": 0,
  "scope": "profile email"
}
```

---

### B. Llamar al API a través de Kong

```bash
# Guardar el token
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

# Llamar al API
curl -X GET https://api.tudominio.com/api/gestal/datos \
  -H "Authorization: Bearer $TOKEN"
```

**Respuestas posibles:**

✅ **Éxito (200 OK):**

```json
{
  "data": "respuesta del backend"
}
```

❌ **Token inválido/expirado (401):**

```json
{
  "message": "Unauthorized"
}
```

❌ **Sin token (401):**

```json
{
  "message": "Unauthorized"
}
```

❌ **Token válido pero sin permisos (403):**

```json
{
  "message": "Forbidden"
}
```

---

### C. Verificar el Token (Debug)

**Decodificar JWT:**

```bash
echo "$TOKEN" | cut -d. -f2 | base64 -d | jq .
```

**Verificar claims importantes:**

```json
{
  "iss": "https://keycloak.tudominio.com/realms/tlm-pe",
  "azp": "gestal-pe-dev",
  "exp": 1733340000,
  "iat": 1733339700,
  "realm_access": {
    "roles": ["gestal:read", "gestal:write"]
  }
}
```

**Claims críticos:**

- `iss`: Debe coincidir con el `key` del consumer en Kong
- `exp`: Timestamp de expiración (debe ser futuro)
- `azp`: Authorized party (el client_id que solicitó el token)

---

## Paso 4: Configuración de Rate Limiting (Opcional)

### Por Consumer (por realm)

```bash
curl -X POST http://localhost:8001/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "consumer": {"id": "ID_DEL_CONSUMER_tlm-pe-realm"},
    "config": {
      "minute": 100,
      "hour": 5000,
      "policy": "local"
    }
  }'
```

### Por Service

```bash
curl -X POST http://localhost:8001/services/gestal-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 1000,
      "hour": 50000,
      "policy": "local"
    }
  }'
```

---

## Flujo Completo de Autenticación

```text
┌──────────────┐
│  Aplicación  │
│ (gestal-pe-  │
│     dev)     │
└──────┬───────┘
       │ 1. Solicita token
       ▼
┌──────────────────────────────────┐
│          Keycloak                │
│  Realm: tlm-pe                   │
│  Client: gestal-pe-dev           │
│  (confidential, service account) │
└──────────────┬───────────────────┘
               │ 2. Retorna JWT
               │    iss: https://keycloak.../realms/tlm-pe
               │    azp: gestal-pe-dev
               ▼
       ┌────────────┐
       │ Aplicación │
       └──────┬─────┘
              │ 3. Llama API con JWT
              │    GET /api/gestal/datos
              │    Authorization: Bearer <JWT>
              ▼
       ┌─────────────────┐
       │  Kong Gateway   │
       │  - Valida JWT   │
       │  - Verifica exp │
       │  - Busca issuer │
       └────────┬────────┘
                │ 4. Si válido, proxy al backend
                │    GET /datos (strip_path=true)
                ▼
         ┌──────────────┐
         │   Backend    │
         │    Gestal    │
         └──────────────┘
```

---

## Troubleshooting

### Error: "No credentials found for given 'iss' claim"

**Causa:** Kong no encuentra un consumer con credencial JWT cuyo `key` coincida con el `iss` del token.

**Solución:**

1. Verificar el claim `iss` en el token: `echo "$TOKEN" | cut -d. -f2 | base64 -d | jq .iss`
2. Verificar consumers en Kong: `curl http://localhost:8001/consumers/tlm-pe-realm/jwt`
3. Asegurar que el `key` de la credencial JWT sea exactamente el `iss`

---

### Error: "Invalid signature"

**Causa:** La clave pública en Kong no coincide con la privada usada por Keycloak.

**Solución:**

1. Obtener clave pública actualizada: Keycloak → Realm Settings → Keys → Public key (RS256)
2. Actualizar credencial en Kong:

```bash
curl -X PATCH http://localhost:8001/consumers/tlm-pe-realm/jwt/ID_CREDENCIAL \
  -d "rsa_public_key=-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
```

---

### Error: "Token expired"

**Causa:** El token ha superado su tiempo de vida (`exp` claim).

**Solución:**

1. Solicitar un nuevo token
2. Ajustar Access Token Lifespan en Keycloak si es muy corto

---

### Error: CORS preflight fails

**Causa:** Plugin JWT bloquea OPTIONS requests.

**Solución:**

```bash
# Actualizar plugin JWT
curl -X PATCH http://localhost:8001/plugins/ID_PLUGIN_JWT \
  -d "config.run_on_preflight=true"

# O agregar plugin CORS
curl -X POST http://localhost:8001/services/gestal-prod/plugins \
  -d "name=cors" \
  -d "config.origins=*" \
  -d "config.methods=GET,POST,PUT,DELETE,OPTIONS" \
  -d "config.headers=Authorization,Content-Type" \
  -d "config.exposed_headers=X-Auth-Token" \
  -d "config.credentials=true" \
  -d "config.max_age=3600"
```

---

## Verificación de Configuración

### Checklist Keycloak

- [ ] Realm creado (`tlm-pe`, `tlm-corp`, etc.)
- [ ] Client API creado (bearer-only)
- [ ] Clients consumidores creados (confidential + service accounts)
- [ ] Roles creados y asignados
- [ ] Public key / JWKS URI obtenido
- [ ] Issuer URL documentado

### Checklist Kong

- [ ] Service creado
- [ ] Route creado con paths correctos
- [ ] Consumer creado (por realm)
- [ ] Credencial JWT agregada con public key
- [ ] Plugin JWT instalado
- [ ] Rate limiting configurado (si aplica)

### Checklist Testing

- [ ] Token obtenido desde Keycloak
- [ ] Token decodificado correctamente
- [ ] Claims verificados (iss, exp, azp)
- [ ] Request a Kong con token exitoso
- [ ] Request sin token rechazado (401)
- [ ] Request con token expirado rechazado (401)

---

**Fecha de última actualización:** 2025-12-04
**Versión:** 1.0
**Mantenido por:** Equipo DevOps TLM
