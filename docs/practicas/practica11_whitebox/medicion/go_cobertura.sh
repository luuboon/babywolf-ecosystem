#!/usr/bin/env bash
# Práctica 11 — cobertura de instrucciones del backend Go (babywolf-blog/backend).
# Uso: BLOG=~/Flutter/babywolf-blog ./go_cobertura.sh     (necesita Go ≥ 1.25.7)
set -euo pipefail
BLOG=${BLOG:-$HOME/Flutter/babywolf-blog}
aqui=$(cd "$(dirname "$0")" && pwd)
salida="$aqui/../resultados/go_cobertura.txt"
mkdir -p "$(dirname "$salida")"
cd "$BLOG/backend"
{
  echo "# Cobertura del backend Go — $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Commit: $(git rev-parse --short HEAD)  $(git diff --quiet || echo '(con cambios sin commit)')"
  echo "Equipo: $(uname -sm) · $(go version)"
  echo
  echo "## go vet"
  go vet ./... 2>&1 && echo "go vet: sin observaciones"
  echo
  echo "## gofmt (archivos sin formato estándar)"
  gofmt -l . || true
  echo
  echo "## go test -race -cover"
  go test -race -count=1 -covermode=atomic -coverprofile=/tmp/bw_cover.out ./... 2>&1
  echo
  echo "## Cobertura por función (sólo < 100 %)"
  go tool cover -func=/tmp/bw_cover.out | awk '$3+0 < 100'
} 2>&1 | tee "$salida"
