# ATS: Crear Posición TALMA

Este endpoint permite crear una **nueva posición (vacante)** en el sistema ATS de TalentHub, específicamente para el cliente **TALMA**.

## Arquitectura

```
┌─────────────────┐
│  App Gestal     │ 1. POST client_credentials
│  (Backend)      │───────────────────────────┐
└─────────────────┘                           │
                                              ▼
                                   ┌──────────────────────┐
                                   │     Keycloak         │
                                   │  Realm: tlm-pe       │
                                   │  Client: gestal-pe-* │
                                   └──────────┬───────────┘
                                              │ 2. JWT Token
                                              │    iss: .../realms/tlm-pe
┌─────────────────┐                           │    azp: gestal-pe-dev
│  App Gestal     │◄──────────────────────────┘
└────────┬────────┘
         │ 3. POST /api-dev/gestal/ats/posiciones
         │    Authorization: Bearer <jwt>
         ▼
┌──────────────────────────────────┐
│       Kong Gateway               │
│  Service: ext-talenthub-ats-dev  │
│  ✅ JWT Plugin: valida JWT        │
│  ✅ Request-Transformer:          │
│     • Inyecta x-api-key          │
│     • Transforma URI             │
└────────┬─────────────────────────┘
         │ 4. POST /ats/lmbExGen?operacion=...
         │    x-api-key: GRFbBhN...
         ▼
┌─────────────────────────────┐
│    TalentHub ATS API        │
│  https://api-ats.talenthub  │
└────────┬────────────────────┘
         │ 5. Response: { vacante_id }
         ▼
┌─────────────────┐
│  App Gestal     │
└─────────────────┘
```

**Flujo completo:**

1. **App Gestal** obtiene JWT de Keycloak usando `client_credentials` grant
2. **Keycloak** valida credenciales y retorna JWT con claims `iss` y `azp`
3. **App Gestal** envía request a Kong con JWT en header `Authorization`
4. **Kong** valida JWT (firma RS256 + expiración) usando JWKS
5. **Kong** inyecta automáticamente `x-api-key` de TalentHub
6. **Kong** transforma URI al formato esperado por TalentHub
7. **Kong** hace proxy a TalentHub ATS
8. **TalentHub** responde con el resultado

**Ventajas de este approach:**

- ✅ **Proxy directo Kong → TalentHub**: Sin backend intermedio para ATS (menor latencia)
- ✅ Kong maneja el secreto `x-api-key` centralizadamente
- ✅ Autenticación JWT unificada con otros servicios
- ✅ Rate limiting en PROD (100 req/min, 1000 req/hour)
- ✅ Configuración declarativa en Git

> **📝 Arquitectura Simplificada:** El servicio Gestal está también expuesto a través del ALB (`http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/*`). En esta integración específica con ATS, Kong hace proxy directo a TalentHub sin pasar por el backend de Gestal.

---

## Endpoint público (Kong)

> **📝 Nota:** Actualmente usando DNS temporal del ALB. Cuando se configure el dominio público, las URLs serán:
>
> - `https://api-dev.talma.com.pe`, `https://api-qa.talma.com.pe`, `https://api.talma.com.pe`
> - `https://auth.talma.com.pe` para Keycloak

**Para clientes/aplicación Gestal:**

```http
POST http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api/gestal/ats/posiciones
Authorization: Bearer <jwt-token-from-keycloak>
Content-Type: application/json
```

**Ambientes disponibles:**

- **DEV**: `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/ats/posiciones`
- **QA**: `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-qa/gestal/ats/posiciones`
- **PROD**: `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api/gestal/ats/posiciones`

**Kong valida:**

- ✅ JWT firma válida (algoritmo RS256)
- ✅ Token no expirado (claim `exp`)
- ✅ Issuer correcto (`http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe`)

**Kong transforma automáticamente:**

- ✅ Agrega header: `x-api-key: GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu`
- ✅ Reemplaza URI a: `/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f`
- ✅ Proxy a: `https://api-ats.talenthub.pe`

---

## Servicio destino (TalentHub ATS)

**Kong hace proxy a:**

```http
POST https://api-ats.talenthub.pe/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f
x-api-key: GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu
Content-Type: application/json
```

> 🔹 Los parámetros `operacion` y `bcode` son constantes configuradas en Kong.
> 🔹 El `x-api-key` es agregado automáticamente por Kong (no lo envíes manualmente).

---

### **Encabezados requeridos**

| Header | Descripción | Ejemplo |
| --- | --- | --- |
| `x-api-key` | Clave de autenticación para el servicio. | `GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu` |
| `Content-Type` | Tipo de contenido del cuerpo de la petición. | `application/json` |

---

### **Cuerpo de la petición (`JSON`)**

El cuerpo debe incluir los siguientes campos:

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
| --- | --- | --- | --- | --- |
| `current_username` | string | ✅ | Correo del usuario ATS que ejecuta la operación. Por defecto es [talmaconfiguracionats@gmail.com](mailto:talmaconfiguracionats@gmail.com) | `"talmaconfiguracionats@gmail.com"` |
| `posicion_solicitada` | string | ✅ | Nombre de la posición o cargo solicitado. | `"Facturador ATC Senior v2"` |
| `cantidad_de_vacantes` | integer | ✅ | Número total de vacantes para la posición. | `2` |
| `gerencia` | string | ✅ | Gerencia a la que pertenece la posición. | `"Gerencia"` |
| `tipo_convocatoria` | string | ✅ | Tipo de convocatoria (Interna o Externa). | `"Externo"` |
| `definicion_tipo_convocatoria` | string | ✅ | Descripción detallada del tipo de convocatoria. | `"Abierta para personal fuera de la compañia"` |
| `estaciones` | string | ✅ | Lugar o sede de trabajo. | `"Lima"` |
| `area` | string | ✅ | Área organizacional. | `"Gestión Comercial"` |
| `motivo` | string | ✅ | Motivo de la solicitud. | `"Motivo 1"` |
| `nombre_persona_reemplazar` | string | ✅ | Persona a reemplazar (si aplica). | `"Juan Pérez"` |
| `cliente` | string | ✅ | Nombre del cliente relacionado (si aplica). | `"Cliente"` |
| `definicion_cliente` | string | ✅ | Detalle o descripción del cliente. | `"Copa Airlines"` |
| `especialidad` | string | ✅ | Especialidad requerida para el puesto. | `"Especialidad"` |
| `ejem_especialidad` | string | ✅ | Ejemplo o detalle adicional de la especialidad. | `"Especialidad 1"` |
| `tipo_contrato` | string | ✅ | Tipo de contrato. | `"Plazo fijo"` |
| `jornada_laboral` | string | ✅ | Jornada laboral asociada. | `"Tiempo completo 8h"` |

---

### **Ejemplo de solicitud**

```bash
curl --location 'https://api-ats.talenthub.pe/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f' \
--header 'x-api-key: GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu' \
--header 'Content-Type: application/json' \
--data-raw '{
    "current_username": "talmaconfiguracionats@gmail.com",
    "posicion_solicitada": "Facturador ATC Senior v2",
    "cantidad_de_vacantes": 2,
    "gerencia": "Gerencia",
    "tipo_convocatoria": "Externo",
    "definicion_tipo_convocatoria": "Abierta para personal fuera de la compañia",
    "estaciones": "Lima",
    "area": "Gestion Comercial",
    "motivo": "Motivo 1",
    "nombre_persona_reemplazar": "Juan Perez",
    "cliente": "Cliente",
    "definicion_cliente": "Copa Airlines",
    "especialidad": "Especialidad",
    "ejem_especialidad": "Especialidad 1",
    "tipo_contrato": "Plazo fijo",
    "jornada_laboral": "Tiempo completo 8h"
}'
```

