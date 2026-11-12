#!/usr/bin/env bash
# Práctica 11 · Fase 1 — dependencias desactualizadas (app y backend).
# Uso: BLOG=~/Flutter/babywolf-blog ./estatico.sh
set -uo pipefail
BLOG=${BLOG:-$HOME/Flutter/babywolf-blog}
aqui=$(cd "$(dirname "$0")" && pwd)
raiz=$(cd "$aqui/../../../.." && pwd)
salida="$aqui/../resultados/estatico_dependencias.txt"
mkdir -p "$(dirname "$salida")"
{
  echo "# Dependencias desactualizadas — $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Equipo: $(uname -sm) · $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
  echo
  echo "## Flutter: flutter pub outdated (phone_app, commit $(git -C "$raiz" rev-parse --short HEAD))"
  (cd "$raiz/phone_app" && flutter --version 2>&1 | head -1; flutter pub outdated --no-dev-dependencies 2>&1 | tail -40) || true
  echo
  echo "## Go: go list -u -m all (sólo módulos con actualización disponible, commit $(git -C "$BLOG" rev-parse --short HEAD))"
  (cd "$BLOG/backend" && go version && go list -u -m all 2>&1 | grep '\[' ) || true
  echo
  echo "## Go: módulos directos (go.mod)"
  (cd "$BLOG/backend" && go list -m -f '{{if not .Indirect}}{{.Path}} {{.Version}}{{end}}' all 2>&1 | grep -v '^$' | head -20) || true
} 2>&1 | tee "$salida"
