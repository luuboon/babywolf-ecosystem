#!/usr/bin/env bash
# Práctica 12 — Segunda ronda: (a) estrés de ESCRITURA con el defecto P12-D01 corregido,
# (b) pruebas de Flutter (analyze + test) de reintento/idempotencia. No toca producción.
export PATH="/opt/homebrew/bin:/usr/local/go/bin:$HOME/go/bin:/usr/local/opt/postgresql@17/bin:$HOME/Flutter/flutter/bin:$PATH"
ECO=${ECO:-$HOME/Flutter/babywolf-ecosystem}; BLOG=${BLOG:-$HOME/Flutter/babywolf-blog}
AQUI="$ECO/docs/practicas/practica12_estres"; R="$AQUI/resultados"; M="$AQUI/medicion"
W=${W:-$HOME/Flutter/p12_trabajo}; PGPORT=54330; export PGHOST=127.0.0.1 PGPORT PGUSER=postgres
SECRETO="p12-secreto-local"; ADMIN="00000000-0000-0000-0000-0000000000a1"; DUR_E=${DUR_E:-10}
mkdir -p "$R" "$W"; LOG="$R/corrida2_$(date +%Y%m%d_%H%M%S).log"; exec > >(tee "$LOG") 2>&1
echo "=== P12 RONDA 2 INICIO $(date '+%F %T %Z')"
git -C "$BLOG" fetch -q origin p12-optimizacion || exit 1
DES=$(git -C "$BLOG" rev-parse --short origin/p12-optimizacion); echo "DESPUÉS (con corrección P12-D01) = $DES"
git -C "$BLOG" worktree remove --force "$W/despues" 2>/dev/null; git -C "$BLOG" worktree prune
git -C "$BLOG" worktree add -q --detach "$W/despues" origin/p12-optimizacion || exit 1
(cd "$W/despues/backend" && go build -o "$W/api_despues" ./cmd/api) || exit 1
pg_ctl -D "$HOME/Flutter/p12_pgdata" status >/dev/null 2>&1 || pg_ctl -D "$HOME/Flutter/p12_pgdata" -o "-p $PGPORT -k /tmp -c listen_addresses=127.0.0.1 -c shared_buffers=128MB -c max_connections=200" -l "$HOME/Flutter/p12_pgdata/log" -w start >/dev/null
dropdb --if-exists bw_escritura 2>/dev/null; createdb -T bw_base bw_escritura
psql -X -q -d bw_escritura -f "$W/despues/backend/sql/009_indice_posts_listado.sql"
echo "posts antes: $(psql -X -tA -d bw_escritura -c 'select count(*) from public.posts')"
DATABASE_URL="host=127.0.0.1 port=$PGPORT user=postgres dbname=bw_escritura sslmode=disable" PORT=8083 JWT_SECRET=$SECRETO GIN_MODE=release SUPABASE_URL=http://127.0.0.1:1 SUPABASE_SERVICE_ROLE_KEY=x "$W/api_despues" > "$W/srv_escritura.log" 2>&1 &
PID=$!; for i in $(seq 1 40); do curl -fs http://127.0.0.1:8083/api/health >/dev/null && break; sleep 0.5; done
TOK=$(python3 - <<P
import sys; sys.path.insert(0,"$M"); import carga; print(carga.jwt_hs256("$SECRETO","$ADMIN"))
P
)
echo "-- POST de verificación (esperado 201):"; curl -s -o /dev/null -w "   HTTP %{http_code}\n" -X POST http://127.0.0.1:8083/api/admin/posts -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d '{"title":"Prueba","slug":"prueba-p12-d01","content":"x","category":"general","published":true}'
echo "-- misma petición con slug repetido (esperado 500 por UNIQUE, sin duplicar):"; curl -s -w "\n   HTTP %{http_code}\n" -X POST http://127.0.0.1:8083/api/admin/posts -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d '{"title":"Prueba","slug":"prueba-p12-d01","content":"x","category":"general","published":true}'
echo; echo "==== ESCRITURA · corregida · POST /api/admin/posts (JWT HS256 local)"
python3 "$M/carga.py" --base http://127.0.0.1:8083/api --ruta /admin/posts --metodo POST --niveles 1,5,10,25 --duracion $DUR_E --pid $PID --jwt-secret "$SECRETO" --jwt-sub "$ADMIN" --etiqueta "escritura-corregida" --json "$R/carga_escritura_corregida.json" | tee "$R/carga_escritura_corregida.txt"
N=$(python3 -c "import json;print(sum(n['solicitudes']-n['errores'] for n in json.load(open('$R/carga_escritura_corregida.json'))['niveles']))")
echo "filas nuevas esperadas (solicitudes 2xx + 1 de verificación): $((N+1)) · filas en BD: $(psql -X -tA -d bw_escritura -c 'select count(*)-5000 from public.posts')"
echo "slugs duplicados: $(psql -X -tA -d bw_escritura -c 'select count(*) from (select slug from public.posts group by slug having count(*)>1) t')"
kill $PID 2>/dev/null; wait $PID 2>/dev/null
dropdb --if-exists bw_escritura 2>/dev/null; pg_ctl -D "$HOME/Flutter/p12_pgdata" stop -m fast >/dev/null 2>&1
git -C "$BLOG" worktree remove --force "$W/despues" 2>/dev/null

echo; echo "### Flutter: pub get, analyze y test (phone_app)"
cd "$ECO/phone_app" && flutter pub get 2>&1 | tail -3
flutter analyze 2>&1 | tail -25
flutter test 2>&1 | tail -60 | tee "$R/flutter_test_p12.txt"
flutter test test/resiliencia_p12_test.dart --reporter expanded 2>&1 | tee "$R/flutter_resiliencia_expanded.txt" | tail -45
echo "=== P12 RONDA 2 FIN $(date '+%F %T %Z')"