---

### **Ejemplo de respuesta exitosa**

```json
{
    "status": "success",
    "message": "Posición creada correctamente",
    "vacante_id": "66f89de6c3b48b7f2d92e45b"
}
```

---

### **Posibles errores**

| Código | Mensaje | Causa |
| --- | --- | --- |
| 400 | Bad Request | Falta algún campo obligatorio en el JSON |
| 401 | Unauthorized | `x-api-key` inválido o faltante |
| 500 | Internal Server Error | Error en el procesamiento del servidor |

---

## Configuración Keycloak

### Prerequisitos

- Acceso administrativo a Keycloak
- Realm `tlm-pe` creado y configurado
- URL de Keycloak: `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth`

### Paso 1: Crear Clients por Ambiente

**Necesitas crear 3 clients en el realm `tlm-pe`:**

```
tlm-pe realm:
├─ gestal-pe-dev      → Ambiente DEV
├─ gestal-pe-qa       → Ambiente QA
└─ gestal-pe-prod     → Ambiente PROD
```

### Paso 2: Configurar Client (ejemplo con gestal-pe-dev)

1. **Ir a Keycloak Admin Console** → Realm `tlm-pe` → **Clients** → **Create**

2. **Configuración básica:**

   ```yaml
   Client ID: gestal-pe-dev
   Name: Gestal Consumidor DEV (Perú)
   Description: Cliente para aplicación Gestal en ambiente DEV
   Client Protocol: openid-connect
   Enabled: ON
   ```

3. **Settings Tab:**

   ```yaml
   Access Type: confidential
   Standard Flow Enabled: OFF
   Implicit Flow Enabled: OFF
   Direct Access Grants Enabled: OFF
   Service Accounts Enabled: ON          # ✅ Requerido para client_credentials
   Authorization Enabled: OFF
   Valid Redirect URIs: (vacío)
   Web Origins: (vacío)
   ```

4. **Click Save**

5. **Credentials Tab:**
   - Copiar el `Secret` (lo necesitarás para tu aplicación)
   - Guardar en un lugar seguro (secrets manager, variables de entorno)

6. **(Opcional) Service Account Roles Tab:**
   - Puedes asignar roles específicos como `gestal:write`
   - Esto permite control granular de permisos

### Paso 3: Repetir para QA y PROD

Crear clients `gestal-pe-qa` y `gestal-pe-prod` con la misma configuración.

### Paso 4: Verificar Configuración

**Test de obtención de token:**

```bash
curl -X POST "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=gestal-pe-dev" \
  -d "client_secret=<TU_CLIENT_SECRET>"
```

**Respuesta esperada:**

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "refresh_expires_in": 0,
  "token_type": "Bearer",
  "not-before-policy": 0,
  "scope": "profile email"
}
```

**Decodificar el token (opcional):**

```bash
echo "<access_token>" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .
```

**Claims importantes:**

```json
{
  "iss": "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe",
  "azp": "gestal-pe-dev",
  "exp": 1702410000,
  "iat": 1702409700,
  "typ": "Bearer"
}
```

---

## Configuración Manual (Alternativa)

> **⚠️ Nota:** La configuración declarativa en archivos YAML es la recomendada. Esta sección es solo si necesitas configurar manualmente usando Kong Admin API o Konga UI.

### Opción 1: Configuración Manual via Kong Admin API

#### Paso 1: Crear Consumer para Realm tlm-pe

```bash
curl -X POST http://localhost:8001/consumers \
  -H "Content-Type: application/json" \
  -d '{
    "username": "tlm-pe-realm",
    "tags": ["jwt", "peru"]
  }'
```

#### Paso 2: Agregar Credencial JWT con JWKS

```bash
curl -X POST http://localhost:8001/consumers/tlm-pe-realm/jwt \
  -H "Content-Type: application/json" \
  -d '{
    "key": "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe",
    "algorithm": "RS256",
    "jwks_uri": "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/certs"
  }'
```

**Verificar:**

```bash
curl http://localhost:8001/consumers/tlm-pe-realm/jwt
```

#### Paso 3: Crear Service para TalentHub ATS

**Para DEV:**

```bash
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ext-talenthub-ats-dev",
    "url": "https://api-ats.talenthub.pe",
    "tags": ["external", "talenthub", "third-party", "dev"]
  }'
```

**Para QA:**

```bash
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ext-talenthub-ats-qa",
    "url": "https://api-ats.talenthub.pe",
    "tags": ["external", "talenthub", "third-party", "qa"]
  }'
```

**Para PROD:**

```bash
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ext-talenthub-ats-prod",
    "url": "https://api-ats.talenthub.pe",
    "tags": ["external", "talenthub", "third-party", "prod"]
  }'
```

#### Paso 4: Crear Route para el Service

**Para DEV:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-dev/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ext-talenthub-ats-dev-route",
    "paths": ["/api-dev/gestal/ats"],
    "strip_path": true,
    "preserve_host": false,
    "tags": ["gestal", "ats", "dev"]
  }'
```

**Para QA:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-qa/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ext-talenthub-ats-qa-route",
    "paths": ["/api-qa/gestal/ats"],
    "strip_path": true,
    "preserve_host": false,
    "tags": ["gestal", "ats", "qa"]
  }'
```

**Para PROD:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-prod/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ext-talenthub-ats-prod-route",
    "paths": ["/api/gestal/ats"],
    "strip_path": true,
    "preserve_host": false,
    "tags": ["gestal", "ats", "prod"]
  }'
```

#### Paso 5: Instalar Plugin JWT

**Para DEV:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-dev/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "claims_to_verify": ["exp"],
      "key_claim_name": "iss",
      "run_on_preflight": false
    },
    "tags": ["auth", "ext-talenthub-ats"]
  }'
```

**Para QA:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-qa/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "claims_to_verify": ["exp"],
      "key_claim_name": "iss",
      "run_on_preflight": false
    },
    "tags": ["auth", "ext-talenthub-ats"]
  }'
```

**Para PROD:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "claims_to_verify": ["exp"],
      "key_claim_name": "iss",
      "run_on_preflight": false
    },
    "tags": ["auth", "ext-talenthub-ats"]
  }'
```

#### Paso 6: Instalar Plugin Request-Transformer (Inyectar x-api-key)

**Para DEV:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-dev/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "add": {
        "headers": ["x-api-key:GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu"]
      },
      "replace": {
        "uri": "/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f"
      }
    },
    "tags": ["transformer", "ext-talenthub-ats"]
  }'
```

**Para QA:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-qa/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "add": {
        "headers": ["x-api-key:GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu"]
      },
      "replace": {
        "uri": "/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f"
      }
    },
    "tags": ["transformer", "ext-talenthub-ats"]
  }'
```

**Para PROD:**

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "add": {
        "headers": ["x-api-key:GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu"]
      },
      "replace": {
        "uri": "/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f"
      }
    },
    "tags": ["transformer", "ext-talenthub-ats"]
  }'
```

#### Paso 7: (Solo PROD) Instalar Plugin Rate Limiting

```bash
curl -X POST http://localhost:8001/services/ext-talenthub-ats-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 100,
      "hour": 1000,
      "policy": "local"
    },
    "tags": ["rate-limit", "prod"]
  }'
```

#### Paso 8: Verificar Configuración

**Listar todos los services:**

```bash
curl http://localhost:8001/services | jq '.data[] | {name, url}'
```

**Listar routes de un service:**

```bash
curl http://localhost:8001/services/ext-talenthub-ats-dev/routes | jq '.data[] | {name, paths}'
```

