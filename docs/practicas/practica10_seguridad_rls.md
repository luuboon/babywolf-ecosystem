# Práctica 10 — Seguridad, autenticación y control de acceso a una base compartida

**En BabyWolf:** las reglas que deciden **qué reportes y comentarios puede
ver o cambiar cada cuenta**. Se ven en el uso normal de la app:
- Cuenta muestra el correo, el **UID** y el rol (Lector / Admin).
- *Mis reportes* de un lector sólo trae los suyos; el admin ve *Reportes de
  lectores* con todos (práctica 9).
- Nadie comenta a nombre de otro ni borra comentarios ajenos (práctica 6).

Las reglas están en el repo `babywolf-blog`: `backend/sql/006_incidencias_rls.sql`
(dueño de cada reporte) y `007_app_lectores.sql` (admin, versión y comentarios).

La interfaz normal no ofrece acciones prohibidas, como leer el reporte de
otro por su ID. Para la evidencia hace falta intentarlas a propósito, así que
en compilaciones de **depuración** Cuenta muestra *Verificación de reglas
(depuración)* (`lib/verificacion/`), que hace los intentos SEG-04…SEG-10. En
una compilación release esa opción no existe.

## Firebase → Supabase

El enunciado está escrito para Firebase. BabyWolf usa Supabase, que tiene una
pieza equivalente para cada una:

| Firebase (enunciado) | Supabase (BabyWolf) |
|---|---|
| Firebase Authentication, proveedor correo/contraseña | Supabase Auth, proveedor *Email* (el mismo que usa el blog) |
| UID del usuario | `auth.users.id`; llega en el JWT como `sub` |
| Colección `incidencias` en Firestore | Tabla `public.incidencias` en Postgres |
| Campo `creadoPor` | Columna `creado_por` |
| Reglas de seguridad de Firestore | Políticas de **Row Level Security** (RLS) de Postgres |
| SDK de Firestore en la app | API REST de Supabase con el JWT del usuario |

Lo importante se cumple igual: la app habla **directo con la base** y la base
decide. La app no filtra ni oculta nada por su cuenta; si una operación no
está permitida, Postgres la rechaza aunque alguien modifique la app.

## Fase 1 — Autenticación

- El proveedor *Email* de Supabase Auth ya está activo (el blog lo usa para
  iniciar sesión).
- Cuentas de prueba: desde la app (Cuenta → *¿No tienes cuenta? Crear una*)
  o en Supabase → Authentication → Users → *Add user*.
- Al iniciar sesión, Cuenta muestra el **correo, el UID y el rol**, con botón
  para copiar el UID. El UID viene de Supabase Auth (claim `sub` del JWT) y el
  rol de la tabla `users` del blog, la misma que usa la web.
- La sesión (práctica 5) guarda sólo el refresh token, cifrado.

## Fase 2 — Registros con propietario

- Al reportar una noticia, la app **no manda** `creado_por`: la columna toma
  `auth.uid()` del token. Así la app no puede, ni por error, crear un reporte
  a nombre de otro.
- La pantalla de verificación sí lo manda explícito, para probar SEG-04.
- Para verificar los propietarios, en el SQL Editor de Supabase (como
  administrador, que no está sujeto a RLS):

```sql
select i.id, i.titulo, i.estado, u.email as propietario, i.creado_por
from public.incidencias i join auth.users u on u.id = i.creado_por
order by i.created_at;
```

## Fase 3 — Reglas de seguridad y qué significa cada condición

```sql
REVOKE ALL ON public.incidencias FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.incidencias TO authenticated;
ALTER TABLE public.incidencias ENABLE ROW LEVEL SECURITY;

CREATE POLICY incidencias_leer_propias   ON public.incidencias FOR SELECT TO authenticated
  USING (creado_por = (select auth.uid()));
CREATE POLICY incidencias_crear_propias  ON public.incidencias FOR INSERT TO authenticated
  WITH CHECK (creado_por = (select auth.uid()));
CREATE POLICY incidencias_editar_propias ON public.incidencias FOR UPDATE TO authenticated
  USING (creado_por = (select auth.uid())) WITH CHECK (creado_por = (select auth.uid()));
CREATE POLICY incidencias_borrar_propias ON public.incidencias FOR DELETE TO authenticated
  USING (creado_por = (select auth.uid()));
```

