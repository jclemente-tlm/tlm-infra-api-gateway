# Estrategia de Dominios - Talma

## 📋 Índice

1. [Convención de Nomenclatura](#convención-de-nomenclatura)
2. [Dominios Públicos](#dominios-públicos)
3. [Dominios Privados](#dominios-privados)
4. [Routing y Arquitectura](#routing-y-arquitectura)
5. [Añadir Nuevos Servicios](#añadir-nuevos-servicios)
6. [Ejemplos de Uso](#ejemplos-de-uso)

---

## Convención de Nomenclatura

### Estándar de la Industria

Talma adopta la convención más utilizada en empresas modernas (AWS, Azure, Google Cloud):

```
<servicio>[-<env>].talma.com.pe
```

**Componentes:**

- `<servicio>`: Identificador del servicio (api, auth, grafana, etc.)
- `<env>`: Ambiente (dev, qa) - **PROD no lleva sufijo**
- `.talma.com.pe`: Dominio base de la organización

### Para Servicios Internos

```
<servicio>[-<env>].internal.talma.com.pe
```

**Beneficios:**

- Separación clara entre público e interno
- Mayor seguridad (internal solo accesible desde VPC)
- Facilita políticas de firewall y security groups

---

## Dominios Públicos

### Lista Completa (9 dominios)

#### API Gateway

**Punto único de entrada para todos los servicios de Talma:**
- Sistemas de negocio (Sisbon, Gestal, BRS)
- Integraciones IA y machine learning
- APIs internas y externas
- Multi-país (México, Perú)

```
api.talma.com.pe                  → Kong PROD (todos los servicios)
api-qa.talma.com.pe               → Kong QA (todos los servicios)
api-dev.talma.com.pe              → Kong DEV (todos los servicios)
```

**Configuración DNS:**

- Tipo: CNAME
- Valor: `alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com`
- TTL: 300

**Target:**

- ALB Listener Rule → Target Group: `kong-api-tg` (puerto 8000)

---

#### Autenticación (Keycloak)

```
auth.talma.com.pe                 → Keycloak PROD
auth-qa.talma.com.pe              → Keycloak QA
auth-dev.talma.com.pe             → Keycloak DEV
```

**Configuración DNS:**

- Tipo: CNAME
- Valor: `alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com`
- TTL: 300

**Target:**

- ALB Listener Rule → Target Group: `keycloak-tg` (puerto 8080)

**Realms:**

- `auth.talma.com.pe/realms/tlm-mx` → Clientes de México
- `auth.talma.com.pe/realms/tlm-pe` → Clientes de Perú

---

#### Observabilidad (Grafana)

```
grafana.talma.com.pe              → Grafana PROD
grafana-qa.talma.com.pe           → Grafana QA
grafana-dev.talma.com.pe          → Grafana DEV
```

**Configuración DNS:**

- Tipo: CNAME
- Valor: `alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com`
- TTL: 300

**Target:**

- ALB Listener Rule → Target Group: `grafana-tg` (puerto 3000)

---

### Certificados SSL

**Wildcard Certificate:**

```
*.talma.com.pe
talma.com.pe
```

**Proveedor:** AWS Certificate Manager (ACM)

**Validación:** DNS (registros CNAME en Route53)

**Uso:**

- Adjuntar al ALB Listener HTTPS (puerto 443)
- Redirect automático HTTP → HTTPS

---

## Dominios Privados

### Lista Completa (13+ dominios)

Configurados en **Route53 Private Hosted Zone** asociada a la VPC.

#### Backends de Servicios

##### Sisbon (Sistema de Bonificaciones - Multi-país)

```
sisbon.internal.talma.com.pe              → PROD (IP: 192.168.x.x)
sisbon-qa.internal.talma.com.pe           → QA
sisbon-dev.internal.talma.com.pe          → DEV
```

**Puerto:** 8080
**Protocolo:** HTTP (interno, no necesita HTTPS)

##### Gestal (Sistema de Gestión de Tickets - Perú)

```
gestal.internal.talma.com.pe              → PROD
gestal-qa.internal.talma.com.pe           → QA
gestal-dev.internal.talma.com.pe          → DEV
```

**Puerto:** 8080
**Protocolo:** HTTP

##### Futuros Servicios

Los siguientes servicios se agregarán siguiendo el mismo patrón:

- `brs.internal.talma.com.pe` - Sistema de reportes y analytics
- `ia-models.internal.talma.com.pe` - Endpoints de modelos IA
- `[servicio].internal.talma.com.pe` - Otros servicios según necesidad

**Patrón:** Cada nuevo servicio suma +3 dominios (prod, qa, dev)

---

#### Administración

##### Konga (Admin UI de Kong)

```
konga.internal.talma.com.pe               → PROD
konga-qa.internal.talma.com.pe            → QA
konga-dev.internal.talma.com.pe           → DEV
```

**Puerto:** 1337
**Acceso:** Solo desde VPN/VPC
**Autenticación:** Usuario/contraseña de Konga

---

#### Observabilidad

##### Observability Proxy (Envoy)

```
observability.internal.talma.com.pe       → PROD (Servidor centralizado de observabilidad)
observability-qa.internal.talma.com.pe    → QA (Servidor centralizado de observabilidad)
observability-dev.internal.talma.com.pe   → DEV (Servidor centralizado de observabilidad)
```

**Puerto:** 8080 (HTTP/gRPC proxy)
**Protocolo:** HTTP, gRPC, OTLP
**Tecnología:** Envoy Proxy
**Ubicación:** Servidor dedicado de observabilidad
**Función:** Único punto de acceso para Loki, Tempo y Mimir
**Clientes:** Grafana, Alloy, servicios que envían métricas/logs/traces

**⚠️ Importante:**

- Loki, Tempo y Mimir **NO tienen dominios públicos ni privados**
- Solo se exponen internamente en el servidor de observabilidad
- Todo acceso debe pasar por el proxy de observabilidad
- Loki (puerto 3100), Tempo (puerto 4317), Mimir (puerto 9009) solo accesibles vía localhost en el servidor

**Routing en Envoy:**

```
observability.internal.talma.com.pe/loki/*   → localhost:3100 (Loki)
observability.internal.talma.com.pe/tempo/*  → localhost:4317 (Tempo)
observability.internal.talma.com.pe/mimir/*  → localhost:9009 (Mimir)
```

---

### Configuración DNS Privada

**Zona:** `internal.talma.com.pe`
**Tipo:** Private Hosted Zone
**VPC:** Asociada a VPC principal de AWS

**Tipos de registros:**

- **A Record:** Para IPs privadas estáticas
- **CNAME:** Para ALBs internos
- **Alias:** Para ECS Services, RDS, etc.

**Ejemplo:**

```hcl
resource "aws_route53_record" "sisbon_prod" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "sisbon.internal.talma.com.pe"
  type    = "A"
  ttl     = "300"
  records = ["192.168.10.50"]
}

# Observability Proxy - Único punto de acceso para observabilidad
# IP del servidor dedicado de observabilidad
resource "aws_route53_record" "observability_prod" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "observability.internal.talma.com.pe"
  type    = "A"
  ttl     = "300"
  records = ["192.168.20.10"]  # IP del servidor de observabilidad
}
```

**Nota sobre Arquitectura de Observabilidad:**

El proxy de observabilidad (Envoy) es el **único componente expuesto** del stack. Loki, Tempo y Mimir **NO tienen DNS** porque:

- Se ejecutan en el mismo servidor que el proxy (comunicación localhost)
- No necesitan ser accesibles desde fuera del servidor
- Mayor seguridad: superficie de ataque mínima
- El proxy provee autenticación/autorización centralizada
- Rate limiting y control de tráfico en un solo punto
- Permite agregar otros proxies Envoy sin conflicto de nombres

**Configuración de clientes:**

```yaml
# Ejemplo: Alloy envía telemetría a través del proxy de observabilidad
# Desde servicios externos (fuera del servidor de observabilidad)
loki:
  client:
    url: http://observability.internal.talma.com.pe:8080/loki/api/v1/push

tempo:
  endpoint: observability.internal.talma.com.pe:8080
  # Proxy rutea /tempo/* a localhost:4317

mimir:
  remote_write:
    url: http://observability.internal.talma.com.pe:8080/mimir/api/v1/push

# Ejemplo: Grafana accede desde el mismo servidor (localhost)
# Dentro del servidor de observabilidad
loki:
  datasource:
    url: http://localhost:8080/loki

tempo:
  datasource:
    url: http://localhost:8080/tempo

mimir:
  datasource:
    url: http://localhost:8080/mimir
```

**Arquitectura del Servidor de Observabilidad:**

```
[Servidor de Observabilidad - 192.168.20.10]
  ├── Envoy (puerto 8080) - Único componente con DNS
  │   ├── Listener: 0.0.0.0:8080
  │   ├── Route: /loki/* → 127.0.0.1:3100
  │   ├── Route: /tempo/* → 127.0.0.1:4317
  │   └── Route: /mimir/* → 127.0.0.1:9009
  │
  ├── Loki (puerto 3100) - Sin DNS, solo localhost
  ├── Tempo (puerto 4317) - Sin DNS, solo localhost
  ├── Mimir (puerto 9009) - Sin DNS, solo localhost
  └── Grafana (puerto 3000) - DNS público: grafana.talma.com.pe
      └── Accede a Loki/Tempo/Mimir vía localhost:8080

loki:
  endpoint: http://observability.internal.talma.com.pe:8080/loki/api/v1/push

tempo:
  endpoint: observability.internal.talma.com.pe:8080

mimir:
  endpoint: http://observability.internal.talma.com.pe:8080/mimir/api/v1/push
```

---

## Routing y Arquitectura

### Flujo Completo de una Request

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Cliente obtiene token JWT                                    │
│    POST https://auth.talma.com.pe/realms/tlm-mx/protocol/...   │
│    → Retorna: access_token                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Cliente llama al API con token                               │
│    GET https://api.talma.com.pe/sisbon/usuarios                 │
│    Authorization: Bearer <token>                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. DNS Público resuelve                                         │
│    api.talma.com.pe → alb-monitoreo-xxx.elb.amazonaws.com      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. ALB recibe request                                           │
│    - Termina SSL                                                │
│    - Listener Rule: Host=api.talma.com.pe                       │
│    - Forward to: kong-api-tg (puerto 8000)                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Kong valida JWT                                              │
│    - Plugin JWT verifica firma RSA256                           │
│    - Verifica exp claim                                         │
│    - Identifica consumer por iss claim                          │
│    - Match route: /sisbon/* → service sisbon-prod               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. DNS Privado resuelve                                         │
│    sisbon.internal.talma.com.pe → 192.168.10.50                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 7. Backend recibe request                                       │
│    GET http://sisbon.internal.talma.com.pe:8080/usuarios       │
│    Headers añadidos por Kong:                                   │
│      - X-Consumer-Username: tlm-mx-realm                        │
│      - X-Consumer-Id: xxx                                       │
│      - X-Credential-Identifier: auth.talma.com.pe/realms/tlm-mx│
│      - Authorization: Bearer <token> (forwarded)                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
├─────────────────────────────────────────────────────────────────┤
│ 8. Backend responde y envía telemetría                          │
│    - Envía logs → observability.internal:8080/loki/* → localhost:3100    │
│    - Envía traces → observability.internal:8080/tempo/* → localhost:4317 │
│    - Envía métricas → observability.internal:8080/mimir/* → localhost:9009│
│    - Retorna datos al cliente vía Kong y ALB                    │
│    │
│    Nota: Loki/Tempo/Mimir solo accesibles via localhost en       │
│          servidor de observabilidad, NO tienen DNS propio        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 9. Grafana consulta datos (desde servidor de observabilidad)   │
│    - Logs: localhost:8080/loki/* → localhost:3100 (Loki)         │
│    - Traces: localhost:8080/tempo/* → localhost:4317 (Tempo)     │
│    - Métricas: localhost:8080/mimir/* → localhost:9009 (Mimir)   │
│    │
│    Grafana accede a Envoy vía localhost, no necesita DNS         │
└─────────────────────────────────────────────────────────────────┘
```

---

### Configuración en Kong

#### Service Sisbon PROD

```bash
curl -X POST http://localhost:8001/services \
  --data "name=sisbon-prod" \
  --data "url=http://sisbon.internal.talma.com.pe:8080" \
  --data "retries=5" \
  --data "connect_timeout=60000" \
  --data "write_timeout=60000" \
  --data "read_timeout=60000"
```

#### Route Sisbon PROD

```bash
curl -X POST http://localhost:8001/services/sisbon-prod/routes \
  --data "name=sisbon-prod-route" \
  --data "paths[]=/sisbon" \
  --data "paths[]=/bonificaciones" \
  --data "strip_path=false" \
  --data "preserve_host=false"
```

#### Plugin JWT

```bash
curl -X POST http://localhost:8001/services/sisbon-prod/plugins \
  --data "name=jwt" \
  --data "config.claims_to_verify=exp" \
  --data "config.key_claim_name=iss"
```

---

## Añadir Nuevos Servicios

### Checklist para Nuevo Servicio

#### 1. Crear Backend

- [ ] Desplegar aplicación en servidor/contenedor
- [ ] Configurar puerto (recomendado: 8080)
- [ ] Validar health check endpoint

#### 2. Configurar DNS Privado

```bash
# Route53 Private Hosted Zone
nuevo-servicio.internal.talma.com.pe      → IP PROD
nuevo-servicio-qa.internal.talma.com.pe   → IP QA
nuevo-servicio-dev.internal.talma.com.pe  → IP DEV
```

#### 3. Configurar Kong

**Service:**

```bash
curl -X POST http://localhost:8001/services \
  --data "name=nuevo-servicio-prod" \
  --data "url=http://nuevo-servicio.internal.talma.com.pe:8080"
```

**Route:**

```bash
curl -X POST http://localhost:8001/services/nuevo-servicio-prod/routes \
  --data "name=nuevo-servicio-prod-route" \
  --data "paths[]=/nuevo-servicio" \
  --data "strip_path=false"
```

**JWT Plugin:**

```bash
curl -X POST http://localhost:8001/services/nuevo-servicio-prod/plugins \
  --data "name=jwt" \
  --data "config.claims_to_verify=exp"
```

#### 4. Configurar Keycloak (si necesita clients específicos)

**Crear Client:**

- Realm: `tlm-mx` o `tlm-pe`
- Client ID: `nuevo-servicio-mx-prod`
- Client Authentication: ON
- Service Accounts: Enabled
- Roles: Asignar desde Realm Roles

#### 5. Probar

```bash
# Obtener token
TOKEN=$(curl -s -X POST "https://auth.talma.com.pe/realms/tlm-mx/protocol/openid-connect/token" \
  -d "client_id=nuevo-servicio-mx-prod" \
  -d "client_secret=xxx" \
  -d "grant_type=client_credentials" | jq -r .access_token)

# Probar API
curl -H "Authorization: Bearer $TOKEN" \
  https://api.talma.com.pe/nuevo-servicio/health
```

---

### Ejemplo Completo: Añadir "Inventario"

**Paso 1: DNS Privado**

```bash
inventario.internal.talma.com.pe → 192.168.10.100
```

**Paso 2: Kong Service**

```bash
curl -X POST http://localhost:8001/services \
  --data "name=inventario-prod" \
  --data "url=http://inventario.internal.talma.com.pe:8080"
```

**Paso 3: Kong Route**

```bash
curl -X POST http://localhost:8001/services/inventario-prod/routes \
  --data "name=inventario-prod-route" \
  --data "paths[]=/inventario" \
  --data "strip_path=false"
```

**Paso 4: Kong JWT Plugin**

```bash
curl -X POST http://localhost:8001/services/inventario-prod/plugins \
  --data "name=jwt" \
  --data "config.claims_to_verify=exp"
```

**Paso 5: Cliente usa**

```bash
GET https://api.talma.com.pe/inventario/productos
```

**✅ NO se necesita:**

- Nuevo dominio público
- Modificar ALB
- Modificar certificado SSL
- Modificar DNS público

---

## Ejemplos de Uso

### Obtener Token JWT

```bash
# Token para Sisbon México (PROD)
curl -X POST "https://auth.talma.com.pe/realms/tlm-mx/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=sisbon-mx-prod" \
  -d "client_secret=YOUR_SECRET" \
  -d "grant_type=client_credentials"

# Respuesta
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "expires_in": 300,
  "token_type": "Bearer"
}
```

### Llamar APIs con Token

```bash
# Guardar token
TOKEN="eyJhbGciOiJSUzI1NiIs..."

# Sisbon - Bonificaciones - Kilos Ingresados
curl -H "Authorization: Bearer $TOKEN" \
  -X POST -H "Content-Type: application/json" \
  https://api.talma.com.pe/sisbon/bonificaciones/kilos-ingresados/otro-almacen \
  -d '{"fecha":"2025-12-04","kilos":1500.50}'

curl -H "Authorization: Bearer $TOKEN" \
  -X POST -H "Content-Type: application/json" \
  https://api.talma.com.pe/sisbon/bonificaciones/kilos-ingresados/siop-impo \
  -d '{"fecha":"2025-12-04","vuelo":"LA2345","kilos":2400.75}'

curl -H "Authorization: Bearer $TOKEN" \
  -X POST -H "Content-Type: application/json" \
  https://api.talma.com.pe/sisbon/bonificaciones/kilos-ingresados/siop-expo \
  -d '{"fecha":"2025-12-04","vuelo":"LA2346","kilos":1800.25}'

# Sisbon - Bonificaciones - Kilos Facturados
curl -H "Authorization: Bearer $TOKEN" \
  -X POST -H "Content-Type: application/json" \
  https://api.talma.com.pe/sisbon/bonificaciones/kilos-facturados/siop-impo \
  -d '{"fecha":"2025-12-04","factura":"FACT-001","kilos_facturados":2350.50}'

curl -H "Authorization: Bearer $TOKEN" \
  -X POST -H "Content-Type: application/json" \
  https://api.talma.com.pe/sisbon/bonificaciones/kilos-facturados/siop-expo \
  -d '{"fecha":"2025-12-04","factura":"FACT-002","kilos_facturados":1750.25}'

# Gestal - En definición
# Los endpoints específicos de Gestal estarán disponibles próximamente
```

### Acceso a Herramientas de Observabilidad

```bash
# Grafana - Visualización (acceso público con autenticación propia)
https://grafana.talma.com.pe
https://grafana-qa.talma.com.pe
https://grafana-dev.talma.com.pe

# Konga - Administración de Kong (acceso privado interno)
# Solo accesible desde VPN o red interna
http://konga.internal.talma.com.pe
http://konga-qa.internal.talma.com.pe
http://konga-dev.internal.talma.com.pe

# Observability Proxy Admin - Stats de Envoy (desde servidor)
# Solo accesible desde el servidor de observabilidad
http://observability.internal.talma.com.pe:9901/stats
http://observability-qa.internal.talma.com.pe:9901/stats
http://observability-dev.internal.talma.com.pe:9901/stats

# Nota: Loki, Tempo y Mimir NO tienen acceso directo
# Solo se accede a través de Grafana o proxy de observabilidad
```

### Ambientes QA y DEV

```bash
# QA - Obtener token
curl -X POST "https://auth-qa.talma.com.pe/realms/tlm-mx/protocol/openid-connect/token" \
  -d "client_id=sisbon-mx-qa" \
  -d "client_secret=YOUR_SECRET" \
  -d "grant_type=client_credentials"

# QA - Llamar API
curl -H "Authorization: Bearer $TOKEN_QA" \
  -X POST -H "Content-Type: application/json" \
  https://api-qa.talma.com.pe/sisbon/bonificaciones/kilos-ingresados/siop-impo \
  -d '{"fecha":"2025-12-04","vuelo":"LA2345","kilos":2400.75}'

# DEV - Llamar API
curl -H "Authorization: Bearer $TOKEN_DEV" \
  -X POST -H "Content-Type: application/json" \
  https://api-dev.talma.com.pe/sisbon/bonificaciones/kilos-facturados/siop-expo \
  -d '{"fecha":"2025-12-04","factura":"FACT-DEV-001","kilos_facturados":1500.00}'
```

### Acceder a Herramientas Internas

```bash
# Konga - Admin de Kong (desde VPN o VPC)
http://konga.internal.talma.com.pe:1337

# Grafana - Visualización (acceso público)
https://grafana.talma.com.pe

# Observability Proxy Admin - Stats de Envoy (desde servidor)
http://localhost:9901/stats
http://localhost:9901/clusters

# Loki/Tempo/Mimir - NO tienen acceso directo
# Solo accesibles vía proxy (localhost:8080) o Grafana
```

---

## Resumen de Dominios

### Dominios Públicos (9)

```
api.talma.com.pe
api-qa.talma.com.pe
api-dev.talma.com.pe

auth.talma.com.pe
auth-qa.talma.com.pe
auth-dev.talma.com.pe

grafana.talma.com.pe
grafana-qa.talma.com.pe
grafana-dev.talma.com.pe
```

### Dominios Privados Actuales (13)

```text
# Backends de Servicios (6)
sisbon.internal.talma.com.pe
sisbon-qa.internal.talma.com.pe
sisbon-dev.internal.talma.com.pe

gestal.internal.talma.com.pe
gestal-qa.internal.talma.com.pe
gestal-dev.internal.talma.com.pe

# Administración (3)
konga.internal.talma.com.pe
konga-qa.internal.talma.com.pe
konga-dev.internal.talma.com.pe

# Observabilidad - Solo proxy expuesto (3)
observability.internal.talma.com.pe     # Proxy PROD (Envoy)
observability-qa.internal.talma.com.pe  # Proxy QA (Envoy)
observability-dev.internal.talma.com.pe # Proxy DEV (Envoy)

# Reserva para futuros servicios (1)
<nuevo-servicio>.internal.talma.com.pe
```

**⚠️ Nota crítica sobre observabilidad:**

- **Loki, Tempo y Mimir NO tienen dominios DNS**
- Se ejecutan en el mismo servidor que el proxy (Envoy)
- Solo accesibles vía `localhost` en puertos 3100, 4317, 9009
- Proxy hace routing: `observability.internal:8080/loki/*` → `localhost:3100`
- Mayor seguridad: superficie de ataque mínima
- Nomenclatura específica permite múltiples Envoy en la infraestructura

---

### Crecimiento Futuro

**Por cada nuevo backend:**

- +3 dominios privados (prod, qa, dev)
- +0 dominios públicos
- +1 servicio en Kong
- +1 ruta en Kong

---

## Documentos Relacionados

- [Keycloak Naming Standard](./KEYCLOAK_NAMING_STANDARD.md)
- [Keycloak Kong Integration](./KEYCLOAK_KONG_INTEGRATION.md)
- [Database Strategy](./DATABASE_STRATEGY.md)
- [Quick Start Guide](./QUICK_START.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)

---

**Última actualización:** Diciembre 2025
**Versión:** 1.0
**Autor:** Equipo de Infraestructura Talma