**Listar plugins de un service:**

```bash
curl http://localhost:8001/services/ext-talenthub-ats-dev/plugins | jq '.data[] | {name, config}'
```

**Verificar consumer JWT:**

```bash
curl http://localhost:8001/consumers/tlm-pe-realm/jwt | jq
```

---

### Opción 2: Configuración Manual via Konga UI

#### Paso 1: Acceder a Konga

1. Abrir navegador: `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/konga`
2. Login con credenciales de administrador
3. Seleccionar conexión a Kong

#### Paso 2: Crear Consumer

1. **Menú lateral** → **Consumers**
2. Click **+ Create Consumer**
3. **Configurar:**
   - Username: `tlm-pe-realm`
   - Tags: `jwt, peru`
4. Click **Submit**

#### Paso 3: Agregar Credencial JWT al Consumer

1. En la lista de Consumers, click en `tlm-pe-realm`
2. Tab **Credentials**
3. Click **+ JWT**
4. **Configurar:**
   - Key (iss claim): `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe`
   - Algorithm: `RS256`
   - JWKS URI: `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/certs`
5. Click **Submit**

#### Paso 4: Crear Service

1. **Menú lateral** → **Services**
2. Click **+ Create Service**
3. **Configurar (para DEV):**
   - Name: `ext-talenthub-ats-dev`
   - Protocol: `https`
   - Host: `api-ats.talenthub.pe`
   - Port: `443`
   - Path: (vacío)
   - Tags: `external, talenthub, third-party, dev`
4. Click **Submit**
5. **Repetir para QA y PROD** cambiando el nombre y tags

#### Paso 5: Crear Route para el Service

1. Dentro del service `ext-talenthub-ats-dev`, tab **Routes**
2. Click **+ Add Route**
3. **Configurar:**
   - Name: `ext-talenthub-ats-dev-route`
   - Paths: `/api-dev/gestal/ats` (click + para agregar)
   - Strip Path: ✅ Enabled
   - Preserve Host: ❌ Disabled
   - Tags: `gestal, ats, dev`
4. Click **Submit**
5. **Repetir para QA** (`/api-qa/gestal/ats`) **y PROD** (`/api/gestal/ats`)

#### Paso 6: Agregar Plugin JWT

1. Dentro del service `ext-talenthub-ats-dev`, tab **Plugins**
2. Click **+ Add Plugin**
3. Buscar y seleccionar **JWT**
4. **Configurar:**
   - Claims to Verify: `exp` (agregar)
   - Key Claim Name: `iss`
   - Run on Preflight: ❌ Disabled
   - Tags: `auth, ext-talenthub-ats`
5. Click **Submit**
6. **Repetir para QA y PROD**

#### Paso 7: Agregar Plugin Request Transformer

1. Dentro del service `ext-talenthub-ats-dev`, tab **Plugins**
2. Click **+ Add Plugin**
3. Buscar y seleccionar **Request Transformer**
4. **Configurar:**
   - **Add Headers:** `x-api-key:GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu`
   - **Replace URI:** `/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f`
   - Tags: `transformer, ext-talenthub-ats`
5. Click **Submit**
6. **Repetir para QA y PROD**

#### Paso 8: (Solo PROD) Agregar Plugin Rate Limiting

1. Dentro del service `ext-talenthub-ats-prod`, tab **Plugins**
2. Click **+ Add Plugin**
3. Buscar y seleccionar **Rate Limiting**
4. **Configurar:**
   - Minute: `100`
   - Hour: `1000`
   - Policy: `local`
   - Tags: `rate-limit, prod`
5. Click **Submit**

#### Paso 9: Verificar Configuración en Konga

**Revisar:**

1. **Dashboard** → Debe mostrar 3 services (dev, qa, prod)
2. **Services** → Cada uno debe tener:
   - 1 route configurada
   - 2 plugins (JWT + Request Transformer)
   - PROD debe tener 3 plugins (+ Rate Limiting)
3. **Consumers** → `tlm-pe-realm` debe tener 1 credencial JWT

---

### Checklist de Configuración Manual

#### Consumer

- [ ] Consumer `tlm-pe-realm` creado
- [ ] Credencial JWT agregada con:
  - [ ] Key (iss): URL de Keycloak realm
  - [ ] Algorithm: RS256
  - [ ] JWKS URI configurado

#### Services (x3: dev, qa, prod)

- [ ] Service `ext-talenthub-ats-dev` creado
- [ ] Service `ext-talenthub-ats-qa` creado
- [ ] Service `ext-talenthub-ats-prod` creado
- [ ] Cada uno apunta a `https://api-ats.talenthub.pe`

#### Routes (x3: dev, qa, prod)

- [ ] Route `/api-dev/gestal/ats` → ext-talenthub-ats-dev
- [ ] Route `/api-qa/gestal/ats` → ext-talenthub-ats-qa
- [ ] Route `/api/gestal/ats` → ext-talenthub-ats-prod
- [ ] Strip path habilitado en todas

#### Plugins JWT (x3: dev, qa, prod)

- [ ] Plugin JWT en ext-talenthub-ats-dev
- [ ] Plugin JWT en ext-talenthub-ats-qa
- [ ] Plugin JWT en ext-talenthub-ats-prod
- [ ] Verifica claim `exp` en todos
- [ ] Key claim name: `iss` en todos

#### Plugins Request Transformer (x3: dev, qa, prod)

- [ ] Plugin Request Transformer en ext-talenthub-ats-dev
- [ ] Plugin Request Transformer en ext-talenthub-ats-qa
- [ ] Plugin Request Transformer en ext-talenthub-ats-prod
- [ ] Header `x-api-key` agregado en todos
- [ ] URI transformada correctamente en todos

#### Rate Limiting (solo PROD)

- [ ] Plugin Rate Limiting en ext-talenthub-ats-prod
- [ ] Límite: 100 req/min, 1000 req/hour

#### Verificación Final

- [ ] Test de obtención de token de Keycloak exitoso
- [ ] Test de llamada a Kong con JWT exitoso
- [ ] Test de respuesta de TalentHub ATS exitoso
- [ ] Kong logs muestran requests correctamente
- [ ] Rate limiting funciona en PROD (test con 101 requests)

---

## Configuración Kong (ya implementada)

> **✅ TODO ESTÁ CONFIGURADO:** Los 4 archivos Kong YAML ya contienen toda la configuración necesaria para la integración Gestal-ATS. Solo necesitas desplegar con `docker compose up -d kong-deck-bootstrap`.

### Archivos Configurados

- `config/kong/kong-dev.yaml` - Ambiente DEV
- `config/kong/kong-nonprod.yaml` - Ambientes DEV + QA compartidos
- `config/kong/kong-qa.yaml` - Ambiente QA standalone
- `config/kong/kong-prod.yaml` - Ambiente PROD

### Configuración Completa Incluida

#### ✅ 1. Consumers con JWKS

```yaml
consumers:
- username: tlm-pe-realm
  tags: [jwt, peru]
  jwt_secrets:
  - key: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe"
    algorithm: RS256
    jwks_uri: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/certs"
```

**Qué hace:**

- Consumer `tlm-pe-realm` valida JWTs del realm Keycloak `tlm-pe`
- JWKS habilitado para rotación automática de claves
- Algoritmo RS256 (firma asimétrica segura)

#### ✅ 2. Service ext-talenthub-ats-{env}

```yaml
services:
- name: ext-talenthub-ats-dev
  url: https://api-ats.talenthub.pe
  tags: [external, talenthub, third-party, dev]
```

**Qué hace:**

- Service apunta directamente a TalentHub ATS API
- Tags identifican servicio externo de tercero
- Configurado en 3 ambientes: dev, qa, prod

