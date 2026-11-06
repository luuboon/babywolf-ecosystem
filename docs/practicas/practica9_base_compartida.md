# Práctica 9 — Conexiones y pruebas de base de datos entre dispositivos

**En BabyWolf:** los **reportes de noticias**. Un lector ve un problema en una
noticia (imagen rota, dato incorrecto, enlace roto…) y lo reporta con la
bandera de arriba. El admin del blog, desde **otro teléfono**, lo ve en
Cuenta → *Reportes de lectores*, cambia su estado y prioridad, y el lector ve
esos cambios en Cuenta → *Mis reportes*.

Código: `phone_app/lib/reportes/`. Base: tabla `incidencias` de Supabase,
ampliada en `babywolf-blog/backend/sql/007_app_lectores.sql`.

## Firebase → Supabase

| Enunciado (Firebase) | BabyWolf (Supabase) |
|---|---|
| Proyecto de Firebase compartido | Proyecto de Supabase del blog (el mismo de la web) |
| Colección `incidencias` | Tabla `public.incidencias` |
| Documento | Fila (`id` UUID) |
| Firebase Console | Supabase → Table Editor / SQL Editor |
| Listener en tiempo real | Consulta automática cada 5 s mientras la pantalla está abierta |
| Estado "Pendiente / En proceso" | `abierta` → **Pendiente**, `en_proceso` → **En proceso**, `cerrada` → **Resuelto** |
| Prioridad, con "Crítica" | `baja`, `media`, `alta`, `critica` (la base rechaza otro valor) |

**Local vs. compartido:** las *noticias guardadas* (práctica 4) viven sólo en
SQLite del teléfono; otro dispositivo nunca las ve. Los *reportes* viven en
Supabase y los dos dispositivos leen y escriben la misma tabla. La app no
guarda copia local de los reportes.

## Quién ve y cambia qué

| | Lector (dueño) | Admin del blog |
|---|---|---|
| Ver | Sólo sus reportes | Todos |
| Crear | Sí (desde una noticia) | Sí |
| Estado | No | Sí |
| Prioridad | Sí | Sí |
| Descripción | Sí | No |
| Borrar | Sí, mientras esté Pendiente | No (lo cierra como Resuelto) |

Lo hace cumplir la base con RLS (práctica 10), no sólo la interfaz.

## Política de actualización (Fase 4)

1. **Sólo se envían los campos que cambiaste**, no el reporte entero. Si A
   cambia el estado y B la prioridad, no se pisan.
2. Cada reporte tiene un **número de versión** que la base sube en cada
   cambio (trigger `incidencias_versionar`), junto con quién hizo el cambio.
3. La app guarda con la condición **"versión = la que abrí"**. Si otro
   dispositivo guardó antes, la base no cambia nada (0 filas) y la app:
   - avisa *"Otro dispositivo guardó antes"* y dice qué campos cambió;
   - carga los valores nuevos;
   - **conserva en pantalla tus cambios sin guardar**, para revisarlos y
     volver a guardar.
4. Mientras tienes un reporte abierto, si otro dispositivo lo cambia, aparece
   un aviso ámbar; si tú no habías cambiado nada, se actualiza solo.

Resultado: **nunca se pierde un cambio confirmado sin que alguien lo vea.** Es
"gana el primero que guarda, y el segundo decide con la información nueva".

## Pérdida de conexión (DB-09)

Toda escritura pasa por `Supabase.enviar`, que convierte un fallo de red en
`SinConexion`. La app **sólo confirma cuando la base devuelve la fila**. Sin
red:
- al reportar, la hoja no se cierra, muestra "Sin conexión. No se guardó
  nada…" y conserva lo escrito;
- al guardar un cambio, el mensaje aparece arriba del botón y los cambios
  siguen pendientes;
- la lista muestra "Sin conexión: mostrando lo último que se consultó."

## Cómo hacer la práctica con dos dispositivos

Antes: ejecutar `007_app_lectores.sql` en el SQL Editor de Supabase (después
de 006). Tener dos cuentas: la del admin y una de lector, creada desde la app.

