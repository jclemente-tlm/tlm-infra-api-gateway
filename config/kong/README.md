# Kong Declarative Configuration (decK)

Este directorio contiene la configuración declarativa de Kong usando el formato oficial de decK.

## 📁 Archivos

| Archivo | Ambiente | Descripción |
|---------|----------|-------------|
| `kong-dev.yaml` | **DEV** | Configuración completa de desarrollo (local + servidor DEV) |
| `kong-qa.yaml` | **QA** | Configuración de ambiente de pruebas |
| `kong-prod.yaml` | **PROD** | Configuración de producción |

## 🎯 Estructura de Archivos

Cada archivo YAML contiene:

```yaml
_format_version: "3.0"

consumers:          # JWT consumers compartidos (tlm-mx-realm, tlm-pe-realm)
  - username: tlm-mx-realm
    jwt_secrets:
    - key: "http://alb-monitoreo-.../auth/realms/tlm-mx"
      algorithm: RS256
      jwks_uri: "http://.../auth/realms/tlm-mx/protocol/openid-connect/certs"
      # JWKS: Kong descarga claves automáticamente, sin mantenimiento manual

services:           # Todos los servicios del ambiente
  - name: sisbon-{env}
    url: ...
    routes: ...
    plugins:
    - jwt             # Valida autenticación (firma + expiración usando JWKS)
    - request-transformer  # Pasa token al backend para autorización
  - name: gestal-{env}
    url: ...
    routes: ...
    plugins:
    - jwt
    - request-transformer
```

### 🔑 Validación JWT con JWKS

**JWKS (JSON Web Key Set)** permite rotación automática de claves:

```yaml
consumers:
- username: tlm-mx-realm
  jwt_secrets:
  - key: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-mx"
    algorithm: RS256
    jwks_uri: "http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth/realms/tlm-mx/protocol/openid-connect/certs"
```

**Ventajas:**

- ✅ Rotación automática sin reconfigurar Kong
- ✅ Zero downtime
- ✅ Multi-key support (kid)
- ✅ Industry standard

Kong descarga claves automáticamente desde Keycloak y las actualiza periódicamente. No requiere configuración en Keycloak (endpoint JWKS disponible por defecto).

### 🔐 Autenticación vs Autorización

**Arquitectura implementada (Industry Best Practice):**

- **Kong (API Gateway)**: Autenticación
  - ✅ Valida firma del JWT usando clave pública RSA
  - ✅ Verifica expiración del token (`exp` claim)
  - ✅ Pasa token completo al backend via header `X-Forwarded-Authorization`
  - ✅ Rate limiting, CORS, logging

- **Backend (Servicio)**: Autorización
  - ✅ Decodifica JWT (sin verificar firma, Kong ya lo hizo)
  - ✅ Extrae roles: `realm_access.roles` → `["sisbon:read", "sisbon:write"]`
  - ✅ Valida permisos específicos según endpoint y método HTTP
  - ✅ Aplica lógica de negocio contextual (ej: "solo sus propios registros")

**Ejemplo de token JWT:**

```json
{
  "iss": "http://.../auth/realms/tlm-mx",
  "azp": "sisbon-mx-dev",
  "realm_access": {
    "roles": ["sisbon:read", "sisbon:write"]
  },
  "country": "MX",
  "tenant": "tlm-mx"
}
```

**Ejemplo en backend (Python/FastAPI):**

```python
import jwt
from fastapi import Header, HTTPException

def verify_permissions(authorization: str = Header(None, alias="X-Forwarded-Authorization")):
    token = authorization.replace('Bearer ', '')
    payload = jwt.decode(token, options={"verify_signature": False})

    return {
        'roles': payload.get('realm_access', {}).get('roles', []),
        'country': payload.get('country'),
        'tenant': payload.get('tenant'),
        'client': payload.get('azp')
    }

@app.get("/api/bonos")
def get_bonos(auth=Depends(verify_permissions)):
    if 'sisbon:read' not in auth['roles']:
        raise HTTPException(403, "Requiere permiso sisbon:read")

    bonos = get_bonos_by_country(auth['country'])
    return bonos
```

**Respaldo de la industria:**

- ✅ **Netflix (Zuul)**: "Edge validates token, services authorize"
- ✅ **Google Cloud**: "API Gateway authenticates, services authorize"
- ✅ **Auth0**: "Gateway verifies JWT, API checks scopes"
- ✅ **Kong Inc**: "JWT plugin validates, request-transformer passes claims"
- ✅ **OWASP**: "Authentication at edge, authorization at resource"

## 🚀 Uso

### Primera vez: Aplicar configuración inicial

```bash
# Ambiente DEV
docker run --rm --network host \
  -v $(pwd)/config/kong:/config \
  kong/deck:latest sync \
  --kong-addr http://localhost:8001 \
  --state /config/kong-dev.yaml

# Ambiente QA (en servidor)
docker run --rm --network host \
  -v /opt/tlm-infra-api-gateway/config/kong:/config \
  kong/deck:latest sync \
  --kong-addr http://localhost:8001 \
  --state /config/kong-qa.yaml
```

### Ver diferencias antes de aplicar

```bash
# Ver qué cambiaría
docker run --rm --network host \
  -v $(pwd)/config/kong:/config \
  kong/deck:latest diff \
  --kong-addr http://localhost:8001 \
  --state /config/kong-dev.yaml
```

### Aplicar cambios después de editar YAML

