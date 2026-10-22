# Práctica 8 — Evaluación de calidad con pruebas de caja negra

**Producto evaluado:** BabyWolf. Es el blog (backend Go en Railway + Supabase)
más la app móvil (`phone_app`), con los módulos de las prácticas 3 a 7.

**Técnicas:**
- Partición de equivalencia (entradas válidas / inválidas).
- Valores límite (longitudes, edades, tiempos).
- Tabla de decisión (permisos por rol).
- Transición de estados (conexión, sesión, reporte).

**Enfoque de caja negra:** cada caso se define sólo por entrada → salida
esperada, sin mirar el código.

Cubre lo que pide la práctica:

| Se recomienda evaluar… | Módulo de BabyWolf |
|---|---|
| Autenticación o control de acceso | AccesoSeguro (P5), sesión del admin y URLs de rol (P7) |
| Formularios de registro | Usuarios (P4), reportes (P7) |
| Consulta, búsqueda o filtrado | VER usuarios, buscar/filtrar reportes, consulta por ID |
| Modificación y eliminación | Usuarios, reportes |
| Reglas de negocio verificables | ID REPnnn sin sobrescritura, acceso perdido directo al admin, cambio de roles |
| Pantallas, módulos o roles | Admin, agente y usuario |
| Persistencia | SQLite local, Postgres (Supabase) |
| Confirmaciones y manejo de errores | SnackBars, mensajes genéricos, cola de pendientes |

---

## 1. Inventario de funcionalidades

| ID | Funcionalidad | Módulo |
|---|---|---|
| F01 | Feed de noticias del blog | Feed |
| F02 | Consulta por URL preasignada | P3 ConsultaWeb |
| F03 | Alta, consulta, modificación y baja de usuarios | P4 |
| F04 | Inicio de sesión simulado seguro | P5 |
| F05 | Intercambio de mensajes A ↔ B | P6 |
| F06 | Entrada a la mesa de ayuda (admin / invitación) | P7 |
| F07 | Gestión de reportes | P7 |
| F08 | Mensajes y archivos entre roles | P7 |
| F09 | Roles, conexión e intercambio de roles | P7 |
| F10 | Lectura del sensor IR del ESP32 | P1 |

## 2–7. Requisitos: entradas, restricciones, salidas, errores y criterio de aceptación

| Req. | Func. | Entrada | Restricción | Salida / cambio de estado esperado | Error a manejar | Criterio de aceptación medible |
|---|---|---|---|---|---|---|
| RQ01 | F01 | Abrir la app | — | Lista de noticias publicadas | Sin red / backend caído | Con red: ≥ 1 noticia en ≤ 15 s. Sin red: mensaje + botón "Reintentar" que **sí** recarga |
| RQ02 | F02 | Botón CONSULTAR | URL firmada, vigencia 5 min | "Consultando..." y luego el resumen | Sin red, URL alterada, URL expirada | Los 3 casos muestran "No fue posible obtener la información." con su causa; la URL alterada da 403 |
| RQ03 | F03 | nombre, edad, profesión, correo | nombre 1–60; edad 15–99; carrera 1–60; correo con formato | Registro con id; aparece en VER usuarios | Campo vacío o fuera de rango | 100 % de los inválidos se rechazan antes de guardar; 3 altas → 3 filas |
| RQ04 | F03 | Modificar o eliminar un usuario | Usuario existente | El cambio se ve al volver a consultar | id inexistente | `actualizar` devuelve 1; tras eliminar, `obtenerPorId` = null |
| RQ05 | F03 | Actualizar desde una base v1 | — | La migración agrega `correo` sin perder registros | — | Los registros previos siguen y su correo queda vacío |
| RQ06 | F04 | usuario, contraseña | usuario 1–30 sin sólo espacios, `[a-zA-Z0-9._-]`; contraseña 8–64 | Acceso simulado sólo con los datos de prueba | Vacíos, largos, espacios, inyección, credencial errónea | Un solo mensaje genérico para credencial errónea; la contraseña nunca aparece en el log |
| RQ07 | F04 | 5 credenciales erróneas seguidas | — | Bloqueo de 30 s | Fuerza bruta | El botón queda deshabilitado 30 s |
| RQ08 | F05 | sala, emisor, texto | sala 3–24 `[A-Z0-9-]`; texto 1–280 | Mensaje con emisor y hora en ambos dispositivos | Vacío, largo, sala inválida | El otro dispositivo lo ve en ≤ 2 s; el vacío se rechaza (422) |
| RQ09 | F05 | Limpiar historial | — | Sala sin mensajes y contadores en 0 | — | Ambos dispositivos ven la lista vacía en ≤ 2 s |
| RQ10 | F06 | Cuenta del blog | Rol `admin` en la BD | Token de mesa | Cuenta sin rol admin | No admin → 403 |
| RQ11 | F06 | URL de invitación | Firmada, ≤ 30 min, un solo uso | Participante con el rol de la URL | Alterada, expirada, reutilizada | 403 / 410 / 409 respectivamente |
| RQ12 | F07 | ID?, equipo, descripción, tipo, prioridad | Equipo 1–80, descripción 1–500; ID `REP` + 3–6 dígitos | Reporte REPnnn activo | Vacíos, ID repetido, ID inexistente | TC01–TC06 de la P7 |
| RQ13 | F07 | Cambio de prioridad o estado | Admin o agente asignado | Se conserva al consultar | Rol sin permiso | Usuario → 403 |
| RQ14 | F07 | Eliminar | Sólo admin real | Baja lógica | Agente o admin temporal | 403 |
| RQ15 | F08 | texto, destinatario, adjunto | Texto ≤ 500; adjunto png/jpg/pdf/txt/log ≤ 5 MB | Mensaje visible según destinatario | Vacío, `.exe`, archivo ajeno | 422 en los tres |
| RQ16 | F09 | Latido cada 10 s | 30 s sin latido = desconectado | Estado de los 4 dispositivos | Pérdida de red | Admin desconectado → agente "cubre al admin"; vuelve a agente al regresar el admin |
| RQ17 | F09 | Monitor en tiempo real | Sólo admin y agente | Recarga automática | Usuario lo intenta | Usuario → 403 |
| RQ18 | F07 | Escritura sin red | — | Operación pendiente + aviso | Pérdida de red | Al volver la red se envía sola y desaparece de pendientes |
| RQ19 | F07 | Cerrar y abrir la app | Sesión ≤ 12 h | Entra directo y ve sus reportes | Token vencido | Token vencido → regresa a la pantalla de entrada |
| RQ20 | F10 | Líneas del ESP32 por SPP | — | Indicador OBJETO / SIN OBJETO | Conexión cortada | Cambio visible ≤ 1 s; aviso al perder la conexión |