| Fase | Dispositivo A (lector) | Dispositivo B (admin) |
|---|---|---|
| 1 | Entrar con la cuenta de lector | Entrar con la cuenta admin. Supabase → Table Editor → `incidencias`: anotar el estado inicial |
| 2 | Abrir una noticia → bandera → motivo "Imagen rota" (es el título del reporte) y en detalles `PRUEBA_A_001` → Enviar. Debe confirmar "Reporte enviado (Pendiente)" | Cuenta → Reportes de lectores: el reporte aparece en ≤ 5 s sin tocar nada |
| 2 | — | Crear `PRUEBA_B_001` desde otra noticia |
| 3 | Mis reportes: ver que el de A pasa a "En proceso" | Abrir el de A → Estado: En proceso → Guardar |
| 3 | Cambiar la prioridad a Crítica → Guardar | Ver el cambio en ≤ 5 s |
| 4 | Abrir el reporte, cambiar la prioridad a Alta **sin guardar** | Abrir el mismo reporte, cambiar el estado a Resuelto y guardar |
| 4 | Guardar → aparece el aviso de conflicto con "cambió estado"; la prioridad Alta sigue en pantalla → Guardar otra vez | Ver el resultado final: Resuelto + Alta |
| 5 | Cerrar la app y abrirla: los reportes siguen | — |
| 5 | Modo avión → intentar reportar o guardar | — |

## Matriz de pruebas

**De dónde salen los resultados:**
- **[BD]:** `backend/pruebas/app_lectores.sh` contra Postgres 16 con los
  roles de Supabase y las reglas de 006 + 007. Ejecutado el 06/11/2026:
  **20/20**.
- **[FT]:** `phone_app/test/reportes_test.dart` (cliente HTTP simulado).
  Pendiente de ejecutar `flutter test` en la Mac.
- **[DISP]:** con dos dispositivos. **Pendiente.**

| ID | Prueba | Esperado | Resultado | Observación |
|---|---|---|---|---|
| DB-01 | Conexión compartida | Ambos dispositivos acceden al mismo proyecto y tabla | Pendiente [DISP] | Los dos usan la URL del proyecto del blog (`core/supabase.dart`); no hay base local de reportes |
| DB-02 | Escritura desde A | El reporte de A aparece en la base | **Pasa** [BD] · [FT] · [DISP] pendiente | Queda con dueño A y versión 1 aunque la app no mande el dueño |
| DB-03 | Lectura desde B | B recupera el reporte de A | **Pasa** [BD] (B = admin) · [DISP] pendiente | Un lector B **no** lo ve (SEG-05b): es la regla de la práctica 10 |
| DB-04 | Escritura desde B | El reporte de B se guarda | **Pasa** [BD] · [DISP] pendiente | |
| DB-05 | Lectura desde A | A recupera lo de B | Pendiente [DISP] | Sólo si A es admin; un lector ve sólo lo suyo |
| DB-06 | Actualización cruzada | El cambio confirmado se ve en el otro | **Pasa** [BD] (`en_proceso critica v2` visto por A) · [FT] · [DISP] pendiente | Tiempo esperado ≤ 5 s (intervalo de consulta) |
| DB-07 | Modificación concurrente | El resultado cumple la política | **Pasa** [BD]: guardar con versión vieja = 0 filas, se conserva el cambio ajeno; al recargar, se guarda y quedan los dos cambios · [FT]: `ConflictoVersion` | [DISP] pendiente |
| DB-08 | Persistencia | Los reportes siguen al cerrar y abrir la app | Pendiente [DISP] | Viven en Supabase; la sesión se recupera sola (práctica 5) |
| DB-09 | Pérdida de conexión | No se confirma un éxito falso | **Pasa** [FT] (`SinConexion` al crear y guardar) · [DISP] pendiente | |

## Riesgos de sincronización

- **Retraso de hasta 5 s:** no es tiempo real. Dos personas pueden ver un
  estado viejo durante unos segundos. El control de versión evita que eso
  termine en un cambio pisado, pero no evita ver datos atrasados.
- **Consultas cada 5 s cuestan batería y datos.** Sólo se hacen mientras la
  lista o el reporte están abiertos.
- **Supabase gratuito se pausa** por inactividad (pasó dos veces). Con el
  proyecto pausado ningún dispositivo puede leer ni escribir; la app lo
  muestra como error de conexión, sin éxito falso.
- **Sin cola offline para reportes:** sin red no se guarda nada (a propósito,
  para no mostrar un éxito que no ocurrió). La mesa de ayuda (práctica 7) sí
  tiene cola de pendientes.

## Conclusión técnica

Los dos dispositivos trabajan sobre la misma tabla de Supabase. La base, y no
la app, decide qué ve cada cuenta y detecta las ediciones simultáneas con un
número de versión, así que un cambio confirmado nunca se sobrescribe sin
aviso. La verificación en la base pasa 20/20; falta registrar la ejecución con
dos dispositivos y sus capturas.
