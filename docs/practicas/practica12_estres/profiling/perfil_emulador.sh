#!/usr/bin/env bash
# Práctica 12 · Fase 2 — profiling de la app en el emulador Android (Pixel_9, adb).
# Mide CPU (de /proc/PID/stat), RAM (VmRSS y PSS), frames (gfxinfo) y arranque en frío. Etiqueta: EMULADOR.
# Consulta producción SÓLO con GET (pull-to-refresh); la "escritura" es guardar/quitar una noticia (SQLite local).
export PATH="$HOME/Flutter/flutter/bin:$HOME/Library/Android/sdk/emulator:$HOME/Library/Android/sdk/platform-tools:$PATH"
ECO=${ECO:-$HOME/Flutter/babywolf-ecosystem}; AQUI="$ECO/docs/practicas/practica12_estres"; R="$AQUI/resultados"; CAP="$HOME/Flutter/p12_capturas"
PKG=com.babywolf.phone_app; mkdir -p "$R" "$CAP" "$HOME/Flutter/p12_tmp_perfil"; T="$HOME/Flutter/p12_tmp_perfil"
exec > >(tee "$R/profiling_emulador_$(date +%H%M%S).txt") 2>&1
now() { python3 -c 'import time;print("%.3f"%time.time())'; }
echo "=== P12 PROFILING $(date '+%F %T %Z') · $(flutter --version 2>&1 | head -1)"

echo; echo "### 0. Benchmark del cliente (VM de Dart del equipo, no teléfono)"
(cd "$ECO/phone_app" && flutter test test/benchmark_p12_test.dart 2>&1 | grep "BENCH") | tee "$R/benchmark_cliente.txt"

asegurar() { # arranca o recupera el emulador si no está en línea
  if ! adb devices | grep -q "emulator-.*[[:space:]]device$"; then
    echo "   (emulador no disponible: se reinicia)"; adb kill-server >/dev/null 2>&1; adb start-server >/dev/null 2>&1
    adb devices | grep -q "emulator-" || { flutter emulators --launch Pixel_9 >/dev/null 2>&1 & sleep 8; }
    adb wait-for-device; until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done; sleep 5
    adb shell am start -n $PKG/.MainActivity >/dev/null 2>&1; sleep 8; fi; }
echo; echo "### 1. Emulador y compilación"
asegurar
echo "dispositivo: $(adb shell getprop ro.product.model | tr -d '\r') · Android $(adb shell getprop ro.build.version.release | tr -d '\r') · $(adb shell wm size | tr -d '\r' | tail -1)"
cd "$ECO/phone_app" || exit 1
MODO=profile; flutter build apk --profile > "$T/build.log" 2>&1 || { MODO=debug; flutter build apk --debug > "$T/build.log" 2>&1; }
APK=$(ls build/app/outputs/flutter-apk/app-$MODO.apk 2>/dev/null) || { echo "NO compiló"; tail -5 "$T/build.log"; exit 1; }
echo "compilación: modo $MODO ($(du -h "$APK" | cut -f1)) — $( [ $MODO = profile ] && echo 'AOT con herramientas de profiling' || echo 'DEBUG (JIT, más lento: las cifras son cota superior)')"
adb install -r "$APK" | tail -1
adb shell cmd connectivity airplane-mode disable >/dev/null 2>&1

centro() { for _i in 1 2 3; do r=$(centro1 "$1"); [ -n "$r" ] && { echo "$r"; return; }; sleep 1; done; }
centro1() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml | tr -d '\r' | python3 -c '
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
capa() { adb shell dumpsys SurfaceFlinger --list 2>/dev/null | tr -d '\r' | grep "$PKG" | grep -i surfaceview | head -1; }
latmuestrear() { # $1 archivo; acumula marcas de tiempo de presentación de frames hasta que exista $1.stop
  local L; L=$(capa); [ -z "$L" ] && L=$(adb shell dumpsys SurfaceFlinger --list 2>/dev/null | tr -d '\r' | grep "$PKG" | head -1)
  echo "$L" > "$1.capa"; rm -f "$1"
  adb shell "dumpsys SurfaceFlinger --latency-clear '$L'" >/dev/null 2>&1
  while [ ! -f "$1.stop" ]; do adb shell "dumpsys SurfaceFlinger --latency '$L'" 2>/dev/null | tr -d '\r' | tail -n +2 >> "$1"; sleep 1; done; }