## 8. Requisitos que todavía no se pueden verificar

| Req. | Por qué | Qué falta |
|---|---|---|
| RQ20 | Circuito no armado y teléfono físico no disponible; el emulador no tiene Bluetooth | Armar el circuito y probar en el teléfono |
| RQ08 (entre dos teléfonos) | Requiere el dispositivo de otro estudiante | Sesión con el compañero |
| RQ16–RQ19 en la app | Requieren 4 dispositivos y Supabase con `005_soporte.sql` aplicado | Ejecutar el SQL y la sesión de 4 dispositivos |
| Tiempo de respuesta en producción | Railway y Supabase en plan gratuito: el 08/10/2026 el proyecto de Supabase estaba **pausado** y el backend respondía 502 | Medir con el servicio activo; definir un SLA, que el curso no da |
| MFA del admin en la app | La web pide segundo factor; la app entra sólo con contraseña | Decidir si el curso lo exige |

---

## Casos de prueba ejecutados

**Fuente de cada resultado:**
- **[GO]:** `go test` del backend.
- **[E2E]:** escenario contra el backend real + Postgres local (`backend/pruebas/escenario_soporte.py`), 37/37 y TC08 1/1.
- **[FT]:** prueba en `phone_app/test` (ejecutar con `flutter test`).
- **[DISP]:** requiere ejecución manual en dispositivo; queda **Pendiente**.

