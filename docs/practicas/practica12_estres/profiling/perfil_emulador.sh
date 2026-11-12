#!/usr/bin/env bash
# Práctica 12 · Fase 2 — profiling de la app en el emulador Android (Pixel_9, adb).
# Mide CPU (de /proc/PID/stat), RAM (VmRSS y PSS), frames (gfxinfo) y arranque en frío. Etiqueta: EMULADOR.
# Consulta producción SÓLO con GET (pull-to-refresh); la "escritura" es guardar/quitar una noticia (SQLite local).
export PATH="$HOME/Flutter/flutter/bin:$HOME/Library/Android/sdk/emulator:$HOME/Library/Android/sdk/platform-tools:$PATH"
ECO=${ECO:-$HOME/Flutter/babywolf-ecosystem}; AQUI="$ECO/docs/practicas/practica12_estres"; R="$AQUI/resultados"; CAP="$HOME/Flutter/p12_capturas"
PKG=com.babywolf.phone_app; mkdir -p "$R" "$CAP" "$HOME/Flutter/p12_tmp_perfil"; T="$HOME/Flutter/p12_tmp_perfil"
exec > >(tee "$R/profiling_emulador.txt") 2>&1
now() { python3 -c 'import time;print("%.3f"%time.time())'; }
echo "=== P12 PROFILING $(date '+%F %T %Z') · $(flutter --version 2>&1 | head -1)"

echo; echo "### 0. Benchmark del cliente (VM de Dart del equipo, no teléfono)"
(cd "$ECO/phone_app" && flutter test test/benchmark_p12_test.dart 2>&1 | grep "BENCH") | tee "$R/benchmark_cliente.txt"

echo; echo "### 1. Emulador y compilación"
if ! adb devices | grep -q "emulator-.*device$"; then flutter emulators --launch Pixel_9 >/dev/null 2>&1 & sleep 5; adb wait-for-device
  until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done; fi
echo "dispositivo: $(adb shell getprop ro.product.model | tr -d '\r') · Android $(adb shell getprop ro.build.version.release | tr -d '\r') · $(adb shell wm size | tr -d '\r' | tail -1)"
cd "$ECO/phone_app" || exit 1
MODO=profile; flutter build apk --profile > "$T/build.log" 2>&1 || { MODO=debug; flutter build apk --debug > "$T/build.log" 2>&1; }
APK=$(ls build/app/outputs/flutter-apk/app-$MODO.apk 2>/dev/null) || { echo "NO compiló"; tail -5 "$T/build.log"; exit 1; }
echo "compilación: modo $MODO ($(du -h "$APK" | cut -f1)) — $( [ $MODO = profile ] && echo 'AOT con herramientas de profiling' || echo 'DEBUG (JIT, más lento: las cifras son cota superior)')"
adb install -r "$APK" | tail -1
adb shell cmd connectivity airplane-mode disable >/dev/null 2>&1