gfx() { python3 - "$1" <<'P'
import sys
rows=set()
try:
    for l in open(sys.argv[1]):
        p=l.split()
        if len(p)==3 and p[1].isdigit() and 0<int(p[1])<10**18: rows.add(int(p[1]))
except FileNotFoundError: pass
t=sorted(rows)
if len(t)<3: print(f"   Frames (SurfaceFlinger): {len(t)} marcas — la interfaz no se redibujó (reposo) o la capa no se encontró"); sys.exit()
d=[(t[i]-t[i-1])/1e6 for i in range(1,len(t))]
d=[x for x in d if x<500]  # ignora pausas sin dibujar
ds=sorted(d); q=lambda f: ds[min(len(ds)-1,int(f*len(ds)))]
mal=sum(1 for x in d if x>25)
print(f"   Frames presentados: {len(t)} · intervalos entre frames (ms): P50 {q(.5):.1f} · P90 {q(.9):.1f} · P95 {q(.95):.1f} · P99 {q(.99):.1f} · máx {max(d):.1f}")
print(f"   Frames con intervalo > 25 ms (se perdió al menos un ciclo de 60 Hz): {mal} de {len(d)} = {100*mal/len(d):.1f} %")
P
}
pss() { echo "   PSS total (dumpsys meminfo): $(adb shell dumpsys meminfo $PKG | tr -d '\r' | grep -m1 'TOTAL PSS\|TOTAL' | awk '{print $2}') KB"; }
escenario() { # $1 id $2 título $3 función
  echo; echo "--- $1 · $2"; asegurar; rm -f "$T/$1.fr.stop"
  muestrear "$T/$1.csv" & local m=$!; latmuestrear "$T/$1.fr" & local f=$!; sleep 2; a=$(now); "$3"; b=$(now); touch "$T/$1.csv.stop" "$T/$1.fr.stop"; wait $m $f
  echo "   duración del escenario: $(python3 -c "print(round($b-$a,1))") s"; resumen "$T/$1.csv" 2>&1 | tail -2; gfx "$T/$1.fr"; pss
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
busqueda() { B=$(centro "Buscar noticias"); [ -z "$B" ] && { echo "   no se encontró el botón de búsqueda"; return; }
  for i in 1 2 3; do adb shell input tap $B; sleep 1; adb shell input text retro; sleep 1.5
    X=$(centro "Cerrar búsqueda"); [ -n "$X" ] && adb shell input tap $X; sleep 1; done; }  # NO se usa BACK: el segundo BACK saca la app
escritura() { for i in 1 2 3 4 5; do adb shell input tap 540 1500; sleep 1.5; G=$(centro "Guardar para leer"); [ -n "$G" ] && { adb shell input tap $G; sleep 1; }
  Q=$(centro "Quitar de guardadas"); [ -n "$Q" ] && { adb shell input tap $Q; sleep 1; }; adb shell input keyevent KEYCODE_BACK; sleep 1; done; }

E=" ${ESCENARIOS:-PER01 PER02 PER03 PER04 PER05 PER06} "
[[ $E == *" PER01 "* ]] && escenario PER01_reposo "Reposo 10 s (línea base)" reposo
[[ $E == *" PER02 "* ]] && escenario PER02_consulta "Consulta repetida: 15 recargas del feed (GET /api/posts de producción)" consulta
[[ $E == *" PER03 "* ]] && escenario PER03_lista "Desplazamiento de la lista, 20 pasadas" lista
[[ $E == *" PER04 "* ]] && escenario PER04_navegacion "Navegación entre pestañas, 30 cambios" nav
[[ $E == *" PER05 "* ]] && escenario PER05_busqueda "Búsqueda en el cliente (3 veces 'retro')" busqueda
[[ $E == *" PER06 "* ]] && escenario PER06_escritura "Escritura local: guardar y quitar noticia, 5 ciclos" escritura

echo; echo "### Memoria al final"; pss; adb shell dumpsys meminfo $PKG | tr -d '\r' | sed -n '1,22p'
echo; echo "=== FIN $(date '+%F %T %Z')"
sleep 2
