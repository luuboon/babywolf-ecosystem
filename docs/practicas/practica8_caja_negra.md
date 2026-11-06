# Práctica 8 — Evaluación de calidad con pruebas de caja negra

**Producto evaluado:** la app BabyWolf (`phone_app`) con las funciones que
salieron de las prácticas 3–7, 9 y 10, junto con el backend Go (Railway) y la
base Supabase del blog.

**Técnicas:**
- Partición de equivalencia (entradas válidas / inválidas).
- Valores límite (longitudes, tiempos de bloqueo y de vigencia).
- Tabla de decisión (permisos por rol y por dueño).
- Transición de estados (sesión, conexión, versión de un reporte).

**Enfoque de caja negra:** cada caso se define sólo por entrada → salida
esperada, sin mirar el código.

| Se recomienda evaluar… | En BabyWolf |
|---|---|
| Autenticación o control de acceso | Cuenta (P5), reglas por dueño y por rol (P10), mesa de ayuda (P7) |
| Formularios de registro | Crear cuenta, reportar una noticia, comentar |
| Consulta, búsqueda o filtrado | Resumen y filtro por tema, Guardadas, filtro de reportes por estado |
| Modificación y eliminación | Nota de una guardada, reportes, comentarios |
| Reglas de negocio verificables | Sin duplicados en Guardadas, versión de reportes, sólo el admin cambia el estado |
| Pantallas, módulos o roles | Lector, admin; admin/agente/usuario en la mesa |
| Persistencia | SQLite local (Guardadas), Supabase (reportes, comentarios), sesión cifrada |
| Confirmaciones y manejo de errores | Mensajes genéricos, sin éxito falso sin red, avisos de conflicto |

---

## 1. Inventario de funcionalidades

| ID | Funcionalidad | Práctica |
|---|---|---|
| F01 | Feed de noticias | — |
| F02 | Resumen del blog por URL firmada y filtro por tema | P3 |
| F03 | Guardar noticias, leerlas sin internet y anotar | P4 |
| F04 | Entrar, crear cuenta, sesión persistente y cerrar sesión | P5 |
| F05 | Comentarios entre lectores | P6 |
| F06 | Mesa de ayuda del equipo (roles, mensajes, archivos) | P7 |
| F07 | Reportar una noticia y seguir el reporte entre dispositivos | P9 |
| F08 | Reglas de acceso por dueño y por rol | P10 |

## 2–7. Requisitos: entradas, restricciones, salidas, errores y criterio de aceptación

