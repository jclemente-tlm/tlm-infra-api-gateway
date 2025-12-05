# API Reference - Talma

Referencia de endpoints disponibles en el API Gateway de Talma.

**Alcance:** Este API Gateway centraliza el acceso a múltiples sistemas:

- Sistemas de negocio (Sisbon, Gestal, BRS)
- Integraciones con modelos IA
- APIs internas y servicios corporativos
- Soporte multi-país (México, Perú)

## 📋 Índice

1. [Autenticación](#autenticación)
2. [Sisbon - Sistema de Bonificaciones](#sisbon---sistema-de-bonificaciones)
3. [Gestal - Sistema de Gestión de Tickets](#gestal---sistema-de-gestión-de-tickets)
4. [Servicios Futuros](#servicios-futuros)
5. [Códigos de Error](#códigos-de-error)
6. [Rate Limiting](#rate-limiting)

---

## Autenticación

Todos los endpoints requieren un token JWT de Keycloak.

### Obtener Token

**Endpoint:** `POST /realms/{realm}/protocol/openid-connect/token`

**Realms disponibles:**

- `tlm-mx` - Clientes de México
- `tlm-pe` - Clientes de Perú

**Request:**

```bash
curl -X POST "https://auth.talma.com.pe/realms/tlm-mx/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=sisbon-mx-prod" \
  -d "client_secret=YOUR_SECRET" \
  -d "grant_type=client_credentials"
```

**Response:**

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

### Usar Token

Incluir el token en el header `Authorization`:

```bash
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  https://api.talma.com.pe/sisbon/bonificaciones/kilos-ingresados/siop-impo
```

---

## Sisbon - Sistema de Bonificaciones

Sistema integral de bonificaciones para operaciones de carga aérea.
Disponible para México y Perú.

**Base URL:**

- PROD: `https://api.talma.com.pe`
- QA: `https://api-qa.talma.com.pe`
- DEV: `https://api-dev.talma.com.pe`

**Backend Interno:**

- `sisbon.internal.talma.com.pe` (PROD)
- `sisbon-qa.internal.talma.com.pe` (QA)
- `sisbon-dev.internal.talma.com.pe` (DEV)

**Autenticación:**

- México: Token del realm `tlm-mx`
- Perú: Token del realm `tlm-pe`

**Módulos Disponibles:**

- ✅ Bonificaciones (5 endpoints)
- 🚧 Otros módulos en desarrollo

---

### Módulo: Bonificaciones

Gestión de kilos ingresados y facturados en diferentes categorías de carga.

#### Kilos Ingresados - Otro Almacén

```http
POST /sisbon/bonificaciones/kilos-ingresados/otro-almacen
```

**Headers:**

```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**

```json
{
  "fecha": "2025-12-04",
  "almacen": "ALM-001",
  "cliente": "CLI-123",
  "kilos": 1500.50,
  "observaciones": "Carga especial"
}
```

**Response:** `201 Created`

```json
{
  "id": 456,
  "fecha": "2025-12-04",
  "almacen": "ALM-001",
  "cliente": "CLI-123",
  "kilos": 1500.50,
  "estado": "registrado",
  "created_at": "2025-12-04T10:30:00Z"
}
```

#### Kilos Ingresados - SIOP Importación

```http
POST /sisbon/bonificaciones/kilos-ingresados/siop-impo
```

**Headers:**

```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**

```json
{
  "fecha": "2025-12-04",
  "vuelo": "LA2345",
  "awb": "125-12345678",
  "kilos": 2400.75,
  "tipo_carga": "general"
}
```

**Response:** `201 Created`

```json
{
  "id": 457,
  "fecha": "2025-12-04",
  "vuelo": "LA2345",
  "awb": "125-12345678",
  "kilos": 2400.75,
  "tipo_carga": "general",
  "estado": "registrado",
  "created_at": "2025-12-04T11:15:00Z"
}
```

#### Kilos Ingresados - SIOP Exportación

```http
POST /sisbon/bonificaciones/kilos-ingresados/siop-expo
```

**Headers:**

```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**

```json
{
  "fecha": "2025-12-04",
  "vuelo": "LA2346",
  "awb": "125-87654321",
  "kilos": 1800.25,
  "tipo_carga": "perecedero",
  "destino": "MIA"
}
```

**Response:** `201 Created`

```json
{
  "id": 458,
  "fecha": "2025-12-04",
  "vuelo": "LA2346",
  "awb": "125-87654321",
  "kilos": 1800.25,
  "tipo_carga": "perecedero",
  "destino": "MIA",
  "estado": "registrado",
  "created_at": "2025-12-04T12:00:00Z"
}
```

---

#### Kilos Facturados - SIOP Importación

```http
POST /sisbon/bonificaciones/kilos-facturados/siop-impo
```

**Headers:**

```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**

```json
{
  "fecha": "2025-12-04",
  "factura": "FACT-2025-001234",
  "cliente": "CLI-123",
  "awb": "125-12345678",
  "kilos_facturados": 2350.50,
  "monto": 4500.00,
  "moneda": "USD"
}
```

**Response:** `201 Created`

```json
{
  "id": 789,
  "fecha": "2025-12-04",
  "factura": "FACT-2025-001234",
  "cliente": "CLI-123",
  "awb": "125-12345678",
  "kilos_facturados": 2350.50,
  "monto": 4500.00,
  "moneda": "USD",
  "estado": "facturado",
  "created_at": "2025-12-04T14:30:00Z"
}
```

#### Kilos Facturados - SIOP Exportación

```http
POST /sisbon/bonificaciones/kilos-facturados/siop-expo
```

**Headers:**

```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**

```json
{
  "fecha": "2025-12-04",
  "factura": "FACT-2025-001235",
  "cliente": "CLI-456",
  "awb": "125-87654321",
  "kilos_facturados": 1750.25,
  "monto": 3200.00,
  "moneda": "USD",
  "destino": "MIA"
}
```

**Response:** `201 Created`

```json
{
  "id": 790,
  "fecha": "2025-12-04",
  "factura": "FACT-2025-001235",
  "cliente": "CLI-456",
  "awb": "125-87654321",
  "kilos_facturados": 1750.25,
  "monto": 3200.00,
  "moneda": "USD",
  "destino": "MIA",
  "estado": "facturado",
  "created_at": "2025-12-04T15:00:00Z"
}
```

---

## Gestal - Sistema de Gestión de Tickets

Sistema de gestión de tickets y soporte operativo. Solo Perú.

**Base URL:**

- PROD: `https://api.talma.com.pe`
- QA: `https://api-qa.talma.com.pe`
- DEV: `https://api-dev.talma.com.pe`

**Backend Interno:**

- `gestal.internal.talma.com.pe` (PROD)
- `gestal-qa.internal.talma.com.pe` (QA)
- `gestal-dev.internal.talma.com.pe` (DEV)

**Autenticación:** Token del realm `tlm-pe`

**Estado:** Módulos y endpoints en definición

> 🚧 Los módulos y endpoints específicos de Gestal se documentarán cuando estén disponibles.
> Seguirá la misma estructura modular que Sisbon.

---

## Servicios Futuros

El API Gateway está diseñado para escalar y soportar múltiples servicios:

### BRS (Business Reporting System)

**Propósito:** Sistema de reportes y analytics

**Estado:** En planificación

```bash
# Ejemplos de endpoints futuros
GET /api/brs/reports
GET /api/brs/dashboards
POST /api/brs/export
```

### Integraciones IA

**Propósito:** Endpoints para modelos de machine learning y AI

**Estado:** En planificación

```bash
# Ejemplos de endpoints futuros
POST /api/ia/predict
POST /api/ia/classify
GET /api/ia/models
```

### Otros Servicios

El API Gateway puede agregar nuevos servicios siguiendo el patrón:

1. Backend interno: `[servicio].internal.talma.com.pe`
2. Ruta pública: `https://api.talma.com.pe/[servicio]/*`
3. Autenticación JWT con realm apropiado
4. Ambientes dev, qa, prod

Ver **[Añadir Nuevos Servicios](./DOMAIN_STRATEGY.md#añadir-nuevos-servicios)** para el proceso completo.

---

## Códigos de Error

### Autenticación

| Código | Descripción | Solución |
|--------|-------------|----------|
| `401 Unauthorized` | Token inválido o expirado | Obtener nuevo token de Keycloak |
| `403 Forbidden` | Token válido pero sin permisos | Verificar roles en Keycloak |

### Validación

| Código | Descripción | Ejemplo |
|--------|-------------|---------|
| `400 Bad Request` | Datos inválidos en request | Campo obligatorio faltante |
| `422 Unprocessable Entity` | Validación de negocio falló | Kilos negativos |

### Recursos

| Código | Descripción | Solución |
|--------|-------------|----------|
| `404 Not Found` | Recurso no existe | Verificar ID |
| `409 Conflict` | Conflicto con estado actual | Registro duplicado |

### Servidor

| Código | Descripción | Acción |
|--------|-------------|--------|
| `500 Internal Server Error` | Error en backend | Contactar soporte |
| `502 Bad Gateway` | Backend no disponible | Verificar estado del servicio |
| `503 Service Unavailable` | Servicio en mantenimiento | Esperar y reintentar |

### Ejemplo de Response de Error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Los datos proporcionados son inválidos",
    "details": [
      {
        "field": "kilos",
        "message": "El valor debe ser mayor a 0"
      },
      {
        "field": "fecha",
        "message": "Formato de fecha inválido. Use YYYY-MM-DD"
      }
    ]
  },
  "request_id": "req-123abc456def",
  "timestamp": "2025-12-04T15:30:00Z"
}
```

---

## Rate Limiting

Todos los endpoints tienen límites de tasa para proteger el servicio.

### Límites por Ambiente

| Ambiente | Requests por minuto | Burst |
|----------|---------------------|-------|
| **PROD** | 1000 | 100 |
| **QA** | 500 | 50 |
| **DEV** | 200 | 20 |

### Headers de Rate Limit

Cada response incluye headers con información de límite:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 995
X-RateLimit-Reset: 1701705600
```

### Cuando se Excede el Límite

**Response:** `429 Too Many Requests`

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Has excedido el límite de solicitudes",
    "retry_after": 30
  }
}
```

**Header adicional:**

```
Retry-After: 30
```

---

## Ejemplos de Integración

### cURL

```bash
# 1. Obtener token
TOKEN=$(curl -s -X POST "https://auth.talma.com.pe/realms/tlm-mx/protocol/openid-connect/token" \
  -d "client_id=sisbon-mx-prod" \
  -d "client_secret=YOUR_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# 2. Usar el token
curl -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "https://api.talma.com.pe/sisbon/bonificaciones/kilos-ingresados/siop-impo" \
  -d '{
    "fecha": "2025-12-04",
    "vuelo": "LA2345",
    "awb": "125-12345678",
    "kilos": 2400.75,
    "tipo_carga": "general"
  }'
```

### Python (requests)

```python
import requests

# 1. Obtener token
auth_url = "https://auth.talma.com.pe/realms/tlm-mx/protocol/openid-connect/token"
auth_data = {
    "client_id": "sisbon-mx-prod",
    "client_secret": "YOUR_SECRET",
    "grant_type": "client_credentials"
}

token_response = requests.post(auth_url, data=auth_data)
token = token_response.json()["access_token"]

# 2. Llamar API
api_url = "https://api.talma.com.pe/sisbon/bonificaciones/kilos-ingresados/siop-impo"
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}
payload = {
    "fecha": "2025-12-04",
    "vuelo": "LA2345",
    "awb": "125-12345678",
    "kilos": 2400.75,
    "tipo_carga": "general"
}

response = requests.post(api_url, json=payload, headers=headers)
print(response.json())
```

### JavaScript (fetch)

```javascript
// 1. Obtener token
const authUrl = 'https://auth.talma.com.pe/realms/tlm-mx/protocol/openid-connect/token';
const authData = new URLSearchParams({
  client_id: 'sisbon-mx-prod',
  client_secret: 'YOUR_SECRET',
  grant_type: 'client_credentials'
});

const tokenResponse = await fetch(authUrl, {
  method: 'POST',
  body: authData
});
const { access_token } = await tokenResponse.json();

// 2. Llamar API
const apiUrl = 'https://api.talma.com.pe/sisbon/bonificaciones/kilos-ingresados/siop-impo';
const response = await fetch(apiUrl, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${access_token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    fecha: '2025-12-04',
    vuelo: 'LA2345',
    awb: '125-12345678',
    kilos: 2400.75,
    tipo_carga: 'general'
  })
});

const data = await response.json();
console.log(data);
```

---

## Soporte

**Documentación adicional:**

- [Estrategia de Dominios](./DOMAIN_STRATEGY.md)
- [Integración Keycloak-Kong](./KEYCLOAK_KONG_INTEGRATION.md)
- [Guía de Despliegue](./DEPLOYMENT_GUIDE.md)

**Contacto:**

- Email: <devops@talma.com.pe>
- Slack: #api-gateway-support

**Última actualización:** 2025-12-04