| Caso | Req. | Técnica | Entrada | Esperado | Resultado |
|---|---|---|---|---|---|
| CP01 | RQ01 | Defecto | "Reintentar" tras un error de red | Recarga la lista | **Defecto encontrado y corregido**: `setState` devolvía un Future y la pantalla no se refrescaba (commit `e53abb3`). Verificación en dispositivo: pendiente [DISP] |
| CP02 | RQ02 | Partición | URL íntegra | 200 + resumen | Pasa [E2E manual con curl] [FT] |
| CP03 | RQ02 | Partición | URL con un parámetro cambiado, agregado, exp alargado, firma alterada o sin firma | 403 | Pasa [GO] (5 variantes) |
| CP04 | RQ02 | Límite | URL usada a los 6 min | 410 | Pasa [GO] |
| CP05 | RQ02 | Partición | Sin red | RF06 | Pasa [FT] |
| CP06 | RQ03 | Límite | edad 14 / 15 / 99 / 100 | rechaza / acepta / acepta / rechaza | 10 → rechaza, 21 → acepta [FT]; límites exactos pendientes [DISP] |
| CP07 | RQ03 | Partición | 3 estudiantes válidos | 3 registros | Pasa [FT] |
| CP08 | RQ04 | Estado | Cambiar la carrera | Persiste | Pasa [FT] |
| CP09 | RQ05 | Estado | Base v1 con 1 registro → app v2 | Registro intacto, correo vacío | Pasa [FT] |
| CP10 | RQ06 | Partición | Usuario `"     "` | "El usuario no puede contener solo espacios" | Pasa [FT] |
| CP11 | RQ06 | Límite | Usuario de 30 / 31 caracteres | acepta / rechaza | Pasa [FT] |
| CP12 | RQ06 | Límite | Contraseña de 7 / 8 / 64 / 65 | rechaza / acepta / acepta / rechaza | 7, 8 y 65 [FT]; 64 pendiente |
| CP13 | RQ06 | Partición | `admin' OR '1'='1` | Rechazo | Pasa [FT] |
| CP14 | RQ06 | Seguridad | Un intento cualquiera | El log no contiene la contraseña | Pasa [FT] |
| CP15 | RQ07 | Estado | 5 fallos, luego a los 31 s | Bloqueo y luego desbloqueo | Pasa [FT] |
| CP16 | RQ08 | Partición | Texto vacío, espacios, 281 caracteres | 422 | Pasa [GO] [FT] |
| CP17 | RQ08 | Partición | Sala `x`, sala `LAB 1` | 422 | Pasa [GO] |
| CP18 | RQ09 | Estado | Limpiar | Sala vacía, contadores en 0 | Pasa [GO] |
| CP19 | RQ10 | Decisión | Cuenta `user` / `admin` | 403 / 200 | Pasa [E2E] |
| CP20 | RQ11 | Partición | URL reutilizada / rol cambiado a admin | 409 / 403 | Pasa [E2E] |
| CP21 | RQ12 | TC01–TC06 | Ver la práctica 7 | — | Pasa [E2E] |
| CP22 | RQ13 | Decisión | Usuario sube prioridad / agente asignado sube prioridad | 403 / 200 | Pasa [E2E] |
| CP23 | RQ14 | Decisión | Eliminar como agente / admin temporal / admin | 403 / 403 / 204 | Pasa [E2E] |
| CP24 | RQ15 | Partición | `.exe`, archivo de otro participante, mensaje vacío | 422 | Pasa [E2E] |
| CP25 | RQ15 | Decisión | Mensaje privado al agente, visto por otro usuario | No lo ve | Pasa [E2E] |
| CP26 | RQ16 | Estado | Admin sale → agente → admin vuelve | admin_temporal → agente | Pasa [E2E] |
| CP27 | RQ16 | Estado | Agente sale → admin asume | Reporte pasa al admin | Pasa [E2E] |
| CP28 | RQ17 | Decisión | Monitor como usuario / agente / admin | 403 / 200 / 200 | Pasa [E2E] |
| CP29 | RQ18 | Estado | Modo avión al guardar un reporte | Pendiente → se envía al volver la red | Pendiente [DISP] |
| CP30 | RQ19 | Estado | Reiniciar el backend y consultar | Persiste | Pasa [E2E] (TC08) · reabrir la app: pendiente [DISP] |
| CP31 | RQ19 | Seguridad | Token alterado / participante expulsado | 401 | Pasa [E2E] |
| CP32 | RQ20 | Partición | `OBJETO DETECTADO` / `SIN OBJETO` / texto desconocido | sensor on / off / sistema | Pasa [FT] · con hardware: pendiente |

## Evaluación

| Pregunta de la práctica | Respuesta con la evidencia actual |
|---|---|
| ¿Las funciones corresponden a los requisitos? | Sí. Cada requisito de las prácticas 1–7 tiene implementación (ver el README de esta carpeta). Las desviaciones están justificadas: Room → SQLite, Kotlin → Dart, Firestore → Supabase |
| ¿Las operaciones principales dan resultados correctos? | En el backend sí: 37/37 [E2E] y todos los [GO]. En la app, pendiente de `flutter test` en el equipo del alumno y de las capturas |
| ¿Se rechazan entradas inválidas? | Sí, en dos capas (app y backend): CP03–CP06, CP10–CP17, CP24 |
| ¿Hay defectos en navegación, formularios o mensajes? | Se encontró y corrigió uno (CP01). No se conocen otros abiertos; falta la revisión visual en dispositivo |
| ¿Los datos conservan su consistencia? | Sí: no se sobrescriben IDs (TC03), baja lógica (TC05), persistencia tras reiniciar (TC08), migración sin pérdida (CP09) e invitación de un solo uso con UPDATE atómico |
| ¿Los permisos se aplican bien? | Sí, y se verifican en el servidor, no sólo en la interfaz: CP19, CP20, CP22, CP23, CP25, CP28, CP31 |
| ¿Responde bien a errores e interrupciones? | Backend: mensajes genéricos sin detalles técnicos y 404/409/422 coherentes. App: pantallas de error y cola de pendientes; CP29 está pendiente |
| ¿Hay defectos que impidan la liberación? | **Riesgo operativo:** si Supabase se pausa, el backend no arranca (502 observado el 08/10/2026). En código no se conocen bloqueantes |
| ¿Las evidencias bastan para aceptar o rechazar? | **Todavía no para la app.** Para el backend sí: la evidencia es reproducible. Para aceptar la entrega faltan los casos [DISP] (CP01, CP29, RQ08 entre teléfonos, RQ16–RQ20 en 4 dispositivos), las capturas y la salida de `flutter analyze` y `flutter test` |

**Veredicto provisional:** backend **aceptado**. App **aceptación
condicionada** a ejecutar los casos [DISP] y registrar sus capturas en esta
tabla.
