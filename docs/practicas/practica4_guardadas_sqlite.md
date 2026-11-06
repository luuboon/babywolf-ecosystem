# Práctica 4 — Almacenamiento estructurado (SQLite)

**En BabyWolf:** **noticias guardadas**. En cada noticia, el marcador de
arriba la guarda en el teléfono. La pestaña **Guardadas** las lista y se
pueden leer **sin internet**, porque se guarda la noticia completa. A cada una
se le puede escribir una nota personal.

Código: `phone_app/lib/guardadas/`. Archivo de la base:
`babywolf_local.db`, en el almacenamiento privado de la app.

## Por qué "noticias guardadas" y no "usuarios"

La práctica pide registrar usuarios (nombre, edad, profesión, correo). En
BabyWolf las cuentas ya existen en Supabase: son las mismas de la web, y la
app entra con ellas (práctica 5). Copiarlas a una tabla local no tendría
ningún uso para el lector.

Lo que un lector sí quiere conservar en su teléfono son las noticias que le
interesan, para leerlas después aunque no tenga conexión. El ejercicio es el
mismo: una entidad, su DAO, una base versionada y las cuatro operaciones.

## Room → sqflite

Room es de Kotlin/Android. BabyWolf es Flutter, por eso se usa **sqflite**,
que trabaja sobre el mismo SQLite del teléfono.

| Room (Kotlin) | BabyWolf (Flutter) | Archivo |
|---|---|---|
| `@Entity` | `class Guardada` + `aMapa()` / `desdeMapa()` | `guardadas.dart` |
| `@Dao` | `class GuardadaDao` | `guardadas.dart` |
| `@Insert` / `@Query` / `@Update` / `@Delete` | `insertar` / `obtenerTodas` / `actualizarNota` / `eliminar` | `guardadas.dart` |
| `@Database(version = N)` | `BaseDatos.version` + `_migrar` | `base_datos.dart` |
| ViewModel | `class Guardadas` (ChangeNotifier) | `guardadas.dart` |

## Tabla `guardadas`

| Campo | Tipo | Descripción |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | Identificador local |
| post_id | TEXT UNIQUE | Id de la noticia en el blog. Único: no se guarda dos veces |
| slug, titulo, categoria, contenido, portada_url, publicada | TEXT | La noticia completa, para leerla sin conexión |
| nota | TEXT | Nota personal del lector (máximo 500 caracteres) |
| guardada_en | TEXT | Cuándo se guardó (la lista se ordena por aquí) |

## Las cuatro operaciones en la app

| Operación | Dónde | Método |
|---|---|---|
| Insertar | Marcador en el detalle de la noticia | `insertar` (si ya estaba, no duplica) |
| Consultar | Pestaña Guardadas; también el contador en la barra inferior | `obtenerTodas` |
| Modificar | Tocar la nota en el detalle → escribir → Guardar | `actualizarNota` |
| Eliminar | Quitar el marcador, o deslizar la fila en Guardadas (pide confirmación) | `eliminar` |

## Pruebas

| Caso | Verificado |
|---|---|
| Insertar tres noticias | `test/guardadas_test.dart` |
| Consultar en orden y con el contenido completo | ídem |
| No duplicar la misma noticia | ídem |
| Modificar la nota (y 0 filas si ya no existe) | ídem |
| Eliminar | ídem |
| Nota de 500 / 501 caracteres | ídem |
| Persistencia al cerrar y abrir la base (archivo real) | ídem |
| En el emulador | La versión anterior pasó el CRUD y la persistencia al cerrar la app el 05/11/2026. Falta repetirlo con Guardadas |

**Lección de la versión anterior (Caso 4):** si se cambia la estructura de una
tabla sólo en el `CREATE TABLE`, un teléfono que ya tenía la base no vuelve a
ejecutarlo y la app falla. Por eso cada cambio sube `BaseDatos.version` y
agrega su paso en `_migrar`. La tabla `guardadas` empieza en la versión 1 de
un archivo nuevo.
