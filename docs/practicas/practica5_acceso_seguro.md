# Práctica 5 — Código seguro: AccesoSeguro

App → 🧪 → *AccesoSeguro*. Código en `phone_app/lib/laboratorio/p5_acceso/`.

> **Lenguaje:** el enunciado pide Kotlin. BabyWolf es Flutter, así que se
> implementó en Dart y se prueba en el emulador de Android Studio. Las medidas
> de seguridad no dependen del lenguaje.

## Datos de prueba

| Usuario | Contraseña |
|---|---|
| `alumno.uteq` | `BabyWolf2026` |

La app **no contiene** esta contraseña: guarda sólo su hash SHA-256 y lo
compara en tiempo constante (`CredencialesPrueba.verificar`).

## Requisitos

| # | Requisito | Implementación |
|---|---|---|
| 1 | Campos usuario y contraseña | `TextFormField` × 2 |
| 2 | Ambos con información | "Escribe tu usuario" / "Escribe tu contraseña" |
| 3 | Rechazar entradas largas | Usuario ≤ 30 y contraseña ≤ 64. El contador se muestra pero **no trunca** (`MaxLengthEnforcement.none`), así que lo largo se rechaza con mensaje |
| 4 | Contraseña oculta | `obscureText`, sin autocorrección, sin sugerencias y sin aprendizaje del teclado (`enableIMEPersonalizedLearning: false`) |
| 5 | Errores genéricos | Credenciales incorrectas → siempre "Usuario o contraseña incorrectos.", sin decir cuál falló; espera fija de 400 ms en ambos casos |
| 6 | Nada sensible en Logcat | `LogSeguro` no tiene parámetro para la contraseña, enmascara el usuario (`a***q (11)`) y sólo imprime en compilación debug. La pantalla muestra lo registrado como evidencia |
| 7 | Acceso simulado | "Acceso concedido (simulado). Bienvenido, alumno.uteq." |
| + | Usuario de puros espacios | "El usuario no puede contener solo espacios" |
| + | Contraseña ≥ 8 | "La contraseña debe tener al menos 8 caracteres" |

**Medidas extra:**
- El usuario sólo admite letras, números, `.`, `-` y `_`, así que entradas
  como `admin' OR '1'='1` se rechazan.
- Tras 5 intentos fallidos se bloquea 30 s.
- La contraseña se borra del campo después de cada intento.

## Pruebas (`test/acceso_seguro_test.dart`)

| Entrada | Esperado |
|---|---|
| Usuario vacío | "Escribe tu usuario" |
| Usuario `"     "` | "El usuario no puede contener solo espacios" |
| Usuario de 31 caracteres | Rechazado |
| Contraseña `1234567` | "…al menos 8 caracteres" |
| Contraseña de 65 caracteres | Rechazada |
| `alumno.uteq` / `babywolf2026` | "Usuario o contraseña incorrectos." |
| `alumno.uteq` / `BabyWolf2026` | Acceso simulado |
| Registro tras un intento | No contiene la contraseña ni el usuario completo |
| 5 fallos | Bloqueo de 30 s |

En la app: pendiente de capturas por cada fila.