centro() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml | tr -d '\r' | python3 -c '
import sys,re
k=sys.argv[1]; x=sys.stdin.read()
for m in re.finditer(r"<node [^>]*>",x):
    n=m.group(0)
    if k in n:
        b=re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"",n)
        if b:
            a=list(map(int,b.groups())); print((a[0]+a[2])//2,(a[1]+a[3])//2); break' "$1"; }
pidapp() { adb shell pidof $PKG | tr -d '\r' | awk '{print $1}'; }
muestrear() { # $1 archivo CSV; se detiene al crear $1.stop
  rm -f "$1" "$1.stop"; local pid; pid=$(pidapp)
  while [ ! -f "$1.stop" ]; do
    o=$(adb shell "cat /proc/$pid/stat; grep VmRSS /proc/$pid/status" 2>/dev/null | tr -d '\r')
    tk=$(echo "$o" | head -1 | awk '{print $14+$15}'); rs=$(echo "$o" | grep VmRSS | awk '{print $2}')
    [ -n "$tk" ] && echo "$(now),$tk,$rs" >> "$1"; sleep 0.8; done; }
resumen() { python3 - "$1" "$2" <<'P'
import sys,statistics
f=[l.strip().split(",") for l in open(sys.argv[1]) if l.count(",")==2]
t=[float(a) for a,_,_ in f]; k=[int(b) for _,b,_ in f]; r=[int(c)/1024 for _,_,c in f if c]
cpu=[(k[i]-k[i-1])/100/(t[i]-t[i-1])*100 for i in range(1,len(f)) if t[i]>t[i-1]]
print(f"   CPU (% de un núcleo, {len(cpu)} muestras): promedio {statistics.mean(cpu):.1f} · máximo {max(cpu):.1f} | RAM RSS (MB): inicial {r[0]:.1f} · máxima {max(r):.1f} · final {r[-1]:.1f}")
P
}
gfx() { adb shell dumpsys gfxinfo $PKG | tr -d '\r' | grep -E "Total frames rendered|Janky frames|50th percentile|90th percentile|95th percentile|99th percentile" | sed 's/^/   /'; }
pss() { echo "   PSS total (dumpsys meminfo): $(adb shell dumpsys meminfo $PKG | tr -d '\r' | grep -m1 'TOTAL PSS\|TOTAL' | awk '{print $2}') KB"; }
escenario() { # $1 id $2 título $3 función
  echo; echo "--- $1 · $2"; adb shell dumpsys gfxinfo $PKG reset >/dev/null 2>&1
  muestrear "$T/$1.csv" & local m=$!; sleep 2; a=$(now); "$3"; b=$(now); touch "$T/$1.csv.stop"; wait $m
  echo "   duración del escenario: $(python3 -c "print(round($b-$a,1))") s"; resumen "$T/$1.csv"; gfx; pss
  adb exec-out screencap -p > "$CAP/p12_$1.png"; }

echo; echo "### 2. Arranque en frío (am start -W, 5 ensayos)"
for i in 1 2 3 4 5; do adb shell am force-stop $PKG; sleep 1
  adb shell am start -W -n $PKG/.MainActivity | tr -d '\r' | grep -E "TotalTime|WaitTime" | tr '\n' ' '; echo; sleep 4; done
adb shell am force-stop $PKG; sleep 1; adb shell am start -n $PKG/.MainActivity >/dev/null; sleep 8
echo "pid: $(pidapp)"; echo "RAM inicial (tras arrancar y cargar el feed):"; pss

reposo() { sleep 10; }
consulta() { for i in $(seq 1 15); do adb shell input swipe 540 900 540 2000 300; sleep 3; done; }
lista() { for i in 1 2 3 4 5 6 7 8 9 10; do adb shell input swipe 540 1900 540 600 250; sleep 0.3; adb shell input swipe 540 600 540 1900 250; sleep 0.3; done; }
nav() { G=$(centro "Guardadas"); C=$(centro "Cuenta"); N=$(centro "Noticias"); echo "   pestañas en: Noticias[$N] Guardadas[$G] Cuenta[$C]"
  for i in $(seq 1 10); do adb shell input tap $G; sleep 0.7; adb shell input tap $C; sleep 0.7; adb shell input tap $N; sleep 0.7; done; }
busqueda() { B=$(centro "Buscar noticias"); for i in 1 2 3; do adb shell input tap $B; sleep 1; adb shell input text retro; sleep 1.5; adb shell input keyevent KEYCODE_BACK; sleep 0.5; adb shell input keyevent KEYCODE_BACK; sleep 1; done; }
escritura() { for i in 1 2 3 4 5; do adb shell input tap 540 1500; sleep 1.5; G=$(centro "Guardar para leer"); [ -n "$G" ] && { adb shell input tap $G; sleep 1; }
  Q=$(centro "Quitar de guardadas"); [ -n "$Q" ] && { adb shell input tap $Q; sleep 1; }; adb shell input keyevent KEYCODE_BACK; sleep 1; done; }

escenario PER01_reposo "Reposo 10 s (línea base)" reposo
escenario PER02_consulta "Consulta repetida: 15 recargas del feed (GET /api/posts de producción)" consulta
escenario PER03_lista "Desplazamiento de la lista, 20 pasadas" lista
escenario PER04_navegacion "Navegación entre pestañas, 30 cambios" nav
escenario PER05_busqueda "Búsqueda en el cliente (3 veces 'retro')" busqueda
escenario PER06_escritura "Escritura local: guardar y quitar noticia, 5 ciclos" escritura

echo; echo "### Memoria al final"; pss; adb shell dumpsys meminfo $PKG | tr -d '\r' | sed -n '1,22p'
echo; echo "=== FIN $(date '+%F %T %Z')"
sleep 2
