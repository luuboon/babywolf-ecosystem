#!/usr/bin/env bash
# Práctica 11 — datos del equipo y del tipo de conexión (sin serial, sin SSID, sin IP).
aqui=$(cd "$(dirname "$0")" && pwd)
salida="$aqui/../resultados/entorno.txt"
{
  echo "# Entorno de medición — $(date '+%Y-%m-%d %H:%M:%S %Z')"
  sw_vers
  system_profiler SPHardwareDataType 2>/dev/null | grep -E "Model Name|Model Identifier|Chip|Total Number of Cores|Memory:"
  ifc=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
  echo "Interfaz de la ruta por omisión: ${ifc:-no disponible}"
  networksetup -listallhardwareports 2>/dev/null | awk -v i="$ifc" '/Hardware Port/{p=$0} $0 ~ "Device: "i"$"{print p}'
  echo "Zona horaria: $(date +%Z) ($(readlink /etc/localtime | sed 's|.*zoneinfo/||'))"
} 2>&1 | tee "$salida"
