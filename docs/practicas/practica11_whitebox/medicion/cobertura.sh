#!/usr/bin/env bash
# Práctica 11 — cobertura de la app Flutter.
#
# Corre toda la suite con --coverage y calcula, del lcov.info, el porcentaje de
# LÍNEAS ejecutadas de los módulos críticos. Dart no entrega cobertura de
# ramas (BRDA): las ramas se verifican en metodos_criticos.md con la tabla de
# caminos y decisiones, y aquí sólo se reportan líneas.
#
# Uso (desde la raíz del repositorio): ./docs/practicas/practica11_whitebox/medicion/cobertura.sh
set -uo pipefail  # sin -e: "flutter --version | head -1" termina con SIGPIPE y abortaba el script
raiz=$(cd "$(dirname "$0")/../../../.." && pwd)
salida="$raiz/docs/practicas/practica11_whitebox/resultados"
mkdir -p "$salida"
cd "$raiz/phone_app"

{
  echo "# Cobertura de la app — $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Commit: $(git -C "$raiz" rev-parse --short HEAD) $(git -C "$raiz" diff --quiet || echo '(con cambios sin commit)')"
  echo "Equipo: $(uname -sm) · $(sw_vers -productName 2>/dev/null || true) $(sw_vers -productVersion 2>/dev/null || true)"
  flutter --version 2>&1 | head -1 || true
  echo
  flutter analyze --no-pub 2>&1 | tail -3
  echo
} | tee "$salida/flutter_cobertura.txt"

flutter test --coverage 2>&1 | tail -4 | tee -a "$salida/flutter_cobertura.txt"

python3 - "$PWD/coverage/lcov.info" <<'PY' | tee -a "$salida/flutter_cobertura.txt"
import sys, re
archivos = {}
actual = None
for linea in open(sys.argv[1], encoding='utf-8'):
    linea = linea.strip()
    if linea.startswith('SF:'):
        actual = linea[3:]; archivos[actual] = {}
    elif linea.startswith('DA:'):
        n, h = linea[3:].split(',')[:2]
        archivos[actual][int(n)] = int(h)
criticos = ['core/validacion.dart', 'services/busqueda.dart', 'services/blog_api.dart',
            'resumen/resumen_api.dart', 'guardadas/guardadas.dart', 'core/sesion.dart',
            'comentarios/comentarios_api.dart', 'reportes/reportes_api.dart', 'soporte/soporte_api.dart']
print("\nCobertura de LÍNEAS (instrucciones) por módulo")
print(f"{'archivo':38s} {'líneas':>7s} {'cubiertas':>10s} {'%':>7s}")
tl = tc = 0
for suf in criticos:
    for ruta, lineas in archivos.items():
        if ruta.replace('\\', '/').endswith('lib/' + suf):
            total = len(lineas); cub = sum(1 for h in lineas.values() if h > 0)
            tl += total; tc += cub
            print(f"{suf:38s} {total:7d} {cub:10d} {100*cub/total:6.1f}%")
if tl:
    print(f"{'TOTAL módulos críticos':38s} {tl:7d} {tc:10d} {100*tc/tl:6.1f}%")
tl = sum(len(l) for l in archivos.values()); tc = sum(1 for l in archivos.values() for h in l.values() if h > 0)
print(f"{'TOTAL de lo que cargó la suite':38s} {tl:7d} {tc:10d} {100*tc/tl:6.1f}%")
print("\nLíneas NO ejecutadas en los módulos críticos:")
for suf in criticos:
    for ruta, lineas in archivos.items():
        if ruta.replace('\\', '/').endswith('lib/' + suf):
            faltan = sorted(n for n, h in lineas.items() if h == 0)
            if faltan: print(f"  {suf}: {', '.join(map(str, faltan))}")
PY
