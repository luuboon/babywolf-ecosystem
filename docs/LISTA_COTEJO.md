# Lista de cotejo — dónde está cada cosa

Materia: Desarrollo para Dispositivos Inteligentes · Evaluación 2 · Nivel SA

Mapa de cada elemento de la lista de cotejo con el archivo, la prueba o la
captura que lo respalda. Los campos que la rúbrica deja en blanco `( ___ )` van
rellenados.

---

## SA.1.A — App wearable (Wear OS emulado) · 8/8

| # | Elemento | Dónde está |
|---|---|---|
| 1 | Proyecto Wear OS separado que compila | `wearable_app/` — compila, instala y arranca en `Wear_OS_Large_Round` |
| 2 | Ícono propio, no el default **(Formato: PNG)** | Lobo pixel generado por `tools/gen_icons.py`; aplicado con `flutter_launcher_icons` |
| 3 | Genera datos cada segundo **(Datos: tema activo, noticias sin leer, minutos de lectura)** | `wearable_app/lib/main.dart` → `_generar()`, `Timer.periodic(1 s)`. Temas y conteo **reales de la API** (CP-06b); sólo se simula el acto de leer |
| 4 | Al menos 3 tipos de datos | Tres características GATT: `string`, `uint16`, `float32` |
| 5 | Pantalla muestra los datos en tiempo real | Evidencia `02-wearable-generando.png` |
| 6 | Botón Iniciar/Detener | `_alternar()` — evidencias `01` (detenido) y `02` (generando) |
| 7 | Características GATT con NOTIFY, no sólo WRITE | `gatt_peripheral.dart` → `notify()`. Ver nota sobre la emulación abajo |
| 8 | UUIDs como constantes compartidas | `gatt_constants.dart`, copiado idéntico en ambos proyectos |

## SA.1.B — App teléfono: recepción BLE · 8/8

| # | Elemento | Dónde está |
|---|---|---|
| 1 | `BleClient` escanea y encuentra por serviceUUID | `phone_app/lib/ble_client.dart` → `escanear()`; el periférico anuncia `kServiceUuid` cada 2 s |
| 2 | Suscripción NOTIFY en cada característica | `setNotifyValue(uuid, true)` — sin ella los valores se descartan |
| 3 | Bytes parseados según su tipo | `gatt_codec.dart` — CP-03, 5/5 pruebas automáticas |
| 4 | `ActivityProvider` acumula y notifica a la UI | `phone_app/lib/providers/activity_provider.dart` |
| 5 | Mínimo 3 métricas en tiempo real | Evidencia `04` — tema, sin leer, minutos + contador de notificaciones |
| 6 | Alerta al superar umbral **(Umbral: más de 4 noticias sin leer)** | `kUmbralNoticiasSinLeer = 4`. Con las 6 reales → banner rojo + alerta en el panel; se apaga sola al bajar de 4 |
| 7 | Estado de conexión BLE visible | Los cuatro estados: buscando / conectado / error / desconectado |
| 8 | Al desconectar no crashea | CP-09 — `pid 7587` vivo, evidencia `06` |

## SA.2.A — PWA: estructura y configuración · 7/7

| # | Elemento | Dónde está |
|---|---|---|
| 1 | `manifest.json` válido | `display: fullscreen`, `orientation: landscape`, name y short_name — validado |
| 2 | Íconos 192 y 512 PNG `purpose: any maskable` | `tv_pwa/icons/` — dimensiones verificadas |
| 3 | Service worker registrado y activo | `tv_pwa/sw.js`; 10 estáticos en cache |
| 4 | Cache First estáticos / Network First API | `cacheFirst()` y `networkFirst()` en `sw.js` |
| 5 | Modo offline | CP-14 — carga con el servidor apagado |
| 6 | CSP en meta tag | `tv_pwa/index.html` — `default-src`, `connect-src`, `media-src`, `object-src`, `base-uri` |
| 7 | **CRÍTICO** Sin API key ni `.env` en commits | Los 5 checks salen vacíos. `GET /api/posts` es público |

## SA.2.B — Layout 1920×1080 y diseño 10-foot · 7/7

| # | Elemento | Dónde está |
|---|---|---|
| 1 | Safe zone del 5 % | `--safe-v: 54px`, `--safe-h: 96px` |
| 2 | Sin scroll en ninguna dimensión | CP-10 — `scrollWidth/Height` = 1920×1080 exactos |
| 3 | Grid de 4 elementos en 2×2 | `.grid` con `repeat(2, 1fr)`; 4 noticias reales |
| 4 | Dato principal ≥ 5rem (80 px) | `.hero-titulo` = `5rem` |
| 5 | Secundaria ≥ 2rem, detalle ≥ 1.5rem | `.card-cat` y `.hero-meta` = `2rem`; `.card-fecha` y footer = `1.5rem` |
| 6 | Contraste WCAG AA ≥ 4.5:1 | CP-17 — todos entre 4.97:1 y 13.75:1, medidos en el peor caso |
| 7 | Foco D-pad con glow dorado | `.card.focused` — `--oro: #ffd166`, contraste 9.47:1 |

## SA.2.C — Navegación D-pad y datos reales · 8/8

