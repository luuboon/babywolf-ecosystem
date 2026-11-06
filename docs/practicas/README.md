# Prácticas de laboratorio aplicadas a BabyWolf

BabyWolf es la app del teléfono del blog **BabyWolf** (noticias de videojuegos
retro y consolas). Lo que hace el blog en la web —leer noticias, tener una
cuenta, el equipo que administra el sitio— es lo que la app debe hacer en el
teléfono.

Por eso las prácticas **no son pantallas de demostración aparte**. De cada una
se tomó lo esencial y se implementó como una función real de la app, donde
tiene sentido para un lector o para el equipo del blog. Las que no tienen uso
en una app de noticias quedan fuera, con su justificación.

## Dónde quedó cada práctica

| # | Práctica | Función de BabyWolf | Dónde se ve en la app | Código | Documento |
|---|---|---|---|---|---|
| 1 | IoT: ESP32 + sensor IR | **No se integra** | — | `firmware/` (anexo) | [práctica 1](practica1_iot_esp32.md) |
| 2 | Firmware: controlador LED | **No se integra** | — | `firmware/` (anexo) | [práctica 2](practica2_firmware.md) |
| 3 | ConsultaWeb: URL preasignada | Resumen del blog arriba del feed, que además filtra por tema | Noticias → tarjeta de resumen | `lib/resumen/` | [práctica 3](practica3_consulta_web.md) |
| 4 | Almacenamiento estructurado | **Noticias guardadas** para leer sin internet, con nota personal | Pestaña Guardadas · marcador en cada noticia | `lib/guardadas/` | [práctica 4](practica4_guardadas_sqlite.md) |
| 5 | Código seguro: AccesoSeguro | **Iniciar sesión con la cuenta de BabyWolf** (la misma de la web) | Pestaña Cuenta | `lib/core/sesion.dart`, `lib/cuenta/` | [práctica 5](practica5_acceso_seguro.md) |
| 6 | Interacción entre dispositivos | **Comentarios** en cada noticia, entre lectores de distintos teléfonos | Final de cada noticia | `lib/comentarios/` | [práctica 6](practica6_comentarios.md) |
| 7 | Roles e interacción (4 dispositivos) | **Mesa de ayuda del equipo** del blog: admin, agente y usuarios invitados | Cuenta → Mesa de ayuda del equipo | `lib/soporte/` + backend | [práctica 7](practica7_mesa_ayuda.md) |
| 8 | Pruebas de caja negra | Evaluación de todo lo anterior | — | `test/`, `backend/pruebas/` | [práctica 8](practica8_caja_negra.md) |
| 9 | Base compartida entre dispositivos | **Reportes de noticias**: el lector reporta, el admin atiende y ambos ven los cambios | Bandera en cada noticia · Cuenta → Mis reportes | `lib/reportes/` | [práctica 9](practica9_base_compartida.md) |
| 10 | Seguridad y control de acceso | Reglas de quién ve y cambia qué reporte y comentario, aplicadas por la base | Cuenta (UID y rol) · Mis reportes | `007_app_lectores.sql` (repo blog) | [práctica 10](practica10_seguridad_rls.md) |

Las prácticas se apoyan unas en otras, como en una app real: la cuenta (5 y
10) es la que permite comentar (6), reportar (9) y abrir la mesa de ayuda
como admin (7).

## Cómo se navega

```
Noticias ─┬─ Lupa: buscar noticias por texto (se combina con el tema)
          ├─ Resumen del blog (P3) → filtra el feed por tema
          └─ Noticia ─┬─ Marcador: guardar para leer sin internet (P4)
                      ├─ Bandera: reportar un problema (P9)
                      └─ Comentarios (P6)
Guardadas ── lista local con nota personal (P4)
Cuenta ───┬─ Entrar / crear cuenta (P5)
          ├─ Correo, UID y rol (P10)
          ├─ Mis reportes · Reportes de lectores si eres admin (P9, P10)
          ├─ Mesa de ayuda del equipo (P7)
          └─ Actividad reciente sin datos sensibles (P5)
```

