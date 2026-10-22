# Práctica 6 — Interacción entre dispositivos: MobileConnect

App → 🧪 → *MobileConnect*. Código en `p6_connect/`; el canal está en el
backend (`/api/connect/salas/:sala/mensajes`).

## Cómo se comunican

Dos instancias de BabyWolf (dos teléfonos, o un teléfono y un emulador)
escriben el **mismo código de sala**. Cada una envía con `POST` y consulta
cada 2 s con `GET ?desde=<último id>`, así que sólo recibe lo nuevo. El canal
vive en memoria del backend: es efímero y no necesita tablas.

El **Dispositivo B es de otro estudiante**: instala la misma app (o abre otra
instancia en un emulador) y elige "B" como emisor en la misma sala.

## Requisitos

| # | Requisito | Implementación |
|---|---|---|
| 1 | Nombres de los dos dispositivos | Campos "Dispositivo A" y "Dispositivo B" (editables) |
| 2 | Seleccionar el emisor | Selector A / B |
| 3 | Campo de texto | Barra inferior, máximo 280 caracteres |
| 4 | Enviar al otro | `POST`; el otro lo recibe en ≤ 2 s |
| 5 | Mensaje y emisor en la lista | Burbuja con "nombre (A/B)", texto y hora |
| 6 | Evitar vacíos | Botón deshabilitado con texto vacío; la app y el backend lo rechazan (422) |
| 7 | Notificación visual | SnackBar al enviar ("Mensaje enviado a … · hh:mm:ss") y al recibir ("Nuevo mensaje de …") |
| + | Hora de envío | La pone el servidor, en cada burbuja |
| + | Contador por dispositivo | "Dispositivo A: n enviados" / "Dispositivo B: m enviados" |
| + | Limpiar historial | Icono de la barra superior: borra mensajes y contadores de la sala para ambos |

## Pruebas

| Prueba | Verificado |
|---|---|
| Vacío / sólo espacios / > 280 rechazados | `go test ./internal/application/connect` y `test/connect_test.dart` |
| Contador cuenta todos los enviados, aunque la sala guarde sólo 200 | `sala_test.go` |
| Limpiar borra mensajes y contadores | `sala_test.go` |
| Envío A → B entre dos dispositivos | Probado con curl contra el backend local. Entre dos teléfonos: pendiente de captura con el compañero |