| # | Elemento | Dónde está |
|---|---|---|
| 1 | Las flechas mueven el foco | CP-11 — 16/16 combinaciones |
| 2 | Enter/OK selecciona y cambia el multimedia | CP-12 |
| 3 | En los bordes el foco no se rompe | CP-11 — los 8 bordes se quedan quietos |
| 4 | Mínimo 4 registros reales de la API | 4 noticias de `GET /api/posts` |
| 5 | Cada tarjeta con ≥ 3 campos | Categoría, título y fecha |
| 6 | El multimedia cambia según el elegido | El fondo pasa a la portada de la noticia |
| 7 | Fallback si el multimedia no carga | CP-13 — queda el color sólido |
| 8 | Información contextual en el header | Hora y fecha en vivo, actualizadas cada segundo |

## SA.3 — Integración del ecosistema · 6/7 (+1 en la demo)

| # | Elemento | Dónde está |
|---|---|---|
| 1 | Teléfono muestra datos de la API (P2.5) | CP-04, evidencia `03` |
| 2 | Wearable envía por BLE NOTIFY (P2.6) | CP-07 — 306 notificaciones recibidas |
| 3 | PWA TV sincronizada con el teléfono (P3.3) | CP-15 — 995 a 1371 ms |
| 4 | Los 3 activos a la vez en la demo | ⏳ **Se comprueba en la demo en vivo** |
| 5 | README con instrucciones de los 3 proyectos | `README.md` |
| 6 | Release v1.0 en GitHub con descripción | [Release v1.0](https://github.com/luuboon/babywolf-ecosystem/releases/tag/v1.0) |
| 7 | **CRÍTICO** Repositorio limpio | Sin API keys, sin `.jks`, sin `.env`, sin `key.properties` |

## SA.4 — Documentación de seguridad · 5/5

| # | Elemento | Dónde está |
|---|---|---|
| 1 | Validación de `event.origin` documentada y en código | `SEGURIDAD.md` §1 + `tv_pwa/js/sync.js` |
| 2 | LFPDPPP con base legal | `SEGURIDAD.md` §2 |
| 3 | Aviso de privacidad con derechos ARCO | `SEGURIDAD.md` §3 |
| 4 | Plan de retención de datos | `SEGURIDAD.md` §4 |
| 5 | Checklist PWA: CSP, HTTPS, SRI, origin | `SEGURIDAD.md` §5 |

## SA.5 — Plan y reporte de pruebas · 8/8

| # | Elemento | Dónde está |
|---|---|---|
| 1 | Al menos 10 casos | `PLAN_PRUEBAS.md` — **19 casos, 19 pasan** |
| 2 | Prueba de API y error de red (P2.5) | CP-04, CP-05 y CP-06b |
| 3 | Prueba de BLE NOTIFY (P2.6) | CP-07 |
| 4 | Prueba de D-pad | CP-11 y CP-12 |
| 5 | Prueba de modo offline | CP-14 |
| 6 | Sincronización en menos de 2 s | CP-15 — peor caso 1371 ms |
| 7 | Mínimo 5 capturas | **9 capturas** en `evidencias/` |
| 8 | Documento firmado con fecha | `pdf/PLAN_PRUEBAS.pdf` — firma manuscrita, 03/08/2026 |

## SA.6.A — Configuración de herramientas · 5/5

| # | Elemento | Dónde está |
|---|---|---|
| 1 | Flutter y Dart SDK | `CONFIGURACION.md` §1.2 — Flutter 3.44.0, Dart 3.12.0 |
| 2 | Android Studio y plugins | §1.3 — 2025.3, plugins Flutter y Dart |
| 3 | Herramientas de la Unidad 3 | §1.4 — Chrome 150, DevTools, VS Code, ffmpeg 8.0.1 |
| 4 | Dependencias con versión | §1.5 — `http` (teléfono y wearable), `provider`, `flutter_launcher_icons` |
| 5 | Pasos reproducibles | §1.6 — desde una máquina limpia |

## SA.6.B — Configuración de emuladores · 5/5

| # | Elemento | Dónde está |
|---|---|---|
| 1 | Emulador de teléfono **(API: 37)** | §2.1 — Pixel 9, `arm64-v8a`, 2048 MB |
| 2 | Emulador Wear OS **(API: 36)** | §2.2 — redondo, 454×454, `arm64-v8a`, 1536 MB |
| 3 | Emulación de TV en DevTools | §2.3 — 1920×1080 y user agent documentado |
| 4 | Capturas de cada emulador en el reporte | §2.5 — las tres capturas van embebidas |
| 5 | Troubleshooting real | §3 — seis problemas encontrados y resueltos |

## APK firmado

| Elemento | Dónde está |
|---|---|
| APK de release firmado e instalable | CP-16 — `CN=Abraham Duran`, 46.5 MB, instalado y arrancado |
| Keystore fuera del repositorio | `~/.android/babywolf-release.jks`; `key.properties` en `.gitignore` |

---

## Nota sobre el GATT emulado

Los emuladores de Android **no tienen radio Bluetooth**: no existe forma de que
un AVD de Wear OS actúe como periférico BLE real. Por eso el enlace viaja por
`hub/hub.dart`, que ocupa el lugar del medio físico.

Lo que se conserva del contrato de BLE:

- Un **servicio** identificado por UUID que el periférico anuncia y el central busca.
- Tres **características**, cada una con su UUID y su tipo de dato.
- **Bytes crudos** sin información de tipo: el UUID define cómo interpretarlos.
- **NOTIFY**: el periférico empuja los valores; el central sólo recibe los de las
  características para las que llamó `setNotifyValue(true)`.
- El hub **no interpreta** los bytes, igual que no lo haría una radio.

Sustituir el transporte por `flutter_blue_plus` sobre dos dispositivos físicos no
tocaría ni el códec, ni los UUIDs, ni el provider, ni la UI.