| Pieza | Qué hace | Casos |
|---|---|---|
| `REVOKE ALL … FROM anon` | Sin sesión no hay ningún permiso sobre la tabla: la base responde *permission denied* | SEG-10 |
| `TO authenticated` | Las reglas sólo aplican a quien trae un JWT válido de Supabase Auth | SEG-01 |
| `auth.uid()` | El UID sale del JWT firmado, no de lo que mande la app; no se puede falsificar | Todos |
| `USING (creado_por = auth.uid())` | Filtra qué filas **existen** para el usuario al leer, cambiar o borrar. Las ajenas no se ven ni se tocan | SEG-05, SEG-06, SEG-07 |
| `WITH CHECK (creado_por = auth.uid())` en INSERT | La fila nueva debe ser del usuario: no se puede crear a nombre de otro | SEG-03, SEG-04 |
| `WITH CHECK` en UPDATE | La fila *después* del cambio también debe ser del usuario: no se puede regalar una incidencia | SEG-08, SEG-09 |
| `(select auth.uid())` | Se calcula una vez por consulta y no por fila (recomendación de rendimiento de Supabase) | — |

### Reglas que agrega `007_app_lectores.sql`

Las de 006 se quedan igual. Las nuevas se **suman** (en Postgres, las
políticas permisivas se combinan con OR):

| Pieza | Qué hace | Casos ([BD] `app_lectores.sh`) |
|---|---|---|
| `es_admin()` (SECURITY DEFINER, `search_path` fijo) | Dice si el UID del token tiene rol `admin` en la tabla `users` del blog | — |
| `incidencias_admin_leer` / `incidencias_admin_atender` | El admin lee y actualiza todos los reportes | ADM-01, DB-03, DB-06 |
| Trigger `incidencias_versionar` | Sube la versión, anota quién cambió y **impide que el admin cambie el dueño** de un reporte | DB-07, ADM-02 |
| Sin regla de DELETE para el admin | El admin cierra reportes; no borra los de los lectores | ADM-03 |
| `comments`: leer público, crear con `author_id = auth.uid()`, editar el propio, borrar el propio o el admin | Comentarios de la práctica 6 | COM-01…COM-08 |
| `CHECK` de longitud y de prioridad | La base rechaza comentarios vacíos o > 280 y prioridades fuera del catálogo | COM-05, COM-06, DB-RN |

## Fase 4 — Pruebas con dos dispositivos

Para esta fase, A y B deben ser **cuentas de lector**: una cuenta admin ve
todos los reportes por diseño, así que SEG-05 no aplicaría.

1. Dispositivo A inicia sesión con el usuario A; dispositivo B con el usuario B.
2. A reporta dos noticias y B reporta una (bandera en el detalle). Las tres
   deben verse sólo en *Mis reportes* de su dueño.
3. Abrir en ambos Cuenta → *Verificación de reglas (depuración)* (aparece al
   ejecutar desde Android Studio en modo debug).
4. En B, copiar su **UID** y el **ID** de su incidencia (botones de copiar).
   Pegarlos en A, en "Fase 4 · Intentos no autorizados". Entre emuladores, el
   portapapeles se comparte con la Mac.
5. En A, pulsar cada botón SEG-04 a SEG-10. Cada intento queda en la bitácora
   con el resultado esperado, el obtenido y si **PASA**.
6. Cerrar sesión y pulsar "Intentar sin sesión" (SEG-10).
7. "Copiar bitácora" deja la matriz lista para pegar en el reporte.

**Cómo contesta la base:**
- Escribir una fila que viola una regla (SEG-04, SEG-09) o actuar sin sesión
  (SEG-10) devuelve error **42501**.
### Reglas que agrega `008_permisos_usuarios.sql` (tabla `users` y bitácora)

**Estado: aplicado en Supabase el 06/11/2026.** Resumen vivo del tema, con
lo pendiente y las reglas para cambios futuros: [`../SEGURIDAD_CUENTAS.md`](../SEGURIDAD_CUENTAS.md).

