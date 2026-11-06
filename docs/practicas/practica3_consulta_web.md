# Práctica 3 — ConsultaWeb: consumo de una URL preasignada

**En BabyWolf:** la tarjeta de **resumen del blog** que aparece arriba del
feed de noticias. Dice cuántas noticias hay y cuántas por tema, y cada tema
es un botón que filtra el feed.

Código: `phone_app/lib/resumen/` (`resumen_api.dart`, `resumen_tarjeta.dart`).
Backend: `/api/consulta/url` y `/api/consulta/recurso` del repo `babywolf-blog`.

## Los tres pasos

| Paso | Implementación |
|---|---|
| URL preasignada | `GET /api/consulta/url` devuelve una URL firmada con HMAC-SHA256 que vale 5 min: `/api/consulta/recurso?exp=…&recurso=resumen&sig=…` |
| Solicitud HTTP | La app hace `GET` a esa URL (`ConsultaApi.consultar`, timeout de 15 s) |
| Procesamiento | El JSON se convierte en `ResumenSitio`: total de noticias, conteo por tema y las más recientes. La tarjeta lo muestra y usa el conteo como filtro |

La firma cubre todos los parámetros. Si se cambia cualquier carácter de la
URL, el backend responde **403**; si pasaron más de 5 minutos, **410**
(`backend/internal/infrastructure/security/presign.go`).

`ResumenServicio` guarda la URL mientras sigue vigente (no pide una nueva en
cada recarga). Si el servidor contesta 410 o 403, pide otra **una sola vez**;
si vuelve a fallar, muestra el error.

## Requisitos funcionales

| RF | Requisito | Cómo se cumple en BabyWolf |
|---|---|---|
| RF01 | Pantalla de consulta | La tarjeta de resumen es lo primero del feed |
| RF02 | Acción de consultar | Se consulta al abrir la app y al deslizar el feed hacia abajo; en error, botón **Reintentar** |
| RF03 | Petición HTTP a la URL preasignada | Pasos 1 y 2 |
| RF04 | Mostrar la información | "N noticias", los temas con su conteo y la hora a la que vence el enlace firmado |
| RF05 | Indicador de "consultando" | "Consultando el resumen del blog…" con indicador de progreso |
| RF06 | Mensaje de error | "No fue posible obtener el resumen." más la causa (sin red, URL rechazada, vencida) |

## Pruebas

| Prueba | Cómo hacerla | Esperado | Verificado |
|---|---|---|---|
| 1 — Con conexión | Abrir la app | Tarjeta con el total y los temas; tocar un tema filtra el feed | `test/resumen_test.dart` (servidor simulado y tarjeta). En el emulador: prueba de la versión anterior con 8 noticias (05/11/2026); falta captura de la tarjeta nueva |
| 2 — Sin conexión | Modo avión → deslizar el feed | Mensaje de error y **Reintentar** | `resumen_test.dart` |
| 3 — URL modificada | Cambiar un carácter de la URL firmada | 403 | Backend: `presign_test.go` (5 alteraciones). App: `resumen_test.dart`. La interfaz ya no deja editar la URL a mano, porque un lector no lo haría; se prueba con la API |
| 4 — URL vencida | Esperar más de 5 min y recargar | La app pide otra URL sola y muestra el resumen | `resumen_test.dart` (410 → URL nueva) |