#### ✅ 3. Routes por Ambiente

```yaml
routes:
- name: ext-talenthub-ats-dev-route
  paths: [/api-dev/gestal/ats]    # DEV
  strip_path: true
  preserve_host: false
```

**Qué hace:**

- DEV: `/api-dev/gestal/ats` → TalentHub
- QA: `/api-qa/gestal/ats` → TalentHub
- PROD: `/api/gestal/ats` → TalentHub
- `strip_path: true` elimina el path antes de enviar a TalentHub

#### ✅ 4. Plugin JWT (Validación)

```yaml
plugins:
- name: jwt
  config:
    claims_to_verify: [exp]
    key_claim_name: iss
    run_on_preflight: false
  tags: [auth, ext-talenthub-ats]
```

**Qué hace:**

- Valida firma del JWT con JWKS de Keycloak
- Verifica claim `exp` (expiración)
- Valida claim `iss` (issuer) contra consumer
- Rechaza tokens expirados o inválidos (401)

#### ✅ 5. Plugin Request-Transformer (Inyección)

```yaml
- name: request-transformer
  config:
    add:
      headers: [x-api-key:GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu]
    replace:
      uri: /ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f
  tags: [transformer, ext-talenthub-ats]
```

**Qué hace:**

- Inyecta header `x-api-key` de TalentHub automáticamente
- Transforma URI al formato esperado por TalentHub
- El cliente NO necesita conocer el x-api-key

#### ✅ 6. Plugin Rate-Limiting (Solo PROD)

```yaml
- name: rate-limiting
  config:
    minute: 100
    hour: 1000
    policy: local
  tags: [rate-limit, prod]
```

**Qué hace:**

- Limita a 100 requests por minuto
- Limita a 1000 requests por hora
- Protege contra abuso y errores de integración
- Solo activo en PROD

### Resumen de Cobertura

| Característica | DEV | QA | PROD | Archivo |
|----------------|:---:|:--:|:----:|---------|
| Consumer `tlm-pe-realm` | ✅ | ✅ | ✅ | Todos |
| JWKS rotación automática | ✅ | ✅ | ✅ | Todos |
| Service `ext-talenthub-ats-*` | ✅ | ✅ | ✅ | Todos |
| Route `/api-*/gestal/ats` | ✅ | ✅ | ✅ | Todos |
| Plugin JWT validación | ✅ | ✅ | ✅ | Todos |
| Plugin Request-Transformer | ✅ | ✅ | ✅ | Todos |
| Plugin Rate-Limiting | ❌ | ❌ | ✅ | kong-prod.yaml |

### Comparación: Configuración Manual vs Automática

| Aspecto | Manual (Kong Admin API / Konga) | Automática (YAML + decK) |
|---------|----------------------------------|--------------------------|
| **Tiempo setup** | ~30-45 minutos | ~2 minutos |
| **Errores humanos** | Alto (copy/paste, typos) | Bajo (validado por decK) |
| **Reproducibilidad** | Difícil (clickops) | Fácil (git + CI/CD) |
| **Versionado** | No (configuración vive en BD) | Sí (Git history completo) |
| **Rollback** | Manual (revertir cambios) | Automático (git revert) |
| **Multi-ambiente** | Repetir 3 veces (dev/qa/prod) | 1 comando para todos |
| **Code Review** | No disponible | Pull Request + aprobación |
| **Documentación** | Se desincroniza | Código = documentación |
| **Auditoría** | Logs de Kong solamente | Git commits + Kong logs |
| **Disaster Recovery** | Backup de BD Kong | Git clone |

### Cómo Desplegar (1 comando)

**Para DEV:**

```bash
cd /mnt/d/dev/work/talma/tlm-infra-api-gateway
docker compose up -d kong-deck-bootstrap
```

**Para QA:**

```bash
docker compose -f docker-compose.yml -f docker-compose.qa.yml up -d kong-deck-bootstrap
```

**Para PROD:**

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d kong-deck-bootstrap
```

**Verificar despliegue:**

```bash
docker compose logs kong-deck-bootstrap
# Debe mostrar: "successfully synced configuration"
```

### ⚠️ Comportamiento con Configuraciones Existentes

**Kong decK usa sincronización declarativa (no incremental):**

#### Escenario 1: Configuración con el Mismo Nombre

Si ya existe un service/route/plugin con el mismo nombre:

✅ **Kong decK actualiza la configuración existente**

- Compara el YAML con lo que hay en Kong
- Aplica solo los cambios (diff)
- Preserva el ID interno del recurso
- No duplica, solo actualiza

**Ejemplo:**

```yaml
# Si Kong tiene:
services:
- name: ext-talenthub-ats-dev
  url: https://old-url.com  # URL antigua

# Y tu YAML tiene:
services:
- name: ext-talenthub-ats-dev
  url: https://api-ats.talenthub.pe  # URL nueva

# Kong decK hace:
# ✅ UPDATE service ext-talenthub-ats-dev
#    url: https://old-url.com → https://api-ats.talenthub.pe
```

#### Escenario 2: Configuración No Definida en YAML

**⚠️ IMPORTANTE:** Kong decK **elimina** recursos que existen en Kong pero no están en el YAML.

```yaml
# Kong tiene:
- service A (en YAML) ✅ se mantiene
- service B (en YAML) ✅ se mantiene
- service C (NO en YAML) ❌ SE ELIMINA
```

**Esto es intencional:** El YAML es la "fuente de verdad".

#### Escenario 3: Primera Ejecución (Kong Vacío)

Si Kong está vacío o recién instalado:

✅ **Kong decK crea todos los recursos desde cero**

- Consumers
- Services
- Routes
- Plugins

#### Escenario 4: Re-ejecutar sin Cambios

Si ejecutas `deck sync` sin cambiar el YAML:

✅ **Kong decK no hace nada**

```
Summary:
  Created: 0
  Updated: 0
  Deleted: 0
```

Kong detecta que no hay diferencias.

### Comandos Útiles de decK

**Ver diferencias sin aplicar (dry-run):**

```bash
docker compose run --rm kong-deck-bootstrap deck diff
```

**Resultado ejemplo:**

```diff
updating service ext-talenthub-ats-dev  {
-  "url": "https://old-url.com"
+  "url": "https://api-ats.talenthub.pe"
}
```

**Ver configuración actual de Kong:**

```bash
docker compose run --rm kong-deck-bootstrap deck dump
```

**Generar YAML desde Kong actual (backup):**

```bash
docker compose run --rm kong-deck-bootstrap deck dump -o backup-$(date +%Y%m%d).yaml
```

**Validar YAML antes de aplicar:**

```bash
docker compose run --rm kong-deck-bootstrap deck validate
```

### Estrategia Recomendada

**Antes de hacer `deck sync` por primera vez:**

1. **Backup de configuración actual:**

   ```bash
   docker compose run --rm kong-deck-bootstrap deck dump -o backup-antes-ats.yaml
   ```

2. **Ver qué va a cambiar:**

   ```bash
   docker compose run --rm kong-deck-bootstrap deck diff
   ```

3. **Si todo se ve bien, aplicar:**

   ```bash
   docker compose up -d kong-deck-bootstrap
   ```

4. **Verificar que funcionó:**

   ```bash
   docker compose logs kong-deck-bootstrap | grep -i "successfully synced"
   ```

### Protección de Recursos Importantes

**Si quieres evitar que decK elimine ciertos recursos:**

Opción 1: **Incluirlos en el YAML** (recomendado)

Opción 2: **Tags de exclusión** (en docker-compose.yml):

```yaml
command: deck sync --select-tag managed-by-deck
```

Solo sincroniza recursos con ese tag.

Opción 3: **Modo no-destructivo** (no elimina):

```yaml
command: deck sync --skip-consumers --no-mask-deck-env-vars
```

### Casos de Conflicto

#### Conflicto 1: Nombres Duplicados en el YAML

❌ **No permitido:**

```yaml
services:
- name: ext-talenthub-ats-dev
  url: https://url1.com
