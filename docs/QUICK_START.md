# Quick Start Guide

Guía rápida para iniciar el API Gateway en diferentes entornos.

## Prerequisitos

- Docker & Docker Compose instalado
- Archivo `.env` configurado (copiar desde `.env.example`)
- Acceso a las bases de datos (PostgreSQL para Kong, MySQL para Konga)
- Keycloak configurado (opcional para testing básico)

## Iniciar Entorno Local

```bash
# 1. Copiar variables de entorno
cp .env.example .env

# 2. Editar .env con tus credenciales de desarrollo
nano .env

# 3. Iniciar servicios locales
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d

# 4. Verificar servicios
docker-compose ps

# 5. Verificar logs
docker-compose logs -f kong
```

## Iniciar Entorno Non-Prod (QA/UAT)

```bash
# 1. Asegurar que .env tiene credenciales de non-prod
nano .env

# 2. Iniciar servicios
docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml up -d

# 3. Verificar
docker-compose ps
```

## Iniciar Entorno Producción

```bash
# 1. Asegurar que .env tiene credenciales de producción
nano .env

# 2. Iniciar servicios
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 3. Verificar salud
curl http://localhost:8001/status
```

## Acceso a Servicios

### Local

- **Kong Admin API**: <http://localhost:8001>
- **Kong Gateway**: <http://localhost:8000>
- **Konga UI**: <http://localhost:3366/konga/>

### Non-Prod

- **Kong Admin API**: <http://localhost:8001> (solo desde VPN/red interna)
- **Kong Gateway**: <http://alb-nonprod.tudominio.com>
- **Konga UI**: <http://alb-nonprod.tudominio.com/konga/>

### Producción

- **Kong Gateway**: <https://api.tudominio.com>
- **Konga UI**: <https://api.tudominio.com/konga/> (restringido por IP)

## Verificación Rápida

```bash
# 1. Verificar Kong está corriendo
curl http://localhost:8001/status

# 2. Listar services
curl http://localhost:8001/services

# 3. Test endpoint público (sin auth)
curl http://localhost:8000/

# 4. Ver logs
docker-compose logs --tail=50 kong
```

## Crear tu Primer Service y Route

```bash
# 1. Crear service
curl -X POST http://localhost:8001/services \
  -d "name=test-service" \
  -d "url=https://httpbin.org"

# 2. Crear route
curl -X POST http://localhost:8001/services/test-service/routes \
  -d "paths[]=/test"

# 3. Probar
curl http://localhost:8000/test/get
```

## Configurar JWT con Keycloak

Ver guía completa en [docs/KEYCLOAK_KONG_INTEGRATION.md](docs/KEYCLOAK_KONG_INTEGRATION.md)

**Pasos resumidos:**

1. Crear realm en Keycloak
2. Crear client API (bearer-only)
3. Crear client consumidor (confidential)
4. Obtener token:

   ```bash
   curl -X POST https://keycloak.tudominio.com/realms/tlm-pe/protocol/openid-connect/token \
     -d "grant_type=client_credentials" \
     -d "client_id=tu-client" \
     -d "client_secret=tu-secret"
   ```

5. Configurar JWT plugin en Kong (ver guía completa)

## Detener Servicios

```bash
# Local
docker-compose -f docker-compose.yml -f docker-compose.local.yml down

# Non-Prod
docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml down

# Producción
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down

# Eliminar también volúmenes (⚠️ borra datos)
docker-compose down -v
```

## Troubleshooting

### Kong no inicia

```bash
# Ver logs detallados
docker-compose logs kong

# Verificar conectividad a DB
docker-compose exec kong kong migrations list

# Reiniciar
docker-compose restart kong
```

### No puedo acceder a Konga

```bash
# Verificar nginx
docker-compose logs konga-proxy

# Verificar Konga
docker-compose logs konga

# Probar acceso directo
curl http://localhost:1337
```

### Error "no Route matched"

1. Verificar que la route existe: `curl http://localhost:8001/routes`
2. Verificar el path configurado
3. Verificar `strip_path` setting

### JWT no valida

1. Verificar token: `echo "$TOKEN" | cut -d. -f2 | base64 -d | jq`
2. Verificar issuer coincide con consumer key
3. Verificar que no expiró

Ver más en [docs/KEYCLOAK_KONG_INTEGRATION.md#troubleshooting](docs/KEYCLOAK_KONG_INTEGRATION.md#troubleshooting)

## Próximos Pasos

1. **Configurar Keycloak**: Ver [docs/KEYCLOAK_KONG_INTEGRATION.md](docs/KEYCLOAK_KONG_INTEGRATION.md)
2. **Seguir estándares**: Ver [docs/KEYCLOAK_NAMING_STANDARD.md](docs/KEYCLOAK_NAMING_STANDARD.md)
3. **Deploy a ambientes**: Ver [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)
4. **Documentación completa**: Ver [docs/README.md](docs/README.md)

## Comandos Útiles

```bash
# Ver todos los containers
docker-compose ps

# Ver logs en tiempo real
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f kong

# Ejecutar comando en container
docker-compose exec kong sh

# Reiniciar un servicio
docker-compose restart kong

# Ver uso de recursos
docker stats

# Limpiar todo (⚠️ cuidado)
docker-compose down -v
docker system prune -a
```

## Soporte

- **Documentación**: [docs/README.md](docs/README.md)
- **Issues**: Crear issue en el repositorio
- **Team**: Equipo DevOps TLM
