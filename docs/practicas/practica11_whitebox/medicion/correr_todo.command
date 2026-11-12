#!/usr/bin/env bash
# Práctica 11 — corre todas las mediciones de este equipo y deja los resultados en
# docs/practicas/practica11_whitebox/resultados/. Doble clic o: ./correr_todo.command
# Opcional: BW_LECTOR_JWT=<access_token de una cuenta de lector> para la prueba 403.
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/Flutter/flutter/bin:/usr/local/go/bin:/opt/homebrew/bin:$HOME/go/bin:$PATH"
ECO=$(cd ../../../.. && pwd)
export BLOG=${BLOG:-$HOME/Flutter/babywolf-blog}
LOG="$ECO/docs/practicas/practica11_whitebox/resultados/corrida_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$(dirname "$LOG")"
paso() { echo; echo "════════ $1 ════════"; }
{
  paso "Código evaluado"
  git -C "$ECO" pull --ff-only 2>&1 | tail -1
  git -C "$BLOG" pull --ff-only 2>&1 | tail -1
  echo "ecosystem $(git -C "$ECO" rev-parse --short HEAD) · blog $(git -C "$BLOG" rev-parse --short HEAD)"

  paso "1/4 Cobertura y pruebas de la app (Flutter)"
  if command -v flutter >/dev/null; then ./cobertura.sh; else echo "flutter no está en el PATH: omitido"; fi

  paso "2/4 Cobertura y pruebas del backend (Go)"
  if command -v go >/dev/null; then ./go_cobertura.sh; else echo "go no está en el PATH: omitido"; fi

  paso "3/4 Códigos HTTP y validaciones contra Railway"
  python3 web_codigos.py | tee ../resultados/web_codigos.txt

  paso "4/4 Ping, latencia, transferencia y carga"
  python3 red_rendimiento.py | tee ../resultados/red_rendimiento.txt

  paso "Terminado"
  echo "Resultados en: $ECO/docs/practicas/practica11_whitebox/resultados"
} 2>&1 | tee "$LOG"
echo; echo "Presiona Enter para cerrar."; read -r _