| Req. | Func. | Entrada | Restricción | Salida / cambio de estado esperado | Error a manejar | Criterio de aceptación medible |
|---|---|---|---|---|---|---|
| RQ01 | F01 | Abrir la app | — | Lista de noticias | Sin red / backend caído | Con red: ≥ 1 noticia en ≤ 15 s. Sin red: mensaje + "Reintentar" que recarga |
| RQ02 | F02 | Abrir o recargar el feed | URL firmada, vigencia 5 min | "Consultando…" y luego total + temas | Sin red, URL alterada (403), vencida (410) | Vencida: pide otra sola; alterada: 403; sin red: mensaje + Reintentar |
| RQ03 | F02 | Tocar un tema | — | El feed muestra sólo ese tema; "Todas" lo quita | — | Todas las tarjetas visibles son del tema elegido |
| RQ04 | F03 | Marcador en una noticia | Una noticia se guarda una sola vez | Aparece en Guardadas con su contenido | Guardar dos veces | 1 fila por noticia; se lee en modo avión |
| RQ05 | F03 | Nota personal | ≤ 500 caracteres | La nota se ve en el detalle y en la lista | 501 caracteres | Se rechaza con mensaje |
| RQ06 | F03 | Quitar (marcador o deslizar) | Confirmación al deslizar | Desaparece de la lista | — | 0 filas para esa noticia |
| RQ07 | F03 | Cerrar y abrir la app | — | Las guardadas siguen | — | Mismo número de guardadas |
| RQ08 | F04 | correo, contraseña | correo ≤ 120 con formato; contraseña ≤ 72 | Sesión con correo, UID y rol | Vacíos, formato, credencial errónea | Lo inválido no llega al servidor; credencial errónea → un solo mensaje genérico |
| RQ09 | F04 | 5 credenciales erróneas | — | Bloqueo de 30 s | Fuerza bruta | Botón deshabilitado con cuenta regresiva; sin peticiones durante el bloqueo |
| RQ10 | F04 | Crear cuenta | nombre 3–20 `[a-zA-Z0-9._-]`; contraseña ≥ 8 con letras y números; confirmación igual | Sesión iniciada, o aviso de confirmar correo | Contraseña débil, distinta, correo o nombre repetido | Mensaje que no revela qué dato chocó |
| RQ11 | F04 | Cerrar y abrir la app | Sesión guardada | Entra directo | Token vencido / revocado | Revocado → queda sin sesión, sin error |
| RQ12 | F04 | Usar la app más de 1 hora | Token de 1 h | Sigue funcionando | — | Comentar a los 65 min funciona sin volver a entrar |
| RQ13 | F04 | Cualquier intento | — | "Actividad reciente" sin datos sensibles | — | Correo enmascarado; nunca la contraseña |
| RQ14 | F05 | Comentario | 1–280 caracteres; con sesión | Aparece con autor y hora en ambos teléfonos | Vacío, largo, sin sesión | El otro teléfono lo ve en ≤ 5 s; vacío y largo se rechazan |
| RQ15 | F05 | Borrar comentario | Propio, o cualquiera si eres admin | Desaparece | Ajeno | Ajeno → "no es tu comentario" |
| RQ16 | F07 | Motivo, detalles, prioridad | Motivo obligatorio; detalles ≤ 500 | Reporte "Pendiente" ligado a la noticia | Sin motivo, sin red | Sin red: no se confirma y lo escrito se conserva |
| RQ17 | F07 | Cambio de estado / prioridad / descripción | Estado sólo admin; descripción sólo dueño | El otro dispositivo lo ve | Rol sin permiso | Visible en ≤ 5 s en el otro dispositivo |
| RQ18 | F07 | Dos dispositivos editan el mismo reporte | — | El segundo en guardar recibe aviso y conserva sus cambios | Escritura concurrente | Ningún cambio confirmado se pierde sin aviso |
| RQ19 | F08 | Lector consulta reportes | — | Sólo los suyos | Intento de leer, cambiar o borrar ajenos | Rechazo en la base (SEG-04…SEG-10) |
| RQ20 | F08 | Admin consulta reportes | Rol admin en `users` | Todos | Cambiar dueño / borrar ajeno | Rechazado |
| RQ21 | F06 | Abrir la mesa como admin | Sesión de una cuenta admin | Panel de la mesa | Cuenta de lector | El lector ve "necesitas invitación"; el backend responde 403 |
| RQ22 | F06 | URL de invitación | Firmada, ≤ 30 min, un solo uso | Participante con ese rol | Alterada, expirada, reutilizada | 403 / 410 / 409 |
| RQ23 | F06 | Reportes, mensajes, archivos y roles de la mesa | Ver práctica 7 | TC01–TC08 | — | Ver práctica 7 |

## 8. Requisitos que todavía no se pueden verificar

| Req. | Por qué | Qué falta |
|---|---|---|
| Todos en la app | El código de esta versión aún no se ha compilado ni probado en el equipo del alumno | `flutter analyze`, `flutter test` y recorrido en el emulador |
| RQ14, RQ17, RQ18 entre dos dispositivos | Requieren dos dispositivos con cuentas distintas | Emulador + teléfono, o dos emuladores |
| RQ16–RQ20 en Supabase real | `007_app_lectores.sql` aún no se ejecuta en el proyecto | Ejecutarlo en el SQL Editor |
| RQ12 | Hay que esperar más de 1 hora con la app abierta | Prueba manual |
| Tiempo de respuesta en producción | Railway y Supabase en plan gratuito se pausan (502 observado el 08/10/2026) | Medir con el servicio activo |

