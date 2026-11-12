-- Práctica 12 · RES-07 en la BD: una escritura reintentada con el MISMO id generado por el cliente no duplica.
-- Esquema real de comments (001_initial_schema.sql). Se ejecuta en un Postgres desechable.
\set ON_ERROR_STOP off
\pset pager off
\echo == 1. Primer envío (el servidor guarda, la respuesta "se pierde")
insert into public.comments(id, post_id, author_id, content)
select 'aaaaaaaa-0000-4000-8000-000000000001', (select id from public.posts limit 1), '00000000-0000-0000-0000-0000000000a1', 'Hola desde el teléfono';
\echo == 2. Reintento con el MISMO id (lo que hace ComentariosApi.publicar): debe fallar con 23505 y NO insertar
\set VERBOSITY verbose
insert into public.comments(id, post_id, author_id, content)
select 'aaaaaaaa-0000-4000-8000-000000000001', (select id from public.posts limit 1), '00000000-0000-0000-0000-0000000000a1', 'Hola desde el teléfono';
\set VERBOSITY default
\echo == 3. Filas con ese id (esperado 1)
select count(*) as filas from public.comments where id='aaaaaaaa-0000-4000-8000-000000000001';
\echo == 4. Contraste: SIN id del cliente, el reintento ingenuo crea un duplicado (comportamiento previo a la Práctica 12)
insert into public.comments(post_id, author_id, content) select (select id from public.posts limit 1), '00000000-0000-0000-0000-0000000000a1', 'Sin clave de idempotencia';
insert into public.comments(post_id, author_id, content) select (select id from public.posts limit 1), '00000000-0000-0000-0000-0000000000a1', 'Sin clave de idempotencia';
select count(*) as filas_duplicadas from public.comments where content='Sin clave de idempotencia';
