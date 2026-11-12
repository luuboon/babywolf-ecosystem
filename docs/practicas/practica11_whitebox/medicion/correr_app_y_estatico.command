#!/usr/bin/env bash
# Práctica 11 — corre sólo la parte de la app (pruebas + cobertura) y las dependencias desactualizadas.
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/Flutter/flutter/bin:/usr/local/go/bin:/opt/homebrew/bin:$HOME/go/bin:$PATH"
export BLOG=${BLOG:-$HOME/Flutter/babywolf-blog}
LOG="../resultados/corrida_app_$(date +%Y%m%d_%H%M%S).log"
{
  echo "════════ Pruebas whitebox de la app ════════"
  (cd ../../../../phone_app && flutter test test/whitebox_test.dart 2>&1 | tail -25)
  echo; echo "════════ Cobertura de la app ════════"
  ./cobertura.sh
  echo; echo "════════ Dependencias ════════"
  ./estatico.sh
  echo; echo "════════ Terminado ════════"
} 2>&1 | tee "$LOG"
echo; echo "Presiona Enter para cerrar."; read -r _
