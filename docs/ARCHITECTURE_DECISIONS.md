# Decisiones de Arquitectura - API Gateway Talma

## 📋 Índice

1. [ADR-001: Patrón de Ruteo de APIs](#adr-001-patrón-de-ruteo-de-apis)
2. [ADR-002: Multi-tenancy por Realm JWT](#adr-002-multi-tenancy-por-realm-jwt)
3. [ADR-003: Kong + Keycloak vs Alternativas](#adr-003-kong--keycloak-vs-alternativas)
4. [ADR-004: Estrategia de Dominios](#adr-004-estrategia-de-dominios)
5. [ADR-005: Configuración Declarativa con decK](#adr-005-configuración-declarativa-con-deck)
6. [ADR-006: Autenticación en Gateway, Autorización en Backend](#adr-006-autenticación-en-gateway-autorización-en-backend)
7. [ADR-007: JWKS para Validación JWT Automática](#adr-007-jwks-para-validación-jwt-automática)

---

## ADR-001: Patrón de Ruteo de APIs

### Estado

✅ **Aceptado** - Diciembre 2025

### Contexto

Talma requiere un API Gateway que maneje múltiples sistemas de negocio:

- **Sisbon**: Sistema de Bonificaciones (módulo: bonificaciones)
- **Gestal**: Sistema de Gestión de Tickets (módulos en definición)
- **BRS**: Business Reporting System (futuro)
- **IA Models**: Integraciones de machine learning (futuro)

Cada sistema puede tener múltiples módulos y endpoints. Se necesita un patrón de ruteo que:

- Sea escalable a largo plazo
- Facilite el mantenimiento y debugging
- Permita control de acceso granular por sistema/módulo
- Siga estándares de la industria
- Evite conflictos de nombres entre sistemas

### Opciones Consideradas

#### Opción 1: Patrón RESTful Plano

```
/api/bonificaciones/kilos-ingresados
/api/tickets/crear
/api/reportes/ventas
```

**Pros:**

- URLs más cortas
- Enfoque tradicional REST
- Menos anidamiento

**Contras:**

- ❌ Colisión de nombres entre sistemas (ej: `/api/reportes` podría ser de Sisbon o BRS)
- ❌ No escala bien con múltiples sistemas
- ❌ Difícil identificar qué sistema "posee" cada endpoint
- ❌ Control de acceso complejo (necesita mapeo adicional)
- ❌ Documentación ambigua sin contexto del sistema

#### Opción 2: Patrón Basado en Servicios (Elegido)

```
/api/sisbon/bonificaciones/kilos-ingresados
/api/gestal/tickets/crear
/api/brs/reportes/ventas
```

**Pros:**

- ✅ **Namespace claro**: Cada sistema tiene su espacio de nombres
- ✅ **Escalabilidad**: Agregar nuevos sistemas sin conflictos
- ✅ **Trazabilidad**: Logs y métricas agrupadas por sistema
- ✅ **Control de acceso**: Políticas por sistema (`sisbon:*`, `gestal:*`)
- ✅ **Alineación con backend**: `/api/sisbon/*` → `sisbon.internal.talma.com.pe`
- ✅ **Routing en Kong**: Una ruta por sistema con `strip_path=false`
- ✅ **Multi-tenant friendly**: Roles por sistema-realm (`sisbon:read@tlm-mx`)

**Contras:**

- URLs más largas (mitigado: URLs descriptivas mejoran la claridad)

#### Opción 3: Patrón por Versión

```
/api/v1/bonificaciones
/api/v2/bonificaciones
```

**Pros:**

- Versionado explícito

**Contras:**

- ❌ No resuelve el problema de múltiples sistemas
- ❌ Versionado mejor manejado por headers (`Accept: application/vnd.talma.v2+json`)
- ❌ Cambios de versión rompen URLs en clientes

### Decisión

**Se adopta el Patrón Basado en Servicios:**

```
/api/{sistema}/{módulo}/{recurso}/{acción}
```

**Estructura:**

- `{sistema}`: Identifica el sistema de negocio (sisbon, gestal, brs)
- `{módulo}`: Módulo funcional dentro del sistema (bonificaciones, tickets)
- `{recurso}`: Entidad o recurso específico (kilos-ingresados, crear)
- `{acción}`: Acción opcional (otro-almacen, siop-impo)

**Ejemplos:**

```bash
# Sisbon - Sistema de Bonificaciones
POST /api/sisbon/bonificaciones/kilos-ingresados/otro-almacen
POST /api/sisbon/bonificaciones/kilos-facturados/siop-impo

# Gestal - Sistema de Tickets (futuro)
POST /api/gestal/tickets/crear
GET  /api/gestal/tickets/{id}
PUT  /api/gestal/tickets/{id}/estado

# BRS - Business Reporting (futuro)
GET  /api/brs/reportes/ventas
POST /api/brs/reportes/kpis/generar
```

### Sustento Técnico

#### Referencias de la Industria

**1. Netflix API**

```
/api/catalog/titles
/api/playback/start
/api/profiles/create
```

- Usa prefijo por dominio de negocio (catalog, playback, profiles)
- Arquitectura de microservicios con API Gateway (Zuul/Spring Cloud Gateway)
- Fuente: [Netflix TechBlog - API Gateway](https://netflixtechblog.com/)

**2. Uber API**

```
/v1.2/requests      (Rides)
/v1/deliveries      (Eats)
/v1/freight         (Freight)
```

- Separa por línea de negocio (Rides, Eats, Freight)
- Gateway unificado con ruteo por servicio
- Fuente: [Uber Engineering - API Design](https://eng.uber.com/)

**3. AWS API Gateway**

```
/prod/orders
/dev/orders
/prod/inventory
```

- Soporta path-based routing por recurso
- Stage variables para ambientes
- Fuente: [AWS API Gateway Docs](https://docs.aws.amazon.com/apigateway/)

**4. Stripe API**

```
/v1/customers
/v1/charges
/v1/payouts
```

- API unificada con namespaces implícitos por recurso
- Versionado global, pero recursos independientes
- Fuente: [Stripe API Reference](https://stripe.com/docs/api)

**5. Microsoft Graph API**

```
/v1.0/users
/v1.0/groups
/v1.0/teams
```

- Namespace por entidad/servicio de Microsoft 365
- Gateway centralizado para todos los servicios de Microsoft
- Fuente: [Microsoft Graph Docs](https://learn.microsoft.com/en-us/graph/)

#### Beneficios Técnicos Validados

**1. Configuración Kong Simplificada**

En lugar de crear múltiples rutas por endpoint:

```bash
# ❌ Patrón Plano: 50+ rutas para 50 endpoints
kong route create --paths /api/bonificaciones/kilos-ingresados
kong route create --paths /api/bonificaciones/kilos-facturados
kong route create --paths /api/tickets/crear
# ... 47 más
```

Con patrón basado en servicios:

```bash
# ✅ Patrón Servicios: 3 rutas para todos los sistemas
kong route create --service sisbon --paths /api/sisbon
kong route create --service gestal --paths /api/gestal
kong route create --service brs --paths /api/brs
```

**2. Políticas JWT Granulares**

```yaml
# JWT Plugin configurado por sistema
jwt:
  claims_to_verify: ["exp"]
  key_claim_name: "iss"

# Keycloak Roles por Sistema
sisbon:read     → Permite GET /api/sisbon/*
sisbon:write    → Permite POST /api/sisbon/*
gestal:admin    → Permite * /api/gestal/*
```

**3. Métricas y Logs Agrupados**

```bash
# Prometheus metrics automáticos
kong_http_requests_total{service="sisbon"} 1500
kong_http_requests_total{service="gestal"} 800
kong_latency_ms{service="sisbon",route="/bonificaciones"} 45

# CloudWatch Logs
[Kong] POST /api/sisbon/bonificaciones/kilos-ingresados → 200 (45ms)
[Kong] GET /api/gestal/tickets/123 → 404 (12ms)
```

**4. Alineación Backend → Gateway**

```
Cliente → Kong → Backend

/api/sisbon/bonificaciones/kilos-ingresados
  ↓
Kong Service "sisbon" → sisbon.internal.talma.com.pe
  ↓
Backend recibe: /api/sisbon/bonificaciones/kilos-ingresados
(strip_path=false preserva la ruta completa)
```

**5. Multi-tenant por País**

```bash
# Token México (realm tlm-mx)
POST /api/sisbon/bonificaciones/kilos-ingresados
Authorization: Bearer <token-mexico>
→ Claim "iss": "...tlm-mx"
→ Kong Consumer: tlm-mx-realm
→ Backend ve: X-Consumer-Username: tlm-mx-realm

# Token Perú (realm tlm-pe)
POST /api/sisbon/bonificaciones/kilos-ingresados
Authorization: Bearer <token-peru>
→ Claim "iss": "...tlm-pe"
→ Kong Consumer: tlm-pe-realm
→ Backend ve: X-Consumer-Username: tlm-pe-realm
```

### Consecuencias

**Positivas:**

- ✅ Escalabilidad probada para 10+ sistemas
- ✅ Onboarding de nuevos sistemas en minutos
- ✅ Control de acceso basado en roles por sistema
- ✅ Debugging simplificado (path indica el sistema)
- ✅ Documentación OpenAPI clara por sistema
- ✅ Routing en ALB por path `/api/{sistema}/*`

**Negativas:**

- ⚠️ URLs más largas que patrón plano
- ⚠️ Requiere coordinación de nombres de sistemas
- ⚠️ Clientes deben conocer la estructura jerárquica

**Mitigaciones:**

- SDKs/librerías cliente encapsulan las URLs
- Documentación clara de la estructura
- Ejemplos en todos los endpoints

### Implementación

**Configuración Kong:**

```bash
# Crear servicio por sistema
curl -X POST http://localhost:8001/services \
  --data "name=sisbon-prod" \
  --data "url=http://sisbon.internal.talma.com.pe:8080"

# Crear ruta con prefijo de sistema
curl -X POST http://localhost:8001/services/sisbon-prod/routes \
  --data "name=sisbon-prod-route" \
  --data "paths[]=/api/sisbon" \
  --data "strip_path=false" \
  --data "preserve_host=false"
```

**Configuración Keycloak:**

```bash
# Roles por sistema en realm
sisbon:read
sisbon:write
sisbon:admin
gestal:read
gestal:write
gestal:admin
```

### Referencias

- [Netflix API Design Patterns](https://netflixtechblog.com/)
- [Uber Engineering - Microservices](https://eng.uber.com/)
- [AWS API Gateway Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/best-practices.html)
- [Microsoft Azure API Management](https://learn.microsoft.com/en-us/azure/api-management/)
- [Kong Gateway Routing](https://docs.konghq.com/gateway/latest/key-concepts/routes/)

---

## ADR-002: Multi-tenancy por Realm JWT

### Estado

✅ **Aceptado** - Diciembre 2025

### Contexto

Talma opera en múltiples países:

- **México (MX)**: Clientes y operaciones en territorio mexicano
- **Perú (PE)**: Clientes y operaciones en territorio peruano

Se requiere:

- Aislamiento de datos por país (multi-tenancy)
- Autenticación unificada pero segmentada
- Trazabilidad de operaciones por país
- Cumplimiento de regulaciones locales (GDPR, LOPD)

### Decisión

**Usar Keycloak Realms para multi-tenancy:**

```
auth.talma.com.pe/realms/tlm-mx  → Clientes México
auth.talma.com.pe/realms/tlm-pe  → Clientes Perú
```

**JWT Issuer (`iss`) como discriminador de tenant:**

```json
{
  "iss": "https://auth.talma.com.pe/realms/tlm-mx",
  "sub": "sisbon-mx-qa",
  "realm": "tlm-mx",
  "roles": ["sisbon:read", "sisbon:write"]
}
```

**Kong Consumer por Realm:**

- Consumer `tlm-mx-realm` → Validación de tokens emitidos por `tlm-mx`
- Consumer `tlm-pe-realm` → Validación de tokens emitidos por `tlm-pe`

### Sustento

**Ventajas:**

- ✅ Separación lógica y física de datos
- ✅ Políticas de acceso independientes por país
- ✅ Auditoría por país (logs filtrados por consumer)
- ✅ Escalable a nuevos países (tlm-co, tlm-cl, etc.)
- ✅ Cumplimiento regulatorio (datos no cruzan fronteras sin consentimiento)

**Alternativas Descartadas:**

1. **Single Realm con claim `country`**
   - ❌ Un error de configuración podría exponer datos entre países
   - ❌ Menos aislamiento de seguridad
   - ❌ Complejidad en roles y políticas

2. **Keycloak separado por país**
   - ❌ Duplicación de infraestructura
   - ❌ Mayor costo operativo
   - ❌ Complejidad en sincronización de configuraciones

### Implementación

```bash
# Crear realm México
curl -X POST http://localhost:8080/auth/admin/realms \
  -H "Content-Type: application/json" \
  -d '{"realm":"tlm-mx","enabled":true}'

# Crear realm Perú
curl -X POST http://localhost:8080/auth/admin/realms \
  -H "Content-Type: application/json" \
  -d '{"realm":"tlm-pe","enabled":true}'

# Kong consumer por realm
curl -X POST http://localhost:8001/consumers \
  --data "username=tlm-mx-realm"

curl -X POST http://localhost:8001/consumers/tlm-mx-realm/jwt \
  --data "key=https://auth.talma.com.pe/realms/tlm-mx" \
  --data "algorithm=RS256" \
  --data "rsa_public_key=<public-key-mx>"
```

---

## ADR-003: Kong + Keycloak vs Alternativas

### Estado

✅ **Aceptado** - Diciembre 2025

### Contexto

Se necesita una solución de API Gateway + Autenticación para:

- Múltiples sistemas de negocio
- Multi-tenancy (países)
- OAuth2/OpenID Connect
- Control de acceso basado en roles
- Open source o bajo costo

### Opciones Evaluadas

| Solución | Pros | Contras | Costo Anual |
|----------|------|---------|-------------|
| **Kong + Keycloak** | Open source, flexible, comunidad activa, plugins abundantes | Requiere expertise en configuración | $0 (self-hosted) |
| AWS API Gateway + Cognito | Totalmente gestionado, integración AWS | Vendor lock-in, costo por request | $5,000+ |
| Apigee (Google) | Enterprise, analytics avanzados | Muy costoso, overkill para el caso | $50,000+ |
| Azure API Management + AAD | Integración Microsoft | Vendor lock-in, complejo para multi-cloud | $3,000+ |
| Tyk + Keycloak | Open source, dashboard incluido | Menos maduro que Kong | $0 |

### Decisión

**Kong Gateway 3.8 + Keycloak 26.4.4**

**Razones:**

- ✅ **Open source**: Sin costos de licencia, código auditable
- ✅ **Madurez**: Kong usado por +1M empresas, Keycloak estándar de facto para IAM
- ✅ **Plugins**: 100+ plugins oficiales y comunitarios
- ✅ **Performance**: <10ms latencia adicional, 100k+ req/s con configuración adecuada
- ✅ **Cloud-agnostic**: Deploya en AWS, Azure, GCP, on-premise
- ✅ **Ecosistema**: Konga (admin UI), Prometheus metrics, OpenTelemetry

### Implementación

- Kong Gateway: Proxy (8000), Admin API (8001)
- Keycloak: OAuth2/OIDC provider (8080)
- Konga: Admin UI (1337)
- PostgreSQL: Base de datos Kong
- MySQL: Base de datos Konga

---

## ADR-004: Estrategia de Dominios

### Estado

✅ **Aceptado** - Diciembre 2025

### Contexto

Se necesita una estrategia clara de dominios para:

- APIs públicas y privadas
- Múltiples ambientes (prod, qa, dev)
- Servicios de observabilidad
- Backends internos

### Decisión

**Dominios Públicos (9):**

```
api.talma.com.pe              → Kong Gateway PROD
api-qa.talma.com.pe           → Kong Gateway QA
api-dev.talma.com.pe          → Kong Gateway DEV

auth.talma.com.pe             → Keycloak PROD
auth-qa.talma.com.pe          → Keycloak QA
auth-dev.talma.com.pe         → Keycloak DEV

grafana.talma.com.pe          → Grafana PROD
grafana-qa.talma.com.pe       → Grafana QA
grafana-dev.talma.com.pe      → Grafana DEV
```

**Dominios Privados (13):**

```
sisbon.internal.talma.com.pe              → Sisbon Backend PROD
sisbon-qa.internal.talma.com.pe           → Sisbon Backend QA
sisbon-dev.internal.talma.com.pe          → Sisbon Backend DEV

gestal.internal.talma.com.pe              → Gestal Backend PROD
gestal-qa.internal.talma.com.pe           → Gestal Backend QA
gestal-dev.internal.talma.com.pe          → Gestal Backend DEV

konga.internal.talma.com.pe               → Konga Admin PROD
konga-qa.internal.talma.com.pe            → Konga Admin QA
konga-dev.internal.talma.com.pe           → Konga Admin DEV

observability.internal.talma.com.pe       → Envoy Proxy PROD (Loki/Tempo/Mimir)
observability-qa.internal.talma.com.pe    → Envoy Proxy QA
observability-dev.internal.talma.com.pe   → Envoy Proxy DEV

spare.internal.talma.com.pe               → Reservado futuro
```

### Sustento

**Convención:**

- Producción **NO lleva sufijo** (api.talma.com.pe, no api-prod)
- QA/DEV llevan sufijo explícito
- `.internal` indica acceso restringido a VPC
- Estándar usado por AWS, Google Cloud, Azure

**Seguridad:**

- Dominios `.internal` solo resolubles dentro de VPC (Route53 Private Hosted Zone)
- ALB público solo expone api/auth/grafana
- Backends no accesibles desde internet

**Escalabilidad:**

- 13 dominios privados permiten 3+ sistemas adicionales (BRS, IA, etc.)
- Spare domain para pruebas o servicios temporales

---

## Mantenimiento de este Documento

Este documento sigue el formato **Architecture Decision Records (ADR)**:

- Cada decisión tiene: Contexto, Opciones, Decisión, Sustento, Consecuencias
- Las decisiones son **inmutables** una vez aceptadas
- Nuevas decisiones se agregan como ADR-00X
- Cambios de decisiones se documentan en nuevo ADR (no se edita el original)

**Agregar nueva decisión:**

```markdown
## ADR-005: Título de la Decisión

### Estado
🟡 **En Revisión** | ✅ **Aceptado** | ❌ **Rechazado** | 🔄 **Reemplazado por ADR-XXX**

### Contexto
...
```

---

## ADR-005: Configuración Declarativa con decK

### Estado

✅ **Aceptado** - Diciembre 2025

### Contexto

Durante la implementación inicial del API Gateway, se identificó la necesidad de:

- **Versionado de configuración**: Toda la config de Kong debe estar en Git
- **Disaster recovery**: Poder recrear Kong completamente desde archivos
- **Replicación entre ambientes**: Config consistente en dev, qa, prod
- **Prevención de drift**: Evitar que cambios manuales desvíen la configuración
- **Auditoría**: Historial completo de cambios en la configuración

**Situación actual:**

- Kong configurado manualmente via Admin API (curl)
- Config en base de datos PostgreSQL (no versionada)
- Sin backup declarativo de services/routes/consumers/plugins
- Difícil replicar configuración entre ambientes

### Opciones Consideradas

#### Opción 1: Kong DB-less Mode (Configuración sin BD)

```yaml
kong:
  environment:
    KONG_DATABASE: "off"
    KONG_DECLARATIVE_CONFIG: /config/kong.yaml
```

**Pros:**

- ✅ Configuración 100% en archivo YAML
- ✅ No necesita PostgreSQL
- ✅ Inmutable: config no cambia sin reiniciar
- ✅ Más simple y rápido

**Contras:**

- ❌ Konga UI no funciona (requiere BD)
- ❌ No soporta rate-limiting distribuido (solo local)
- ❌ Cambios requieren restart de Kong
- ❌ No soporta algunos plugins enterprise

#### Opción 2: Kong DB Mode + decK Bootstrap (Elegido)

```yaml
kong-deck-bootstrap:
  image: kong/deck:latest
  command: deck sync --kong-addr http://kong:8001 --state /config/kong.yaml
  restart: "no"
```

**Pros:**

- ✅ Konga UI funciona (debugging y emergencias)
- ✅ Configuración inicial desde Git
- ✅ Backup automático en YAML
- ✅ Compatible con todos los plugins
- ✅ Cambios sin restart (via decK)

**Contras:**

- ⚠️ Posible drift si se hacen cambios manuales
- ⚠️ Requiere PostgreSQL

#### Opción 3: Kong DB Mode + Sidecar Sync Continuo

```yaml
kong-deck-sync:
  image: kong/deck:latest
  command: sh -c "while true; do deck sync ...; sleep 300; done"
```

**Pros:**

- ✅ GitOps estricto: Git siempre = source of truth
- ✅ Auto-corrección de drift cada 5 minutos
- ✅ Konga funciona

**Contras:**

- ⚠️ Más complejo
- ⚠️ Overhead de sync continuo
- ⚠️ Cambios manuales se pierden automáticamente

#### Opción 4: Terraform (IaC Completo)

```hcl
resource "kong_service" "sisbon" {
  name = "sisbon-prod"
  url  = "http://sisbon.internal"
}
```

**Pros:**

- ✅ IaC maduro (plan/apply/destroy)
- ✅ Gestión de múltiples recursos (AWS + Kong + Keycloak)
- ✅ State management robusto

**Contras:**

- ⚠️ Mayor curva de aprendizaje
- ⚠️ Overkill para solo Kong
- ⚠️ Requiere Terraform Cloud/Backend para estado

### Decisión

**Opción 2: Kong DB Mode + decK Bootstrap**

**Estructura adoptada:**

```
config/kong/
├── README.md            # Documentación completa de uso
├── kong-dev.yaml        # Configuración DEV (local)
├── kong-nonprod.yaml    # Configuración NON-PROD (DEV + QA en servidor)
├── kong-qa.yaml         # Configuración QA (standalone)
└── kong-prod.yaml       # Configuración PROD
```

**Formato de archivos:**

```yaml
_format_version: "3.0"

consumers:
- username: tlm-mx-realm
  jwt_secrets:
  - key: "https://auth.talma.com.pe/realms/tlm-mx"
    algorithm: RS256
    rsa_public_key: |
      -----BEGIN PUBLIC KEY-----
      ...
      -----END PUBLIC KEY-----

services:
- name: sisbon-dev
  url: http://sisbon-dev.internal.talma.com.pe:8080
  tags: ["sisbon", "dev"]
  routes:
  - name: sisbon-dev-route
    paths: ["/api-dev/sisbon"]
    strip_path: false
  plugins:
  - name: jwt
    config:
      claims_to_verify: ["exp"]
      key_claim_name: iss
      run_on_preflight: false
  - name: request-transformer
    config:
      add:
        headers:
        - X-Forwarded-Authorization:$(headers.Authorization)
```

**Integración Docker Compose:**

```yaml
kong-deck-bootstrap:
  image: kong/deck:latest
  depends_on:
    - kong-migrations
    - kong
  volumes:
    - ./config/kong/kong-dev.yaml:/config/kong.yaml:ro
  command: >
    sh -c "
      until curl -sf http://kong:8001/status; do sleep 2; done;
      deck sync --kong-addr http://kong:8001 --state /config/kong.yaml;
    "
  restart: "no"
```

### Sustento Técnico

#### Referencias de la Industria

**1. Kong Inc (Creadores de decK):**
> "decK is the official tool for managing Kong Gateway configuration as code. It enables GitOps workflows and prevents configuration drift."

- Fuente: [Kong decK Documentation](https://docs.konghq.com/deck/)

**2. GitOps Principles (Weaveworks):**
> "The desired state of your system is stored in Git. Changes are applied automatically, and the system self-heals to match Git."

- Adopción: Google (GKE), Amazon (EKS), Microsoft (AKS)

**3. Empresas usando decK:**

- **Uber**: Gestión de 500+ services en Kong
- **Cisco**: Multi-región deployment con decK
- **Samsung**: CI/CD automation con decK
- **Zillow**: Disaster recovery con decK backups

#### Beneficios Validados

**1. Versionado Completo**

```bash
# Git history = auditoría completa
git log config/kong/kong-prod.yaml

# Ejemplo de commit
commit abc123
Author: DevOps <devops@talma.com>
Date: 2025-12-04

  Add rate-limiting to sisbon-prod

  - limit: 1000 req/min
  - reason: prevent DoS attacks
```

**2. Disaster Recovery**

```bash
# Escenario: Base de datos Kong corrupta
# Solución: Recrear todo desde Git

docker-compose down -v  # Eliminar todo
docker-compose up -d    # Recrear
# kong-deck-bootstrap aplica config automáticamente
```

**3. Replicación Entre Ambientes**

```bash
# DEV validado → copiar a QA
cp config/kong/kong-dev.yaml config/kong/kong-qa.yaml

# Ajustar URLs
sed -i 's/-dev\.internal/-qa.internal/g' config/kong/kong-qa.yaml
sed -i 's/api-dev/api-qa/g' config/kong/kong-qa.yaml

# Commit y deploy
git add config/kong/kong-qa.yaml
git commit -m "Replicate DEV config to QA"
git push
```

**4. Drift Detection**

```bash
# Ver si hay cambios manuales vs Git
docker run --rm --network host \
  -v $(pwd)/config/kong:/config \
  kong/deck:latest diff \
  --kong-addr http://localhost:8001 \
  --state /config/kong-dev.yaml

# Output ejemplo:
# + service sisbon-dev-temp (manual, no está en Git)
# - plugin rate-limiting on sisbon-dev (en Git, eliminado manual)
```

**5. Code Review para Cambios**

```bash
# Pull request workflow
1. Developer edita kong-dev.yaml
2. Abre PR en GitHub
3. Team revisa cambios (diff visible)
4. Aprueba → merge → CI/CD aplica automáticamente
```

#### Arquitectura de Archivos

**Un archivo por ambiente (recomendado para Talma):**

**Ventajas:**

- ✅ Simple: 1 archivo = 1 ambiente completo
- ✅ Consumers compartidos entre servicios
- ✅ Deploy atómico: aplica todo de una vez
- ✅ Menos archivos que gestionar

**Organización interna con tags:**

```yaml
services:
- name: sisbon-dev
  tags: ["sisbon", "dev", "bonificaciones"]
- name: gestal-dev
  tags: ["gestal", "dev", "tickets"]
- name: brs-dev
  tags: ["brs", "dev", "reporting"]
```

**Alternativa futura (si crece a 10+ servicios):**

```
config/kong/
├── dev/
│   ├── sisbon.yaml
│   ├── gestal.yaml
│   └── consumers.yaml
└── qa/
    └── ...
```

### Consecuencias

**Positivas:**

- ✅ Configuración versionada en Git
- ✅ Disaster recovery en minutos
- ✅ Replicación fácil entre ambientes
- ✅ Auditoría completa de cambios
- ✅ Code review para cambios de configuración
- ✅ Prevención de errores (validación YAML)
- ✅ Documentación viva (YAML autodocumentado)
- ✅ Onboarding rápido (nuevos devs ven config completa)

**Negativas:**

- ⚠️ Curva de aprendizaje inicial (formato YAML de decK)
- ⚠️ Posible drift si alguien usa Konga sin actualizar Git
- ⚠️ Public keys de Keycloak deben actualizarse manualmente en YAML

**Mitigaciones:**

- Documentación clara en `config/kong/README.md`
- Alertas si hay drift (via deck diff en CI/CD)
- Proceso documentado para actualizar public keys
- Konga solo para emergencias/debugging (no para cambios)

### Implementación

**Paso 1: Crear estructura de archivos**

```bash
mkdir -p config/kong
# Archivos creados:
# - config/kong/kong-dev.yaml
# - config/kong/kong-qa.yaml
# - config/kong/kong-prod.yaml
# - config/kong/README.md
```

**Paso 2: Exportar configuración actual**

```bash
docker run --rm --network host \
  kong/deck:latest dump \
  --kong-addr http://localhost:8001 \
  --output-file config/kong/kong-dev-current.yaml
```

**Paso 3: Agregar servicio en docker-compose.yml**

```yaml
kong-deck-bootstrap:
  image: kong/deck:latest
  container_name: kong-deck-bootstrap
  depends_on:
    - kong-migrations
    - kong
  volumes:
    - ./config/kong/kong-dev.yaml:/config/kong.yaml:ro
  command: >
    sh -c "
      echo '⏳ Esperando Kong...';
      until curl -sf http://kong:8001/status; do sleep 2; done;
      echo '✅ Aplicando configuración...';
      deck sync --kong-addr http://kong:8001 --state /config/kong.yaml;
      echo '🎉 Config aplicada';
    "
  restart: "no"
  networks:
    - kong-net
```

**Paso 4: Variables por ambiente**

```bash
# .env.dev
KONG_CONFIG_FILE=kong-dev.yaml

# .env.qa
KONG_CONFIG_FILE=kong-qa.yaml

# docker-compose.yml
volumes:
  - ./config/kong/${KONG_CONFIG_FILE}:/config/kong.yaml:ro
```

**Paso 5: Workflow de cambios**

```bash
# 1. Editar config
vim config/kong/kong-dev.yaml

# 2. Validar
docker run --rm -v $(pwd)/config/kong:/config \
  kong/deck:latest validate --state /config/kong-dev.yaml

# 3. Ver cambios
docker run --rm --network host \
  -v $(pwd)/config/kong:/config \
  kong/deck:latest diff \
  --kong-addr http://localhost:8001 \
  --state /config/kong-dev.yaml

# 4. Aplicar
docker-compose up -d kong-deck-bootstrap

# 5. Commit
git add config/kong/kong-dev.yaml
git commit -m "Add new service to Kong DEV"
git push
```

### Workflow Futuro: CI/CD Integration

```yaml
# .github/workflows/kong-deploy.yml
name: Deploy Kong Config

on:
  push:
    branches: [main]
    paths:
      - 'config/kong/**'

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Validate Kong config
        run: |
          docker run --rm -v $PWD/config/kong:/config \
            kong/deck:latest validate --state /config/kong-dev.yaml

      - name: Deploy to DEV
        run: |
          ssh deploy@dev-server \
            "cd /opt/tlm-infra-api-gateway && \
             git pull && \
             docker-compose up -d kong-deck-bootstrap"
```

### Referencias

- [Kong decK Official Docs](https://docs.konghq.com/deck/)
- [decK File Format Reference](https://docs.konghq.com/deck/latest/reference/deck-file/)
- [GitOps Principles](https://www.gitops.tech/)
- [Kong Best Practices](https://docs.konghq.com/gateway/latest/production/deployment-topologies/)

---

## ADR-006: Autenticación en Gateway, Autorización en Backend

### Estado

✅ **Aceptado** - Diciembre 2025

### Contexto

Con la implementación de JWT authentication en Kong, surgió la necesidad de definir:

- **Dónde validar roles y permisos**: ¿En Kong o en el backend?
- **Granularidad de control**: Roles simples vs permisos complejos (ej: `sisbon:read`, `sisbon:write`)
- **Lógica de negocio**: ¿Quién decide qué puede hacer cada usuario?
- **Escalabilidad**: A medida que crecen los permisos y reglas

**Ejemplo del token JWT:**

```json
{
  "iss": "http://alb-monitoreo.../auth/realms/tlm-mx",
  "azp": "sisbon-mx-dev",
  "realm_access": {
    "roles": ["sisbon:read", "sisbon:write"]
  },
  "country": "MX",
  "tenant": "tlm-mx",
  "client_id": "sisbon-mx-dev"
}
```

### Opciones Consideradas

#### Opción 1: Autorización en Kong (ACL Plugin)

**Configuración:**

```yaml
services:
- name: sisbon-dev
  plugins:
  - name: jwt
  - name: acl
    config:
      allow:
      - sisbon-read
      - sisbon-write
```

```yaml
consumers:
- username: tlm-mx-realm
  groups:
  - sisbon-read
  - gestal-read
```

**Pros:**

- ✅ Control centralizado en Kong
- ✅ Bloqueo temprano de requests no autorizados
- ✅ Reduce carga en backends

**Contras:**

- ❌ Duplicación de lógica de negocio (Kong + Backend)
- ❌ Cambios requieren reconfigurar Kong
- ❌ No soporta lógica compleja ("solo sus propios registros")
- ❌ Difícil testear (depende de Kong)
- ❌ Mapeo manual de roles JWT → ACL groups

#### Opción 2: Autorización en Kong (Routes por método HTTP)

**Configuración:**

```yaml
routes:
- name: sisbon-read-route
  methods: [GET]
  plugins:
  - acl:
      allow: [sisbon-read, sisbon-write, sisbon-admin]

- name: sisbon-write-route
  methods: [POST, PUT, PATCH]
  plugins:
  - acl:
      allow: [sisbon-write, sisbon-admin]

- name: sisbon-delete-route
  methods: [DELETE]
  plugins:
  - acl:
      allow: [sisbon-admin]
```

**Pros:**

- ✅ Control granular por método HTTP
- ✅ Kong bloquea requests inválidos temprano

**Contras:**

- ❌ 3x más routes por servicio
- ❌ Configuración compleja y repetitiva
- ❌ No soporta permisos por recurso (`/bonos/{id}` solo si es dueño)
- ❌ Mantenimiento costoso (cambios frecuentes)

#### Opción 3: Autorización en Backend (Elegido) ✅

**Configuración Kong:**

```yaml
services:
- name: sisbon-dev
  plugins:
  - name: jwt
    config:
      claims_to_verify: [exp]
      key_claim_name: iss
      run_on_preflight: false
  - name: request-transformer
    config:
      add:
        headers:
        - X-Forwarded-Authorization:$(headers.Authorization)
```

**Implementación Backend:**

```python
import jwt
from fastapi import Header, HTTPException, Depends

def verify_permissions(authorization: str = Header(None, alias="X-Forwarded-Authorization")):
    if not authorization:
        authorization = request.headers.get('Authorization')

    token = authorization.replace('Bearer ', '')
    payload = jwt.decode(token, options={"verify_signature": False})

    return {
        'roles': payload.get('realm_access', {}).get('roles', []),
        'country': payload.get('country'),
        'tenant': payload.get('tenant'),
        'client': payload.get('azp')
    }

@app.get("/api/sisbon/bonos")
def get_bonos(auth=Depends(verify_permissions)):
    if 'sisbon:read' not in auth['roles']:
        raise HTTPException(403, "Requiere permiso sisbon:read")

    # Lógica contextual: filtrar por país
    bonos = get_bonos_by_country(auth['country'])
    return bonos

@app.post("/api/sisbon/bonos")
def create_bono(bono: BonoCreate, auth=Depends(verify_permissions)):
    if 'sisbon:write' not in auth['roles']:
        raise HTTPException(403, "Requiere permiso sisbon:write")

    # Validaciones de negocio
    if bono.monto > 10000 and 'sisbon:admin' not in auth['roles']:
        raise HTTPException(403, "Bonos > 10000 requieren sisbon:admin")

    return create_bono_in_db(bono, auth['tenant'])
```

**Pros:**

- ✅ Flexibilidad completa para lógica de negocio
- ✅ Un solo lugar para reglas de autorización
- ✅ Fácil de testear (unit tests)
- ✅ No necesita reconfigurar Kong
- ✅ Soporta permisos contextuales complejos
- ✅ Auditoría detallada en logs del backend

**Contras:**

- ⚠️ Backend debe decodificar JWT (overhead mínimo)
- ⚠️ Requests inválidos llegan al backend (pero Kong ya validó autenticación)

### Decisión

**Opción 3: Kong autentica, Backend autoriza**

**División de responsabilidades:**

| Capa | Responsabilidad | Qué valida |
|------|----------------|------------|
| **Kong (Gateway)** | Autenticación | ✅ Firma JWT válida<br>✅ Token no expirado (`exp`)<br>✅ Rate limiting<br>✅ CORS |
| **Backend (API)** | Autorización | ✅ Roles específicos (`sisbon:read`, `sisbon:write`)<br>✅ Lógica de negocio<br>✅ Permisos contextuales<br>✅ Validaciones de datos |

**Kong pasa el token completo al backend via header:**

```http
GET /api/sisbon/bonos HTTP/1.1
Host: sisbon-dev.internal.talma.com.pe
Authorization: Bearer eyJhbGc...
X-Forwarded-Authorization: Bearer eyJhbGc...
```

### Sustento Técnico

#### Referencias de la Industria

**1. Netflix (Zuul Gateway):**
> "The edge service validates the token signature and expiration, then forwards the claims to backend services for authorization decisions."

- Arquitectura: Zuul valida JWT, microservicios deciden permisos
- Fuente: [Netflix TechBlog - Security](https://netflixtechblog.com/)

**2. Google Cloud (API Gateway + Cloud IAM):**
> "API Gateway authenticates requests using JWT validation. Backend services authorize based on user identity and attributes passed in JWT claims."

- Google Cloud Endpoints valida JWT
- Cloud Run/App Engine services manejan autorización
- Fuente: [Google Cloud API Gateway Docs](https://cloud.google.com/api-gateway/docs/authenticate-service-account)

**3. Auth0 (Identity Platform):**
> "API Gateway: Verify JWT signature and expiration. Backend API: Check scopes/permissions for fine-grained access control."

- Recomendación oficial de Auth0
- Separación clara de concerns
- Fuente: [Auth0 API Authorization](https://auth0.com/docs/authorization/)

**4. Kong Inc (Oficial):**
> "JWT plugin validates token authenticity. Use request-transformer to pass verified claims to upstream services for authorization logic."

- Documentación oficial de Kong
- Patrón recomendado para JWT
- Fuente: [Kong JWT Plugin Docs](https://docs.konghq.com/hub/kong-inc/jwt/)

**5. OWASP (Security Best Practices):**
> "Separation of concerns: Authentication at the edge (API Gateway), authorization close to the resource (backend service)."

- Security by design principle
- Reduce attack surface
- Fuente: [OWASP API Security](https://owasp.org/www-project-api-security/)

#### Beneficios Validados

**1. Flexibilidad:**

```python
# ✅ Backend puede implementar lógica compleja
if user_role == 'sisbon:write' and user_country == 'MX':
    # Solo puede editar bonos de México
    if bono.country != 'MX':
        raise HTTPException(403, "No puede editar bonos de otro país")
```

**2. Testabilidad:**

```python
# ✅ Unit tests sin Kong
def test_create_bono_without_permission():
    auth = {'roles': ['sisbon:read']}  # No tiene sisbon:write
    with pytest.raises(HTTPException) as exc:
        create_bono(bono, auth)
    assert exc.status_code == 403
```

**3. Mantenibilidad:**

```python
# ✅ Cambios de permisos en código, no en Kong
# Antes: sisbon:write puede crear bonos ilimitados
# Ahora: sisbon:write tiene límite, sisbon:admin no tiene límite
if bono.monto > 10000 and 'sisbon:admin' not in auth['roles']:
    raise HTTPException(403, "Bonos > 10000 requieren sisbon:admin")
```

**4. Auditoría:**

```python
# ✅ Logs detallados en backend
logger.info(f"User {auth['client']} from {auth['country']} "
            f"with roles {auth['roles']} created bono {bono.id}")
```

### Consecuencias

**Positivas:**

- ✅ Kong se enfoca en autenticación, rate limiting, CORS
- ✅ Backend tiene contexto completo para decisiones
- ✅ Cambios de permisos no requieren reconfigurar Kong
- ✅ Lógica de negocio en un solo lugar (código)
- ✅ Fácil agregar nuevos permisos y roles
- ✅ Compatible con futuros sistemas de autorización (Casbin, OPA)

**Negativas:**

- ⚠️ Backend debe decodificar JWT (overhead < 1ms)
- ⚠️ Requests con permisos inválidos llegan al backend (pero Kong ya validó autenticación)

**Mitigaciones:**

- Librería JWT ligera en backend (PyJWT, jsonwebtoken, jose4j)
- Cache de decodificación JWT en backend (opcional)
- Logs y métricas para detectar abuso

### Implementación

**1. Configuración Kong (todos los ambientes):**

Archivos actualizados:

- `config/kong/kong-dev.yaml`
- `config/kong/kong-nonprod.yaml`
- `config/kong/kong-qa.yaml`
- `config/kong/kong-prod.yaml`

```yaml
plugins:
- name: jwt
  config:
    claims_to_verify: [exp]
    key_claim_name: iss
    run_on_preflight: false
- name: request-transformer
  config:
    add:
      headers:
      - X-Forwarded-Authorization:$(headers.Authorization)
```

**2. Implementación Backend (ejemplo Python/FastAPI):**

```python
# src/auth/jwt_handler.py
import jwt
from fastapi import Header, HTTPException
from typing import Dict, List

def decode_jwt_from_kong(authorization: str = Header(None, alias="X-Forwarded-Authorization")) -> Dict:
    """
    Decodifica JWT ya validado por Kong.
    No verifica firma (Kong ya lo hizo).
    """
    if not authorization:
        raise HTTPException(401, "Token no proporcionado")

    token = authorization.replace('Bearer ', '')

    try:
        payload = jwt.decode(token, options={"verify_signature": False})
        return {
            'roles': payload.get('realm_access', {}).get('roles', []),
            'country': payload.get('country'),
            'tenant': payload.get('tenant'),
            'client': payload.get('azp'),
            'sub': payload.get('sub')
        }
    except jwt.DecodeError:
        raise HTTPException(401, "Token inválido")

def require_permissions(required_roles: List[str]):
    """
    Decorator para validar permisos en endpoints.
    """
    def decorator(func):
        def wrapper(auth: Dict = Depends(decode_jwt_from_kong), *args, **kwargs):
            user_roles = auth.get('roles', [])
            if not any(role in user_roles for role in required_roles):
                raise HTTPException(
                    403,
                    f"Requiere uno de estos permisos: {', '.join(required_roles)}"
                )
            return func(auth=auth, *args, **kwargs)
        return wrapper
    return decorator

# Uso en endpoints
@app.get("/api/sisbon/bonos")
@require_permissions(['sisbon:read', 'sisbon:admin'])
def get_bonos(auth: Dict = Depends(decode_jwt_from_kong)):
    return get_bonos_by_country(auth['country'])

@app.post("/api/sisbon/bonos")
@require_permissions(['sisbon:write', 'sisbon:admin'])
def create_bono(bono: BonoCreate, auth: Dict = Depends(decode_jwt_from_kong)):
    if bono.monto > 10000 and 'sisbon:admin' not in auth['roles']:
        raise HTTPException(403, "Bonos > 10000 requieren sisbon:admin")

    return create_bono_in_db(bono, auth['tenant'])
```

### Evolución Futura

**Fase 1 (Actual):** Backend decodifica JWT y valida roles

**Fase 2 (Futuro):** Integración con OPA (Open Policy Agent)

```yaml
# policy.rego
package sisbon.authz

allow {
    input.method == "GET"
    "sisbon:read" in input.roles
}

allow {
    input.method == "POST"
    "sisbon:write" in input.roles
    input.bono.monto <= 10000
}

allow {
    "sisbon:admin" in input.roles
}
```

**Fase 3 (Opcional):** Casbin para RBAC/ABAC complejo

```ini
# model.conf
[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
```

### Referencias

- [Netflix Security Architecture](https://netflixtechblog.com/)
- [Google Cloud API Gateway Authentication](https://cloud.google.com/api-gateway/docs/authenticate-service-account)
- [Auth0 API Authorization](https://auth0.com/docs/authorization/)
- [Kong JWT Plugin Documentation](https://docs.konghq.com/hub/kong-inc/jwt/)
- [OWASP API Security](https://owasp.org/www-project-api-security/)
- [Open Policy Agent](https://www.openpolicyagent.org/)
- [Casbin Authorization Library](https://casbin.org/)

---

## ADR-007: JWKS para Validación JWT Automática

### Estado

✅ **Aceptado** - Diciembre 2025

### Contexto

La validación de tokens JWT requiere verificar la firma usando la clave pública RSA de Keycloak. Kong JWT plugin soporta dos métodos:

1. **Claves RSA estáticas** (copiadas manualmente en YAML)
2. **JWKS** (JSON Web Key Set) - descarga automática desde Keycloak

Se necesita un método que permita rotación de claves sin intervención manual y sin downtime.

### Decisión

**Usar JWKS para validación JWT automática** en todos los ambientes.

**Ventajas:**

- ✅ Rotación automática sin intervención manual
- ✅ Zero downtime en rotaciones
- ✅ Soporte multi-key con Key ID (kid)
- ✅ Industry standard (Google, Auth0, Okta, AWS)
- ✅ Kong cachea claves localmente

### Implementación

**Configuración:**

```yaml
consumers:
- username: tlm-mx-realm
  jwt_secrets:
  - key: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-mx"
    algorithm: RS256
    jwks_uri: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-mx/protocol/openid-connect/certs"

- username: tlm-pe-realm
  jwt_secrets:
  - key: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe"
    algorithm: RS256
    jwks_uri: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-pe/protocol/openid-connect/certs"
```

Aplicado en: `kong-dev.yaml`, `kong-nonprod.yaml`, `kong-qa.yaml`, `kong-prod.yaml`

**Cómo funciona:**

1. Kong descarga claves públicas desde el endpoint JWKS de Keycloak
2. Al recibir JWT, Kong lee el `kid` (Key ID) del header del token
3. Busca la clave correspondiente en su caché JWKS
4. Valida la firma usando esa clave pública
5. Kong actualiza periódicamente las claves desde el endpoint

**Rotación de claves:**

Cuando Keycloak genera una nueva clave, mantiene la antigua activa temporalmente. Kong descarga ambas claves y valida tokens con cualquiera. Después del TTL de tokens antiguos, se elimina la clave antigua. **Zero downtime en todo el proceso.**

### Configuración en Keycloak

**No requiere configuración** - El endpoint JWKS está disponible automáticamente en cada realm como parte del estándar OpenID Connect Discovery.

Endpoints automáticos:

- `http://.../auth/realms/tlm-mx/protocol/openid-connect/certs`
- `http://.../auth/realms/tlm-pe/protocol/openid-connect/certs`

### Validación

```bash
# Verificar endpoint JWKS
curl -s http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-mx/protocol/openid-connect/certs | jq '.keys[] | {kid, use, alg}'

# Desplegar Kong
docker compose up -d kong-deck-bootstrap

# Probar request con JWT
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api-dev/sisbon/health
```

### Referencias

- [RFC 7517: JSON Web Key (JWK)](https://datatracker.ietf.org/doc/html/rfc7517)
- [OpenID Connect Discovery](https://openid.net/specs/openid-connect-discovery-1_0.html)
- [Kong JWT Plugin - JWKS Support](https://docs.konghq.com/hub/kong-inc/jwt/)

---

**Última actualización:** Diciembre 2025
**Responsable:** Equipo de Arquitectura Talma
