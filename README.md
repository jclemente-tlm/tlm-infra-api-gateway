# tlm-infra-api-gateway

Infraestructura de API Gateway para TLM usando Kong y Keycloak.

## 🚀 Quick Start

¿Primera vez aquí? Ve directo a **[docs/QUICK_START.md](./docs/QUICK_START.md)** para levantar el entorno en minutos.

```bash
# Clonar el repo y configurar
git clone <repo-url>
cd tlm-infra-api-gateway

# Usar configuración local (con bases de datos en contenedores)
cp .env.local .env

# Iniciar ambiente local (incluye PostgreSQL y MySQL)
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d

# Esperar a que las bases de datos inicialicen (30-60 segundos)
docker-compose logs -f kong-db konga-db

# Verificar
curl http://localhost:8001/status
```

## Arquitectura

```text
ALB → nginx → Kong API Gateway → Backends
              ↓
           Keycloak (JWT Auth)
```

## Componentes

- **Kong 3.8**: API Gateway (puertos 8000, 8001, 8443, 8444)
- **Konga**: Admin UI para Kong (puerto 1337)
- **nginx**: Reverse proxy para path rewriting (puerto 3366)
- **Keycloak**: Servidor de autenticación OAuth2/OIDC (JWT)
- **PostgreSQL**: Base de datos para Kong
- **MySQL**: Base de datos para Konga

## 📚 Documentación

Toda la documentación está en el directorio **[docs/](./docs/)**:

| Documento | Descripción |
|-----------|-------------|
| **[docs/README.md](./docs/README.md)** | Índice completo de documentación |
| **[docs/KEYCLOAK_NAMING_STANDARD.md](./docs/KEYCLOAK_NAMING_STANDARD.md)** | Estándares de nomenclatura para Keycloak |
| **[docs/KEYCLOAK_KONG_INTEGRATION.md](./docs/KEYCLOAK_KONG_INTEGRATION.md)** | Guía paso a paso de integración JWT |
| **[docs/DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md)** | Guía de despliegue en ambientes |
| **[docs/QUICK_START.md](./docs/QUICK_START.md)** | Inicio rápido |
| **[docs/STRUCTURE.md](./docs/STRUCTURE.md)** | Estructura del proyecto |

## 🏗️ Estructura del Proyecto

```text
tlm-infra-api-gateway/
├── docker-compose.yml              # Base configuration
├── docker-compose.local.yml        # Local overrides
├── docker-compose.nonprod.yml      # Non-prod overrides (QA/UAT)
├── docker-compose.prod.yml         # Production overrides
├── .env.example                    # Template de variables
├── .env                            # Variables de entorno (git ignored)
├── config/
│   ├── nginx-konga.conf           # Nginx reverse proxy config
│   └── kong-local.conf            # Kong config para local
├── docs/
│   ├── README.md                  # Índice de documentación
│   ├── KEYCLOAK_NAMING_STANDARD.md
│   ├── KEYCLOAK_KONG_INTEGRATION.md
│   └── DEPLOYMENT_GUIDE.md
├── QUICK_START.md                 # Esta guía
└── STRUCTURE.md                   # Documentación de estructura
```

Ver detalles completos en **[docs/STRUCTURE.md](./docs/STRUCTURE.md)**

## 🌍 Ambientes

### Local (Desarrollo)

```bash
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

- Kong Admin API expuesto en `localhost:8001`
- Logs a STDOUT para debugging
- Configuraciones de desarrollo relajadas

### Non-Prod (QA/UAT)

```bash
docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml up -d
```

- Kong Admin API protegido
- Healthchecks configurados
- Rate limiting moderado

### Producción

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

- Kong Admin API no expuesto públicamente
- Configuraciones optimizadas para performance
- Rate limiting estricto
- Healthchecks agresivos

Ver más en **[docs/DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md)**

## Acceso a Servicios

### Local

- **Kong Admin API**: <http://localhost:8001>
- **Kong Gateway**: <http://localhost:8000>
- **Konga UI**: <http://localhost:3366/konga/>

### Non-Prod

- **Kong Gateway**: <http://alb-nonprod.tudominio.com>
- **Konga UI**: <http://alb-nonprod.tudominio.com/konga/>

### Producción

- **Kong Gateway**: <https://api.tudominio.com>
- **Konga UI**: <https://api.tudominio.com/konga/> (restringido)

## 🔧 Configuración

### Variables de Entorno

1. Copiar template: `cp .env.example .env`
2. Editar con tus valores (ver comentarios en `.env.example`)

**Variables principales:**

- `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: Base de datos Kong
- `DB_HOST`, `DB_USER`, `DB_PASSWORD`: Base de datos Konga
- `KONG_ADMIN_LISTEN`: Configuración de admin API por ambiente

Ver documentación completa en **[docs/DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md#variables-de-entorno)**

## 🧪 Testing

```bash
# Verificar Kong
curl http://localhost:8001/status

# Listar services
curl http://localhost:8001/services

# Test simple
curl http://localhost:8000/
```

Ver más en **[docs/QUICK_START.md](./docs/QUICK_START.md#verificación-rápida)**

## 🐛 Troubleshooting

### Kong no inicia

```bash
docker-compose logs kong
docker-compose exec kong kong migrations list
```

### 502 Bad Gateway

1. Verificar backend accesible
2. Revisar `preserve_host: false` para HTTPS backends
3. Verificar `strip_path` en route

### JWT no valida

1. Verificar `iss` claim coincide con consumer key
2. Obtener public key actualizada de Keycloak
3. Verificar token no expirado

Ver guía completa en **[docs/KEYCLOAK_KONG_INTEGRATION.md#troubleshooting](./docs/KEYCLOAK_KONG_INTEGRATION.md#troubleshooting)**

## 📦 Comandos Útiles

```bash
# Ver logs
docker-compose logs -f kong

# Reiniciar servicio
docker-compose restart kong

# Ejecutar comando en container
docker-compose exec kong sh

# Detener todo
docker-compose down

# Limpiar volúmenes (⚠️ borra datos)
docker-compose down -v
```

## 🤝 Contribuir

1. Seguir estándares en **[docs/KEYCLOAK_NAMING_STANDARD.md](./docs/KEYCLOAK_NAMING_STANDARD.md)**
2. Probar en local antes de non-prod
3. Documentar cambios
4. Actualizar este README si es necesario

## 📞 Soporte

**Mantenido por:** Equipo DevOps TLM
**Última actualización:** 2025-12-04

**Enlaces importantes:**

- 📖 [Documentación completa](./docs/README.md)
- 🚀 [Quick Start](./docs/QUICK_START.md)
- 🏗️ [Estructura del proyecto](./docs/STRUCTURE.md)
- 🔐 [Integración Keycloak](./docs/KEYCLOAK_KONG_INTEGRATION.md)
