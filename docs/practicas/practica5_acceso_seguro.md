# Práctica 5 — Código seguro: AccesoSeguro

**En BabyWolf:** **iniciar sesión con la cuenta de BabyWolf**, la misma de la
web (Supabase Auth), en la pestaña **Cuenta**. También se puede crear una
cuenta. Con la sesión el lector comenta (P6) y reporta (P9), y el admin abre
la mesa de ayuda (P7).

Código: `phone_app/lib/core/sesion.dart`, `core/validacion.dart`,
`core/log_seguro.dart` y `lib/cuenta/`.

> **Lenguaje:** el enunciado pide Kotlin. BabyWolf es Flutter, así que se
> implementó en Dart y se prueba en el emulador de Android Studio. Las medidas
> de seguridad no dependen del lenguaje.

> **De simulado a real:** la versión anterior era un acceso simulado con un
> usuario de prueba (`alumno.uteq`). Ahora las mismas medidas protegen la
> cuenta real del blog.

## Requisitos

| # | Requisito | Implementación |
|---|---|---|
| 1 | Campos de usuario y contraseña | Correo y contraseña (Supabase usa el correo como usuario). Al crear cuenta, también nombre de usuario |
| 2 | Ambos obligatorios | "Escribe tu correo" / "Escribe tu contraseña" |
| 3 | Rechazar entradas largas o con formato inválido | Correo ≤ 120 y con formato `nombre@dominio.xx`; contraseña ≤ 72 (límite de bcrypt). Nombre de usuario 3–20 con `[a-zA-Z0-9._-]`. Lo inválido **no llega al servidor** |
| 4 | Contraseña oculta | `obscureText`, sin autocorrección, sin sugerencias ni aprendizaje del teclado; botón para mostrarla |
| 5 | Errores genéricos | Siempre "Correo o contraseña incorrectos.": no se dice si el correo existe ni si falta confirmarlo. Al crear cuenta: "Prueba con otro correo o nombre de usuario", sin decir cuál chocó |
| 6 | Nada sensible en Logcat | `LogSeguro` no tiene parámetro para contraseña ni token, enmascara el correo (`a***m@gmail.com`) y sólo imprime en depuración. Cuenta muestra la "Actividad reciente" con esos eventos |
| 7 | Acceso concedido | La cuenta queda abierta: nombre, correo, UID y rol (Lector / Admin) |
| + | Contraseña nueva robusta | Mínimo 8, con letras y números; se pide repetirla |
| + | Fuerza bruta | 5 fallos seguidos bloquean el botón 30 s, con cuenta regresiva. El bloqueo vive en la sesión de la app: salir de la pantalla no lo reinicia. Sin red no cuenta como fallo |
| + | Sesión guardada de forma segura | Sólo se guarda el **refresh token**, en `flutter_secure_storage` (Android Keystore). La contraseña no se guarda en ningún lado |
| + | Token de corta duración | El access token dura 1 hora y se renueva solo antes de vencer |
| + | Cerrar sesión | Invalida la sesión en Supabase y borra el token del teléfono |

## Pruebas (`test/cuenta_test.dart`)

| Entrada | Esperado |
|---|---|
| Correo vacío, `abraham@`, `x' OR 1=1 --` | Rechazado sin llamar al servidor |
| Contraseña de 73 caracteres | Rechazada |
| Contraseña nueva `abc123` / `soloLetras` / `12345678` | Rechazada |
| Credenciales correctas | Sesión abierta, rol leído de la tabla del blog, refresh token guardado |
| Contraseña incorrecta | "Correo o contraseña incorrectos." y nada guardado |
| 5 fallos | Bloqueo de 30 s **sin** llamar al servidor; a los 31 s se puede entrar |
| Sin conexión | Mensaje de conexión; no cuenta como intento |
| A 30 s de vencer el token | Se renueva solo |
| Reabrir la app con sesión guardada | Entra directo; sin red conserva el token para después |
| Refresh token inválido | Se borra y queda sin sesión |
| Cerrar sesión | Token borrado y `token()` rechaza |
| Registro de eventos | Correo enmascarado; ningún parámetro para la contraseña |

**En el emulador** (versión anterior, acceso simulado, 05/11/2026): acceso
correcto, credencial incorrecta con mensaje genérico, validación de longitud
y bloqueo tras 5 fallos ("Espera 25 s"). Falta repetirlo con la cuenta real.

## Para probar en el dispositivo

Hace falta una cuenta de BabyWolf: la del admin del blog, o una nueva creada
desde la app con "¿No tienes cuenta? Crear una". Si Supabase tiene activada la
confirmación por correo, hay que confirmarla antes de entrar.
