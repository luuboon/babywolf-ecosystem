-- Práctica 11 · Fase 4 — Pruebas White Box de la base de datos (DB-01…DB-06).
-- Esquema real del blog (001, 002) en un Postgres local. Cada bloque imprime
-- "== DB-xx" y el resultado observado; el script no oculta ningún error.
\set ON_ERROR_STOP off
\pset pager off
\timing off
\pset footer off
set client_min_messages = warning;

create schema if not exists wb;
create or replace function wb.intentar(q text) returns text language plpgsql as $$
begin execute q; return 'OK';
exception when others then return 'ERROR ' || sqlstate || ' · ' || sqlerrm; end $$;

truncate public.comments, public.posts, public.users restart identity cascade;
insert into public.users(id, supabase_uid, email, username, role) values
  ('00000000-0000-0000-0000-0000000000a1', gen_random_uuid(), 'admin@bw.test', 'admin', 'admin'),
  ('00000000-0000-0000-0000-0000000000b2', gen_random_uuid(), 'lector@bw.test', 'lector', 'user');

\echo
\echo '== DB-01 · Inserción válida'
insert into public.posts(id, author_id, title, slug, content, category, published)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000000a1',
        'Analogue 3D', 'analogue-3d', 'Contenido de prueba', 'retro', true)
returning id, slug, published, created_at is not null as tiene_fecha, updated_at = created_at as fechas_iguales;
select 'publicada por defecto = ' || (select column_default from information_schema.columns
        where table_name='posts' and column_name='published') as valor_por_omision;

\echo
\echo '== DB-02 · Integridad (restricciones)'
select 'NOT NULL title      → ' || wb.intentar($$insert into public.posts(author_id,title,slug,content) values ('00000000-0000-0000-0000-0000000000a1',NULL,'x1','c')$$);
select 'NOT NULL content    → ' || wb.intentar($$insert into public.posts(author_id,title,slug,content) values ('00000000-0000-0000-0000-0000000000a1','t','x2',NULL)$$);
select 'UNIQUE slug         → ' || wb.intentar($$insert into public.posts(author_id,title,slug,content) values ('00000000-0000-0000-0000-0000000000a1','t','analogue-3d','c')$$);
select 'FK author_id        → ' || wb.intentar($$insert into public.posts(author_id,title,slug,content) values (gen_random_uuid(),'t','x3','c')$$);
select 'FK comment.post_id  → ' || wb.intentar($$insert into public.comments(post_id,author_id,content) values (gen_random_uuid(),'00000000-0000-0000-0000-0000000000a1','c')$$);
select 'CHECK role          → ' || wb.intentar($$insert into public.users(supabase_uid,email,username,role) values (gen_random_uuid(),'r@bw.test','r','superadmin')$$);
select 'UNIQUE email        → ' || wb.intentar($$insert into public.users(supabase_uid,email,username) values (gen_random_uuid(),'admin@bw.test','otro')$$);
select 'UNIQUE username     → ' || wb.intentar($$insert into public.users(supabase_uid,email,username) values (gen_random_uuid(),'otro@bw.test','admin')$$);
\echo '-- Lo que la base NO impide (la regla vive sólo en la capa de aplicación):'
select 'título vacío ''''     → ' || wb.intentar($$insert into public.posts(author_id,title,slug,content) values ('00000000-0000-0000-0000-0000000000a1','','vacio-1','')$$);
select 'categoría inventada → ' || wb.intentar($$insert into public.posts(author_id,title,slug,content,category) values ('00000000-0000-0000-0000-0000000000a1','t','cat-x','c','no-existe')$$);
delete from public.posts where slug in ('vacio-1','cat-x');

\echo '-- Transacción: si la segunda sentencia falla, la primera no queda guardada'
begin;
  insert into public.posts(id, author_id, title, slug, content) values ('22222222-2222-2222-2222-222222222222','00000000-0000-0000-0000-0000000000a1','Parcial','parcial','c');
  select wb.intentar($$insert into public.comments(post_id,author_id,content) values (gen_random_uuid(),'00000000-0000-0000-0000-0000000000a1','c')$$) as segundo_insert;
rollback;
select 'post "parcial" tras ROLLBACK: ' || count(*) || ' filas (esperado 0)' from public.posts where slug='parcial';

\echo
\echo '== DB-03 · Consulta'
select 'por id existente    → ' || count(*) || ' fila(s)' from public.posts where id = '11111111-1111-1111-1111-111111111111';
select 'por id inexistente  → ' || count(*) || ' fila(s)' from public.posts where id = gen_random_uuid();
select 'por slug existente  → ' || count(*) || ' fila(s)' from public.posts where slug = 'analogue-3d';
\echo '-- Inyección SQL: el valor viaja como parámetro (como hace GORM con Where("slug = ?", x))'
prepare por_slug(text) as select count(*) from public.posts where slug = $1;
\echo '   parámetro  '' OR ''1''=''1  →'
execute por_slug($q$' OR '1'='1$q$);
\echo '-- Contraste: la MISMA cadena concatenada en el SQL (lo que NO hace el código)'
select count(*) as filas_si_se_concatena from public.posts where slug = '' OR '1'='1';
deallocate por_slug;

\echo
\echo '== DB-04 · Actualización'
\echo '-- Sesión en UTC (como Supabase): el trigger update_modified_column actualiza updated_at'
set time zone 'UTC';
insert into public.posts(id, author_id, title, slug, content) values ('33333333-3333-3333-3333-333333333333','00000000-0000-0000-0000-0000000000a1','Zona UTC','zona-utc','c');
select pg_sleep(0.05);
update public.posts set title = 'Zona UTC (editado)' where id = '33333333-3333-3333-3333-333333333333'
returning title, updated_at > created_at as trigger_actualizo_updated_at;
update public.posts set title = 'x' where id = gen_random_uuid();
select 'update de id inexistente → 0 filas afectadas (el comando no falla)' as resultado;
\echo '-- Sesión en America/Mexico_City: DEFAULT timezone(''utc'', now()) sobre una columna timestamptz'
set time zone 'America/Mexico_City';
insert into public.posts(id, author_id, title, slug, content) values ('44444444-4444-4444-4444-444444444444','00000000-0000-0000-0000-0000000000a1','Zona MX','zona-mx','c');
select round(extract(epoch from (created_at - now()))/3600.0, 1) as horas_de_desfase_de_created_at from public.posts where id='44444444-4444-4444-4444-444444444444';
set time zone 'UTC';
delete from public.posts where id in ('33333333-3333-3333-3333-333333333333','44444444-4444-4444-4444-444444444444');
\echo
\echo '== DB-05 · Eliminación'
insert into public.comments(post_id, author_id, content) values ('11111111-1111-1111-1111-111111111111','00000000-0000-0000-0000-0000000000b2','Gran noticia');
select 'comentarios antes de borrar el post: ' || count(*) from public.comments;
delete from public.posts where id = '11111111-1111-1111-1111-111111111111';
select 'comentarios después (ON DELETE CASCADE): ' || count(*) from public.comments;
select 'post borrado, consulta posterior: ' || count(*) || ' fila(s)' from public.posts where slug='analogue-3d';
delete from public.posts where id = gen_random_uuid();
select 'delete de id inexistente → 0 filas afectadas (no falla)' as resultado;
