# Estándar de Nomenclatura Keycloak - TLM

## Principios Generales

- **Consistencia**: Todos los nombres siguen el mismo patrón
- **Claridad**: El nombre debe indicar propósito y contexto
- **Escalabilidad**: Preparado para multi-tenant y multi-país
- **Separación**: Realms separan tenants/países, no los nombres

---

## Estructura de Realms

### Naming Pattern

```
{tenant}-{pais}    → Para países específicos
{tenant}-corp      → Para servicios corporativos globales
```

### Ejemplos

```
tlm-mx       → TLM México
tlm-pe       → TLM Perú
tlm-co       → TLM Colombia
tlm-corp     → TLM Corporativo (servicios compartidos)
acme-mx      → Cliente externo ACME en México (futuro)
```

---

## Nomenclatura de Clients

### 1. APIs de Servicios Corporativos (Compartidos)

**Ubicación:** Realm `tlm-corp`
**Pattern:** `{servicio}-api`
**Tipo:** Bearer-only (solo valida tokens)

```
Ejemplos:
├─ sisbon-api          → API Gateway Kong para sisbon
├─ hr-global-api       → API Gateway para RRHH global
└─ finance-global-api  → API Gateway para finanzas
```

**Configuración Keycloak:**

- Access Type: `bearer-only`
- Standard Flow: `OFF`
- Service Accounts: `OFF`

---

### 2. Consumidores de Servicios Corporativos

**Ubicación:** Realm del país (`tlm-mx`, `tlm-pe`, etc.)
**Pattern:** `{servicio}-{pais}-{ambiente}`

```
Realm: tlm-mx
├─ sisbon-mx-dev
├─ sisbon-mx-qa
└─ sisbon-mx-prod

Realm: tlm-pe
├─ sisbon-pe-dev
├─ sisbon-pe-qa
└─ sisbon-pe-prod
```

**Configuración Keycloak:**

- Access Type: `confidential`
- Service Accounts Enabled: `Yes`
- Standard Flow: `OFF`
- Direct Access Grants: `OFF`

---

### 3. APIs de Servicios Locales (No compartidos)

**Ubicación:** Realm del país
**Pattern:** `{servicio}-api`

```
Realm: tlm-pe
├─ gestal-api          → API Gateway Kong para gestal (local PE)
```

**Configuración Keycloak:**

- Access Type: `bearer-only`
- Standard Flow: `OFF`
- Service Accounts: `OFF`

---

### 4. Consumidores de Servicios Locales

**Ubicación:** Realm del país
**Pattern:** `{servicio}-{pais}-{ambiente}`

**Nota:** Aunque el servicio sea local, incluir el país facilita escalabilidad futura.

```
Realm: tlm-pe
├─ gestal-pe-dev
├─ gestal-pe-qa
└─ gestal-pe-prod
```

**Configuración Keycloak:**

- Access Type: `confidential`
- Service Accounts Enabled: `Yes`
- Standard Flow: `OFF`

#### Escalabilidad: Múltiples Tipos de Consumidores

**Aplica para:** Cualquier servicio (corporativo o local)

Si en el futuro necesitas distinguir entre tipos de consumidores (web, mobile, batch), evoluciona el patrón:

**Pattern extendido:** `{servicio}-{tipo}-{pais}-{ambiente}`

```
Ejemplo con servicio local (gestal):

Hoy (suficiente):
├─ gestal-pe-dev
├─ gestal-pe-qa
└─ gestal-pe-prod

Futuro (si agregas tipos):
├─ gestal-app-pe-dev      → Backend/Web App DEV
├─ gestal-app-pe-prod     → Backend/Web App PROD
├─ gestal-mobile-pe-dev   → App Móvil DEV
├─ gestal-mobile-pe-prod  → App Móvil PROD
├─ gestal-batch-pe-prod   → Jobs batch PROD
└─ gestal-widget-pe-prod  → Widget embebido PROD

Ejemplo con servicio corporativo (sisbon):

Hoy:
├─ sisbon-mx-dev
└─ sisbon-mx-prod

Futuro (si agregas tipos):
├─ sisbon-app-mx-dev      → Backend DEV
├─ sisbon-app-mx-prod     → Backend PROD
├─ sisbon-mobile-mx-prod  → App Móvil PROD
└─ sisbon-etl-mx-prod     → Proceso ETL PROD
```

**Cuándo evolucionar:**

- ✅ Cuando tengas 2+ tipos diferentes de consumidores
- ✅ Cuando necesites permisos/roles diferentes por tipo
- ✅ Cuando necesites rate limits diferentes por tipo

**Cómo migrar:**

1. Crear nuevos clients con el patrón extendido
2. Mantener ambos funcionando en paralelo
3. Migrar aplicaciones gradualmente
4. Eliminar clients antiguos cuando ya no se usen