---

## Casos de prueba

**Fuente de cada resultado:**
- **[GO]:** `go test` del backend.
- **[E2E]:** escenario de la mesa de ayuda contra el backend real + Postgres local (`backend/pruebas/escenario_soporte.py`), 37/37 y TC08 1/1 (22/10/2026).
- **[BD]:** `backend/pruebas/rls_incidencias.sh` (9/9) y `app_lectores.sh` (20/20) con los roles de Supabase, 06/11/2026.
- **[FT]:** `phone_app/test`. **Pendiente** de ejecutar para esta versión (la anterior pasó `flutter analyze` sin observaciones y 40/40 el 02/11/2026).
- **[DISP]:** manual en el emulador o el teléfono.

| Caso | Req. | Técnica | Entrada | Esperado | Resultado |
|---|---|---|---|---|---|
| CP01 | RQ01 | Defecto | "Reintentar" tras un error de red | Recarga la lista | Defecto encontrado y corregido en la versión anterior (`setState` devolvía un Future, commit `e53abb3`) |
| CP02 | RQ02 | Partición | URL íntegra | 200 + resumen | [GO] pasa · [FT] escrito · [DISP] la versión anterior mostró 8 noticias (05/11/2026) |
| CP03 | RQ02 | Partición | URL con un parámetro cambiado, agregado, exp alargado, firma alterada o sin firma | 403 | Pasa [GO] (5 variantes) · [FT] escrito |
| CP04 | RQ02 | Límite | URL usada después de 5 min | 410 y la app pide otra | 410 pasa [GO] · nueva URL: [FT] escrito |
| CP05 | RQ02 | Partición | Sin red | Mensaje + Reintentar | [FT] escrito |
| CP06 | RQ03 | Partición | Tema "retro" / "Todas" | Sólo retro / todas | [DISP] pendiente |
| CP07 | RQ04 | Partición | Guardar la misma noticia dos veces | 1 fila | [FT] escrito |
| CP08 | RQ05 | Límite | Nota de 500 / 501 | acepta / rechaza | [FT] escrito |
| CP09 | RQ06 | Estado | Quitar una guardada | 0 filas | [FT] escrito |
| CP10 | RQ07 | Estado | Cerrar y abrir la base / la app | Siguen | Base: [FT] escrito · App: la versión anterior conservó el registro al cerrar y abrir (05/11/2026); repetir con Guardadas |
| CP11 | RQ08 | Partición | Correo `abraham@`, `x' OR 1=1 --` | Rechazo sin petición | [FT] escrito |
| CP12 | RQ08 | Límite | Contraseña de 72 / 73 | acepta / rechaza | [FT] escrito (73) |
| CP13 | RQ08 | Partición | Contraseña incorrecta | "Correo o contraseña incorrectos." | [FT] escrito · [DISP] la versión simulada lo mostró (05/11/2026) |
| CP14 | RQ09 | Estado | 5 fallos, luego a los 31 s | Bloqueo y desbloqueo | [FT] escrito · [DISP] la versión simulada mostró "Espera 25 s" (05/11/2026) |
| CP15 | RQ10 | Partición | Contraseña nueva `abc123` / `12345678` / `BabyWolf2026` | rechaza / rechaza / acepta | [FT] escrito |
| CP16 | RQ10 | Partición | Nombre de usuario ya usado | Mensaje que no dice cuál dato chocó | [FT] escrito (500 simulado) |
| CP17 | RQ11 | Estado | Reabrir con sesión / sin red / con token revocado | Entra / conserva el token / queda fuera | [FT] escrito |
| CP18 | RQ12 | Límite | Token a 30 s de vencer | Se renueva | [FT] escrito |
| CP19 | RQ13 | Seguridad | Intento fallido | El registro no tiene la contraseña; correo enmascarado | [FT] escrito |
| CP20 | RQ14 | Partición | Comentario vacío / 281 | Rechazo en la app y en la base | Base: Pasa [BD] COM-05, COM-06 · App: [FT] escrito |
| CP21 | RQ14 | Seguridad | Comentar sin sesión / a nombre de otro | Rechazo | Pasa [BD] COM-03, COM-04 |
| CP22 | RQ15 | Decisión | Borrar comentario ajeno como lector / como admin | 0 filas / 1 fila | Pasa [BD] COM-07, COM-08 |
| CP23 | RQ16 | Estado | Reportar en modo avión | No se confirma; el texto sigue | [FT] escrito (`SinConexion`) · [DISP] pendiente |
| CP24 | RQ17 | Decisión | Admin cambia estado; lector ve el cambio | Visible | Pasa [BD] DB-06 · [DISP] pendiente |
| CP25 | RQ18 | Estado | Guardar con una versión vieja | No se pisa; aviso; al recargar se guardan los dos cambios | Pasa [BD] DB-07, DB-07b · [FT] escrito |
| CP26 | RQ19 | Decisión | SEG-04…SEG-10 | Rechazos | Pasa [BD] 9/9 · [DISP] pendiente (pantalla de verificación) |
| CP27 | RQ20 | Decisión | Admin cambia dueño / borra ajeno | Rechazado / 0 filas | Pasa [BD] ADM-02, ADM-03 |
| CP28 | RQ20 | Partición | Prioridad `urgente` | Rechazo de la base | Pasa [BD] DB-RN |
| CP29 | RQ21 | Decisión | Cuenta `user` / `admin` abre la mesa | 403 / 200 | Pasa [E2E] |
| CP30 | RQ22 | Partición | URL reutilizada / rol cambiado a admin | 409 / 403 | Pasa [E2E] |
| CP31 | RQ23 | TC01–TC08 | Ver la práctica 7 | — | Pasa [E2E] |

