#!/usr/bin/env bash
# Práctica 11 · Fase 4 — DB-01…DB-06 y medición de consultas.
# Requiere preparar_pg_local.sh ya ejecutado. Imprime el reporte en pantalla.
set -u
export PGHOST=127.0.0.1 PGPORT=${PGPORT:-54329} PGUSER=${PGUSER:-postgres}
Q="psql -X -q -d bwp11 -v ON_ERROR_STOP=0 -t -A"
aqui=$(cd "$(dirname "$0")" && pwd)

echo "# Reporte de base de datos — $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Servidor: $(psql -X -d bwp11 -t -A -c 'select version()')"
echo "Equipo: $(uname -sm) · CPU: $(nproc 2>/dev/null || sysctl -n hw.ncpu) núcleos"
echo "Base: Postgres LOCAL con el esquema real del blog (001, 002, 005). No es Supabase."

psql -X -q -d bwp11 -f "$aqui/pruebas_db.sql" 2>&1 | sed '/^$/N;/^\n$/D'

echo
echo "== DB-06 · Concurrencia"
$Q <<'SQL' >/dev/null
delete from public.users where email='conc@bw.test';
insert into public.users(id,supabase_uid,email,username,role,active)
values ('00000000-0000-0000-0000-0000000000c3',gen_random_uuid(),'conc@bw.test','conc','user',true);
SQL

echo "-- (1) Dos UPDATE a la misma fila: el segundo espera al primero (bloqueo de fila)"
( $Q <<'SQL'
begin;
update public.users set username='conc_A' where id='00000000-0000-0000-0000-0000000000c3';
select pg_sleep(2);
commit;
SQL
) &
sleep 0.4
t0=$(date +%s.%N)
$Q -c "update public.users set role='admin' where id='00000000-0000-0000-0000-0000000000c3'" >/dev/null
t1=$(date +%s.%N)
wait
printf "   el UPDATE de B esperó %.2f s (A mantenía el bloqueo ~2 s)\n" "$(echo "$t1 - $t0" | bc -l)"
$Q -c "select '   estado final: username=' || username || ', role=' || role from public.users where id='00000000-0000-0000-0000-0000000000c3'"

echo "-- (2) Actualización perdida con leer-modificar-guardar (así guarda GORM: db.Save(user))"
$Q <<'SQL' >/dev/null
update public.users set username='conc', role='user', active=true where id='00000000-0000-0000-0000-0000000000c3';
SQL
read_row() { $Q -c "select username||'|'||role||'|'||active from public.users where id='00000000-0000-0000-0000-0000000000c3'"; }
A=$(read_row); B=$(read_row)               # las dos peticiones leen la misma fila
IFS='|' read -r au ar aa <<<"$A"; IFS='|' read -r bu br ba <<<"$B"
# A cambia el rol y guarda TODA la fila; B desactiva y guarda TODA la fila con el rol viejo.
$Q -c "update public.users set username='$au', role='admin', active=$( [ "$aa" = t ] && echo true || echo false ) where id='00000000-0000-0000-0000-0000000000c3'"
$Q -c "update public.users set username='$bu', role='$br', active=false where id='00000000-0000-0000-0000-0000000000c3'"
$Q -c "select '   A puso role=admin, B puso active=false. Resultado: role=' || role || ', active=' || active || '  → ' || case when role='admin' then 'sin pérdida' else 'SE PERDIÓ el cambio de A' end from public.users where id='00000000-0000-0000-0000-0000000000c3'"
echo "-- (2b) La misma operación como UPDATE de sólo la columna cambiada"
$Q <<'SQL' >/dev/null
update public.users set username='conc', role='user', active=true where id='00000000-0000-0000-0000-0000000000c3';
update public.users set role='admin' where id='00000000-0000-0000-0000-0000000000c3';   -- A
update public.users set active=false where id='00000000-0000-0000-0000-0000000000c3';    -- B
SQL
$Q -c "select '   Resultado: role=' || role || ', active=' || active || '  → ' || case when role='admin' and not active then 'ambos cambios conservados' else 'pérdida' end from public.users where id='00000000-0000-0000-0000-0000000000c3'"

