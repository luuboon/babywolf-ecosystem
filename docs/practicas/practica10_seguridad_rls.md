# Práctica 10 — Seguridad, autenticación y control de acceso a una base compartida

App → 🧪 → *Práctica 10 · Incidencias seguras*
(`phone_app/lib/laboratorio/p10_incidencias/`). Las reglas están en el repo
`babywolf-blog`, en `backend/sql/006_incidencias_rls.sql`.

## Firebase → Supabase

El enunciado está escrito para Firebase. BabyWolf usa Supabase, que tiene una
pieza equivalente para cada una:

| Firebase (enunciado) | Supabase (BabyWolf) |
|---|---|
| Firebase Authentication, proveedor correo/contraseña | Supabase Auth, proveedor *Email* (el mismo que usa el blog) |
| UID del usuario | `auth.users.id`; llega en el JWT como `sub` |
| Colección `incidencias` en Firestore | Tabla `public.incidencias` en Postgres |
| Campo `creadoPor` | Columna `creado_por` |
| Reglas de seguridad de Firestore | Políticas de **Row Level Security** (RLS) de Postgres |
| SDK de Firestore en la app | API REST de Supabase con el JWT del usuario |

Lo importante se cumple igual: la app habla **directo con la base** y la base
decide. La app no filtra ni oculta nada por su cuenta; si una operación no
está permitida, Postgres la rechaza aunque alguien modifique la app.

## Fase 1 — Autenticación

- El proveedor *Email* de Supabase Auth ya está activo (el blog lo usa para
  iniciar sesión).
- Cuentas de prueba: se crean en Supabase → Authentication → Users → *Add
  user* (por ejemplo `usuario.a@…` y `usuario.b@…`).
- Al iniciar sesión, la app muestra el **correo y el UID**, con botón para
  copiarlo. El UID se toma de la respuesta de Supabase Auth y coincide con el
  `sub` del JWT.

## Fase 2 — Registros con propietario

- "Registrar" envía `creado_por = UID` de forma explícita.
- Si no se envía, la columna toma `auth.uid()` por defecto.
- Para verificar los propietarios, en el SQL Editor de Supabase (como
  administrador, que no está sujeto a RLS):

```sql
select i.id, i.titulo, i.estado, u.email as propietario, i.creado_por
from public.incidencias i join auth.users u on u.id = i.creado_por
order by i.created_at;
```

## Fase 3 — Reglas de seguridad y qué significa cada condición

```sql
REVOKE ALL ON public.incidencias FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.incidencias TO authenticated;
ALTER TABLE public.incidencias ENABLE ROW LEVEL SECURITY;

CREATE POLICY incidencias_leer_propias   ON public.incidencias FOR SELECT TO authenticated
  USING (creado_por = (select auth.uid()));
CREATE POLICY incidencias_crear_propias  ON public.incidencias FOR INSERT TO authenticated
  WITH CHECK (creado_por = (select auth.uid()));
CREATE POLICY incidencias_editar_propias ON public.incidencias FOR UPDATE TO authenticated
  USING (creado_por = (select auth.uid())) WITH CHECK (creado_por = (select auth.uid()));
CREATE POLICY incidencias_borrar_propias ON public.incidencias FOR DELETE TO authenticated
  USING (creado_por = (select auth.uid()));
```

| Pieza | Qué hace | Casos |
|---|---|---|
| `REVOKE ALL … FROM anon` | Sin sesión no hay ningún permiso sobre la tabla: la base responde *permission denied* | SEG-10 |
| `TO authenticated` | Las reglas sólo aplican a quien trae un JWT válido de Supabase Auth | SEG-01 |
| `auth.uid()` | El UID sale del JWT firmado, no de lo que mande la app; no se puede falsificar | Todos |
| `USING (creado_por = auth.uid())` | Filtra qué filas **existen** para el usuario al leer, cambiar o borrar. Las ajenas no se ven ni se tocan | SEG-05, SEG-06, SEG-07 |
| `WITH CHECK (creado_por = auth.uid())` en INSERT | La fila nueva debe ser del usuario: no se puede crear a nombre de otro | SEG-03, SEG-04 |
| `WITH CHECK` en UPDATE | La fila *después* del cambio también debe ser del usuario: no se puede regalar una incidencia | SEG-08, SEG-09 |
| `(select auth.uid())` | Se calcula una vez por consulta y no por fila (recomendación de rendimiento de Supabase) | — |

## Fase 4 — Pruebas con dos dispositivos

1. Dispositivo A inicia sesión con el usuario A; dispositivo B con el usuario B.
2. A registra dos incidencias y B registra una.
3. En B, copiar su **UID** y el **ID** de su incidencia (botones de copiar).
   Pegarlos en A, en "Fase 4 · Intentos no autorizados". Entre emuladores, el
   portapapeles se comparte con la Mac.
4. En A, pulsar cada botón SEG-04 a SEG-10. Cada intento queda en la bitácora
   con el resultado esperado, el obtenido y si **PASA**.
5. Cerrar sesión y pulsar "Intentar sin sesión" (SEG-10).
6. "Copiar bitácora" deja la matriz lista para pegar en el reporte.

**Cómo contesta la base:**
- Escribir una fila que viola una regla (SEG-04, SEG-09) o actuar sin sesión
  (SEG-10) devuelve error **42501**.
