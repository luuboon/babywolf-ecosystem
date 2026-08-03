# hub — el "aire" del ecosistema

```bash
dart run hub/hub.dart     # escucha en :8090
```

Cero dependencias: sólo `dart:io`.

| Ruta | Método | Para qué |
|---|---|---|
| `/gatt` | WebSocket | GATT emulado. El wearable publica `{uuid, bytes}` y el hub lo reenvía a los demás suscritos: eso es el NOTIFY. No interpreta los bytes, igual que no lo haría una radio. |
| `/state` | GET | La TV consulta cada segundo qué noticia está viendo el teléfono. |
| `/state` | POST | El teléfono publica `{slug, category}` al abrir una noticia. |
| `/health` | GET | Responde `ok`. Sirve para confirmar que está arriba. |

Desde los emuladores Android el host es `10.0.2.2:8090`; desde la PWA en la
laptop, `localhost:8090`.