## Evaluación

| Pregunta de la práctica | Respuesta con la evidencia actual |
|---|---|
| ¿Las funciones corresponden a los requisitos? | Sí: cada práctica integrada tiene su función en la app (ver el [índice](README.md)), y las desviaciones están justificadas |
| ¿Las operaciones principales dan resultados correctos? | En la base sí: 20/20 y 9/9 [BD]. En el backend: [GO] y 37/37 [E2E]. **En la app aún no hay evidencia de esta versión**: las pruebas están escritas pero sin ejecutar |
| ¿Se rechazan entradas inválidas? | Sí, en dos capas (app y base): CP03, CP08, CP11, CP12, CP15, CP20, CP28 |
| ¿Hay defectos en navegación, formularios o mensajes? | No se conocen; falta el recorrido en el emulador |
| ¿Los datos conservan su consistencia? | Sí en la base: sin duplicados, control de versión (CP25), dueño inmutable (CP27) |
| ¿Los permisos se aplican bien? | Sí, en la base y no sólo en la interfaz: CP21, CP22, CP26, CP27, CP29 |
| ¿Responde bien a errores e interrupciones? | Diseñado para no confirmar sin respuesta del servidor (CP23); falta verificarlo en el dispositivo |
| ¿Hay defectos que impidan la liberación? | **Riesgo operativo:** si Supabase se pausa, nada que dependa de la base funciona (502 observado el 08/10/2026). **Riesgo de datos:** la tabla `users` podría ser legible por cualquiera (ver práctica 10) |
| ¿Las evidencias bastan para aceptar o rechazar? | **No todavía para la app.** Faltan `flutter analyze` y `flutter test` de esta versión, ejecutar 007 en Supabase y los casos [DISP] |

**Veredicto provisional:** base y backend **aceptados**. App **pendiente**
de compilar, probar y registrar los casos [DISP].
