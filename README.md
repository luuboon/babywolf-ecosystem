# BabyWolf — Ecosistema de dispositivos inteligentes

Noticias de videojuegos retro y consolas en tres pantallas a la vez: teléfono,
wearable y Smart TV. Los tres consumen el mismo caso de estudio, el blog
**BabyWolf**, cuyo backend ya está en producción.

> Evaluación 2 · Desarrollo para Dispositivos Inteligentes · Mayo–Agosto 2026

## Qué hace cada dispositivo

| Proyecto | Dispositivo | Qué muestra |
|---|---|---|
| `phone_app/` | Teléfono (Flutter, Android) | El feed de noticias del blog, igual que la web. Además recibe las métricas del wearable. |
| `wearable_app/` | Wearable (Flutter, Wear OS) | Los temas del blog con su icono de consola retro, y la actividad de lectura simulada. |
| `tv_pwa/` | Smart TV (PWA, 1920×1080) | Las 4 noticias más recientes en un grid 2×2, navegable con D-pad. |
| `hub/` | Proceso en la laptop | El "aire" entre dispositivos: GATT emulado y estado compartido. |

## Arquitectura

```
        API del blog (Go, Railway) ── noticias reales
               │ HTTPS
      ┌────────┴──────────────────────┐
      │                               │
 phone_app                        tv_pwa
 feed de noticias                 grid 2×2 + D-pad
      │  ▲                            ▲
   WS │  │ NOTIFY por UUID        GET │ /state cada 1 s
      │  │                            │
      │  └──── hub (dart:io, 0 deps) ─┘
      │             ▲
      │         WS  │ publica valores por UUID
      └──── wearable_app
```

**Por qué existe el hub.** Un wearable BLE real anunciaría un servicio GATT y
expondría características con NOTIFY. Los emuladores de Android no tienen radio
Bluetooth, así que el hub ocupa el lugar del medio físico: transporta los mismos
UUIDs y los mismos bytes crudos, sin interpretarlos. El contrato — servicio,
características, tipos — es idéntico al de BLE y vive en `gatt_constants.dart`.

## Cómo ejecutar los tres proyectos

Requisitos: Flutter 3.44+, Android Studio con los AVD `Pixel_9` y
`Wear_OS_Large_Round`, Python 3 (sólo para servir la PWA), Chrome.

### 1. El hub — siempre primero

```bash
dart run hub/hub.dart
```

Queda escuchando en `:8090`. Sin él los tres siguen funcionando por separado,
pero no se comunican entre ellos.

### 2. Smart TV (PWA)

```bash
cd tv_pwa && python3 -m http.server 3000
```

Abrir <http://localhost:3000> en Chrome, con DevTools en modo dispositivo a
**1920×1080**.

> El puerto **3000 no es arbitrario**: es uno de los orígenes que el CORS del
> backend permite. En otro puerto el navegador bloquea las peticiones a la API.

### 3. Wearable (Wear OS)

```bash
cd wearable_app && flutter run
```

Con el emulador `Wear_OS_Large_Round` encendido. Pulsar **Iniciar** en el reloj
para que empiece a generar actividad de lectura.

### 4. Teléfono

```bash
cd phone_app && flutter run
```

Con el emulador `Pixel_9` encendido. El icono de reloj en la barra superior abre
el panel con las métricas que llegan del wearable.

### APK firmado

El keystore vive **fuera del repositorio** y `android/key.properties` está en
`.gitignore`: ninguna contraseña llega al historial de Git.

```bash
# 1. Crear el keystore (una sola vez; pide contraseña de forma interactiva)
keytool -genkey -v -keystore ~/.android/babywolf-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias babywolf

# 2. Rellenar las credenciales a partir de la plantilla
cp phone_app/android/key.properties.example phone_app/android/key.properties
#    y editar storeFile, storePassword, keyAlias y keyPassword

# 3. Compilar
cd phone_app && flutter build apk --release
```

Sin `key.properties` el build no falla: cae al keystore de debug para que
`flutter run --release` siga funcionando en otra máquina.

Para comprobar que quedó firmado con el certificado correcto:

```bash
~/Library/Android/sdk/build-tools/*/apksigner verify --print-certs \
  phone_app/build/app/outputs/flutter-apk/app-release.apk
```

## Documentación

| Documento | Contenido |
|---|---|
| [docs/SEGURIDAD.md](docs/SEGURIDAD.md) | Validación de origen, LFPDPPP, aviso de privacidad, retención de datos |
| [docs/PLAN_PRUEBAS.md](docs/PLAN_PRUEBAS.md) | Plan y reporte de pruebas, con resultados medidos |
| [docs/CONFIGURACION.md](docs/CONFIGURACION.md) | Herramientas, emuladores y troubleshooting |

## Sobre los secretos

El endpoint que consumen los tres dispositivos, `GET /api/posts`, es **público y
no lleva API key**. No hay ningún secreto que esconder en este repositorio, y aun
así `.gitignore` bloquea `.env`, `*.jks`, `*.keystore` y `key.properties` desde
el primer commit.
