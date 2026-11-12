#!/usr/bin/env bash
# Práctica 12 — Postgres DESECHABLE para las pruebas (no toca ninguna base real
# ni el Postgres que ya tengas corriendo): clúster propio en otro puerto, con el
# esquema real del blog (001 y 002) y una plantilla bw_base con datos de prueba.
#
#   PGBIN   binarios de Postgres (por omisión el de Homebrew)    PGPORT  puerto (54330)
#   N_POSTS cuántos posts sembrar (5000; 1 de cada 10 queda sin publicar)
set -euo pipefail
BLOG=${BLOG:-$HOME/Flutter/babywolf-blog}
PGBIN=${PGBIN:-/usr/local/opt/postgresql@17/bin}
PGDATA=${PGDATA:-$HOME/Flutter/p12_pgdata}
PGPORT=${PGPORT:-54330}
N_POSTS=${N_POSTS:-5000}
export PGHOST=127.0.0.1 PGPORT PGUSER=postgres PATH="$PGBIN:$PATH"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
  initdb -D "$PGDATA" -U postgres --auth=trust -E UTF8 >/dev/null
fi
if ! pg_isready -q -h 127.0.0.1 -p "$PGPORT"; then
  pg_ctl -D "$PGDATA" -o "-p $PGPORT -k /tmp -c listen_addresses=127.0.0.1 -c shared_buffers=128MB -c max_connections=200" -l "$PGDATA/log" -w start >/dev/null
fi

if psql -X -tA -d postgres -c "select 1 from pg_database where datname='bw_base'" | grep -q 1; then
  echo "bw_base ya existe (usa N_POSTS distinto: dropdb -h 127.0.0.1 -p $PGPORT -U postgres bw_base)"; exit 0
fi
createdb bw_base
psql -X -q -d bw_base -v ON_ERROR_STOP=1 <<'SQL'
create role anon nologin; create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb);
create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
grant usage on schema public, auth to anon, authenticated;
SQL
psql -X -q -d bw_base -v ON_ERROR_STOP=1 -f "$BLOG/backend/sql/001_initial_schema.sql" -f "$BLOG/backend/sql/002_add_category.sql"
psql -X -q -d bw_base -v ON_ERROR_STOP=1 -v n="$N_POSTS" <<'SQL'
insert into public.users(id, supabase_uid, email, username, role)
values ('00000000-0000-0000-0000-0000000000a1', gen_random_uuid(), 'admin@bw.test', 'admin', 'admin');
insert into public.posts(author_id, title, slug, content, category, published, created_at)
select '00000000-0000-0000-0000-0000000000a1', 'Noticia ' || g, 'noticia-' || g,
       repeat('Texto de noticia retro de consolas y videojuegos. ', 10) || g,   -- ~500 caracteres, como los posts reales (≈470 B)
       (array['retro','tech','gaming','guides','opinion'])[1 + g % 5],
       (g % 10 <> 0), now() - (g || ' minutes')::interval
from generate_series(1, :n) g;
analyze public.posts;
SQL
psql -X -tA -d bw_base -c "select 'bw_base lista: ' || count(*) || ' posts (' || count(*) filter (where published) || ' publicados), tamaño tabla ' || pg_size_pretty(pg_total_relation_size('public.posts')) from public.posts"
