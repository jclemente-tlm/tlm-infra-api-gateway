# Estructura del Proyecto TLM API Gateway

```text
tlm-infra-api-gateway/
│
├── 📄 README.md                          # Documentación principal del proyecto
├── 📄 .env.example                       # Template de variables de entorno
├── 📄 .env                               # Variables de entorno (gitignored)
├── 📄 .gitignore                         # Archivos excluidos de git
│
├── 🐳 docker-compose.yml                 # Compose base (requerido siempre)
├── 🐳 docker-compose.local.yml           # Override para desarrollo local
├── 🐳 docker-compose.nonprod.yml         # Override para DEV/QA
├── 🐳 docker-compose.prod.yml            # Override para producción
│
├── 📁 config/                            # Archivos de configuración
│   ├── nginx-konga.conf                  # Nginx reverse proxy
│   └── kong-local.conf                   # Kong config local
│
└── 📁 docs/                              # Documentación detallada
    ├── README.md                         # Índice de documentación
    ├── KEYCLOAK_NAMING_STANDARD.md       # Nomenclatura de Keycloak
    ├── KEYCLOAK_KONG_INTEGRATION.md      # Guía de integración
    └── DEPLOYMENT_GUIDE.md               # Guía de despliegue
```

## Uso por Archivo

### Archivos de Configuración

| Archivo | Propósito | Cuándo Modificar |
|---------|-----------|------------------|
| `.env.example` | Template de variables | Al agregar nuevas variables |
| `.env` | Variables reales | Setup inicial y cambios de credenciales |
| `config/nginx-konga.conf` | Proxy Konga | Cambios de rutas o paths |
| `config/kong-local.conf` | Kong local | Tuning local |

### Docker Compose Files

| Archivo | Comando | Entorno |
|---------|---------|---------|
| `docker-compose.yml` | Base (siempre) | Todos |
| `+ docker-compose.local.yml` | `docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d` | Local |
| `+ docker-compose.nonprod.yml` | `docker-compose -f docker-compose.yml -f docker-compose.nonprod.yml up -d` | DEV/QA |
| `+ docker-compose.prod.yml` | `docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d` | Producción |

### Documentación

| Documento | Audiencia | Contenido |
|-----------|-----------|-----------|
| `README.md` | Todos | Overview, quick start, comandos comunes |
| `docs/KEYCLOAK_NAMING_STANDARD.md` | DevOps, Arquitectos | Convenciones de nomenclatura |
| `docs/KEYCLOAK_KONG_INTEGRATION.md` | DevOps, Developers | Setup JWT authentication |
| `docs/DEPLOYMENT_GUIDE.md` | DevOps | Deploy por ambiente |

## Flujo de Trabajo

### Setup Inicial

1. Clonar repositorio
2. Copiar `.env.example` → `.env`
3. Editar `.env` con credenciales
4. Ejecutar compose según entorno

### Desarrollo Local

1. Usar `docker-compose.local.yml`
2. Modificar configs en `config/`
3. Reload sin reiniciar: `docker exec ... reload`

### Deploy a Non-Prod

1. Push cambios a git
2. Pull en servidor DEV/QA
3. Usar `docker-compose.nonprod.yml`
4. Verificar health checks

### Deploy a Producción

1. Revisar checklist en `DEPLOYMENT_GUIDE.md`
2. Backup de DBs
3. Blue-Green deploy
4. Usar `docker-compose.prod.yml`

## Archivos NO en Git

```
.env                  # Credenciales reales
/opt/                 # Datos de volúmenes
*.log                 # Logs
```

## Mantenimiento

- **Documentación**: Actualizar docs/ al cambiar arquitectura
- **Variables**: Mantener .env.example sincronizado con .env
- **Configs**: Versionar configs en config/
- **Compose**: Un override por entorno, no mezclar

---

**Fecha:** 2025-12-04  
**Versión:** 1.0