Al revisar el proyecto real de Supabase (06/11/2026) se encontró que la
seguridad de los reportes dependía de una tabla mal protegida: `es_admin()`
lee el rol de `public.users`, y **cualquier usuario podía ponerse
`role = 'admin'` editando su propia fila** (la regla "Users can update own
profile" no limitaba columnas y `authenticated` tenía UPDATE sobre todas).

| Pieza | Qué hace | Casos ([BD] `usuarios_permisos.sh`) |
|---|---|---|
| Permiso por columna: `UPDATE (username, avatar_url)` | El usuario sólo cambia su nombre y avatar (lo único que edita la web) | U-01…U-06 |
| Trigger `users_proteger_columnas` | Segunda barrera: aunque se vuelva a dar permiso de más, un cliente no cambia rol, estado, correo ni bloqueos | U-25 |
| `anon` sólo lee `id, username, email, avatar_url` | Sin sesión ya no se ven rol, estado ni intentos fallidos | U-08, U-09 |
| `record_successful_login`, `record_logout`, `record_password_change` exigen `auth.uid() = p_user_id` | Antes, sin sesión y con el id de otra cuenta, se reiniciaba su contador de intentos (anulaba el bloqueo por fuerza bruta) | U-14…U-19 |
| `audit_log` sin INSERT para clientes; `record_admin_action` sin EXECUTE | Nadie escribe registros falsos en la bitácora | U-20, U-21 |
| `search_path` fijo en todas las funciones SECURITY DEFINER | Evita que se suplante una tabla con otra del mismo nombre | — |

El backend (Railway) entra como `postgres`, dueño de las tablas, y no se ve
afectado: el admin sigue creando usuarios y cambiando roles (U-07). El
registro de cuentas sigue funcionando (U-24, probado también con un rol sin
privilegios como el que usa Supabase Auth).

- Leer, cambiar o borrar algo ajeno (SEG-05, SEG-06, SEG-07) devuelve **0
  filas**: para RLS esas filas no existen para ese usuario. La app lo registra
  como rechazo.

## Fase 5 — Matriz de pruebas de seguridad

**De dónde salen los resultados:**
- **[BD]:** `backend/pruebas/rls_incidencias.sh` ejecuta cada operación con los
  roles de Supabase (`authenticated` con el JWT del usuario, y `anon`) sobre
  las mismas reglas, en Postgres 16. Se corrió el 29/10/2026 con resultado
  **9/9**, y otra vez el 06/11/2026 con `007_app_lectores.sql` aplicado
  encima: sigue **9/9** (las reglas nuevas no abren ningún hueco).
- **[APP]:** falta ejecutarlo en los dos dispositivos con capturas.

| ID | Acción | Esperado | Resultado | Evidencia |
|---|---|---|---|---|
| SEG-01 | Ingresar con la cuenta de A | Autenticación exitosa | Pendiente [APP] | Captura con correo y UID de A, y otra de B (UID distinto) |
| SEG-02 | Contraseña incorrecta | Acceso rechazado | Pendiente [APP] | Mensaje genérico "Correo o contraseña incorrectos." |
| SEG-03 | A registra una incidencia con su UID | Creada con propietario A | **Pasa** [BD] · [APP] pendiente | `creado_por` = UID de A; consulta de la Fase 2 |
| SEG-04 | A crea indicando el UID de B | Rechazada por la base | **Pasa** [BD]: `new row violates row-level security policy` | Bitácora de A |
| SEG-05 | A lee la incidencia de B por su ID | Lectura denegada | **Pasa** [BD]: 0 filas visibles | Bitácora de A |
| SEG-06 | A modifica la incidencia de B | Actualización denegada | **Pasa** [BD]: 0 filas cambiadas, B sigue `abierta` | Bitácora de A + estado en B |
| SEG-07 | A elimina la incidencia de B | Eliminación denegada | **Pasa** [BD]: 0 filas borradas, B sigue existiendo | Bitácora de A + lista de B |
| SEG-08 | A cambia el estado de su incidencia | Permitida | **Pasa** [BD]: `en_proceso` | Bitácora de A |
| SEG-09 | A cambia el propietario de su incidencia a B | Rechazado | **Pasa** [BD]: `new row violates row-level security policy`; sigue siendo de A | Bitácora de A |
| SEG-10 | Sin sesión: leer y escribir | Rechazado | **Pasa** [BD]: `permission denied for table incidencias` (las dos) | Bitácora sin sesión |

Caso extra [BD]: B consulta todas las incidencias y sólo recibe la suya (1 de 3).

Casos de 007 [BD] (06/11/2026, `app_lectores.sh` 20/20), los de seguridad:

| ID | Acción | Esperado | Resultado |
|---|---|---|---|
| SEG-05b | Un lector consulta todos los reportes | Sólo los suyos | **Pasa** |
| SEG-06b | Un lector cambia el reporte de otro | 0 filas | **Pasa** |
| ADM-01 | El admin consulta todos los reportes | Ve los de todos | **Pasa** |
| ADM-02 | El admin cambia el dueño de un reporte | Rechazado | **Pasa**: "El dueño de un reporte no se puede cambiar" |
| ADM-03 | El admin borra un reporte ajeno | 0 filas | **Pasa** |
| COM-03 | Comentar sin sesión | Rechazado | **Pasa** |
| COM-04 | Comentar a nombre de otro | Rechazado por RLS | **Pasa** |
| COM-07 | Borrar el comentario de otro | 0 filas | **Pasa** |

Casos de 008 [BD] (06/11/2026, `usuarios_permisos.sh`: antes del arreglo
10/23, con el arreglo **25/25**; `app_lectores.sh` sigue 20/20 y
`rls_incidencias.sh` 9/9):

| ID | Acción | Antes de 008 | Con 008 |
|---|---|---|---|
| U-01 | Un lector se pone `role = 'admin'` | **Lo logró** | Rechazado: *permission denied* |
| U-04 | Un lector edita su nombre y avatar | Permitido | Permitido |
| U-08 | Sin sesión: leer rol y bloqueos | **Los leía** | Rechazado |
| U-14 | Sin sesión: desbloquear la cuenta de otro | **Lo logró** | Rechazado |
| U-20 | Sin sesión: escribir en la bitácora | **Lo logró** | Rechazado |
| U-22 | Un lector lee la bitácora | **La leía** (tras hacerse admin) | 0 filas |
| U-25 | Con permiso de más por error, hacerse admin | — | Rechazado por el trigger |

---

## Reporte técnico

**Objetivo.** Que cada usuario sólo pueda operar sobre sus propias incidencias,
y que la base de datos lo garantice aunque la app sea alterada.

**Defectos encontrados**

1. **Tabla sin reglas.** Con la tabla creada pero sin RLS (control negativo
   del script), 7 de 9 casos fallaron: A leyó, cerró y borró la incidencia de
   B, se crearon registros a nombre de otro, y sin sesión se leían todos los
   datos. Es el estado en el que queda cualquier tabla nueva hasta que se
   activa RLS.
2. **Sin sesión daba "vacío" y no error.** Con RLS pero sin quitar permisos al
   rol `anon`, una lectura sin sesión devolvía una lista vacía. Eso parece
   correcto en la interfaz, pero no demuestra el rechazo que pide SEG-10.
3. **Los rechazos de UPDATE y DELETE son silenciosos.** Postgres no da error al
   tocar filas ajenas: responde 0 filas, porque para ese usuario no existen.
   Una app que sólo revise el código HTTP mostraría "éxito".

**Correcciones**

1. `ENABLE ROW LEVEL SECURITY` con una política por operación, todas sobre
   `creado_por = auth.uid()`. El UPDATE lleva `USING` y `WITH CHECK` para
   impedir también el cambio de propietario.
2. `REVOKE ALL … FROM anon`: sin sesión la base responde *permission denied*.
3. La app pide `Prefer: return=representation` y cuenta las filas afectadas.
   0 filas se registra como **rechazado**, no como éxito.
4. Se repitieron las pruebas fallidas: **9/9** con las reglas aplicadas.

**Defecto encontrado después, en el proyecto real (008)**

5. **Escalada a admin.** La tabla `users` del blog dejaba que cada usuario
   editara cualquier columna de su fila, incluido `role`. Como las reglas
   de admin (007) y la web leen ese rol, un lector podía hacerse admin con
   una sola petición. También se podía reiniciar el contador de intentos de
   otra cuenta y escribir en la bitácora sin sesión. Se corrigió con
   permisos por columna, un trigger de respaldo y funciones que exigen que
   el `auth.uid()` sea el de la cuenta (ver la tabla de 008).

**Riesgos pendientes**

- La llave `anon` va dentro de la app y es pública por diseño. La seguridad no
  depende de ocultarla, sino de RLS. En cambio, la `service_role` que usa el
  backend en Railway **salta RLS**: si se filtrara, las reglas no protegerían
  nada.
- Las cuentas de prueba deben borrarse o tener contraseñas fuertes al terminar
  la práctica.
- ~~El JWT dura 1 hora y la app no lo renueva.~~ **Corregido:** la sesión de
  la app renueva el token antes de que venza y guarda sólo el refresh token,
  cifrado (práctica 5).
- **Correos visibles:** con 008, sin sesión ya no se leen rol ni bloqueos,
  pero sí el **correo** de los autores, y con sesión cualquier lector sigue
  leyendo todas las columnas de todas las cuentas. La web pide
  `users(email, username)` en las noticias y muestra el correo si el autor
  no tiene nombre, y el panel de admin y el perfil leen `select *`. Cerrarlo
  requiere primero cambiar esas consultas de la web; si se cierra antes, el
  blog deja de mostrar noticias.
- `record_failed_login` sigue abierta sin sesión (la usa la web antes de
  entrar). Con ella cualquiera puede bloquear 15 minutos una cuenta ajena si
  conoce su correo. Es el costo del bloqueo por correo; se mitigaría
  bloqueando por correo + IP.
- Los scripts `seed.js` / `seed.mjs` de la web hacían admin a un usuario con
  la llave pública (justo el hueco cerrado). Ya no funcionan: los admins se
  crean desde el panel (backend).
- La app entra sólo con contraseña. Si la cuenta tiene segundo factor en la
  web, la app no lo pide.
- Supabase en plan gratuito se pausa por inactividad (ya ocurrió dos veces). Es
  un riesgo de disponibilidad, no de seguridad.

**Conclusión.** Las reglas impiden en el servidor todas las operaciones no
autorizadas de la matriz, y el control negativo demuestra que sin ellas esas
operaciones sí ocurrían. Falta la ejecución en los dos dispositivos para
completar las evidencias [APP] de SEG-01, SEG-02 y las capturas.
