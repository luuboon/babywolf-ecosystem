#!/usr/bin/env bash
# Práctica 11 — Fase 4: Postgres local desechable con el esquema real del blog.
#
# Crea un clúster temporal en $PGDATA, lo arranca en el puerto $PGPORT y carga
# 001, 002 y 005 de babywolf-blog/backend/sql (más lo mínimo de Supabase:
# roles y esquema auth). No toca ninguna base real.
#
# Uso: BLOG=/ruta/a/babywolf-blog ./preparar_pg_local.sh
set -euo pipefail
BLOG=${BLOG:-$HOME/babywolf-blog}
PGBIN=${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | tail -1)}
PGDATA=${PGDATA:-/var/tmp/bwpg_p11}
PGPORT=${PGPORT:-54329}
export PGHOST=127.0.0.1 PGPORT PGUSER=${PGUSER:-postgres}

if [ "$(id -u)" = 0 ]; then echo "Corre como un usuario normal (postgres no arranca como root)"; exit 1; fi

rm -rf "$PGDATA"; mkdir -p "$PGDATA"
"$PGBIN/initdb" -D "$PGDATA" -U postgres --auth=trust -E UTF8 >/dev/null
"$PGBIN/pg_ctl" -D "$PGDATA" -o "-p $PGPORT -k /tmp -c listen_addresses=127.0.0.1 -c shared_buffers=128MB" -l "$PGDATA/log" -w start >/dev/null
"$PGBIN/createdb" bwp11
psql -X -q -d bwp11 -v ON_ERROR_STOP=1 <<'SQL'
create role anon nologin; create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb);
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $$;
create schema storage;
create table storage.buckets(id text primary key, name text, public bool, file_size_limit bigint, allowed_mime_types text[]);
grant usage on schema public, auth to anon, authenticated;
SQL
psql -X -q -d bwp11 -v ON_ERROR_STOP=1 -f "$BLOG/backend/sql/001_initial_schema.sql" -f "$BLOG/backend/sql/002_add_category.sql"
psql -X -q -d bwp11 -c "ALTER TABLE users ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT true"
psql -X -q -d bwp11 -v ON_ERROR_STOP=1 -f "$BLOG/backend/sql/005_soporte.sql"
echo "Listo: psql -h 127.0.0.1 -p $PGPORT -U postgres bwp11"