---

### 5. Integraciones Externas (Keycloak Clients)

**Ubicación:** Realm del país
**Pattern:** `{servicio}-ext-{partner}`
**Contexto:** Client de Keycloak que consume servicios externos

```

Realm: tlm-pe
└─ gestal-ext-ats      → Client para integración con ATS externo

Realm: tlm-mx
└─ sisbon-ext-reniec   → Client para integración con RENIEC

```

**Configuración Keycloak:**

- Access Type: `confidential`
- Service Accounts Enabled: `Yes`
- Standard Flow: `OFF`

---

### 6. Servicios Externos de Terceros (Kong Services)

**Ubicación:** Kong configuration (no son clients de Keycloak)
**Pattern:** `ext-{partner}-{servicio}-{ambiente}`
**Contexto:** Servicios de terceros que Kong expone como proxy

```
Ejemplos Kong:
├─ ext-talenthub-ats-dev       → TalentHub ATS (externo) en DEV
├─ ext-talenthub-ats-prod      → TalentHub ATS (externo) en PROD
├─ ext-reniec-validation-prod  → RENIEC validación (externo)
├─ ext-sunat-facturacion-prod  → SUNAT facturación (externo)
└─ ext-stripe-payments-prod    → Stripe pagos (externo)
```

**Configuración Kong:**

```yaml
services:
- name: ext-talenthub-ats-dev
  url: https://api-ats.talenthub.pe
  tags:
  - external
  - talenthub
  - third-party
  - dev
  routes:
  - name: ext-talenthub-ats-dev-route
    paths:
    - /api-dev/gestal/ats
  plugins:
  - name: jwt              # Valida JWT de clientes internos
  - name: request-transformer  # Inyecta x-api-key del partner
    config:
      add:
        headers:
        - x-api-key:PARTNER_API_KEY
```

**Diferencia clave:**

| Tipo | Ubicación | Pattern | Propósito |
|------|-----------|---------|------------|
| Client Keycloak | Keycloak realm | `{servicio}-ext-{partner}` | Identidad que **consume** servicio externo |
| Service Kong | Kong config | `ext-{partner}-{servicio}-{env}` | Servicio externo que Kong **expone/protege** |

**Ejemplo completo:**

```
Keycloak (tlm-pe):
└─ gestal-ext-ats      → Client que autentica contra ATS

Kong:
└─ ext-talenthub-ats-dev → Proxy a TalentHub ATS con JWT + x-api-key

Flujo:
1. App Gestal obtiene token con client "gestal-pe-dev"
2. Llama a Kong: POST /api-dev/gestal/ats
3. Kong valida JWT
4. Kong inyecta x-api-key de TalentHub
5. Kong hace proxy a https://api-ats.talenthub.pe
```

**Fundamento (Industry Standards):**

- ✅ **CNCF Cloud-Native Patterns**: Prefijo `ext-` marca trust boundaries
- ✅ **AWS/GCP/Azure**: Usan patrones similares para recursos externos
- ✅ **Kong Best Practices**: Tags semánticos (`external`, `third-party`)
- ✅ **Security Compliance** (SOC2/ISO27001): Separación clara de integraciones externas
- ✅ **Microservices Architecture**: Bounded contexts explícitos

---

## Arquitectura Completa - Ejemplo

### Servicio Corporativo: SISBON (Multi-país)

```

Realm: tlm-corp
└─ sisbon-api          → Kong valida tokens de todos los realms

Realm: tlm-mx
├─ sisbon-mx-dev       → Consumidor México DEV
├─ sisbon-mx-qa        → Consumidor México QA
└─ sisbon-mx-prod      → Consumidor México PROD

Realm: tlm-pe
├─ sisbon-pe-dev       → Consumidor Perú DEV
└─ sisbon-pe-qa        → Consumidor Perú QA

```

### Servicio Local: GESTAL (Solo Perú)

```

Realm: tlm-pe
├─ gestal-api          → Kong (solo para gestal)
├─ gestal-pe-dev       → Consumidor DEV
├─ gestal-pe-qa        → Consumidor QA
├─ gestal-pe-prod      → Consumidor PROD
└─ gestal-ext-ats      → Integración con ATS externo

```

---

## Flujo de Autenticación

### Servicio Corporativo (SISBON)

```

1. Consumidor tlm-mx obtiene token:
   POST <https://keycloak.com/realms/tlm-mx/protocol/openid-connect/token>
   client_id: sisbon-mx-prod
   client_secret: xxx
   grant_type: client_credentials

2. Token JWT contiene:
   {
     "iss": "<https://keycloak.com/realms/tlm-mx>",
     "azp": "sisbon-mx-prod",
     "realm_access": { "roles": ["sisbon-user"] }
   }

3. Consumidor llama al API:
   GET <https://api.tudominio.com/api/sisbon/datos>
   Authorization: Bearer <jwt>

4. Kong valida el token con sisbon-api (tlm-corp realm)
5. Si válido, envía petición al backend sisbon

```