- Leer, cambiar o borrar algo ajeno (SEG-05, SEG-06, SEG-07) devuelve **0
  filas**: para RLS esas filas no existen para ese usuario. La app lo registra
  como rechazo.

## Fase 5 — Matriz de pruebas de seguridad

**De dónde salen los resultados:**
- **[BD]:** `backend/pruebas/rls_incidencias.sh` ejecuta cada operación con los
  roles de Supabase (`authenticated` con el JWT del usuario, y `anon`) sobre
  las mismas reglas, en Postgres 16. Se corrió el 29/10/2026 con resultado
  **9/9**.
- **[APP]:** falta ejecutarlo en los dos dispositivos con capturas.

| ID | Acción | Esperado | Resultado | Evidencia |
|---|---|---|---|---|
| SEG-01 | Ingresar con la cuenta de A | Autenticación exitosa | Pendiente [APP] | Captura con correo y UID de A, y otra de B (UID distinto) |
| SEG-02 | Contraseña incorrecta | Acceso rechazado | Pendiente [APP] | Mensaje genérico "Correo o contraseña incorrectos." |
| SEG-03 | A registra una incidencia con su UID | Creada con propietario A | **Pasa** [BD] · [APP] pendiente | `creado_por` = UID de A; consulta de la Fase 2 |
| SEG-04 | A crea indicando el UID de B | Rechazada por la base | **Pasa** [BD]: `new row violates row-level security policy` | Bitácora de A |
| SEG-05 | A lee la incidencia de B por su ID | Lectura denegada | **Pasa** [BD]: 0 filas visibles | Bitácora de A |
| SEG-06 | A modifica la incidencia de B | Actualización denegada | **Pasa** [BD]: 0 filas cambiadas, B sigue `abierta` | Bitácora de A + estado en B |
| SEG-07 | A elimina la incidencia de B | Eliminación denegada | **Pasa** [BD]: 0 filas borradas, B sigue existiendo | Bitácora de A + lista de B |
| SEG-08 | A cambia el estado de su incidencia | Permitida | **Pasa** [BD]: `en_proceso` | Bitácora de A |
| SEG-09 | A cambia el propietario de su incidencia a B | Rechazado | **Pasa** [BD]: `new row violates row-level security policy`; sigue siendo de A | Bitácora de A |
| SEG-10 | Sin sesión: leer y escribir | Rechazado | **Pasa** [BD]: `permission denied for table incidencias` (las dos) | Bitácora sin sesión |

Caso extra [BD]: B consulta todas las incidencias y sólo recibe la suya (1 de 3).

---

## Reporte técnico

**Objetivo.** Que cada usuario sólo pueda operar sobre sus propias incidencias,
y que la base de datos lo garantice aunque la app sea alterada.

**Defectos encontrados**

1. **Tabla sin reglas.** Con la tabla creada pero sin RLS (control negativo
   del script), 7 de 9 casos fallaron: A leyó, cerró y borró la incidencia de
   B, se crearon registros a nombre de otro, y sin sesión se leían todos los
   datos. Es el estado en el que queda cualquier tabla nueva hasta que se
   activa RLS.
2. **Sin sesión daba "vacío" y no error.** Con RLS pero sin quitar permisos al
   rol `anon`, una lectura sin sesión devolvía una lista vacía. Eso parece
   correcto en la interfaz, pero no demuestra el rechazo que pide SEG-10.
3. **Los rechazos de UPDATE y DELETE son silenciosos.** Postgres no da error al
   tocar filas ajenas: responde 0 filas, porque para ese usuario no existen.
   Una app que sólo revise el código HTTP mostraría "éxito".

**Correcciones**

1. `ENABLE ROW LEVEL SECURITY` con una política por operación, todas sobre
   `creado_por = auth.uid()`. El UPDATE lleva `USING` y `WITH CHECK` para
   impedir también el cambio de propietario.
2. `REVOKE ALL … FROM anon`: sin sesión la base responde *permission denied*.
3. La app pide `Prefer: return=representation` y cuenta las filas afectadas.
   0 filas se registra como **rechazado**, no como éxito.
4. Se repitieron las pruebas fallidas: **9/9** con las reglas aplicadas.

**Riesgos pendientes**

- La llave `anon` va dentro de la app y es pública por diseño. La seguridad no
  depende de ocultarla, sino de RLS. En cambio, la `service_role` que usa el
  backend en Railway **salta RLS**: si se filtrara, las reglas no protegerían
  nada.
- Las cuentas de prueba deben borrarse o tener contraseñas fuertes al terminar
  la práctica.
- El JWT dura 1 hora y la app no lo renueva: pasado ese tiempo hay que volver
  a iniciar sesión. Es incómodo, pero no inseguro.
- La app entra sólo con contraseña. Si la cuenta tiene segundo factor en la
  web, la app no lo pide.
- Supabase en plan gratuito se pausa por inactividad (ya ocurrió dos veces). Es
  un riesgo de disponibilidad, no de seguridad.

**Conclusión.** Las reglas impiden en el servidor todas las operaciones no
autorizadas de la matriz, y el control negativo demuestra que sin ellas esas
operaciones sí ocurrían. Falta la ejecución en los dos dispositivos para
completar las evidencias [APP] de SEG-01, SEG-02 y las capturas.
