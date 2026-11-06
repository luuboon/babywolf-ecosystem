# Práctica 6 — Interacción entre dispositivos: comentarios

**En BabyWolf:** los **comentarios** al final de cada noticia. Lo esencial de
MobileConnect es que dos teléfonos se manden mensajes por un canal compartido
y cada mensaje diga quién lo mandó, a qué hora, con un contador. En BabyWolf
ese canal es la noticia: cada noticia es una "sala" y cada lector, con su
cuenta, es un emisor.

Código: `phone_app/lib/comentarios/`. Datos: tabla `comments` del blog en
Supabase (existía en el esquema inicial y la web no la usaba), con reglas en
`007_app_lectores.sql`.

## Cómo se comunican dos teléfonos

1. Teléfono A y teléfono B abren **la misma noticia**, cada uno con su cuenta.
2. A escribe y publica: el comentario se guarda en Supabase.
3. La sección de comentarios de B consulta cada **5 s** mientras la noticia
   está abierta, y el comentario de A aparece solo.

A diferencia de la versión anterior (sala en memoria del backend), los
comentarios **persisten**: siguen ahí al cerrar la app o si Railway reinicia.

## Requisitos

| # | Requisito de MobileConnect | En BabyWolf |
|---|---|---|
| 1 | Nombres de los dos dispositivos | Cada comentario muestra el **nombre de usuario** de su autor; los tuyos dicen "Tú" y van resaltados |
| 2 | Seleccionar el emisor | No se elige: el emisor es la cuenta con la que entraste. La base comprueba que `author_id` sea el del token (nadie comenta a nombre de otro) |
| 3 | Campo de texto | "Comentar como …", con contador `n/280` |
| 4 | Enviar al otro dispositivo | Botón de enviar; el otro lo ve en ≤ 5 s |
| 5 | Mensaje y emisor en la lista | Autor, hora y fecha en cada comentario |
| 6 | Evitar vacíos | La app y la base rechazan vacíos y > 280 caracteres |
| 7 | Notificación visual | El comentario aparece al instante en tu lista; error visible si no se publicó |
| + | Contador | "COMENTARIOS · N" y "Tuyos: k" |
| + | Borrar | Cada quien borra los suyos; el admin puede moderar cualquiera |
| + | Sin sesión | Se pueden leer; para comentar aparece "Inicia sesión para comentar" |
| + | Sin red | No se finge el envío: el texto se queda en el campo con el aviso |

## Pruebas

| Prueba | Verificado |
|---|---|
| Vacío, sólo espacios y 281 caracteres se rechazan en la app | `test/comentarios_test.dart` |
| …y en la base | `backend/pruebas/app_lectores.sh` COM-05, COM-06 |
| La app no manda el autor; la base lo toma del token | `comentarios_test.dart` + COM-01 |
| Comentar a nombre de otro | Rechazado por RLS (COM-04) |
| Sin sesión: leer sí, comentar no | COM-02, COM-03 |
| Borrar el comentario ajeno / moderar como admin | COM-07 (0 filas) / COM-08 (1 fila) |
| Contador por autor y hora local | `comentarios_test.dart` |
| A → B entre dos teléfonos | Pendiente de captura (emulador + teléfono, o dos emuladores) |
