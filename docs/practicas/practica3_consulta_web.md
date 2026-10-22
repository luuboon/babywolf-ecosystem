# Práctica 3 — ConsultaWeb: consumo de una URL preasignada

ConsultaWeb es una **extensión del sitio BabyWolf** dentro de la app (🧪 →
*ConsultaWeb*).

## Los tres pasos

| Paso | Implementación |
|---|---|
| URL preasignada | `GET /api/consulta/url` devuelve una URL firmada con HMAC-SHA256 que vale 5 min: `/api/consulta/recurso?exp=…&recurso=resumen&sig=…` |
| Solicitud HTTP | La app hace `GET` a esa URL (`consulta_api.dart`, timeout de 15 s) |
| Procesamiento | El JSON se convierte en `ResumenSitio`: total de noticias, conteo por categoría y las 3 más recientes |

La firma cubre todos los parámetros. Si se cambia cualquier carácter de la
URL, el backend responde **403**; si pasaron más de 5 minutos, **410**
(`backend/internal/infrastructure/security/presign.go`).

## Requisitos funcionales

| RF | Requisito | Cómo se cumple |
|---|---|---|
| RF01 | Al iniciar: "Consulta de información" | Encabezado de la pantalla |
| RF02 | Botón CONSULTAR | Botón principal (tooltip "Consultar información") |
| RF03 | Petición HTTP a la URL preasignada | Pasos 1 y 2 de arriba |
| RF04 | Mostrar la información | Tarjetas "Respuesta", "URL preasignada usada" y "JSON recibido" |
| RF05 | "Consultando..." | Indicador de progreso + texto mientras dura la petición |
| RF06 | "No fue posible obtener la información." | Tarjeta de error, con la causa debajo (sin red, URL modificada, expirada) |

## Actividad principal

| Prueba | Cómo hacerla | Esperado | Verificado |
|---|---|---|---|
| 1 — Con conexión | Pulsar CONSULTAR | Resumen del blog en pantalla | `test/consulta_web_test.dart` (servidor simulado). En la app real: pendiente de captura |
| 2 — Sin conexión | Modo avión en el emulador → CONSULTAR | "No fue posible obtener la información." + "Revisa tu conexión" | `consulta_web_test.dart` (RF06) |
| 3 — Modificación de la URL | Activar "Modificar la URL", cambiar un carácter → CONSULTAR | Mensaje de RF06 + "El servidor rechazó la URL: fue modificada" (403) | Backend: `presign_test.go` (5 alteraciones distintas) y prueba manual con curl; app: `consulta_web_test.dart` |