echo "-- (3) Dos INSERT con el mismo slug a la vez: sólo uno gana (UNIQUE)"
$Q -c "delete from public.posts where slug='carrera'" >/dev/null
ins() { $Q -c "insert into public.posts(author_id,title,slug,content) values ('00000000-0000-0000-0000-0000000000a1','t$1','carrera','c')" 2>&1 | head -1; }
ins 1 >/tmp/p11_i1 & ins 2 >/tmp/p11_i2 & wait
res() { if [ -s "$1" ]; then head -c 90 "$1"; else echo "OK (1 fila insertada)"; fi; }
echo "   sesión 1: $(res /tmp/p11_i1)"
echo "   sesión 2: $(res /tmp/p11_i2)"
$Q -c "select '   filas con slug=carrera: ' || count(*) from public.posts where slug='carrera'"
rm -f /tmp/p11_i1 /tmp/p11_i2
$Q -c "delete from public.posts where slug='carrera'" >/dev/null

echo
echo "== Medición de consultas (EXPLAIN ANALYZE) =="
medir() { # $1 etiqueta  $2 sql
  echo "-- $1"
  psql -X -q -d bwp11 -t -A -c "explain (analyze, buffers, timing on, format text) $2" | grep -E "Scan|Sort|Execution Time|Planning Time|Limit|Index" | sed 's/^/   /'
}
sembrar() { # $1 = cantidad de posts
  $Q <<SQL >/dev/null
truncate public.comments, public.posts restart identity cascade;
insert into public.posts(author_id,title,slug,content,category,published,created_at)
select '00000000-0000-0000-0000-0000000000a1', 'Noticia '||g, 'noticia-'||g,
       repeat(md5(g::text), 64),                                   -- ~2 KB de texto
       (array['retro','nintendo','sega','guias','general'])[1+g%5],
       g % 20 <> 0,                                                -- 5 % sin publicar
       now() - (g || ' minutes')::interval
from generate_series(1,$1) g;
analyze public.posts;
SQL
}
for n in 15 5000; do
  sembrar $n
  echo
  echo "### Con $n posts (~2 KB de contenido cada uno)"
  medir "Q1 listado público: GET /api/posts → ListAll(false)" "select * from public.posts where published = true order by created_at desc"
  medir "Q2 por slug: GetBySlug" "select * from public.posts where slug = 'noticia-$((n/2))' order by id limit 1"
  ID=$($Q -c "select id from public.posts where slug='noticia-$((n/2))'")
  medir "Q3 por id: GetByID" "select * from public.posts where id = '$ID' order by id limit 1"
  echo "-- tamaño transferido por Q1"
  $Q -c "select '   filas=' || count(*) || ', bytes de contenido=' || sum(octet_length(content)) || ' (' || round(sum(octet_length(content))/1024.0/1024.0,2) || ' MB)' from public.posts where published"
  $Q -c "select '   sólo título+slug+categoría: ' || round(sum(octet_length(title)+octet_length(slug)+octet_length(category))/1024.0,1) || ' KB' from public.posts where published"
done

echo
echo "### Propuesta de corrección: índice para el listado público (5000 posts)"
$Q -c "create index if not exists idx_posts_pub_fecha on public.posts(created_at desc) where published" >/dev/null
$Q -c "analyze public.posts" >/dev/null
medir "Q1 con índice parcial (created_at desc) WHERE published" "select * from public.posts where published = true order by created_at desc"
medir "Q1 con LIMIT 20 (paginación)" "select * from public.posts where published = true order by created_at desc limit 20"
$Q -c "drop index if exists idx_posts_pub_fecha" >/dev/null