### Servicio Local (GESTAL)

```

1. Consumidor gestal-pe-dev obtiene token:
   POST <https://keycloak.com/realms/tlm-pe/protocol/openid-connect/token>
   client_id: gestal-pe-dev

2. Token contiene:
   {
     "iss": "<https://keycloak.com/realms/tlm-pe>",
     "azp": "gestal-pe-dev"
   }

3. Kong valida con gestal-api (mismo realm tlm-pe)

```---

## Configuración en Kong

### Para Servicios Corporativos (múltiples realms)

```bash
# Kong debe aceptar tokens de múltiples issuers
curl -X POST http://localhost:8001/services/sisbon-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "claims_to_verify": ["exp"],
      "key_claim_name": "iss"
    }
  }'

# Crear consumers para cada realm
curl -X POST http://localhost:8001/consumers -d "username=tlm-mx-realm"
curl -X POST http://localhost:8001/consumers -d "username=tlm-pe-realm"

# Agregar credencial JWT con la clave pública de cada realm
```

### Para Servicios Locales (un solo realm)

```bash
# Kong valida solo un issuer
curl -X POST http://localhost:8001/services/gestal-prod/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jwt",
    "config": {
      "claims_to_verify": ["exp"],
      "key_claim_name": "iss"
    }
  }'

# Un solo consumer
curl -X POST http://localhost:8001/consumers -d "username=tlm-pe-realm"
```

---

## Roles y Permisos

### Naming Pattern

```
{servicio}:{accion}
```

### Ejemplos

```
Realm: tlm-corp (global)
├─ sisbon:read
├─ sisbon:write
└─ sisbon:admin

Realm: tlm-pe
├─ gestal:read
├─ gestal:write
└─ gestal:admin
```

### Asignación

```
Client: sisbon-mx-prod    → Roles: sisbon:read, sisbon:write
Client: sisbon-mx-dev     → Roles: sisbon:read, sisbon:write, sisbon:admin
Client: gestal-ext-ats    → Roles: gestal:write
```

---

## Migración de Clientes Existentes

### Estado Actual

```
Realm: tlm-pe
├─ gestal-dev ✅ (mantener - credenciales ya enviadas)
├─ gestal-qa  ✅ (mantener - credenciales ya enviadas)
```

### Acción Requerida

```
Crear nuevos:
├─ gestal-api
├─ gestal-prod
└─ gestal-ext-ats
```

**Nota:** No renombrar clientes existentes con credenciales distribuidas.

---

## Checklist de Creación de Servicios

### Servicio Corporativo Nuevo

- [ ] Crear realm si no existe (`tlm-{pais}`)
- [ ] Crear `{servicio}-api` en `tlm-corp` (bearer-only)
- [ ] Por cada país:
  - [ ] Crear `{servicio}-{pais}-dev` en realm del país
  - [ ] Crear `{servicio}-{pais}-qa` en realm del país
  - [ ] Crear `{servicio}-{pais}-prod` en realm del país
- [ ] Configurar roles en `tlm-corp`
- [ ] Asignar roles a clients
- [ ] Configurar Kong para múltiples issuers
- [ ] Documentar endpoints y credenciales

### Servicio Local Nuevo

- [ ] Crear realm si no existe (`tlm-{pais}`)
- [ ] Crear `{servicio}-api` en realm del país
- [ ] Crear `{servicio}-dev`
- [ ] Crear `{servicio}-qa`
- [ ] Crear `{servicio}-prod`
- [ ] Si hay integraciones externas:
  - [ ] Client Keycloak: `{servicio}-ext-{partner}`
  - [ ] Service Kong: `ext-{partner}-{servicio}-{env}`
- [ ] Configurar roles
- [ ] Configurar Kong
- [ ] Documentar endpoints

### Servicio Externo de Tercero (Proxy en Kong)

- [ ] Crear service en Kong: `ext-{partner}-{servicio}-{env}`
- [ ] Configurar URL del partner
- [ ] Agregar tags: `["external", "{partner}", "third-party", "{env}"]`
- [ ] Configurar JWT plugin (valida clientes internos)
- [ ] Configurar request-transformer (x-api-key del partner)
- [ ] Configurar rate limiting (protección)
- [ ] Documentar credenciales del partner
- [ ] Definir rutas públicas en Kong
- [ ] Probar integración end-to-end

---

## Resumen Rápido

