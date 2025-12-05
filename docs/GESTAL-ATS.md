# ATS: Crear Posición TALMA

Este endpoint permite crear una **nueva posición (vacante)** en el sistema ATS de TalentHub, específicamente para el cliente **TALMA**.

## Arquitectura

```
Cliente/Gestal → Kong (JWT + x-api-key) → TalentHub ATS
```

**Flujo:**

1. Cliente/Gestal envía request a Kong con JWT token
2. Kong valida autenticación (firma + expiración del JWT)
3. Kong agrega automáticamente el header `x-api-key` de TalentHub
4. Kong transforma la URI al formato esperado por TalentHub
5. Kong hace proxy directo a TalentHub ATS
6. TalentHub responde directamente al cliente

**Ventajas de este approach:**

- ✅ Sin backend intermedio (menor latencia)
- ✅ Kong maneja el secreto `x-api-key` centralizadamente
- ✅ Autenticación JWT unificada con otros servicios
- ✅ Rate limiting en PROD (100 req/min, 1000 req/hour)
- ✅ Configuración declarativa en Git

---

## Endpoint público (Kong)

**Para clientes/aplicación Gestal:**

```http
POST https://api.talma.com.pe/api/gestal/ats/posiciones
Authorization: Bearer <jwt-token-from-keycloak>
Content-Type: application/json
```

**Ambientes disponibles:**

- **DEV**: `https://api-dev.talma.com.pe/api-dev/gestal/ats/posiciones`
- **QA**: `https://api-qa.talma.com.pe/api-qa/gestal/ats/posiciones`
- **PROD**: `https://api.talma.com.pe/api/gestal/ats/posiciones`

**Kong valida:**

- ✅ JWT firma válida (algoritmo RS256)
- ✅ Token no expirado (claim `exp`)
- ✅ Issuer correcto (`https://auth.talma.com.pe/realms/tlm-pe`)

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

## Configuración Kong (ya implementada)

**Los archivos Kong ya están configurados:**

- `config/kong/kong-dev.yaml`
- `config/kong/kong-nonprod.yaml`
- `config/kong/kong-qa.yaml`
- `config/kong/kong-prod.yaml`

```yaml
services:
- name: gestal-pe-dev
  url: http://gestal-pe-dev.internal.talma.com.pe:8080
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
curl -X POST https://api.talma.com.pe/api-dev/gestal/ats/posiciones \
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
POST http://gestal-pe-dev.internal.talma.com.pe:8080/api-dev/gestal/ats/posiciones
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

## Testing

### 1. Obtener token JWT de Keycloak

```bash
TOKEN=$(curl -X POST "http://alb-monitoreo.../auth/realms/tlm-pe/protocol/openid-connect/token" \
  -d "client_id=gestal-pe-dev" \
  -d "client_secret=<secret>" \
  -d "grant_type=client_credentials" \
  | jq -r '.access_token')
```

### 2. Llamar al API Gateway

```bash
curl -X POST https://api.talma.com.pe/api-dev/gestal/ats/posiciones \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "posicion_solicitada": "Test Position",
    "cantidad_de_vacantes": 1,
    "gerencia": "Test",
    "tipo_convocatoria": "Externo",
    "definicion_tipo_convocatoria": "Test",
    "estaciones": "Lima",
    "area": "Test Area",
    "motivo": "Test",
    "nombre_persona_reemplazar": "N/A",
    "cliente": "Test Cliente",
    "definicion_cliente": "Test",
    "especialidad": "Test",
    "ejem_especialidad": "Test",
    "tipo_contrato": "Plazo fijo",
    "jornada_laboral": "Tiempo completo 8h"
  }'
```

### 3. Verificar respuesta

```json
{
  "status": "success",
  "message": "Posición creada correctamente",
  "vacante_id": "66f89de6c3b48b7f2d92e45b"
}
```

---

## Seguridad

**✅ Implementado:**

- JWT authentication en Kong (RS256)
- Validación de roles en backend (`gestal:write`)
- `x-api-key` de TalentHub en variable de entorno (no hardcoded)
- HTTPS en comunicación Kong ↔ Cliente
- Logging de auditoría (quién creó qué posición)

**⚠️ Recomendaciones adicionales:**

- Rate limiting por usuario (ya configurado en PROD)
- Rotación periódica de `x-api-key` de TalentHub
- Monitoreo de llamadas fallidas a TalentHub
- Circuit breaker si TalentHub está caído