- name: ext-talenthub-ats-dev  # ❌ ERROR: nombre duplicado
  url: https://url2.com
```

**Error de decK:** "duplicate resource"

#### Conflicto 2: Cambio de ID en YAML

Kong usa IDs internos, pero el YAML usa nombres.

✅ **No hay problema:** decK resuelve por nombre, no por ID.

#### Conflicto 3: Recursos Creados Manualmente en Konga

Si creaste recursos en Konga que **no están en el YAML:**

⚠️ **Se eliminarán** en el próximo `deck sync`

**Solución:**

1. Exportar configuración de Kong: `deck dump`
2. Agregar esos recursos al YAML
3. Hacer `deck sync`

### Ejemplo Real: Actualización de x-api-key

**Situación:** Necesitas rotar el x-api-key de TalentHub

**Paso 1: Actualizar YAML**

```yaml
# En kong-prod.yaml
- name: request-transformer
  config:
    add:
      headers:
      - x-api-key:NUEVA_API_KEY_AQUI  # ✅ Cambiar valor
```

**Paso 2: Aplicar**

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d kong-deck-bootstrap
```

**Paso 3: Verificar**

```bash
docker compose logs kong-deck-bootstrap
# Debe mostrar: "updating plugin request-transformer"
```

✅ **Resultado:** x-api-key actualizado sin downtime.

### Diagrama de Flujo: deck sync

```
┌─────────────────────────────────────────────────────┐
│  ARCHIVOS YAML (Fuente de Verdad)                  │
│  - kong-dev.yaml                                    │
│  - kong-qa.yaml                                     │
│  - kong-prod.yaml                                   │
└────────────────┬────────────────────────────────────┘
                 │
                 │ deck sync
                 ▼
┌─────────────────────────────────────────────────────┐
│  KONG decK DIFF ENGINE                              │
│  1. Lee YAML                                        │
│  2. Lee configuración actual de Kong (DB)           │
│  3. Compara (diff)                                  │
└────────────────┬────────────────────────────────────┘
                 │
      ┌──────────┴──────────┐
      │                     │
      ▼                     ▼
┌──────────┐         ┌──────────┐
│ CAMBIOS  │         │ NO HAY   │
│ DETECTADOS│         │ CAMBIOS  │
└─────┬────┘         └────┬─────┘
      │                   │
      │                   └─► No hace nada
      │                       (idempotente)
      │
      ├─► CREAR (si no existe)
      │   - Nuevo consumer
      │   - Nuevo service
      │   - Nuevo plugin
      │
      ├─► ACTUALIZAR (si existe con cambios)
      │   - Cambia URL de service
      │   - Actualiza config de plugin
      │   - Modifica route paths
      │
      └─► ELIMINAR (si existe en Kong pero no en YAML)
          - Service no definido
          - Plugin eliminado del YAML
          - Consumer removido
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│  KONG DATABASE (Actualizado)                       │
│  Configuración sincronizada con YAML               │
└─────────────────────────────────────────────────────┘
```

### Casos de Uso Frecuentes

#### ✅ Caso 1: Agregar Nuevo Ambiente

**Situación:** Quieres agregar staging entre QA y PROD

**Paso 1:** Crear `kong-staging.yaml`

```yaml
# Copiar de kong-qa.yaml y modificar tags/paths
services:
- name: ext-talenthub-ats-staging
  url: https://api-ats.talenthub.pe
  routes:
  - paths: [/api-staging/gestal/ats]
```

**Paso 2:** Ejecutar

```bash
docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d kong-deck-bootstrap
```

✅ **Resultado:** Nuevo ambiente sin afectar DEV/QA/PROD

#### ✅ Caso 2: Modificar Configuración Existente

**Situación:** Cambiar rate limiting de 100 a 200 req/min

**Paso 1:** Editar `kong-prod.yaml`

```yaml
- name: rate-limiting
  config:
    minute: 200  # Antes: 100
    hour: 2000   # Antes: 1000
```

**Paso 2:** Aplicar

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d kong-deck-bootstrap
```

✅ **Resultado:** Plugin actualizado, conexiones existentes no se interrumpen

#### ✅ Caso 3: Eliminar Plugin Temporal

**Situación:** Quitaste un plugin de debug del YAML

**Antes (en YAML):**

```yaml
plugins:
- name: jwt
- name: request-transformer
- name: http-log  # Plugin temporal para debug
```

**Después (en YAML):**

```yaml
plugins:
- name: jwt
- name: request-transformer
# Plugin http-log eliminado
```

**Ejecutar:** `deck sync`

✅ **Resultado:** Plugin http-log eliminado de Kong

#### ⚠️ Caso 4: Proteger Configuración Manual

**Situación:** Tienes plugins configurados manualmente en Konga que NO quieres que decK elimine

**Opción A:** Agregar al YAML (recomendado)

```yaml
# Exportar primero
deck dump -o current-config.yaml

# Copiar plugins manuales al YAML oficial
# Hacer commit en Git
```

**Opción B:** Usar tags de exclusión

```yaml
# En docker-compose.yml
command: deck sync --select-tag automated --skip-consumers
```

Solo sincroniza recursos con tag `automated`.

### FAQ: Configuraciones Existentes

**Q: ¿Se pierden las conexiones activas al hacer sync?**
A: No. Kong aplica cambios sin downtime (hot reload).

**Q: ¿Puedo hacer rollback si algo sale mal?**
A: Sí, 3 formas:

1. Git: `git revert` + `deck sync`
2. Backup: `deck sync -s backup.yaml`
3. Manual: Restaurar en Konga

**Q: ¿decK elimina datos de aplicación?**
A: No. Solo configuración de Kong (routes, plugins). Los datos de tu app no se tocan.

**Q: ¿Qué pasa con plugins de terceros?**
A: decK los soporta si están instalados en Kong. Solo los incluye en el YAML.

**Q: ¿Puedo hacer sync parcial?**
A: Sí, con tags:

```bash
deck sync --select-tag gestal-ats  # Solo recursos con ese tag
```

**Q: ¿Se puede usar decK en producción?**
A: Sí, es el método recomendado por Kong. Usado por miles de empresas.

**Q: ¿Cómo revierto un cambio malo?**
A: Usa el backup que hiciste antes:

```bash
deck sync -s backup-antes-ats.yaml
```

### Lo Que NO Necesitas Hacer

❌ Crear consumers manualmente
❌ Copiar/pegar claves públicas RSA
❌ Configurar plugins uno por uno
❌ Repetir configuración en 3 ambientes
❌ Recordar settings específicos
❌ Documentar qué configuraste

**Todo ya está en los archivos YAML** ✅

---

### Ejemplo de Configuración YAML (Referencia)

**Extracto de `kong-dev.yaml`:**

```yaml
# Consumer con JWKS
consumers:
- username: tlm-pe-realm
  jwt_secrets:
  - key: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe"
    algorithm: RS256
    jwks_uri: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/certs"

services:
# Service TalentHub ATS
- name: ext-talenthub-ats-dev
  url: https://api-ats.talenthub.pe
  tags: [external, talenthub, third-party, dev]
  routes:
  - name: ext-talenthub-ats-dev-route
    paths: [/api-dev/gestal/ats]
    strip_path: true
  plugins:
  # Plugin 1: JWT Validation
  - name: jwt
    config:
      claims_to_verify: [exp]
      key_claim_name: iss
  # Plugin 2: Request Transformer
  - name: request-transformer
    config:
      add:
        headers: [x-api-key:GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu]
      replace:
        uri: /ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f
