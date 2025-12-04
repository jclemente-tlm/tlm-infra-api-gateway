# Guía de Despliegue por Entorno

Esta guía explica cómo desplegar y configurar el API Gateway en diferentes entornos.

---

## Tabla de Contenido

1. [Entorno Local](#entorno-local)
2. [Entorno Non-Prod (DEV/QA)](#entorno-non-prod-devqa)
3. [Entorno Producción](#entorno-producción)
4. [Variables de Entorno](#variables-de-entorno)
5. [Troubleshooting](#troubleshooting)

---

## Entorno Local

### Características

- **Propósito:** Desarrollo local en máquina del desarrollador
- **SSL:** Deshabilitado
- **Logging:** Debug level
- **Puertos:** Todos expuestos para acceso directo
- **Base de datos:** Puede usar PostgreSQL/MySQL local o remoto

### Configuración

1. **Crear archivo `.env`:**

```bash
cp .env.example .env
```

2. **Editar `.env` para local:**

```env
# Para local, puedes usar localhost o RDS remoto
POSTGRES_HOST=localhost  # o tu-rds-dev.amazonaws.com
POSTGRES_PORT=5432
POSTGRES_DB=kong_local
POSTGRES_USER=kong
POSTGRES_PASSWORD=kong_local_pass
POSTGRES_SSL=off

# MySQL local para Konga
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=konga_local
DB_USER=konga
DB_PASSWORD=konga_local_pass

ENVIRONMENT=local
```

3. **Levantar servicios:**

```bash
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

4. **Verificar:**

```bash
# Ver logs
docker-compose logs -f kong

# Probar Kong Admin API
curl http://localhost:8001/status

# Probar Kong Proxy
curl http://localhost:8000/

# Acceder a Konga UI
open http://localhost:3366/konga/
```

### Puertos Expuestos (Local)

| Servicio | Puerto | URL |
|----------|--------|-----|
| Kong Proxy | 8000 | http://localhost:8000 |
| Kong Admin API | 8001 | http://localhost:8001 |
| Kong Proxy SSL | 8443 | https://localhost:8443 |
| Kong Admin SSL | 8444 | https://localhost:8444 |
| Konga UI | 1337 | http://localhost:1337 |
| nginx (Konga) | 3366 | http://localhost:3366/konga/ |
| MySQL (Konga) | 3307 | localhost:3307 |

### Desarrollo en Local

**Hot reload de configuración nginx:**

```bash
# Editar config/nginx-konga.conf
# Recargar nginx sin parar el contenedor
docker exec konga-proxy nginx -s reload
```

**Debugging Kong:**

```bash
# Ver configuración de Kong
docker exec kong kong config

# Ver plugins disponibles
curl http://localhost:8001/plugins/enabled

# Ver errores en detalle
docker exec kong tail -f /usr/local/kong/logs/error.log
```

---

## Entorno Non-Prod (DEV/QA)

### Características

- **Propósito:** Ambientes de desarrollo y QA en AWS
- **SSL:** Requerido pero sin verificación estricta
- **Logging:** Info level con rotación
- **Health Checks:** Habilitados
- **Base de datos:** AWS RDS/MySQL
- **Auto-restart:** Always

### Configuración

1. **Preparar `.env` para DEV/QA:**

```env
# AWS RDS PostgreSQL
POSTGRES_HOST=kong-db-dev.xxxxxx.us-east-1.rds.amazonaws.com
POSTGRES_PORT=5432
POSTGRES_DB=kong_dev
POSTGRES_USER=kong
POSTGRES_PASSWORD=your-secure-password-here
POSTGRES_SSL=on
POSTGRES_SSL_VERIFY=off

# AWS RDS MySQL
DB_HOST=konga-db-dev.xxxxxx.us-east-1.rds.amazonaws.com
DB_PORT=3306
DB_DATABASE=konga_dev
DB_USER=konga
DB_PASSWORD=your-secure-password-here

# Keycloak
KEYCLOAK_URL=https://keycloak-dev.tudominio.com
KEYCLOAK_REALM_PE=tlm-pe
KEYCLOAK_REALM_MX=tlm-mx
KEYCLOAK_REALM_CORP=tlm-corp

# Backend Services
GESTAL_DEV_URL=https://gestal-dev.tudominio.com
SISBON_DEV_URL=https://sisbon-dev.tudominio.com

ENVIRONMENT=dev
```

2. **Levantar servicios:**

```bash
docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml up -d
```

3. **Verificar health checks:**

```bash
docker ps  # Ver estado HEALTHY

# Ver logs de health check
docker inspect kong --format='{{json .State.Health}}' | jq .
```

### Acceso en Non-Prod

- **Kong Admin API:** Solo accesible desde VPC/VPN
- **Kong Proxy:** A través de ALB interno
- **Konga UI:** A través de ALB: `http://alb-nonprod.elb.amazonaws.com/konga/`

### Migración Local → DEV

```bash
# 1. Exportar configuración de Kong local
docker exec kong kong config db_export kong_config_local.yml

# 2. Copiar al servidor DEV
scp kong_config_local.yml user@dev-server:/path/

# 3. En servidor DEV, importar
docker exec kong kong config db_import /path/kong_config_local.yml
```

---

## Entorno Producción

### Características

- **Propósito:** Ambiente de producción
- **SSL:** Verificación estricta habilitada
- **Logging:** Warn level
- **Resource Limits:** CPU y memoria limitados
- **Security:** Hardening aplicado
- **Optimización:** Workers y connections optimizados

### Configuración

1. **Preparar `.env` para PROD:**

```env
# AWS RDS PostgreSQL (Multi-AZ)
POSTGRES_HOST=kong-db-prod.xxxxxx.us-east-1.rds.amazonaws.com
POSTGRES_PORT=5432
POSTGRES_DB=kong_prod
POSTGRES_USER=kong
POSTGRES_PASSWORD=STRONG-PASSWORD-HERE-USE-SECRETS-MANAGER
POSTGRES_SSL=on
POSTGRES_SSL_VERIFY=on  # STRICT en producción

# AWS RDS MySQL
DB_HOST=konga-db-prod.xxxxxx.us-east-1.rds.amazonaws.com
DB_PORT=3306
DB_DATABASE=konga_prod
DB_USER=konga
DB_PASSWORD=STRONG-PASSWORD-HERE-USE-SECRETS-MANAGER

# Keycloak
KEYCLOAK_URL=https://keycloak.tudominio.com
KEYCLOAK_REALM_PE=tlm-pe
KEYCLOAK_REALM_MX=tlm-mx
KEYCLOAK_REALM_CORP=tlm-corp

# Backend Services
GESTAL_PROD_URL=https://gestal.tudominio.com
SISBON_PROD_URL=https://sisbon.tudominio.com

# Rate Limiting
RATE_LIMIT_MINUTE=1000
RATE_LIMIT_HOUR=50000

ENVIRONMENT=prod
```

2. **Checklist Pre-Deploy:**

- [ ] Backups de base de datos completados
- [ ] Credenciales en AWS Secrets Manager
- [ ] SSL certificates válidos
- [ ] Health checks configurados en ALB
- [ ] Alertas de CloudWatch configuradas
- [ ] Plan de rollback definido

3. **Levantar servicios:**

```bash
# Blue-Green deployment recomendado
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

4. **Verificar:**

```bash
# Health checks
docker ps  # Todos deben estar HEALTHY

# Resource usage
docker stats kong konga konga-proxy

# Logs (no debe haber errores)
docker-compose logs --tail=100 | grep -i error
```

### Resource Limits (Prod)

| Servicio | CPU Limit | Memory Limit | CPU Reserved | Memory Reserved |
|----------|-----------|--------------|--------------|-----------------|
| Kong | 2 cores | 2GB | 1 core | 1GB |
| Konga | 1 core | 1GB | 0.5 cores | 512MB |
| nginx | 1 core | 512MB | 0.25 cores | 128MB |
| konga-db | 1 core | 1GB | 0.5 cores | 512MB |

### Acceso en Producción

- **Kong Admin API:** Solo desde bastion host o VPN
- **Kong Proxy:** A través de ALB público: `https://api.tudominio.com`
- **Konga UI:** Solo desde VPN: `https://alb-internal.elb.amazonaws.com/konga/`

### Monitoreo en Producción

```bash
# CloudWatch Logs (si configurado)
aws logs tail /ecs/api-gateway-prod --follow

# Métricas de Kong
curl http://localhost:8001/metrics  # Desde bastion

# Verificar SSL
openssl s_client -connect api.tudominio.com:443 -showcerts
```

---

## Variables de Entorno

### Variables Requeridas (Todos los entornos)

```env
# PostgreSQL (Kong)
POSTGRES_HOST=
POSTGRES_PORT=5432
POSTGRES_DB=
POSTGRES_USER=
POSTGRES_PASSWORD=

# MySQL (Konga)
DB_HOST=
DB_PORT=3306
DB_DATABASE=
DB_USER=
DB_PASSWORD=
```

### Variables Opcionales

```env
# Kong Tuning
KONG_NGINX_WORKER_PROCESSES=auto
KONG_NGINX_WORKER_CONNECTIONS=4096
KONG_MEM_CACHE_SIZE=128m

# Logging
KONG_LOG_LEVEL=info  # debug, info, warn, error

# Rate Limiting
RATE_LIMIT_MINUTE=1000
RATE_LIMIT_HOUR=50000
```

### Usar AWS Secrets Manager (Recomendado para Prod)

**Crear secret:**

```bash
aws secretsmanager create-secret \
  --name api-gateway/prod/db \
  --secret-string '{
    "postgres_password": "xxx",
    "mysql_password": "yyy"
  }'
```

**Obtener en deploy:**

```bash
# En script de deployment
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id api-gateway/prod/db \
  --query SecretString \
  --output text | jq -r .postgres_password)

export POSTGRES_PASSWORD=$DB_PASS
```

---

## Troubleshooting

### Kong no inicia

**Síntoma:** Container `kong` se reinicia constantemente

**Diagnóstico:**

```bash
docker logs kong --tail=50
```

**Causas comunes:**

1. **No puede conectar a PostgreSQL:**
   - Verificar security groups
   - Verificar credenciales en `.env`
   - Probar conexión: `docker exec kong pg_isready -h $POSTGRES_HOST`

2. **Migraciones no ejecutadas:**
   ```bash
   docker-compose logs kong-migrations
   # Si falló, ejecutar manualmente:
   docker-compose run --rm kong kong migrations bootstrap
   ```

3. **Puerto ya en uso:**
   ```bash
   sudo lsof -i :8000
   # Matar proceso o cambiar puerto en docker-compose
   ```

### Konga no carga

**Síntoma:** `502 Bad Gateway` al acceder a `/konga/`

**Diagnóstico:**

```bash
docker logs konga-proxy
docker logs konga
```

**Soluciones:**

1. **Konga aún iniciando:**
   ```bash
   # Esperar hasta que salga: "Konga started on port 1337"
   docker logs -f konga
   ```

2. **MySQL no conecta:**
   ```bash
   docker exec konga-db mysql -u$DB_USER -p$DB_PASSWORD -e "SHOW DATABASES;"
   ```

### Health Check fallando en Non-Prod/Prod

**Síntoma:** Container marcado como `unhealthy`

**Diagnóstico:**

```bash
docker inspect kong --format='{{json .State.Health}}' | jq .
```

**Soluciones:**

```bash
# Test manual del health check
docker exec kong kong health

# Si falla, revisar logs
docker logs kong --tail=100

# Ajustar health check si es necesario en docker-compose
```

### SSL Verification falla en Prod

**Síntoma:** `SSL certificate verify failed`

**Diagnóstico:**

```bash
docker logs kong | grep -i ssl
```

**Soluciones:**

1. **Certificate chain incompleto en RDS:**
   - Descargar CA bundle de AWS
   - Montar en Kong: `- ./rds-ca-bundle.pem:/etc/ssl/certs/rds-ca.pem`

2. **Temporalmente deshabilitar (NO recomendado en prod):**
   ```env
   KONG_PG_SSL_VERIFY=off
   ```

### Performance Issues

**Síntoma:** Respuestas lentas, timeouts

**Diagnóstico:**

```bash
# Resource usage
docker stats

# Kong metrics
curl http://localhost:8001/status | jq .

# Database connections
docker exec kong kong health | grep database
```

**Soluciones:**

1. **Aumentar workers (Prod):**
   ```env
   KONG_NGINX_WORKER_PROCESSES=4
   KONG_NGINX_WORKER_CONNECTIONS=8192
   ```

2. **Optimizar cache:**
   ```env
   KONG_MEM_CACHE_SIZE=256m
   KONG_DB_CACHE_TTL=7200
   ```

3. **Database connection pooling:**
   ```env
   KONG_PG_MAX_CONCURRENT_QUERIES=0
   KONG_PG_SEMAPHORE_TIMEOUT=60000
   ```

---

## Comandos Útiles por Entorno

### Local

```bash
# Reinicio rápido
docker-compose -f docker-compose.yml -f docker-compose.local.yml restart kong

# Rebuild completo
docker-compose -f docker-compose.yml -f docker-compose.local.yml down -v
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d --build

# Limpiar todo
docker-compose -f docker-compose.yml -f docker-compose.local.yml down -v --remove-orphans
```

### Non-Prod

```bash
# Deploy actualización
docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml pull
docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml up -d

# Ver logs con timestamps
docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml logs -f --timestamps
```

### Producción

```bash
# Blue-Green Deploy (requiere 2x recursos temporalmente)
# 1. Deploy nuevo stack
docker-compose -f docker-compose.yml -f docker-compose.prod.yml -p kong-green up -d

# 2. Verificar health
docker ps | grep green

# 3. Switch ALB target group

# 4. Remover stack viejo
docker-compose -f docker-compose.yml -f docker-compose.prod.yml -p kong-blue down
```

---

**Última actualización:** 2025-12-04
**Versión:** 1.0
**Mantenido por:** Equipo DevOps TLM
