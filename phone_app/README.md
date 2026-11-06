# phone_app — BabyWolf en el teléfono

App Flutter (Android) del blog BabyWolf, de noticias de videojuegos retro y
consolas. Lee las noticias del backend y usa la cuenta de la web.

## Pestañas

| Pestaña | Qué hace | Código |
|---|---|---|
| Noticias | Feed con **búsqueda** (lupa), resumen del blog y filtro por tema | `lib/screens`, `lib/resumen`, `lib/services/busqueda.dart` |
| Guardadas | Noticias guardadas en SQLite para leer sin internet, con nota | `lib/guardadas` |
| Cuenta | Entrar o crear cuenta, UID y rol, reportes, mesa de ayuda | `lib/cuenta`, `lib/core/sesion.dart` |

En cada noticia: guardar (marcador), reportar un problema (bandera) y
comentarios. Detalle de qué práctica cubre cada función:
[`../docs/practicas/README.md`](../docs/practicas/README.md).

## Seguridad: léelo antes de tocar la base o la cuenta

- La seguridad está en las reglas de Supabase, no en la app. Qué ve y cambia
  cada rol, qué falta y las reglas para cambios futuros:
  **[`../docs/SEGURIDAD_CUENTAS.md`](../docs/SEGURIDAD_CUENTAS.md)**.
- Los scripts de la base están en el repo `babywolf-blog/backend/sql`
  (`005` a `008`, en orden). Sin `007` no funcionan los reportes con
  prioridad ni los comentarios; sin `008`, un usuario puede hacerse admin.
- La app **nunca** lleva la llave `service_role`. La llave `anon` es pública
  por diseño.
- La sesión guarda sólo el refresh token en el almacenamiento cifrado de
  Android. La contraseña no se guarda.

## Probar

```bash
flutter pub get && flutter analyze && flutter test   # 70 pruebas al 06/11/2026
flutter run                                          # con el Pixel (no "Chrome")
```

Los reportes y comentarios se sincronizan consultando cada 5 s, no en tiempo
real. En modo depuración, Cuenta muestra una pantalla de verificación de
reglas (SEG-04…SEG-10).
