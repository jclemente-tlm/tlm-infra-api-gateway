# Índice de Documentación

Este directorio contiene toda la documentación para la infraestructura del API Gateway de TLM.

## Quick Links

- 🚀 **¿Nuevo aquí?** Empieza con la [Guía de Inicio Rápido](./QUICK_START.md)
- 📖 **¿Usando la API?** Consulta la [API Reference](./API_REFERENCE.md)
- 🏗️ **¿Por qué esta arquitectura?** Lee las [Decisiones de Arquitectura](./ARCHITECTURE_DECISIONS.md)
- 🌐 **¿Configurando dominios?** Lee la [Estrategia de Dominios](./DOMAIN_STRATEGY.md)
- 📐 **¿Entendiendo el proyecto?** Ve la [Estructura del Proyecto](./STRUCTURE.md)
- 🗄️ **¿Configurando bases de datos?** Lee la [Estrategia de Bases de Datos](./DATABASE_STRATEGY.md)
- 🔐 **¿Configurando autenticación?** Revisa la [Guía de Integración Keycloak](./KEYCLOAK_KONG_INTEGRATION.md)
- 🚢 **¿Desplegando?** Lee la [Guía de Despliegue](./DEPLOYMENT_GUIDE.md)

---

## Documentación Principal

### 1. [Guía de Inicio Rápido](./QUICK_START.md) 🚀

Levanta el API Gateway funcionando en minutos.

**Temas cubiertos:**

- Prerequisitos y configuración inicial
- Iniciar servicios en diferentes ambientes (local, non-prod, prod)
- Crear tu primer service y route
- Verificación básica y testing
- Troubleshooting común

**Cuándo consultar:** Primera configuración o al incorporar nuevos miembros del equipo.

---

### 2. [Decisiones de Arquitectura](./ARCHITECTURE_DECISIONS.md) 🏗️

Documentación de decisiones técnicas clave y su justificación.

**Temas cubiertos:**

- **ADR-001**: Patrón de ruteo `/api/{sistema}/{módulo}/{recurso}` - Sustento técnico y comparación con alternativas
- **ADR-002**: Multi-tenancy por Realm JWT (México/Perú)
- **ADR-003**: Kong + Keycloak vs alternativas (AWS API Gateway, Apigee, Azure)
- **ADR-004**: Estrategia de dominios públicos y privados
- Referencias a patrones de Netflix, Uber, AWS, Stripe, Microsoft
- Beneficios técnicos validados
- Consecuencias e implementación

**Cuándo consultar:** Al cuestionar decisiones de arquitectura, incorporar nuevos miembros, planear nuevos sistemas, o documentar el "por qué" de la implementación actual.

---

### 3. [Estructura del Proyecto](./STRUCTURE.md) 📐

Entendiendo la organización del proyecto y disposición de archivos.

**Temas cubiertos:**

- Explicación de la estructura de directorios
- Propósito de los archivos Docker Compose
- Ubicación de archivos de configuración
- Overrides específicos por ambiente
- Patrones de git ignore

**Cuándo consultar:** Al explorar el código o agregar nuevas configuraciones.

---### 3. [Estructura del Proyecto](./STRUCTURE.md) 📐

Entendiendo la organización del proyecto y disposición de archivos.

**Temas cubiertos:**

- Explicación de la estructura de directorios
- Propósito de los archivos Docker Compose
- Ubicación de archivos de configuración
- Overrides específicos por ambiente
- Patrones de git ignore

**Cuándo consultar:** Al explorar el código o agregar nuevas configuraciones.

---

### 4. [API Reference](./API_REFERENCE.md) 📖

Referencia completa de todos los endpoints disponibles en el API Gateway.

**Temas cubiertos:**

- Autenticación y obtención de tokens JWT
- Endpoints de Sisbon (usuarios y bonificaciones)
- Endpoints de Gestal (almacenes)
- Códigos de error y manejo de errores
- Rate limiting y mejores prácticas
- Ejemplos de integración en múltiples lenguajes

**Cuándo consultar:** Al desarrollar integraciones con el API o documentar casos de uso.

---

### 4. [API Reference](./API_REFERENCE.md) 📖

Referencia completa de todos los endpoints disponibles en el API Gateway.

**Temas cubiertos:**

- Autenticación y obtención de tokens JWT
- Endpoints de Sisbon (usuarios y bonificaciones)
- Endpoints de Gestal (almacenes)
- Códigos de error y manejo de errores
- Rate limiting y mejores prácticas
- Ejemplos de integración en múltiples lenguajes

**Cuándo consultar:** Al desarrollar integraciones con el API o documentar casos de uso.

---

### 5. [Estrategia de Dominios](./DOMAIN_STRATEGY.md) 🌐

Convención de nomenclatura de dominios y arquitectura de routing.

**Temas cubiertos:**