```

**Ver archivos completos en:**

- [`config/kong/kong-dev.yaml`](../config/kong/kong-dev.yaml)
- [`config/kong/kong-qa.yaml`](../config/kong/kong-qa.yaml)
- [`config/kong/kong-prod.yaml`](../config/kong/kong-prod.yaml)

---

## Configuración Declarativa vs Manual

### ¿Cuándo usar YAML declarativo? (Recomendado)

✅ **Siempre, especialmente cuando:**

- Trabajas en equipo (code review)
- Necesitas multi-ambiente (DEV/QA/PROD)
- Quieres versionado en Git
- Requieres automatización (CI/CD)
- Necesitas disaster recovery rápido
- Quieres documentación sincronizada

### ¿Cuándo usar configuración manual?

⚠️ **Solo en casos específicos:**

- Debugging en tiempo real (Konga UI)
- Prototipado rápido (Kong Admin API)
- Verificación de configuración actual
- Learning/exploración de opciones

**Nota:** La configuración manual NO se persiste en Git y se puede perder si la base de datos de Kong se corrompe.

---

## Próximos Pasos

### 1. Configurar Keycloak

Seguir la sección [Configuración Keycloak](#configuración-keycloak) para crear los clients:

- `gestal-pe-dev`
- `gestal-pe-qa`
- `gestal-pe-prod`

### 2. Desplegar Kong

```bash
docker compose up -d kong-deck-bootstrap
```

### 3. Configurar Aplicación Gestal

Seguir la sección [Configuración de Aplicación](#configuración-de-aplicación) para:

- Variables de entorno
- Código para obtener token
- Código para llamar a ATS

### 4. Testing

Ejecutar los tests de la sección [Testing](#testing):

- Obtener token de Keycloak
- Llamar a Kong con JWT
- Verificar respuesta de TalentHub

---

## Resumen Ejecutivo

**Estado actual de la integración Gestal-ATS:**

✅ **Configuración Kong:** 100% completa en archivos YAML
✅ **Consumers:** Configurados con JWKS rotación automática
✅ **Services:** 3 ambientes (DEV, QA, PROD)
✅ **Routes:** Paths correctos por ambiente
✅ **Plugins JWT:** Validación RS256 configurada
✅ **Plugins Transformer:** x-api-key + URI transformation
✅ **Rate Limiting:** Activo en PROD (100/min, 1000/hour)
✅ **Documentación:** Completa con ejemplos de código

⏸️ **Pendiente:**

- Crear clients en Keycloak (15 minutos)
- Desplegar Kong con decK (2 minutos)
- Configurar aplicación Gestal (30 minutos)
- Testing end-to-end (20 minutos)

**Tiempo total de implementación:** ~1 hora

---

## Configuración Manual Detallada (Opcional)

services:

- name: gestal-pe-dev
  url: <http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com>
  routes:
  - name: gestal-pe-dev-route
    paths:
    - /api-dev/gestal
    strip_path: false
  plugins:
  - name: jwt
    config:
      claims_to_verify: [exp]
      key_claim_name: iss
  - name: request-transformer
    config:
      add:
        headers:
        - X-Forwarded-Authorization:$(headers.Authorization)

```

**Cliente externo llama:**

```bash
curl -X POST http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/ats/posiciones \
  -H "Authorization: Bearer <jwt-token-from-keycloak>" \
  -H "Content-Type: application/json" \
  -d '{
    "posicion_solicitada": "Facturador ATC Senior",
    "cantidad_de_vacantes": 2,
    ...
  }'
```

**Kong → Backend Gestal:**

```bash
POST http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/ats/posiciones
X-Forwarded-Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "posicion_solicitada": "Facturador ATC Senior",
  "cantidad_de_vacantes": 2,
  ...
}
```

**Backend Gestal → TalentHub ATS:**

```bash
POST https://api-ats.talenthub.pe/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f
x-api-key: GRFbBhN2ql6u2QT4M5hQU3bYxr6EMOoP30mWEzpu
Content-Type: application/json

{
  "current_username": "talmaconfiguracionats@gmail.com",
  "posicion_solicitada": "Facturador ATC Senior",
  ...
}
```

---

## Configuración de Aplicación

### Variables de Entorno

**Configurar en tu aplicación Gestal:**

```bash
# Keycloak Configuration
KEYCLOAK_URL=http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth
KEYCLOAK_REALM=tlm-pe
KEYCLOAK_CLIENT_ID=gestal-pe-dev        # Cambiar según ambiente: dev, qa, prod
KEYCLOAK_CLIENT_SECRET=<secret-from-keycloak>

# Kong API Gateway
KONG_API_URL=http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev  # Cambiar según ambiente
# DEV:  http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev
# QA:   http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-qa
# PROD: http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api

# ATS Configuration
ATS_CURRENT_USERNAME=talmaconfiguracionats@gmail.com
```

### Implementación en Código

#### Opción 1: Node.js / TypeScript

```javascript
const axios = require('axios');

/**
 * Obtiene un token JWT de Keycloak usando client_credentials grant
 * @returns {Promise<string>} JWT access token
 */
async function getKeycloakToken() {
  const params = new URLSearchParams();
  params.append('grant_type', 'client_credentials');
  params.append('client_id', process.env.KEYCLOAK_CLIENT_ID);
  params.append('client_secret', process.env.KEYCLOAK_CLIENT_SECRET);

  try {
    const response = await axios.post(
      `${process.env.KEYCLOAK_URL}/realms/${process.env.KEYCLOAK_REALM}/protocol/openid-connect/token`,
      params,
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      }
    );

    return response.data.access_token;
  } catch (error) {
    console.error('Error obteniendo token de Keycloak:', error.response?.data || error.message);
    throw new Error('No se pudo obtener token de autenticación');
  }
}

/**
 * Crea una nueva posición en TalentHub ATS vía Kong
 * @param {Object} posicionData - Datos de la posición a crear
 * @returns {Promise<Object>} Respuesta de TalentHub ATS
 */
async function crearPosicionATS(posicionData) {
  try {
    // 1. Obtener token de Keycloak
    const token = await getKeycloakToken();

    // 2. Preparar datos con current_username
    const payload = {
      current_username: process.env.ATS_CURRENT_USERNAME,
      ...posicionData
    };

    // 3. Llamar a Kong API Gateway
    const response = await axios.post(
      `${process.env.KONG_API_URL}/api-dev/gestal/ats/posiciones`,
      payload,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000 // 30 segundos
      }
    );

    return response.data;
  } catch (error) {
    if (error.response) {
      console.error('Error en llamada a ATS:', error.response.status, error.response.data);
      throw new Error(`Error ATS: ${error.response.data.message || error.response.statusText}`);
    } else {
      console.error('Error de red:', error.message);
      throw new Error('Error de comunicación con el servicio ATS');
    }
  }
}

/**
 * Ejemplo de uso con caché de token (recomendado para producción)
 */
class ATSService {
  constructor() {
    this.tokenCache = null;
    this.tokenExpiry = null;
  }

  async getToken() {
    // Renovar token si expiró (con 30 segundos de margen)
    if (!this.tokenCache || Date.now() >= this.tokenExpiry - 30000) {
      this.tokenCache = await getKeycloakToken();
      // Tokens de Keycloak expiran en 5 minutos por defecto
      this.tokenExpiry = Date.now() + (5 * 60 * 1000);
    }
    return this.tokenCache;
  }

  async crearPosicion(posicionData) {
    const token = await this.getToken();

    const payload = {
      current_username: process.env.ATS_CURRENT_USERNAME,
      ...posicionData
    };

    const response = await axios.post(
      `${process.env.KONG_API_URL}/api-dev/gestal/ats/posiciones`,
      payload,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      }
    );

    return response.data;
  }
}

// Exportar instancia singleton
module.exports = new ATSService();
```