| Tipo | Ubicación | Pattern | Ejemplo |
|------|-----------|---------|---------|-------
| API Corporativa | tlm-corp (Keycloak) | `{servicio}-api` | `sisbon-api` |
| Consumidor Corp | tlm-{pais} (Keycloak) | `{servicio}-{pais}-{env}` | `sisbon-mx-dev` |
| API Local | tlm-{pais} (Keycloak) | `{servicio}-api` | `gestal-api` |
| Consumidor Local | tlm-{pais} (Keycloak) | `{servicio}-{pais}-{env}` | `gestal-pe-dev` |
| Consumidor Local (multi-tipo) | tlm-{pais} (Keycloak) | `{servicio}-{tipo}-{pais}-{env}` | `gestal-mobile-pe-dev` |
| Client Integración Externa | tlm-{pais} (Keycloak) | `{servicio}-ext-{partner}` | `gestal-ext-ats` |
| Servicio Externo Terceros | Kong | `ext-{partner}-{servicio}-{env}` | `ext-talenthub-ats-dev` |

---

## Evolución del Estándar

### Cuándo y Cómo Escalar

#### Escenario 1: De Servicio Local a Corporativo

**Situación:** Gestal inicialmente es solo PE, pero luego MX y CO lo necesitan.

**Migración:**

```
Paso 1 - Estado actual:
Realm: tlm-pe
├─ gestal-api
├─ gestal-pe-dev
└─ gestal-pe-prod

Paso 2 - Mover API a tlm-corp:
Realm: tlm-corp
└─ gestal-api (mover desde tlm-pe)

Realm: tlm-pe (sin cambios)
├─ gestal-pe-dev
└─ gestal-pe-prod

Paso 3 - Agregar otros países:
Realm: tlm-mx
├─ gestal-mx-dev
└─ gestal-mx-prod

Realm: tlm-co
└─ gestal-co-prod
```

**Impacto:** Mínimo - Solo mueves gestal-api, los consumidores no cambian.

---

#### Escenario 2: De Un Tipo a Múltiples Tipos

**Situación:** Agregas app móvil además del backend (aplica a cualquier servicio).

**Ejemplo con servicio local (gestal):**

```
Paso 1 - Estado actual:
├─ gestal-pe-dev        → Backend
├─ gestal-pe-prod       → Backend

Paso 2 - Crear nuevos con tipo:
├─ gestal-app-pe-dev    → Backend (nuevo)
├─ gestal-app-pe-prod   → Backend (nuevo)
├─ gestal-mobile-pe-dev → Móvil (nuevo)
├─ gestal-mobile-pe-prod→ Móvil (nuevo)

Paso 3 - Migrar credenciales:
- Actualizar backend para usar gestal-app-pe-*
- Distribuir credenciales gestal-mobile-pe-* a app móvil

Paso 4 - Limpiar:
- Eliminar gestal-pe-dev (antiguo)
- Eliminar gestal-pe-prod (antiguo)
```

**Ejemplo con servicio corporativo (sisbon):**

```
Paso 1 - Estado actual:
├─ sisbon-mx-prod       → Backend

Paso 2 - Crear con tipos:
├─ sisbon-app-mx-prod   → Backend (nuevo)
├─ sisbon-etl-mx-prod   → Proceso ETL (nuevo)

Paso 3 - Migrar y limpiar similar al ejemplo anterior
```

**Impacto:** Requiere actualizar credenciales en aplicaciones.

---

#### Escenario 3: Agregar Nuevo País

**Situación:** Expandir a Colombia.

**Para servicio corporativo (sisbon):**

```
Crear en realm tlm-co:
├─ sisbon-co-dev
├─ sisbon-co-qa
└─ sisbon-co-prod

La API sisbon-api en tlm-corp ya los acepta.
```

**Para servicio local (gestal):**

```
Si gestal se expande a CO:
1. Evaluar si debe ser corporativo (ver Escenario 1)
2. Si sigue local: crear realm tlm-co con gestal-api local
```

---

### Principios de Evolución

1. **Backward Compatibility:** Mantén clients antiguos funcionando durante migración
2. **Gradual Migration:** No cambies todo de una vez
3. **Clear Communication:** Avisa a equipos antes de deprecar clients
4. **Documentation First:** Actualiza docs antes de hacer cambios
5. **Testing:** Prueba en DEV/QA antes de tocar PROD

---

## Implementación

Para la guía detallada de configuración paso a paso en Keycloak y Kong, consultar:

**→ [KEYCLOAK_KONG_INTEGRATION.md](./KEYCLOAK_KONG_INTEGRATION.md)**

---

**Fecha de última actualización:** 2025-12-05
**Versión:** 1.1
**Mantenido por:** Equipo DevOps TLM

**Changelog:**
- v1.1 (2025-12-05): Agregada sección 6 para servicios externos de terceros en Kong
- v1.0 (2025-12-04): Versión inicial
