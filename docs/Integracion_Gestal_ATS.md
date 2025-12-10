# ATS: Crear Posición TALMA

Este endpoint permite crear una **nueva posición (vacante)** en el sistema ATS de TalentHub, específicamente para el cliente **TALMA**.

El servicio procesa los datos enviados en formato JSON y crea el registro correspondiente en la base de datos.

---

### **URL del servicio**

```
POST https://api-ats.talenthub.pe/ats/lmbExGen?operacion=TALMA_CREAR_POSICION_V1&bcode=68e6d6ae94a907a6ef26e95f
```

> 🔹 El parámetro bcode es constante y corresponde al identificador del cliente TALMA.
>

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