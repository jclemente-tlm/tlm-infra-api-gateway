# Estrategia de Bases de Datos

## Resumen

Este proyecto utiliza dos bases de datos:

1. **PostgreSQL** - Para Kong API Gateway
2. **MySQL** - Para Konga (Kong Admin UI)

## Estrategia por Ambiente

### 🏠 Desarrollo Local

**Kong Database (PostgreSQL):**

- ✅ Contenedor Docker local (`kong-db`)
- Puerto: `5432` (expuesto para debugging)
- Credentials: `kong/kong_local_password`
- Volumen: `kong-db-data` (persistencia local)
- **Razón:** No requiere RDS, desarrollo aislado y rápido

**Konga Database (MySQL):**

- ✅ Contenedor Docker local (`konga-db` del compose base)
- Puerto: `3307` (para evitar conflictos con MySQL local)
- Credentials: `konga/konga_local_password`
- Volumen: `konga-db-data` (persistencia local)
- **Razón:** Configuración independiente para cada desarrollador

### 🧪 Non-Prod (DEV/QA/UAT)

**Kong Database (PostgreSQL):**

- ❌ NO contenedor Docker
- ✅ AWS RDS PostgreSQL compartido
- Conexión: Variables de entorno en `.env`
- SSL: Requerido (`KONG_PG_SSL=on`)
- **Razón:** Base de datos gestionada, backups automáticos

**Konga Database (MySQL):**

- ✅ Contenedor Docker (`konga-db` del compose base)
- Volumen: `/opt/konga/mysql` (host mount)
- **Razón:** Konga es solo UI administrativa, no crítica para producción

### 🚀 Producción

**Kong Database (PostgreSQL):**

- ❌ NO contenedor Docker
- ✅ AWS RDS PostgreSQL dedicado
- Conexión: Variables de entorno en `.env`
- SSL: Requerido con verificación (`KONG_PG_SSL=on`)
- **Razón:** Alta disponibilidad, backups, multi-AZ

**Konga Database (MySQL):**

- ✅ Contenedor Docker (`konga-db` del compose base)
- Volumen: `/opt/konga/mysql` (host mount con backups)
- **Razón:** Konga accesible solo desde VPN/bastion, no crítica

---

## Configuración por Archivo

### docker-compose.yml (Base)

```yaml
services:
  kong-migrations:
    environment:
      KONG_PG_HOST: ${KONG_PG_HOST}  # Desde .env

  kong:
    environment:
      KONG_PG_HOST: ${KONG_PG_HOST}  # Desde .env

  konga-db:
    image: mysql:5.7  # DEFINIDO en base, usado por todos
    volumes:
      - /opt/konga/mysql:/var/lib/mysql
```

### docker-compose.local.yml (Override)

```yaml
services:
  kong-db:  # NUEVO servicio solo para local
    image: postgres:15-alpine

  kong-migrations:
    environment:
      KONG_PG_HOST: kong-db  # Override para usar DB local

  kong:
    environment:
      KONG_PG_HOST: kong-db  # Override para usar DB local

  konga-db:  # Override del base
    ports:
      - "3307:3306"  # Exponer para debugging local
    environment:
      MYSQL_PASSWORD: konga_local_password  # Credentials locales
    volumes:
      - konga-db-data:/var/lib/mysql  # Volumen Docker en vez de host mount
```

### docker-compose.nonprod.yml / prod.yml

```yaml
# NO definen kong-db (usan RDS desde .env)
# konga-db se hereda del compose base sin cambios
```

---

## Variables de Entorno

### Local (.env)

```bash
# Kong DB - NO USADO (override en docker-compose.local.yml)
# Las variables existen pero son ignoradas

# Konga DB - Usado por override local
KONGA_PG_USER=konga
KONGA_PG_PASSWORD=konga_local_password
KONGA_PG_DATABASE=konga
```

### Non-Prod (.env)

```bash
# Kong DB - AWS RDS
KONG_PG_HOST=kong-nonprod.xxxxx.us-east-1.rds.amazonaws.com
KONG_PG_USER=kong
KONG_PG_PASSWORD=<secure-password>
KONG_PG_DATABASE=kong
KONG_PG_SSL=on
KONG_PG_SSL_VERIFY=off

# Konga DB - Container local (no necesita host externo)
KONGA_PG_USER=konga
KONGA_PG_PASSWORD=<secure-password>
KONGA_PG_DATABASE=konga
KONGA_RP_PASSWORD=<root-password>
```

### Producción (.env)

```bash
# Kong DB - AWS RDS
KONG_PG_HOST=kong-prod.xxxxx.us-east-1.rds.amazonaws.com
KONG_PG_USER=kong
KONG_PG_PASSWORD=<secure-password>
KONG_PG_DATABASE=kong
KONG_PG_SSL=on
KONG_PG_SSL_VERIFY=on  # Verificación completa en prod

# Konga DB - Container local
KONGA_PG_USER=konga
KONGA_PG_PASSWORD=<secure-password>
KONGA_PG_DATABASE=konga
KONGA_RP_PASSWORD=<root-password>
```

