#!/usr/bin/env bash
# Práctica 12 — Campaña completa: el MISMO banco de pruebas contra la versión original (commit 801dac0)
# y la optimizada (rama p12-optimizacion) del backend, cada una con su propia base desechable
# (5,000 posts) en un Postgres aparte (puerto 54330). No toca producción ni tus bases.
# Mide: estrés de lectura y escritura, consultas de BD, concurrencia y (opcional) producción.
#
# Uso: ./correr_estres.sh            (RUN_PROD=0 para omitir la parte contra producción)
export PATH="/opt/homebrew/bin:/usr/local/go/bin:$HOME/go/bin:/usr/local/opt/postgresql@17/bin:$PATH"
ECO=${ECO:-$HOME/Flutter/babywolf-ecosystem}; BLOG=${BLOG:-$HOME/Flutter/babywolf-blog}
AQUI="$ECO/docs/practicas/practica12_estres"; R="$AQUI/resultados"; M="$AQUI/medicion"; D="$AQUI/db"
W=${W:-$HOME/Flutter/p12_trabajo}; PGPORT=54330; export PGHOST=127.0.0.1 PGPORT PGUSER=postgres
RUN_PROD=${RUN_PROD:-1}; DUR_L=${DUR_L:-12}; DUR_E=${DUR_E:-10}
SECRETO="p12-secreto-local"; ADMIN="00000000-0000-0000-0000-0000000000a1"
mkdir -p "$R" "$W"
LOG="$R/corrida_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG") 2>&1
echo "=== P12 INICIO $(date '+%F %T %Z') · $(uname -sm) · $(go version) · $(psql --version)"
echo "Blog: $(git -C "$BLOG" rev-parse --short HEAD) (rama $(git -C "$BLOG" branch --show-current))"

echo; echo "### 0. Preparar versiones (worktrees, no se toca tu copia de trabajo)"
git -C "$BLOG" fetch -q origin p12-optimizacion || { echo "no pude traer p12-optimizacion"; exit 1; }
ANT=$(git -C "$BLOG" rev-parse --short 801dac0); DES=$(git -C "$BLOG" rev-parse --short origin/p12-optimizacion)
echo "ANTES = $ANT  ·  DESPUÉS = $DES"
for v in antes despues; do git -C "$BLOG" worktree remove --force "$W/$v" 2>/dev/null; done
git -C "$BLOG" worktree prune
git -C "$BLOG" worktree add -q --detach "$W/antes" 801dac0 && git -C "$BLOG" worktree add -q --detach "$W/despues" origin/p12-optimizacion || exit 1
for v in antes despues; do (cd "$W/$v/backend" && go build -o "$W/api_$v" ./cmd/api) || { echo "FALLÓ la compilación de $v"; exit 1; }; done
echo "compilado: api_antes y api_despues"

echo; echo "### 1. Pruebas unitarias y análisis de la versión optimizada"
(cd "$W/despues/backend" && go vet ./internal/... 2>&1 | tail -5; echo "go vet terminado"; go test -race -cover ./internal/interfaces/controllers/... ./internal/application/... ./internal/infrastructure/security/... 2>&1 | tail -12)

echo; echo "### 2. Postgres desechable con 5,000 posts"
BLOG="$BLOG" "$D/preparar_pg.sh" || exit 1
nueva_bd() { # $1 nombre  $2 con_indice
  dropdb --if-exists "$1" 2>/dev/null; createdb -T bw_base "$1" || return 1
  [ "$2" = 1 ] && psql -X -q -d "$1" -f "$W/despues/backend/sql/009_indice_posts_listado.sql"; return 0; }
arrancar() { # $1 version  $2 puerto  $3 bd
  DATABASE_URL="host=127.0.0.1 port=$PGPORT user=postgres dbname=$3 sslmode=disable" PORT=$2 JWT_SECRET=$SECRETO GIN_MODE=release \
    SUPABASE_URL=http://127.0.0.1:1 SUPABASE_SERVICE_ROLE_KEY=x "$W/api_$1" > "$W/srv_$1_$2.log" 2>&1 &
  PID=$!
  for i in $(seq 1 40); do curl -fs "http://127.0.0.1:$2/api/health" >/dev/null && return 0; sleep 0.5; done
  echo "el servidor $1 no arrancó"; tail -5 "$W/srv_$1_$2.log"; return 1; }