- Convenciones de nomenclatura (público vs privado)
- Lista completa de dominios (9 públicos + 13 privados)
- Configuración DNS en Route53
- Arquitectura de observabilidad con Envoy
- Flujo completo de requests
- Ejemplos de configuración Kong
- Guía para añadir nuevos servicios

**Cuándo consultar:** Al configurar nuevos servicios, planear DNS, o entender el routing.

---

### 6. [Estrategia de Bases de Datos](./DATABASE_STRATEGY.md) 🗄️

Estrategia completa de bases de datos por ambiente.

**Temas cubiertos:**

- PostgreSQL local para Kong (solo desarrollo)
- MySQL para Konga (todos los ambientes)
- AWS RDS para Kong en non-prod/prod
- Configuración de conexiones por ambiente
- Comandos de debugging y troubleshooting

**Cuándo consultar:** Al configurar ambiente local o resolver problemas de conexión a BD.

---

### 7. [Estándar de Nomenclatura Keycloak](./KEYCLOAK_NAMING_STANDARD.md) 📝

Estrategia completa de bases de datos por ambiente.

**Temas cubiertos:**

- PostgreSQL local para Kong (solo desarrollo)
- MySQL para Konga (todos los ambientes)
- AWS RDS para Kong en non-prod/prod
- Configuración de conexiones por ambiente
- Comandos de debugging y troubleshooting

**Cuándo consultar:** Al configurar ambiente local o resolver problemas de conexión a BD.

---

### 7. [Estándar de Nomenclatura Keycloak](./KEYCLOAK_NAMING_STANDARD.md) 📝

Convenciones completas de nomenclatura para clients, realms y roles de Keycloak.

**Temas cubiertos:**

- Patrones de nomenclatura de realms para arquitectura multi-tenant
- Nomenclatura de clients para servicios locales vs corporativos
- Convenciones de nomenclatura de roles
- Patrones de escalabilidad y estrategias de evolución
- Guías de migración

**Cuándo consultar:** Antes de crear nuevos clients de Keycloak o planear expansión de servicios.

---

### 8. [Guía de Integración Keycloak + Kong](./KEYCLOAK_KONG_INTEGRATION.md) 🔐

Guía paso a paso para configurar autenticación JWT entre Keycloak y Kong.

**Temas cubiertos:**

- Configuración de realm y client en Keycloak
- Setup de service, route y consumer en Kong
- Configuración de plugin JWT
- Procedimientos de testing
- Escenarios comunes de troubleshooting

**Cuándo consultar:** Al configurar un nuevo servicio o debuggear problemas de autenticación.

---

### 8. [Guía de Despliegue](./DEPLOYMENT_GUIDE.md) 🚢

Guía completa para desplegar y configurar el API Gateway en diferentes ambientes.

**Temas cubiertos:**

- Setup de desarrollo local
- Configuración non-prod (DEV/QA)
- Despliegue a producción con hardening de seguridad
- Variables específicas por ambiente
- Troubleshooting por ambiente

**Cuándo consultar:** Al desplegar a un nuevo ambiente o resolver problemas de despliegue.

---

## Referencias Rápidas

### Visión General de Arquitectura

Ver [README.md](../README.md) principal para:

- Diagrama de arquitectura del sistema
- Descripciones de componentes
- Guía de inicio rápido
- Configuración de ambientes

### Archivos de Configuración

Ubicados en el directorio `/config`:

- `nginx-konga.conf` - Configuración del reverse proxy Nginx
- `kong-local.conf` - Configuración de Kong para desarrollo local

### Configuración de Ambientes

- `.env.example` - Template para variables de entorno
- Copiar a `.env` y llenar con tus valores

---

## Organización de Documentos

```text
docs/
├── README.md                          # Este archivo
├── KEYCLOAK_NAMING_STANDARD.md        # Convenciones de nomenclatura
├── KEYCLOAK_KONG_INTEGRATION.md       # Guía de integración
└── DEPLOYMENT_GUIDE.md                # Despliegue por ambiente

config/
├── nginx-konga.conf                   # Configuración Nginx
└── kong-local.conf                    # Config Kong local

docker-compose.yml                      # Archivo compose base
docker-compose.local.yml                # Overrides locales
docker-compose.nonprod.yml              # Overrides Dev/QA
docker-compose.prod.yml                 # Overrides producción
```

---

## Contribuir a la Documentación

Al actualizar la documentación:

1. **Mantenerla actualizada:** Actualizar fechas y números de versión
2. **Ser específico:** Usar ejemplos concretos con valores reales
3. **Probar comandos:** Verificar que todos los comandos curl/bash funcionen
4. **Referencias cruzadas:** Enlazar documentos relacionados
5. **Actualizar este índice:** Si agregas nuevos documentos

---

## Historial de Versiones

| Fecha | Versión | Cambios |
|------|---------|---------|
| 2025-12-04 | 1.0 | Estructura inicial de documentación |

---

**Mantenido por:** Equipo DevOps TLM
