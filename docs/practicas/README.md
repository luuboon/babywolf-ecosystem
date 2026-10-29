# Prácticas de laboratorio aplicadas a BabyWolf

Todas las prácticas se implementaron **sobre la app existente** (`phone_app/`),
no como apps nuevas. Se abren desde el feed de noticias con el botón 🧪
**Prácticas de laboratorio**. Reutilizan el backend Go del blog (Railway), la
base de datos Supabase y el tema visual del blog.

| # | Práctica | Estado | Dónde está | Documento |
|---|---|---|---|---|
| 1 | IoT: ESP32 + sensor IR + móvil | Implementada (Bluetooth real + modo simulado) | `phone_app/lib/laboratorio/p1_iot`, `SppBridge.kt`, `firmware/` | [práctica 1](practica1_iot_esp32.md) |
| 2 | Firmware: Controlador LED | Firmware en el repo; la app muestra el botón con el firmware combinado | `firmware/` | [práctica 2](practica2_firmware.md) |
| 3 | ConsultaWeb: URL preasignada | Implementada como módulo de BabyWolf | `p3_consulta`, backend `/api/consulta/*` | [práctica 3](practica3_consulta_web.md) |
| 4 | Almacenamiento estructurado | Implementada con SQLite (sqflite) en vez de Room | `p4_usuarios` | [práctica 4](practica4_usuarios_sqlite.md) |
| 5 | Código seguro: AccesoSeguro | Implementada en Flutter/Dart en vez de Kotlin | `p5_acceso` | [práctica 5](practica5_acceso_seguro.md) |
| 6 | Interacción entre dispositivos | Implementada (MobileConnect) | `p6_connect`, backend `/api/connect/*` | [práctica 6](practica6_mobile_connect.md) |
| 7 | Roles masivos e interacción | Implementada con Supabase en vez de Firestore | `p7_soporte`, backend `/api/soporte/*`, `005_soporte.sql` | [práctica 7](practica7_mesa_ayuda.md) |
| 8 | Pruebas de caja negra | Matriz de requisitos y casos | — | [práctica 8](practica8_caja_negra.md) |
| 10 | Seguridad y control de acceso | Implementada con Supabase Auth + RLS en vez de Firebase | `p10_incidencias`, `006_incidencias_rls.sql` (repo blog) | [práctica 10](practica10_seguridad_rls.md) |

## Lo que no se implementó al pie de la letra, y por qué

| Requisito del enunciado | Qué se hizo | Justificación |
|---|---|---|
| P3 y P6: "crear una aplicación denominada ConsultaWeb / MobileConnect" | Son pantallas dentro de BabyWolf | El enunciado de la P3 permite usar el propio proyecto como base, y el proyecto del curso es extender BabyWolf. Una app aparte duplicaría tema, red y configuración sin aportar nada a lo que se evalúa (la petición HTTP y el intercambio de mensajes). |
| P4: Room | SQLite con `sqflite` | Room es una biblioteca de Kotlin para Android. BabyWolf está escrita en Flutter (Dart), y en Flutter Room no se puede usar directo. `sqflite` usa el **mismo motor SQLite** del teléfono y tiene las mismas piezas: entidad, DAO, base de datos versionada y migración (ver la equivalencia en el documento de la P4). |
| P5: Kotlin y Android Studio | Dart/Flutter, probada en el emulador de Android Studio | Mismo motivo. Las 7 medidas de seguridad son independientes del lenguaje y todas se implementaron. Android Studio sigue siendo el IDE y el emulador. |
| P1: prueba con hardware | Código Bluetooth real + modo simulado | La práctica con el ESP32 ya se hizo en clase, pero ahorita el circuito no está armado y el teléfono físico no está a la mano. El emulador no tiene radio Bluetooth. La evidencia con hardware queda pendiente y el modo simulado permite mostrar la pantalla. |
| P2: interfaz en la app | Ninguna obligatoria | La práctica 2 es sólo de firmware (monitor serial). Como extensión, `firmware/iot_combinado` manda el botón por Bluetooth y la app lo muestra. |
| P10: Firebase Authentication + reglas de Firestore | Supabase Auth + Row Level Security de Postgres | Mismo motivo que la P7. RLS es el equivalente directo de las reglas de Firestore: la base rechaza lo no autorizado aunque la app se modifique. |
| P7: Firestore | Postgres de Supabase a través del backend Go | BabyWolf ya usa Supabase y el backend en Railway. Agregar Firebase metería un segundo proveedor sólo para una práctica. Los casos TC01–TC08 se cumplen igual, y TC08 se verifica sobre Postgres. |
| P7: "seleccionar el dispositivo emisor (administrador)" | Cada dispositivo envía como sí mismo; el admin elige **destinatario** | Que un dispositivo pueda mandar mensajes a nombre de otro sería suplantación, contrario a la práctica 5. El emisor lo fija el token de sesión en el servidor. |
| P7: "mostrar los nombres de los dos dispositivos conectados" | Se muestran los 4 (admin, agente, 2 usuarios) | La misma práctica pide 4 dispositivos; se listan todos con su estado. |