---

## Comandos Útiles

### Local

```bash
# Iniciar con DBs locales
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d

# Verificar Kong DB
docker exec -it kong-db psql -U kong -d kong

# Verificar Konga DB
docker exec -it konga-db mysql -u konga -pkonga_local_password konga

# Ver logs de migraciones
docker logs kong-migrations

# Limpiar y reiniciar DBs
docker-compose -f docker-compose.yml -f docker-compose.local.yml down -v
docker volume rm tlm-infra-api-gateway_kong-db-data
docker volume rm tlm-infra-api-gateway_konga-db-data
```

### Non-Prod / Producción

```bash
# Iniciar (usa RDS para Kong)
docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml up -d

# Verificar conexión a RDS
docker logs kong | grep -i "database"

# Verificar Konga DB local
docker exec -it konga-db mysql -u konga -p konga

# Backup de Konga DB
docker exec konga-db mysqldump -u konga -p konga > konga_backup.sql
```

---

## Troubleshooting

### Error: "failed to connect to PostgreSQL"

**Local:**

```bash
# Verificar que kong-db esté corriendo
docker ps | grep kong-db

# Verificar healthcheck
docker inspect kong-db | grep -A 5 Health

# Reintentar migraciones
docker-compose -f docker-compose.yml -f docker-compose.local.yml restart kong-migrations
```

**Non-Prod/Prod:**

```bash
# Verificar conexión a RDS
telnet kong-nonprod.xxxxx.rds.amazonaws.com 5432

# Verificar security groups en AWS
# Verificar variables en .env
cat .env | grep KONG_PG
```

### Error: "Access denied for user 'konga'@'%'"

```bash
# Verificar password en override local
cat docker-compose.local.yml | grep MYSQL_PASSWORD

# Resetear Konga DB
docker-compose down
docker volume rm tlm-infra-api-gateway_konga-db-data
docker-compose up -d konga-db
```

### Kong migrations no se ejecutan

```bash
# Verificar orden de dependencias
docker-compose config | grep -A 10 kong-migrations

# Forzar re-ejecución
docker-compose down
docker-compose up kong-migrations
```

---

## Diagrama de Arquitectura

```text
┌─────────────────────────────────────────────────────────────┐
│                         LOCAL                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐    ┌────────────────┐    ┌──────────────┐   │
│  │  Kong    │───→│  kong-db       │    │  konga-db    │   │
│  │ Gateway  │    │ (PostgreSQL    │    │  (MySQL      │   │
│  └──────────┘    │  Container)    │    │   Container) │   │
│                  └────────────────┘    └──────────────┘   │
│                                              ↑             │
│                                              │             │
│                                        ┌───────────┐       │
│                                        │   Konga   │       │
│                                        └───────────┘       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    NON-PROD / PROD                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐    ┌────────────────┐    ┌──────────────┐   │
│  │  Kong    │───→│  AWS RDS       │    │  konga-db    │   │
│  │ Gateway  │    │ (PostgreSQL    │    │  (MySQL      │   │
│  └──────────┘    │  Managed)      │    │   Container) │   │
│                  └────────────────┘    └──────────────┘   │
│                         ↑                     ↑            │
│                         │                     │            │
│                    Multi-AZ             ┌───────────┐      │
│                    Backups              │   Konga   │      │
│                    Encryption           └───────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## Decisiones de Diseño

### ¿Por qué PostgreSQL local para Kong en desarrollo?

✅ **Ventajas:**

- Sin dependencia de AWS durante desarrollo
- Desarrollo offline posible
- Cada desarrollador tiene su propia DB
- Rápido de levantar y tirar abajo
- No hay costos de RDS para desarrollo

❌ **Sin esto:**

- Necesitarías VPN para desarrollar
- Compartirías DB con otros developers
- Más lento (latencia de red)
- Costos de RDS innecesarios

### ¿Por qué RDS para Kong en non-prod/prod?

✅ **Ventajas:**

- Backups automáticos
- Multi-AZ para alta disponibilidad
- Encryption at rest y in transit
- Performance tuning gestionado
- Menos riesgo de pérdida de datos

### ¿Por qué contenedor MySQL para Konga en todos los ambientes?

✅ **Ventajas:**

- Konga es solo UI administrativa (no crítica)
- Acceso restringido desde VPN/bastion
- Datos no son críticos (se pueden recrear)
- Simplicidad operativa
- Reduce costos (no necesita RDS)

---

**Mantenido por:** Equipo DevOps TLM
**Última actualización:** 2025-12-04