## Lo que no se implementó al pie de la letra, y por qué

| Requisito del enunciado | Qué se hizo | Justificación |
|---|---|---|
| P1 y P2: ESP32, sensor IR, LED y botón | Fuera de la app; firmware en `firmware/` como anexo | Un blog de noticias no tiene ningún caso de uso para un sensor de proximidad ni para un LED. Meterlo sería una pantalla ajena al producto. Además el emulador no tiene radio Bluetooth. Las prácticas se hicieron en clase con el circuito. |
| P3 y P6: "crear una aplicación ConsultaWeb / MobileConnect" | Funciones dentro de BabyWolf | El proyecto del curso es extender BabyWolf. Lo que se evalúa (petición a URL firmada, mensajes entre dispositivos) está intacto. |
| P3: pantalla con botón CONSULTAR | La consulta ocurre al abrir el feed y al deslizar para recargar | En una app real el resumen se muestra solo. Los estados que pide la práctica (consultando, datos, error y reintento) siguen en la tarjeta. |
| P4: Room y entidad "usuario" (nombre, edad, profesión, correo) | SQLite con `sqflite`; entidad "noticia guardada" | Room es de Kotlin y BabyWolf es Flutter: `sqflite` usa el mismo motor SQLite, con entidad, DAO y base versionada. Las cuentas de usuario ya existen en Supabase (son las de la web); copiarlas al teléfono no tendría uso. Lo que un lector sí guarda en su teléfono son noticias para leer sin internet. El CRUD es el mismo. |
| P5: Kotlin, usuario y contraseña de prueba | Dart; inicio de sesión real con Supabase Auth | Mismo motivo de lenguaje. En vez de un acceso simulado, se aplican las medidas a la cuenta real del blog, que es más exigente: además se guarda la sesión cifrada y se renueva el token. |
| P6: Dispositivo A / B y selector de emisor | Cada teléfono comenta con su cuenta | Elegir "soy A" o "soy B" permitiría escribir a nombre de otro (contrario a la P5). El emisor lo fija la sesión y la base lo comprueba. |
| P7, P9 y P10: Firebase (Firestore, Auth, reglas) | Supabase: Postgres, Auth y Row Level Security | BabyWolf ya usa Supabase (la web y el backend). Agregar Firebase metería un segundo proveedor sólo para las prácticas. RLS es el equivalente directo de las reglas de Firestore. |
| P9: colección "incidencias" de empleados | Reportes que hacen los lectores sobre una noticia | Es el caso real de BabyWolf. Se conservan las pruebas: dos dispositivos, la misma base, cambios cruzados, conflictos y pérdida de conexión. |
| P9: actualización en tiempo real | Consulta automática cada 5 s | Supabase Realtime necesitaría otra dependencia y canales WebSocket. Con 5 s se ve el cambio del otro dispositivo sin tocar nada, y el tiempo queda medido en la matriz. |
| P10: el lector intenta a propósito tocar datos ajenos | Pantalla de verificación sólo en depuración | La interfaz normal no ofrece esas acciones, y no debe. Para la evidencia, Cuenta muestra en modo depuración una pantalla que hace los intentos SEG-04…SEG-10. |

## Qué cambió en el backend y la base

- `babywolf-blog/backend/sql/007_app_lectores.sql`: reportes con noticia,
  prioridad y versión; el admin ve y atiende todos; reglas de comentarios.
  Probado en Postgres 16 con los roles de Supabase:
  `pruebas/app_lectores.sh` **20/20**, y `pruebas/rls_incidencias.sh` sigue
  en **9/9**.
- `babywolf-blog/backend/sql/008_permisos_usuarios.sql`: cierra la escalada a
  admin por la tabla `users` y protege la bitácora y el bloqueo por intentos
  (práctica 10). `pruebas/usuarios_permisos.sh` **25/25**.
- Los endpoints `/api/consulta/*` (P3) y `/api/soporte/*` (P7) se usan sin
  cambios. `/api/connect/*` (canal efímero de la versión anterior de la P6)
  queda sin uso en la app.
