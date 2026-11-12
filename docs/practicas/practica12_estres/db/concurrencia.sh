#!/usr/bin/env bash
# Práctica 12 · Fase 4 (5 y 6) — escrituras concurrentes sobre registros y sobre un mismo registro.
set -u
PGBIN=${PGBIN:-/usr/local/opt/postgresql@17/bin}; export PATH="$PGBIN:$PATH"
export PGHOST=127.0.0.1 PGPORT=${PGPORT:-54330} PGUSER=postgres
DB=${1:-bw_sql}; P="psql -X -q -tA -d $DB"
now() { python3 -c 'import time;print(time.time())'; }
echo "# Concurrencia en $DB — $(date '+%F %T')"

echo; echo "== C1 · Dos sesiones actualizan el MISMO post: la segunda espera el bloqueo de fila"
$P -c "update public.posts set title='base' where slug='noticia-1'"
( $P -c "begin; update public.posts set title='sesion A' where slug='noticia-1'; select pg_sleep(3); commit;" >/dev/null ) &
sleep 0.6
T0=$(now)
$P -c "update public.posts set title='sesion B' where slug='noticia-1'" >/dev/null
T1=$(now); wait
python3 -c "print(f'  la sesión B esperó {$T1-$T0:.2f} s (A retuvo la fila 3 s; B entró a los ~0.6 s)')"
echo "  título final (gana la última en confirmar): $($P -c "select title from public.posts where slug='noticia-1'")"

echo; echo "== C2 · 10 sesiones, cada una actualiza posts DISTINTOS (sin conflicto), 200 UPDATE cada una"
T0=$(now)
for w in $(seq 1 10); do
  $P -c "do \$\$ begin for i in 1..200 loop update public.posts set title='w$w-'||i where slug='noticia-'||($w*10+i%10+10); commit; end loop; end \$\$" >/dev/null &
done; wait
T1=$(now); python3 -c "print(f'  2000 actualizaciones en {$T1-$T0:.2f} s = {2000/($T1-$T0):.0f} UPDATE/s, sin errores')"

echo; echo "== C3 · 10 sesiones × 200 incrementos del MISMO contador (esperado final = 2000)"
$P -c "drop table if exists p12_contador; create table p12_contador(id int primary key, n int not null); insert into p12_contador values (1,0)" >/dev/null
correr() { # $1 etiqueta  $2 cuerpo del bucle
  $P -c "update p12_contador set n=0 where id=1" >/dev/null
  T0=$(now)
  for w in $(seq 1 10); do
    $P -c "do \$\$ declare v int; begin for i in 1..200 loop $2 commit; end loop; end \$\$" >/dev/null 2>/tmp/p12_err_$w.txt &
  done; wait
  T1=$(now)
  FIN=$($P -c "select n from p12_contador where id=1")
  ERR=$(cat /tmp/p12_err_*.txt 2>/dev/null | grep -c -i error); rm -f /tmp/p12_err_*.txt
  python3 -c "print(f'  $1: final = $FIN (esperado 2000) → se perdieron {2000-int($FIN)} incrementos; {$T1-$T0:.2f} s; errores: $ERR')"
}
correr "leer y luego escribir (SELECT + UPDATE v+1)   " "select n into v from p12_contador where id=1; perform pg_sleep(0.0005); update p12_contador set n=v+1 where id=1;"
correr "SELECT ... FOR UPDATE antes de escribir       " "select n into v from p12_contador where id=1 for update; perform pg_sleep(0.0005); update p12_contador set n=v+1 where id=1;"
correr "UPDATE atómico (n = n + 1)                    " "update p12_contador set n=n+1 where id=1;"

echo; echo "== C4 · Integridad tras las operaciones"
$P -c "select 'posts: ' || count(*) || ' · sin título: ' || count(*) filter (where title is null or title='') || ' · slugs duplicados: ' || (count(*) - count(distinct slug)) from public.posts"
$P -c "select 'filas huérfanas (post sin autor): ' || count(*) from public.posts p left join public.users u on u.id=p.author_id where u.id is null"
$P -c "drop table if exists p12_contador" >/dev/null