**Uso:**

```javascript
const atsService = require('./services/atsService');

// En tu controlador/handler
app.post('/api/posiciones', async (req, res) => {
  try {
    const resultado = await atsService.crearPosicion({
      posicion_solicitada: req.body.posicion,
      cantidad_de_vacantes: req.body.vacantes,
      gerencia: req.body.gerencia,
      tipo_convocatoria: req.body.tipo_convocatoria,
      definicion_tipo_convocatoria: req.body.definicion_tipo_convocatoria,
      estaciones: req.body.estaciones,
      area: req.body.area,
      motivo: req.body.motivo,
      nombre_persona_reemplazar: req.body.nombre_persona_reemplazar,
      cliente: req.body.cliente,
      definicion_cliente: req.body.definicion_cliente,
      especialidad: req.body.especialidad,
      ejem_especialidad: req.body.ejem_especialidad,
      tipo_contrato: req.body.tipo_contrato,
      jornada_laboral: req.body.jornada_laboral
    });

    res.json({
      success: true,
      vacante_id: resultado.vacante_id,
      message: 'Posición creada exitosamente en ATS'
    });
  } catch (error) {
    console.error('Error creando posición:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});
```

#### Opción 2: Python

```python
import os
import requests
from datetime import datetime, timedelta
from typing import Dict, Optional

class ATSService:
    """Servicio para interactuar con TalentHub ATS vía Kong API Gateway"""

    def __init__(self):
        self.keycloak_url = os.getenv('KEYCLOAK_URL')
        self.keycloak_realm = os.getenv('KEYCLOAK_REALM')
        self.client_id = os.getenv('KEYCLOAK_CLIENT_ID')
        self.client_secret = os.getenv('KEYCLOAK_CLIENT_SECRET')
        self.kong_api_url = os.getenv('KONG_API_URL')
        self.ats_username = os.getenv('ATS_CURRENT_USERNAME')

        # Cache de token
        self._token_cache: Optional[str] = None
        self._token_expiry: Optional[datetime] = None

    def get_token(self) -> str:
        """Obtiene token JWT de Keycloak con caché"""
        # Renovar si expiró (con 30 segundos de margen)
        if not self._token_cache or datetime.now() >= self._token_expiry - timedelta(seconds=30):
            self._token_cache = self._fetch_new_token()
            # Tokens expiran en 5 minutos
            self._token_expiry = datetime.now() + timedelta(minutes=5)

        return self._token_cache

    def _fetch_new_token(self) -> str:
        """Obtiene un nuevo token de Keycloak"""
        token_url = f"{self.keycloak_url}/realms/{self.keycloak_realm}/protocol/openid-connect/token"

        data = {
            'grant_type': 'client_credentials',
            'client_id': self.client_id,
            'client_secret': self.client_secret
        }

        try:
            response = requests.post(token_url, data=data, timeout=10)
            response.raise_for_status()
            return response.json()['access_token']
        except requests.exceptions.RequestException as e:
            raise Exception(f"Error obteniendo token de Keycloak: {str(e)}")

    def crear_posicion(self, posicion_data: Dict) -> Dict:
        """Crea una nueva posición en TalentHub ATS"""
        token = self.get_token()

        # Agregar current_username
        payload = {
            'current_username': self.ats_username,
            **posicion_data
        }

        # Determinar ambiente basado en KONG_API_URL
        if 'api-dev' in self.kong_api_url:
            env_path = '/api-dev/gestal/ats/posiciones'
        elif 'api-qa' in self.kong_api_url:
            env_path = '/api-qa/gestal/ats/posiciones'
        else:
            env_path = '/api/gestal/ats/posiciones'

        url = f"{self.kong_api_url}{env_path}"

        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }

        try:
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            if hasattr(e, 'response') and e.response is not None:
                raise Exception(f"Error ATS: {e.response.status_code} - {e.response.text}")
            raise Exception(f"Error de comunicación con ATS: {str(e)}")

# Instancia singleton
ats_service = ATSService()
```

**Uso:**

```python
from services.ats_service import ats_service
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/api/posiciones', methods=['POST'])
def crear_posicion():
    try:
        data = request.get_json()

        resultado = ats_service.crear_posicion({
            'posicion_solicitada': data['posicion'],
            'cantidad_de_vacantes': data['vacantes'],
            'gerencia': data['gerencia'],
            'tipo_convocatoria': data['tipo_convocatoria'],
            'definicion_tipo_convocatoria': data['definicion_tipo_convocatoria'],
            'estaciones': data['estaciones'],
            'area': data['area'],
            'motivo': data['motivo'],
            'nombre_persona_reemplazar': data.get('nombre_persona_reemplazar', 'N/A'),
            'cliente': data['cliente'],
            'definicion_cliente': data['definicion_cliente'],
            'especialidad': data['especialidad'],
            'ejem_especialidad': data['ejem_especialidad'],
            'tipo_contrato': data['tipo_contrato'],
            'jornada_laboral': data['jornada_laboral']
        })

        return jsonify({
            'success': True,
            'vacante_id': resultado['vacante_id'],
            'message': 'Posición creada exitosamente en ATS'
        })

    except Exception as e:
        app.logger.error(f'Error creando posición: {str(e)}')
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500
```

---

## Testing

### 1. Test Manual con cURL

**Paso 1: Obtener token JWT de Keycloak**

```bash
TOKEN=$(curl -s -X POST "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=gestal-pe-dev" \
  -d "client_secret=<TU_CLIENT_SECRET>" \
  -d "grant_type=client_credentials" \
  | jq -r '.access_token')

echo "Token obtenido: ${TOKEN:0:50}..."
```

**Paso 2: Llamar al API Gateway Kong**

```bash
curl -X POST http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/ats/posiciones \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "current_username": "talmaconfiguracionats@gmail.com",
    "posicion_solicitada": "Desarrollador Backend Senior",
    "cantidad_de_vacantes": 2,
    "gerencia": "Tecnología",
    "tipo_convocatoria": "Externo",
    "definicion_tipo_convocatoria": "Abierta para personal fuera de la compañía",
    "estaciones": "Lima",
    "area": "Desarrollo de Software",
    "motivo": "Expansión del equipo",
    "nombre_persona_reemplazar": "N/A",
    "cliente": "Interno",
    "definicion_cliente": "TALMA",
    "especialidad": "Backend Development",
    "ejem_especialidad": "Node.js, Python, Microservices",
    "tipo_contrato": "Plazo indefinido",
    "jornada_laboral": "Tiempo completo 8h"
  }'
```

**Respuesta esperada:**

```json
{
  "status": "success",
  "message": "Posición creada correctamente",
  "vacante_id": "66f89de6c3b48b7f2d92e45b"
}
```

### 2. Test de Validación JWT

**Verificar que Kong valida correctamente el JWT:**

```bash
# Test con token inválido (debe fallar)
curl -X POST http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/ats/posiciones \
  -H "Authorization: Bearer token_invalido" \
  -H "Content-Type: application/json" \
  -d '{"posicion_solicitada": "Test"}'

# Respuesta esperada: 401 Unauthorized
```

**Verificar que Kong valida expiración:**

