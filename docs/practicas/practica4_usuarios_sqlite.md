# Práctica 4 — Almacenamiento estructurado (SQLite)

App → 🧪 → *Usuarios · SQLite*. Los datos se guardan en
`babywolf_usuarios.db`, en el almacenamiento privado de la app.

## Room → sqflite

La práctica pide Room, que es de Kotlin/Android. BabyWolf es Flutter, por eso
se usa **sqflite**, que trabaja sobre el mismo SQLite del teléfono. Cada pieza
de Room tiene su equivalente:

| Room (Kotlin) | BabyWolf (Flutter) | Archivo |
|---|---|---|
| `@Entity data class Usuario` | `class Usuario` + `aMapa()`/`desdeMapa()` | `usuario.dart` |
| `@Dao interface UsuarioDao` | `class UsuarioDao` | `usuario_dao.dart` |
| `@Insert` / `@Query("SELECT * …")` / `@Update` / `@Delete` | `insertar` / `obtenerTodos` / `actualizar` / `eliminar` | `usuario_dao.dart` |
| `@Database(version = N)` | `BaseDatos.version` | `base_datos.dart` |
| `Migration(1, 2)` | `onUpgrade` → `_migrar` | `base_datos.dart` |

## Tabla `usuarios`

| Campo | Tipo | Descripción |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | Identificador |
| nombre | TEXT | Nombre del usuario |
| edad | INTEGER | Edad (15 a 99) |
| profesion | TEXT | Carrera |
| correo | TEXT | **Caso 4**: agregado en la versión 2 |

"VER usuarios" ejecuta `dao.obtenerTodos()` y muestra los registros.

## Casos

| Caso | Acción | Verificado |
|---|---|---|
| 1 — Insertar | Registrar tres estudiantes | `test/usuarios_dao_test.dart` · en la app: pendiente de captura |
| 2 — Consultar | VER usuarios | ídem |
| 3 — Actualizar | Cambiar la carrera de un estudiante (lápiz → ACTUALIZAR) | ídem |
| 4 — Campo correo | Ver abajo | ídem, incluye la migración de una base v1 real |

### Caso 4: qué se modificó

Está en un commit aparte (`feat(phone): practica 4 caso 4 …`) para ver la
diferencia exacta con `git show`:

| Capa | Cambio |
|---|---|
| Entity | Campo `correo`, en el mapeo, en `copiar()` y con validación |
| Base de datos | `version` 1 → 2; la columna se agrega en `onCreate` y con `ALTER TABLE` en `_migrar` |
| Interfaz | Campo "Correo" en el formulario; el correo se ve en la lista |
| Inserción | `aMapa()` incluye `correo` |
| Consulta | `desdeMapa()` lee `correo` (vacío para registros de la v1) |
| Actualización | `actualizar()` usa el mismo mapa |

**Lo que se observa:** si sólo se cambia el `CREATE TABLE`, un teléfono que ya
tenía la versión 1 nunca vuelve a ejecutarlo y la app falla con *"table
usuarios has no column named correo"*. Por eso cambiar la estructura obliga a
tocar también la versión y la migración.
