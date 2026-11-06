# Seguridad de cuentas y datos de BabyWolf: qué está protegido, dónde y qué falta

Complementa a [`SEGURIDAD.md`](SEGURIDAD.md) (PWA de TV, hub y privacidad de la
entrega de agosto).

Documento vivo. Si cambias una regla de la base, una consulta de la web o
algo de la cuenta, actualiza este archivo.

## Quién decide qué (todo en Supabase, no en la app)

La app y la web llevan la llave pública `anon`, que cualquiera puede ver. La
protección no está en ocultarla sino en las reglas de la base (RLS y permisos
por columna). La llave `service_role` y `DATABASE_URL` viven sólo en el
backend (Railway) y **se saltan** las reglas: nunca van en la app ni en Git.

| Dato | Sin sesión | Lector con sesión | Admin |
|---|---|---|---|
| Noticias publicadas | Lee | Lee | Lee, edita |
| Comentarios aprobados | Lee | Lee, crea, edita y borra los suyos | Además borra cualquiera |
| Perfil (`users`): id, nombre, correo, avatar | Lee | Lee todos | Lee todos |
| Perfil: rol, estado, intentos y bloqueo | **No** | Lee (ver "Pendiente") | Lee |
| Perfil: cambiar nombre y avatar | No | **Sólo los propios** | Sólo los propios |
| Perfil: cambiar rol, estado, correo | No | **No** | Por el backend, no por la API pública |
| Reportes de noticias (`incidencias`) | No | Sólo los suyos | Todos; atiende, no borra ni reasigna |
| Bitácora (`audit_log`) | No | No | Lee; escribe el backend y las funciones |

## Scripts de la base: orden y estado

Se ejecutan una vez, en el SQL Editor de Supabase, y son repetibles.

| Script (repo `babywolf-blog/backend/sql`) | Qué hace | Aplicado en producción |
|---|---|---|
| `001` a `004` | Esquema, categorías, almacenamiento, auditoría y bloqueo por intentos | Sí |
| `005_soporte.sql` | Mesa de ayuda | Según la práctica 7 |
| `006_incidencias_rls.sql` | Reportes con dueño y reglas RLS | Sí |
| `007_app_lectores.sql` | Reportes con prioridad y versión, el admin los atiende, comentarios con reglas | **Sí, 06/11/2026** |
| `008_permisos_usuarios.sql` | Cierra la escalada a admin y protege bitácora y bloqueo | **Sí, 06/11/2026** |

## Lo que se encontró el 06/11/2026 (y ya está corregido)

Al revisar el proyecto real, la tabla `users` dejaba que **cualquier usuario
con sesión se pusiera `role = 'admin'`** con una sola petición, porque la
regla de actualización no limitaba columnas. Como el admin de la web, el
panel de usuarios y las reglas de reportes leen ese rol, esa cuenta
controlaba todo. También se podía, sin sesión, leer rol y bloqueos de todas
las cuentas, reiniciar el contador de intentos de otra cuenta y escribir en la
bitácora. El arreglo es `008`. Detalle y pruebas:
[`practicas/practica10_seguridad_rls.md`](practicas/practica10_seguridad_rls.md).

Verificado ese día: pruebas en base local `usuarios_permisos.sh` 25/25
(antes 10/23), y contra el proyecto real con la llave pública: rol, bloqueos y
bitácora responden *permission denied*, y los posts siguen mostrando su autor.

## Pendiente (cada punto explica por qué no se hizo ya)

1. **Correos y datos de cuenta legibles.** Sin sesión se ve el correo de los
   autores; con sesión, un lector lee todas las columnas de todas las
   cuentas. La web depende de eso (`users(email, username)` en las noticias,
   panel de admin, perfil con `select *`). Hay que cambiar esas consultas
   antes de cerrarlo, o el blog deja de mostrar noticias.
2. **Bloqueo de cuentas ajenas.** `record_failed_login` es pública porque se
   usa antes de entrar: quien conozca un correo puede bloquear esa cuenta 15
   minutos. Se mitiga bloqueando por correo y por IP.
3. **Segundo factor.** Si la cuenta lo tiene en la web, la app sólo pide
   contraseña.
4. **Sin cola offline para reportes.** Sin red no se guarda nada (a propósito).
5. **Supabase gratuito se pausa** por inactividad: ningún dispositivo lee ni
   escribe hasta reactivar el proyecto.
6. **Los scripts `seed.js` y `seed.mjs` de la web ya no hacen admin a nadie**
   (usaban el hueco cerrado). Los admins se crean desde el panel del backend.
7. Evidencias con dos dispositivos (capturas) de las prácticas 9 y 10.
8. **Aviso de privacidad y plan de retención** (`SEGURIDAD.md`, secciones 3 y 4)
   dicen que no se recaban datos del usuario final: ya no es cierto para la
   app del teléfono (correo, usuario, comentarios, reportes). Hay que
   actualizarlos: qué se guarda, dónde (Supabase y SQLite del teléfono), cuánto
   y cómo pedir que se borre.

## Reglas para cambios futuros

- Una tabla nueva en `public` **sin RLS queda abierta** a la llave pública:
  activa RLS y da permisos sólo a quien los necesite.
- Una política de UPDATE sin permisos por columna deja editar toda la fila.
  Para tablas con columnas de seguridad (rol, estado, dueño) usa
  `GRANT UPDATE (columnas)` y un trigger de respaldo.
- Toda función `SECURITY DEFINER` lleva `SET search_path` fijo y, si actúa
  sobre una cuenta, comprueba `auth.uid()`. Postgres da EXECUTE a todos por
  omisión: quítalo con `REVOKE ... FROM PUBLIC, anon`.
- Cada regla nueva se prueba con un script en `babywolf-blog/backend/pruebas/`
  contra Postgres con los roles de Supabase, y se corre **antes** de aplicarla
  para ver que reproduce el hueco.
- Contraseñas y tokens: nunca en la app ni en Git. La sesión de la app guarda
  sólo el refresh token, en el almacenamiento cifrado del sistema.

## Cómo verificar el estado actual (sin tocar datos)

Con la llave pública, sin sesión, estas consultas deben dar *permission
denied* (401): `users?select=role`, `users?select=locked_until`,
`POST audit_log` y `rpc/record_successful_login`. En cambio deben seguir
dando 200: `users?select=id,username,avatar_url` y
`posts?select=title,users(email,username)`.
