#!/usr/bin/env bash
# Práctica 12 · Fase 2 — tiempos de frame (build/raster) con flutter drive --profile en el emulador.
export PATH="$HOME/Flutter/flutter/bin:$HOME/Library/Android/sdk/emulator:$HOME/Library/Android/sdk/platform-tools:$PATH"
ECO=${ECO:-$HOME/Flutter/babywolf-ecosystem}; R="$ECO/docs/practicas/practica12_estres/resultados"
exec > >(tee "$R/profiling_frames.txt") 2>&1
echo "=== P12 FRAMES $(date '+%F %T %Z') · $(flutter --version 2>&1 | head -1)"
adb devices | grep -q "emulator-.*[[:space:]]device$" || { flutter emulators --launch Pixel_9 >/dev/null 2>&1 & sleep 8; adb wait-for-device; until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done; sleep 5; }
cd "$ECO/phone_app" && flutter pub get >/dev/null 2>&1
export P12_SALIDA="$R"
flutter drive --profile -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/rendimiento_test.dart > "$R/profiling_frames_drive.log" 2>&1; grep -E "Exception|Error|error|EXCEPTION|expected|Test failed|All tests passed|Some tests|Built|Install" "$R/profiling_frames_drive.log" | head -20
echo "--- reporte"
python3 - "$R/rendimiento_frames.json" <<'P'
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception as e: print("sin reporte:",e); sys.exit()
for k,v in d.items():
    if not isinstance(v,dict): continue
    print(f"[{k}]")
    for m in ("average_frame_build_time_millis","90th_percentile_frame_build_time_millis","99th_percentile_frame_build_time_millis","worst_frame_build_time_millis",
              "average_frame_rasterizer_time_millis","90th_percentile_frame_rasterizer_time_millis","99th_percentile_frame_rasterizer_time_millis","worst_frame_rasterizer_time_millis",
              "frame_count","missed_frame_build_budget_count","missed_frame_rasterizer_budget_count"):
        if m in v: print(f"   {m}: {v[m]}")
P
echo "=== FIN $(date '+%F %T %Z')"; sleep 2
