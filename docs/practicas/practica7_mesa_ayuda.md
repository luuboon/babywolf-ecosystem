# Práctica 7 — Asignación de roles e interacción: Mesa de ayuda BabyWolf

App → 🧪 → *Mesa de ayuda*. Código en `phone_app/lib/laboratorio/p7_soporte/`.
El backend vive en el repo `babywolf-blog`:
- `controllers/soporte_controller.go`
- `application/soporte/reglas.go`
- `sql/005_soporte.sql`

## Roles y cómo se asignan (URLs preasignadas)

| Rol | Cómo entra | Qué puede hacer |
|---|---|---|
| Administrador | Con su cuenta del blog BabyWolf (Supabase). El backend comprueba en la BD que su rol sea `admin` | Todo: invitar, asignar, cambiar prioridad y estado, eliminar, expulsar, borrar el historial, ver todos los mensajes |
| Agente de atención | Con una **URL preasignada** que genera el admin | Ver y atender los reportes asignados a él o sin asignar; cambiar su prioridad y estado |
| Usuario (×2) | Con una URL preasignada | Crear reportes y ver sólo los suyos; mandar mensajes |

La URL de invitación trae el rol y el nombre **firmados con HMAC**. Vale 30
minutos y se usa una sola vez. Cambiar `rol=agente` por `rol=admin` invalida
la firma (403).

### Casos del proyecto

Los tipos de reporte son los que pide la práctica:
- **Reporte de falla:** un equipo o servicio no funciona.
- **Proceso de atención:** seguimiento de una solicitud.
- **Acceso perdido:** va **directo al administrador**; el agente no lo ve.

### Intercambio de roles

| Situación | Regla (verificable) |
|---|---|
| El admin se desconecta (30 s sin latido, o "Conectado" apagado) | El agente pasa a **"Agente (cubre al admin)"**: puede invitar y asignar, pero **no eliminar** |
| El admin vuelve | El agente regresa a su rol |
| El agente se desconecta | El admin usa "Asumir reportes de agentes desconectados" y los reportes pasan a él |
| Solicitud directa al admin | Tipo "acceso perdido" o mensaje privado al admin |

### Mensajes y archivos

- Selector **Para:** Todos o un dispositivo (mensaje privado, con borde ámbar).
- **Adjuntos:**
  - Imagen de la galería o una bitácora `.txt` generada en el teléfono.
  - Se suben al bucket **privado** `soporte_archivos` con una URL preasignada de Supabase Storage.
  - Se abren con otra URL preasignada de lectura (5 min), y sólo si el mensaje es visible para quien la pide.
- Cada mensaje lleva **hora de envío**; arriba hay **contador por dispositivo**
  y botón **limpiar historial**:
  - El admin lo borra para todos.
  - Los demás lo ocultan sólo en su teléfono.
- **Notificación visual:** SnackBar al enviar y al recibir.

### Tiempo real sólo para admin y agente

- Admin y agente consultan `/api/soporte/monitor` cada 3 s y recargan si algo cambió.
- Para un usuario, el backend responde **403** a `/monitor` y la app muestra
  "Vista de usuario: sin actualización en tiempo real".

## Firestore → Supabase

El enunciado menciona Firestore. BabyWolf ya usa **Supabase (Postgres)**
detrás del backend Go en Railway, así que la persistencia de TC08 se cumple
sobre Postgres. Las 4 tablas nuevas (`soporte_*`) tienen RLS activo sin
políticas: sólo el backend puede leerlas. **No se tocó ninguna tabla del blog**
y la web sigue igual.

## Puesta en marcha

1. Supabase → SQL Editor → ejecutar `backend/sql/005_soporte.sql` (una vez).
2. Railway despliega el backend. Usa las variables que ya tiene
   (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `JWT_SECRET`,
   `DATABASE_URL`). `PRESIGN_SECRET` es opcional.
3. Teléfono 1: Mesa de ayuda → "Administrador" → cuenta admin del blog.
4. Dispositivos → INVITAR AGENTE / INVITAR USUARIO → copiar la URL y enviarla
   a cada teléfono.
5. Teléfonos 2–4: "Unirme con invitación" → pegar → VERIFICAR URL → UNIRME.

## Matriz de pruebas

**Cómo se ejecutó:**
- Contra el backend real compilado y un **Postgres 16 local** con `005_soporte.sql` aplicado.
- Storage de Supabase simulado (`backend/pruebas/escenario_soporte.py`).
- Fecha: 22/10/2026.
- **Falta:** ejecutarla en los 4 teléfonos con Supabase real y adjuntar capturas.

| ID | Acción | Esperado | Resultado (backend) | Observaciones |
|---|---|---|---|---|
| TC01 | Registrar un reporte con todos los campos | Se guarda y se puede consultar | **Pasa** — 201 y luego 200 | |
| TC02 | Guardar sin equipo ni descripción | Se rechaza con validación | **Pasa** — 422 con `equipo` y `descripcion` | La app valida antes de enviar |
| TC03 | Guardar dos veces REP001 | No sobrescribe, o aplica una política explícita | **Pasa** — 409 "Ya existe… No se sobrescribió"; el original queda intacto | Política: nunca sobrescribir. Tampoco se reutiliza el ID de un reporte eliminado |
| TC04 | Cambiar prioridad de Media a Alta | El cambio se conserva al volver a consultar | **Pasa** — el agente asignado la cambia y la consulta devuelve Alta | El usuario recibe 403 al intentarlo |
| TC05 | Eliminar un reporte y consultarlo | Ya no aparece como registro activo | **Pasa** — 204, luego 404 y fuera de la lista | Baja lógica (`activo = false`) |
| TC06 | Consultar REP999 | Maneja el resultado vacío sin bloquearse | **Pasa** — 404 "No existe un reporte activo con el ID REP999." | En la app: SnackBar, la pantalla sigue usable |
| TC07 | Quitar la red durante una escritura | Informa el estado y sincroniza o maneja el error | Implementado en la app: la operación queda **pendiente** (banda ámbar) y se reenvía sola al volver la red | Sólo se puede probar en el dispositivo (modo avión); captura pendiente |
| TC08 | Cerrar y abrir la app; consultar un reporte | El dato persiste y vuelve a mostrarse | **Pasa** — tras reiniciar el backend, REP001 sigue con prioridad Alta | En la app, la sesión se guarda en SQLite y se entra directo |

Reglas de roles comprobadas en el mismo escenario: **29 reglas, P7-R01 a
P7-R29** (37 verificaciones en total con las de TC01–TC06). Detalle en
`backend/pruebas/escenario_soporte.py`. Por ejemplo:
- Invitación reutilizada → 409.
- Rol alterado en la URL → 403.
- Un usuario no ve reportes ajenos.
- El monitor da 403 a usuarios.
- El admin temporal no puede eliminar.
- Un usuario expulsado ya no puede usar su token.
