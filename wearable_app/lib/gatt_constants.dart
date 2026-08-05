// Contrato GATT del wearable BabyWolf.
//
// Fuente única de verdad de los UUIDs. Este archivo se copia IDÉNTICO en
// wearable_app y phone_app: si un UUID cambia aquí, hay que copiarlo allá.
// Los bytes en el aire no llevan información de tipo — el UUID de la
// característica es el que define cómo interpretarlos (ver gatt_codec.dart).

/// Servicio que anuncia el wearable. El teléfono escanea buscando este UUID.
const String kServiceUuid = '0000babe-0000-1000-8000-00805f9b34fb';

/// Tema del blog que el usuario está leyendo. Valor: UTF-8.
const String kCharTemaActivo = '0000bab1-0000-1000-8000-00805f9b34fb';

/// Noticias pendientes de leer en el tema activo. Valor: uint16 little-endian.
const String kCharNoticiasSinLeer = '0000bab2-0000-1000-8000-00805f9b34fb';

/// Minutos de lectura acumulados en la sesión. Valor: float32 little-endian.
const String kCharMinutosLectura = '0000bab3-0000-1000-8000-00805f9b34fb';

/// Por encima de este backlog el teléfono levanta alerta visible.
/// El blog ronda las 6 noticias publicadas, así que el umbral se fija en 4:
/// alto para que no salte por cualquier cosa, bajo para que se pueda apagar
/// leyendo un par de noticias durante la demo.
const int kUmbralNoticiasSinLeer = 4;

/// Temas conocidos del blog. Sólo se usan como respaldo: los temas reales los
/// trae `consultarBlog()` desde la columna `category` de la API.
const List<String> kTemas = ['retro', 'gaming', 'tech', 'opinion'];

/// Dónde vive el hub que hace de medio físico (ver hub/hub.dart).
/// 10.0.2.2 es el host visto desde un emulador Android.
const String kHubHost = '10.0.2.2';
const int kHubPort = 8090;
String get kGattUrl => 'ws://$kHubHost:$kHubPort/gatt';