```bash
# 1. Editar archivo
vim config/kong/kong-dev.yaml

# 2. Ver cambios
docker run --rm --network host \
  -v $(pwd)/config/kong:/config \
  kong/deck:latest diff \
  --kong-addr http://localhost:8001 \
  --state /config/kong-dev.yaml

# 3. Aplicar
docker run --rm --network host \
  -v $(pwd)/config/kong:/config \
  kong/deck:latest sync \
  --kong-addr http://localhost:8001 \
  --state /config/kong-dev.yaml
```

### Exportar configuración actual de Kong

```bash
# Útil para backup o debug
docker run --rm --network host \
  kong/deck:latest dump \
  --kong-addr http://localhost:8001 \
  --output-file /tmp/kong-backup-$(date +%Y%m%d).yaml
```

## 🔄 Workflow Recomendado

### Agregar nuevo servicio

```bash
# 1. Editar archivo YAML
vim config/kong/kong-dev.yaml

# Agregar:
# - name: nuevo-servicio-dev
#   url: http://nuevo.internal.talma.com.pe:8080
#   routes:
#   - name: nuevo-dev-route
#     paths: ["/api-dev/nuevo"]

# 2. Commit a Git
git add config/kong/kong-dev.yaml
git commit -m "Add nuevo-servicio to DEV"
git push

# 3. En servidor DEV
cd /opt/tlm-infra-api-gateway
git pull

# 4. Aplicar cambios (automático con docker-compose up)
# O manual:
docker-compose up -d kong-deck-bootstrap
```

### Actualizar URL de backend

```bash
# 1. Editar kong-qa.yaml
vim config/kong/kong-qa.yaml

# Cambiar:
# - name: sisbon-qa
#   url: http://httpbin.org  ← ANTES
#   url: http://sisbon-qa.internal.talma.com.pe:8080  ← DESPUÉS

# 2. Commit y push
git add config/kong/kong-qa.yaml
git commit -m "Update sisbon-qa backend URL"
git push

# 3. Aplicar en servidor QA
ssh qa-server
cd /opt/tlm-infra-api-gateway
git pull
docker-compose up -d kong-deck-bootstrap
```

### Rotación de claves JWT

Automática con JWKS - no requiere acción manual. Keycloak mantiene múltiples claves activas durante la rotación, Kong las descarga automáticamente. Zero downtime.

## 🐳 Integración con Docker Compose

El servicio `kong-deck-bootstrap` aplica automáticamente la configuración al iniciar:

```yaml
# docker-compose.yml
kong-deck-bootstrap:
  image: kong/deck:latest
  volumes:
    - ./config/kong/kong-dev.yaml:/config/kong.yaml:ro
  command: >
    sh -c "
      until curl -sf http://kong:8001/status; do sleep 2; done;
      deck sync --kong-addr http://kong:8001 --state /config/kong.yaml;
    "
  restart: "no"
```

Para re-aplicar config después de cambios:

```bash
docker-compose up -d kong-deck-bootstrap
```

## 📝 Notas Importantes

### Tags para Organización

Los tags ayudan a filtrar y organizar recursos:

```yaml
services:
- name: sisbon-dev
  tags: ["sisbon", "dev", "bonificaciones"]  # Facilita búsqueda
```

### Strip Path

**`strip_path: false`** es importante para el patrón de ruteo:

```yaml
routes:
- paths: ["/api-dev/sisbon"]
  strip_path: false  # Backend recibe /api-dev/sisbon/bonificaciones/...
```

Con `strip_path: true`, el backend recibiría solo `/bonificaciones/...`

### Rate Limiting en Producción

Los archivos de PROD incluyen rate-limiting por defecto:

```yaml
plugins:
- name: rate-limiting
  config:
    minute: 1000
    hour: 10000
```

Ajustar según necesidades de cada servicio.

## 🆘 Troubleshooting

### Error: "schema violation"

**Causa:** YAML mal formateado o campo inválido

**Solución:**
```bash
# Validar YAML
docker run --rm -v $(pwd)/config/kong:/config \
  kong/deck:latest validate \
  --state /config/kong-dev.yaml
```

### Error: "cannot connect to Kong"

**Causa:** Kong no está corriendo o puerto incorrecto

**Solución:**
```bash
# Verificar Kong
curl http://localhost:8001/status

# Si no responde
docker-compose ps kong
docker-compose logs kong
```

### Cambios no se aplican

**Causa:** Posible drift (cambios manuales en Kong)

**Solución:**
```bash
# Ver diferencias
docker run --rm --network host \
  -v $(pwd)/config/kong:/config \
  kong/deck:latest diff \
  --kong-addr http://localhost:8001 \
  --state /config/kong-dev.yaml

# Forzar sincronización
docker run --rm --network host \
  -v $(pwd)/config/kong:/config \
  kong/deck:latest sync \
  --kong-addr http://localhost:8001 \
  --state /config/kong-dev.yaml
```

## 📚 Referencias

- [Kong decK Documentation](https://docs.konghq.com/deck/)
- [decK File Format](https://docs.konghq.com/deck/latest/reference/deck-file/)
- [Kong Admin API](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong JWT Plugin](https://docs.konghq.com/hub/kong-inc/jwt/)
- [JWKS Specification (RFC 7517)](https://datatracker.ietf.org/doc/html/rfc7517)
- [OpenID Connect Discovery](https://openid.net/specs/openid-connect-discovery-1_0.html)

---

**Última actualización:** 2025-12-05
**Mantenido por:** DevOps Talma
