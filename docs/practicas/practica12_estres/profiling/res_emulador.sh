#!/usr/bin/env bash
# Práctica 12 · Fase 5 — RES-01/RES-03(parcial)/RES-06 en el emulador con el build NUEVO (reintento con espera progresiva).
# Etiqueta: EMULADOR, build profile. Método: tamaño del PNG de screencap (pantalla de error ≈ 78 KB; feed completo > 500 KB).
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
ECO=${ECO:-$HOME/Flutter/babywolf-ecosystem}; R="$ECO/docs/practicas/practica12_estres/resultados"; D="$HOME/Flutter/p12_capturas"; PKG=com.babywolf.phone_app
mkdir -p "$D"; exec > >(tee "$R/res_emulador.txt") 2>&1
now() { python3 -c 'import time;print("%.3f"%time.time())'; }
kb() { adb exec-out screencap -p | wc -c | awk '{printf "%d", $1/1024}'; }
dif() { python3 -c "print(round($2-$1,2))"; }
echo "=== P12 RES emulador $(date '+%F %T %Z') | $(adb shell getprop ro.product.model | tr -d '\r') Android $(adb shell getprop ro.build.version.release | tr -d '\r')"
adb shell cmd connectivity airplane-mode disable; sleep 3
APK="$ECO/phone_app/build/app/outputs/flutter-apk/app-profile.apk"
adb shell pm path $PKG >/dev/null 2>&1 || { echo "instalando $APK"; adb install -r "$APK" | tail -1; }
adb shell am force-stop $PKG; adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 10
echo "estado base: captura ${KB:=$(kb)} KB (feed con contenido > 500 KB)"; adb exec-out screencap -p > "$D/p12_res_00_base.png"

for ENS in 1 2 3; do
  echo; echo "--- RES-01/PER-09 · ensayo $ENS: sin red, el usuario recarga el feed"
  adb shell cmd connectivity airplane-mode enable; sleep 3
  T0=$(now); adb shell input swipe 540 900 540 2000 300
  SER=""; ERR=""
  for i in $(seq 1 60); do t=$(now); s=$(kb); SER="$SER $(dif $T0 $t)s:${s}KB"
    if [ "$s" -lt 200 ] && [ "$(python3 -c "print(int($t-$T0>=0.6))")" = 1 ]; then ERR=$t; break; fi; done
  if [ -n "$ERR" ]; then echo "PER-09: pantalla de error visible ≤ $(dif $T0 $ERR) s tras el gesto (incluye 0.3 s del gesto y ≈0.3 s por captura)"; else echo "PER-09: no apareció la pantalla de error en 60 capturas"; fi
  echo "serie: $SER"
  [ "$ENS" = 1 ] && adb exec-out screencap -p > "$D/p12_res_01_sin_red.png"
  sleep 1
  TA=$(now); adb shell cmd connectivity airplane-mode disable
  UP=""; for i in $(seq 1 80); do adb shell ping -c 1 -W 1 8.8.8.8 2>/dev/null | tr -d '\r' | grep -q ' 0% packet loss' && { UP=$(now); break; }; sleep 0.2; done
  [ -z "$UP" ] && { echo "RES-06: la red no volvió en ~20 s"; continue; }
  echo "RES-06: red disponible $(dif $TA $UP) s tras quitar modo avión"
  TB=$(now); adb shell input tap 540 964   # botón Reintentar
  SER=""; OK=""; for i in $(seq 1 60); do t=$(now); s=$(kb); SER="$SER $(dif $TB $t)s:${s}KB"; [ "$s" -gt 500 ] && { OK=$t; break; }; done
  if [ -n "$OK" ]; then echo "PER-10: feed completo ≤ $(dif $TB $OK) s tras tocar Reintentar ($(dif $TA $OK) s tras quitar modo avión)"; else echo "PER-10: el feed NO se recuperó"; fi
  echo "serie: $SER"; [ "$ENS" = 1 ] && adb exec-out screencap -p > "$D/p12_res_02_recuperado.png"; sleep 3
done

echo; echo "### RES-06 automático: la red vuelve DURANTE los reintentos (sin tocar nada)"
for ENS in 1 2 3; do
  adb shell cmd connectivity airplane-mode enable; sleep 3
  T0=$(now); adb shell input swipe 540 900 540 2000 300 &
  sleep 0.7; adb shell cmd connectivity airplane-mode disable; TA=$(now)
  SER=""; OK=""; for i in $(seq 1 80); do t=$(now); s=$(kb); SER="$SER $(dif $T0 $t)s:${s}KB"; [ "$s" -gt 500 ] && [ "$(python3 -c "print(int($t-$T0>=1.2))")" = 1 ] && { OK=$t; break; }; done
  if [ -n "$OK" ]; then echo "ensayo $ENS: feed completo ≤ $(dif $T0 $OK) s tras el gesto, sin intervención del usuario"; else echo "ensayo $ENS: NO se recuperó solo (quedó en pantalla de error, serie: $SER)"; fi
  sleep 4; s=$(kb); [ "$s" -lt 200 ] && { adb shell input tap 540 964; sleep 5; }
done
adb shell cmd connectivity airplane-mode disable
echo "=== FIN $(date '+%F %T %Z')"; sleep 2
