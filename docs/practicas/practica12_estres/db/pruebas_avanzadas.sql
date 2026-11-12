-- Práctica 12 · Fase 4 — Pruebas avanzadas de base de datos.
-- Uso: psql -d bw_sql -v fase=antes|despues -f pruebas_avanzadas.sql
-- Cada consulta se ejecuta 30 veces (tras 3 de calentamiento) y se reporta
-- promedio, mínimo, máximo, filas recuperadas y el nodo principal del plan.
\set ON_ERROR_STOP on
\pset pager off
\pset footer off
set client_min_messages = warning;
create schema if not exists p12;
create or replace function p12.medir(nombre text, q text, n int default 30)
returns table(consulta text, filas bigint, prom_ms numeric, min_ms numeric, max_ms numeric) language plpgsql as $$
declare t0 timestamptz; ms numeric; mn numeric := 1e9; mx numeric := 0; tot numeric := 0; f bigint;
begin
  for i in 1..3 loop execute q; end loop;
  for i in 1..n loop
    t0 := clock_timestamp(); execute q; get diagnostics f = row_count;
    ms := extract(epoch from clock_timestamp() - t0) * 1000;
    tot := tot + ms; mn := least(mn, ms); mx := greatest(mx, ms);
  end loop;
  return query select nombre, f, round(tot / n, 3), round(mn, 3), round(mx, 3);
end $$;

select 'FASE: ' || :'fase' as fase, (select count(*) from public.posts) as posts_total,
       (select count(*) from public.posts where published) as publicados,
       exists(select 1 from pg_indexes where indexname = 'idx_posts_publicados_recientes') as indice_009;
select id as id_prueba from public.posts where slug = 'noticia-2500' \gset
vacuum analyze public.posts;

\echo
\echo '== Tiempos por consulta (30 ejecuciones, ms)'
select * from p12.medir('1 por id (PK)',                     format($$select * from public.posts where id = %L$$, :'id_prueba'));
select * from p12.medir('1b por slug (idx_posts_slug)',      $$select * from public.posts where slug = 'noticia-2500'$$);
select * from p12.medir('2 pequeño: 10 más recientes',       $$select * from public.posts where published order by created_at desc limit 10$$);
select * from p12.medir('2b pequeño: 50 más recientes',      $$select * from public.posts where published order by created_at desc, id limit 50$$);
select * from p12.medir('3 grande: todos los publicados',    $$select * from public.posts where published order by created_at desc$$, 10);
select * from p12.medir('3b grande: sólo campos de lista',   $$select id, title, slug, category, created_at from public.posts where published order by created_at desc$$, 10);
select * from p12.medir('4 filtro: categoría retro (20)',    $$select * from public.posts where published and category = 'retro' order by created_at desc limit 20$$);
select * from p12.medir('4b filtro: categoría retro (todos)',$$select * from public.posts where published and category = 'retro' order by created_at desc$$, 10);
select * from p12.medir('5 conteo de publicados',            $$select count(*) from public.posts where published$$);

\echo
\echo '== Plan: lectura que hacía la API (todos los publicados)'
explain (analyze, buffers, costs off) select * from public.posts where published order by created_at desc;
\echo '== Plan: primera página (limit 50) — lo que hace la API optimizada'
explain (analyze, buffers, costs off) select * from public.posts where published order by created_at desc, id limit 50;
\echo '== Plan: filtro por categoría'
explain (analyze, buffers, costs off) select * from public.posts where published and category = 'retro' order by created_at desc limit 20;
\echo '== Tamaño transferido (bytes de contenido) por consulta'
select 'todos los publicados' as consulta, pg_size_pretty(sum(pg_column_size(p.*))) as tamano_filas, count(*) from public.posts p where published
union all select 'primera página (50)', pg_size_pretty(sum(pg_column_size(q.*))), count(*) from (select * from public.posts where published order by created_at desc, id limit 50) q;