parar() { kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; }

echo; echo "### 3. Verificación funcional de GET /api/posts"
nueva_bd bw_antes 0; nueva_bd bw_despues 1
{
for v in antes despues; do
  p=8081; [ $v = despues ] && p=8082
  arrancar $v $p bw_$v || continue
  echo "-- versión $v ($p)"
  for q in "" "?limit=5" "?limit=5&offset=4498" "?limit=0" "?limit=101" "?offset=-1"; do
    out=$(curl -s -D - -o /tmp/p12_body.txt "http://127.0.0.1:$p/api/posts$q"); code=$(echo "$out" | head -1 | tr -d '\r'); tot=$(echo "$out" | grep -i '^x-total-count' | tr -d '\r')
    n=$(python3 -c "import json;d=json.load(open('/tmp/p12_body.txt'));print(len(d) if isinstance(d,list) else d)" 2>/dev/null)
    printf "   GET /api/posts%-22s %s | elementos: %s | %s | %s bytes\n" "$q" "$code" "$n" "${tot:-sin X-Total-Count}" "$(wc -c </tmp/p12_body.txt | tr -d ' ')"
  done
  parar
done; } | tee "$R/verificacion_api.txt"

echo; echo "### 4. Estrés de la API local (lectura y escritura), antes y después"
for v in antes despues; do
  p=8081; [ $v = despues ] && p=8082; idx=0; [ $v = despues ] && idx=1
  nueva_bd bw_$v $idx; arrancar $v $p bw_$v || continue
  echo; echo "==== LECTURA · $v · GET /api/posts (5,000 posts en BD)"
  python3 "$M/carga.py" --base "http://127.0.0.1:$p/api" --ruta /posts --niveles 1,5,10,25,50 --duracion $DUR_L --pid $PID --etiqueta "lectura-$v" --json "$R/carga_lectura_$v.json" | tee "$R/carga_lectura_$v.txt"
  parar
  nueva_bd bw_$v $idx; arrancar $v $p bw_$v || continue
  echo; echo "==== ESCRITURA · $v · POST /api/admin/posts (JWT HS256 local)"
  python3 "$M/carga.py" --base "http://127.0.0.1:$p/api" --ruta /admin/posts --metodo POST --niveles 1,5,10,25 --duracion $DUR_E --pid $PID --jwt-secret "$SECRETO" --jwt-sub "$ADMIN" --etiqueta "escritura-$v" --json "$R/carga_escritura_$v.json" | tee "$R/carga_escritura_$v.txt"
  echo "filas en BD tras la escritura: $(psql -X -tA -d bw_$v -c 'select count(*) from public.posts')"
  parar
done

echo; echo "### 5. Base de datos: consultas, planes y concurrencia"
dropdb --if-exists bw_sql 2>/dev/null; createdb -T bw_base bw_sql
{ psql -X -d bw_sql -v fase=antes -f "$D/pruebas_avanzadas.sql"
  echo; echo "######## aplicando 009_indice_posts_listado.sql ########"
  psql -X -q -d bw_sql -f "$W/despues/backend/sql/009_indice_posts_listado.sql"
  psql -X -d bw_sql -v fase=despues -f "$D/pruebas_avanzadas.sql"; } 2>&1 | tee "$R/db_consultas.txt"
"$D/concurrencia.sh" bw_sql 2>&1 | tee "$R/db_concurrencia.txt"

if [ "$RUN_PROD" = 1 ]; then
  echo; echo "### 6. Producción (sólo lectura, carga moderada: 1, 5, 10 y 20 hilos)"
  python3 "$M/carga.py" --base "https://babywolf-blog-production.up.railway.app/api" --ruta /posts --niveles 1,5,10,20 --duracion 10 --etiqueta "produccion-lectura" --json "$R/carga_produccion_lectura.json" | tee "$R/carga_produccion_lectura.txt"
fi
echo; echo "### Limpieza"; pg_ctl -D "$HOME/Flutter/p12_pgdata" stop -m fast >/dev/null 2>&1 && echo "Postgres desechable detenido"
for v in antes despues; do git -C "$BLOG" worktree remove --force "$W/$v" 2>/dev/null; done
echo "=== P12 FIN $(date '+%F %T %Z')"