```bash
# Esperar 5+ minutos y reusar token antiguo (debe fallar)
curl -X POST http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/ats/posiciones \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{...}'

# Respuesta esperada: 401 Unauthorized (token expirado)
```

### 3. Test de Rate Limiting (PROD)

**En ambiente PROD, Kong limita a 100 req/min:**

```bash
# Ejecutar 101 requests rápidamente
for i in {1..101}; do
  curl -s -X POST http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api/gestal/ats/posiciones \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{...}' &
done

# Algunos requests deben retornar: 429 Too Many Requests
```

### 4. Verificar logs

**En Kong:**

```bash
docker compose logs kong | grep -i "ext-talenthub-ats"
```

**Buscar:**

- ✅ JWT validation success
- ✅ Request transformed
- ✅ Response 200 from TalentHub

### 3. Verificar respuesta completa

```json
{
  "status": "success",
  "message": "Posición creada correctamente",
  "vacante_id": "66f89de6c3b48b7f2d92e45b"
}
```

---

## Seguridad

### ✅ Controles Implementados

#### 1. Autenticación y Autorización

- **JWT RS256**: Tokens firmados con clave asimétrica (más seguro que HMAC)
- **JWKS**: Rotación automática de claves públicas sin downtime
- **Client Credentials**: Grant type apropiado para comunicación server-to-server
- **Token Expiration**: Tokens expiran en 5 minutos (configurable en Keycloak)
- **Issuer Validation**: Kong valida claim `iss` para prevenir token replay attacks

#### 2. Secretos y Credenciales

- **Client Secret**: Almacenado en variables de entorno (nunca en código)
- **x-api-key de TalentHub**: Inyectado por Kong (no expuesto al cliente)
- **Separación de ambientes**: Credenciales diferentes para DEV/QA/PROD

#### 3. Network Security

- **HTTPS**: Comunicación encriptada Cliente ↔ Kong
- **Rate Limiting**: PROD limitado a 100 req/min, 1000 req/hour
- **Strip Path**: Kong normaliza rutas antes de enviar a backend

#### 4. Auditoría

- **Kong Access Logs**: Registra todas las llamadas con timestamps
- **JWT Claims**: Identifican qué client hizo cada llamada (`azp` claim)
- **TalentHub**: Registra `current_username` para trazabilidad

### ⚠️ Recomendaciones Adicionales

#### Mejoras de Seguridad

1. **Secrets Manager**

   ```bash
   # En lugar de variables de entorno planas, usar:
   # - AWS Secrets Manager
   # - HashiCorp Vault
   # - Azure Key Vault

   # Ejemplo con AWS Secrets Manager:
   CLIENT_SECRET=$(aws secretsmanager get-secret-value \
     --secret-id gestal/keycloak/dev/client-secret \
     --query SecretString --output text)
   ```

2. **Rotación de Credenciales**
   - `client_secret` de Keycloak: rotar cada 90 días
   - `x-api-key` de TalentHub: coordinar rotación con proveedor
   - Documentar procedimiento en runbook

3. **Monitoreo y Alertas**

   ```yaml
   Alertas recomendadas:
   - Tasa de errores 401 > 5% (posible ataque)
   - Tasa de errores 429 > 10% (rate limit alcanzado)
   - Latencia > 5 segundos (TalentHub lento/caído)
   - Tasa de errores 500 de TalentHub > 1%
   ```

4. **Circuit Breaker**
   - Implementar en aplicación Gestal
   - Si TalentHub falla 5 veces consecutivas, abrir circuito
   - Retornar error amigable al usuario
   - Reintentar después de 60 segundos

5. **Validación de Input**

   ```javascript
   // Validar datos antes de enviar a ATS
   const schema = Joi.object({
     posicion_solicitada: Joi.string().min(5).max(200).required(),
     cantidad_de_vacantes: Joi.number().integer().min(1).max(50).required(),
     gerencia: Joi.string().required(),
     // ... resto de validaciones
   });

   const { error, value } = schema.validate(posicionData);
   if (error) throw new ValidationError(error.details);
   ```

6. **Rate Limiting por Usuario**
   - Implementar en aplicación Gestal
   - Limitar a X posiciones por usuario por día
   - Prevenir abuso o errores de integración

### 🔒 Checklist de Seguridad

**Antes de ir a Producción:**

- [ ] Client secrets almacenados en secrets manager (no en .env)
- [ ] HTTPS configurado con certificados válidos
- [ ] Rate limiting activado en Kong PROD
- [ ] Logs de auditoría funcionando
- [ ] Alertas de monitoreo configuradas
- [ ] Procedimiento de rotación de credenciales documentado
- [ ] Tests de penetración ejecutados
- [ ] Plan de respuesta a incidentes documentado
- [ ] Backup de configuraciones Kong y Keycloak
- [ ] Contactos de TalentHub para emergencias documentados

---

## Anexo: URLs del Entorno

### DNS Temporal (Desarrollo/Testing)

**Load Balancer Base:** `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com`

#### Keycloak

```
Base URL: http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth
Admin Console: http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/admin
Realm tlm-pe: http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe
Token Endpoint: http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/token
JWKS Endpoint: http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/certs
```

#### Kong API Gateway

```
DEV:  http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/
QA:   http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-qa/
PROD: http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api/
```

**Rutas disponibles por servicio:**

```
# Gestal (backend general)
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/*
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-qa/gestal/*
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api/gestal/*

# Gestal ATS (proxy directo a TalentHub)
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/gestal/ats/posiciones
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-qa/gestal/ats/posiciones
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api/gestal/ats/posiciones

# Otros servicios (Sisbon, etc.)
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-dev/sisbon/*
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api-qa/sisbon/*
http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/api/sisbon/*
```

#### Konga (Kong Admin UI)

```
Dashboard: http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/konga
```

### URLs Futuras (Producción con Dominio)

**Cuando se configure el dominio público `talma.com.pe`:**

#### Keycloak

```
Base URL: https://auth.talma.com.pe
Admin Console: https://auth.talma.com.pe/admin
Token Endpoint: https://auth.talma.com.pe/realms/tlm-pe/protocol/openid-connect/token
```

#### Kong API Gateway

```
DEV:  https://api-dev.talma.com.pe
QA:   https://api-qa.talma.com.pe
PROD: https://api.talma.com.pe
```

#### Konga

```
Dashboard: https://konga.talma.com.pe (o acceso por VPN)
```

### Acceso a Herramientas Administrativas

| Herramienta | URL Actual | Usuario | Notas |
|-------------|-----------|---------|-------|
| Keycloak Admin | `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/admin` | admin | Gestión de realms, clients, usuarios |
| Konga | `http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/konga` | admin | UI para administrar Kong |
| Kong Admin API | `http://localhost:8001` | - | API administrativa (solo interna) |

**⚠️ Importante:** Las herramientas administrativas deben estar protegidas:

- Keycloak Admin: Solo accesible desde VPN/IPs permitidas
- Konga: Solo accesible desde VPN/IPs permitidas
- Kong Admin API: Solo accesible desde red interna (no expuesto públicamente)

---

## Changelog

- **v1.1** (2025-12-10): Actualización de arquitectura y URLs
  - Todas las URLs de backend apuntan al ALB temporal
  - Aclaración: Gestal backend disponible en `/api-dev/gestal/*`
  - Proxy directo Kong → TalentHub ATS (sin backend intermedio)
  - Agregada guía de configuración manual (Kong Admin API + Konga UI)

- **v1.0** (2025-12-10): Documentación inicial de integración Gestal-ATS con Keycloak client_credentials
  - Configuración completa de Keycloak
  - Ejemplos de código Node.js y Python
  - Testing y seguridad
  - URLs temporales del ALB
