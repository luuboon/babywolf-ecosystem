// BabyWolf Wear — widget de temas del blog para Wear OS.
//
// Muestra el tema que se está leyendo con su icono de consola retro y publica
// la actividad por GATT hacia el teléfono.
//
// Los temas y el número de noticias son REALES: salen de la misma API que
// alimenta al teléfono y a la Smart TV. Lo único simulado es el acto de leer
// —eso es actividad del usuario y ningún emulador tiene un sensor que lo mida.

import 'dart:async';

import 'package:flutter/material.dart';

import 'blog_api.dart';
import 'gatt_codec.dart';
import 'gatt_constants.dart';
import 'gatt_peripheral.dart';

void main() => runApp(const BabyWolfWearApp());

// Paleta del blog BabyWolf ("Dark Gaming / Cyberpunk Minimal").
const _fondo = Color(0xFF1A1A2E);
const _superficie = Color(0xFF16213E);
const _neon = Color(0xFFE94560);
const _neonGlow = Color(0x80E94560);
const _texto = Color(0xE6FFFFFF);
const _tenue = Color(0x8CFFFFFF);
const _verde = Color(0xFF4ADE80);

/// Icono de consola retro por tema del blog.
const _consolas = <String, IconData>{
  'retro': Icons.videogame_asset, // cartucho / control clásico
  'gaming': Icons.sports_esports, // control moderno
  'tech': Icons.memory, // chip
  'opinion': Icons.tv, // televisor CRT
};

class BabyWolfWearApp extends StatelessWidget {
  const BabyWolfWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyWolf Wear',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _fondo,
      ),
      home: const PantallaTemas(),
    );
  }
}

class PantallaTemas extends StatefulWidget {
  const PantallaTemas({super.key});

  @override
  State<PantallaTemas> createState() => _PantallaTemasState();
}

/// Cada cuánto "lee" una noticia. A este ritmo las ~6 del blog se leen en unos
/// tres minutos: alcanza para ver la alerta encenderse y apagarse en la demo.
const _cadaCuantoLee = Duration(seconds: 30);

/// Cada cuánto se vuelve a preguntar al blog. Si publicas una noticia durante
/// la demo, el contador del reloj sube dentro de este plazo.
const _cadaCuantoRefresca = Duration(seconds: 60);

class _PantallaTemasState extends State<PantallaTemas> {
  final _gatt = GattPeripheral();
  Timer? _anuncio;
  Timer? _generador;
  Timer? _refresco;
  StreamSubscription<bool>? _subEnlace;

  bool _generando = false;
  bool _conectado = false;
  int _temaIdx = 0;
  double _minutos = 0;
  int _tick = 0;

  /// Lo que dice el blog ahora mismo.
  ResumenBlog _blog = ResumenBlog.vacio;
  bool _apiOk = false;

  /// Noticias que el usuario ya leyó. Es lo único que se simula.
  int _leidas = 0;

  List<String> get _temas => _blog.temas;
  int get _sinLeer => (_blog.total - _leidas).clamp(0, 9999);

  @override
  void initState() {
    super.initState();
    _subEnlace = _gatt.enlace.listen((c) {
      if (mounted) setState(() => _conectado = c);
    });
    _gatt.iniciar();

    // Un periférico BLE anuncia su servicio aunque no esté emitiendo datos.
    // Así el teléfono lo encuentra por serviceUUID antes de suscribirse, y el
    // botón Iniciar/Detener gobierna sólo la generación, no el enlace.
    _anuncio = Timer.periodic(const Duration(seconds: 2), (_) {
      _gatt.notify(kServiceUuid, GattCodec.encodeString('BabyWolf Wear'));
    });

    _cargarBlog();
    _refresco = Timer.periodic(_cadaCuantoRefresca, (_) => _cargarBlog());
  }

  /// Trae los temas y el conteo reales. Si falla, el reloj sigue en pie con el
  /// último dato bueno: una demo no se cae por un corte de red.
  Future<void> _cargarBlog() async {
    try {
      final resumen = await consultarBlog();
      if (!mounted) return;
      setState(() {
        _blog = resumen;
        _apiOk = true;
        if (_temaIdx >= _temas.length) _temaIdx = 0;
      });
    } catch (_) {
      if (mounted) setState(() => _apiOk = false);
    }
  }

  @override
  void dispose() {
    _anuncio?.cancel();
    _generador?.cancel();
    _refresco?.cancel();
    _subEnlace?.cancel();
    _gatt.detener();
    super.dispose();
  }

  void _alternar() {
    setState(() => _generando = !_generando);
    if (_generando) {
      _generador = Timer.periodic(const Duration(seconds: 1), (_) => _generar());
    } else {
      _generador?.cancel();
    }
  }

  /// Una lectura por segundo, como pide la rúbrica.
  ///
  /// El tema y el contador salen del blog real; sólo se simula que el usuario
  /// va leyendo, que es justo lo que un emulador no puede medir.
  void _generar() {
    if (_temas.isEmpty) return;

    setState(() {
      _tick++;
      // El tema cambia cada 5 s, como si el usuario navegara entre secciones.
      if (_tick % 5 == 0) _temaIdx = (_temaIdx + 1) % _temas.length;
      // Va leyendo: lo único simulado de los tres valores.
      if (_tick % _cadaCuantoLee.inSeconds == 0 && _sinLeer > 0) _leidas++;
      _minutos += 1 / 60; // cronómetro real de la sesión
    });

    _gatt.notify(kCharTemaActivo, GattCodec.encodeString(_temas[_temaIdx]));
    _gatt.notify(kCharNoticiasSinLeer, GattCodec.encodeUint16(_sinLeer));
    _gatt.notify(kCharMinutosLectura, GattCodec.encodeFloat32(_minutos));
  }

  @override
  Widget build(BuildContext context) {
    final tema = _temas.isEmpty ? '—' : _temas[_temaIdx];
    final critico = _sinLeer > kUmbralNoticiasSinLeer;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _enlaceGatt(),
                const SizedBox(height: 6),
                _consolaActiva(tema),
                const SizedBox(height: 8),
                _tiraTemas(),
                const SizedBox(height: 8),
                _metricas(critico),
                const SizedBox(height: 8),
                _boton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dos indicadores: el enlace con el teléfono y el origen de los datos.
  /// Así, durante la demo, se ve de un vistazo que los números vienen del blog.
  Widget _enlaceGatt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Etiqueta siempre corta: en una pantalla redonda, un "SIN ENLACE"
        // empuja el indicador de al lado fuera del área visible. El color ya
        // dice el estado.
        _punto(_conectado ? _verde : _tenue, 'GATT'),
        const SizedBox(width: 10),
        _punto(_apiOk ? _verde : _tenue, 'API'),
      ],
    );
  }

  Widget _punto(Color color, String etiqueta) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 4),
        Text(
          etiqueta,
          style: const TextStyle(color: _tenue, fontSize: 9, letterSpacing: 1.2),
        ),
      ],
    );
  }

  /// El widget principal: la consola del tema activo, en grande.
  Widget _consolaActiva(String tema) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: _superficie,
            // Bordes duros, sin redondeo: estética pixel de consola.
            border: Border.all(color: _neon, width: 2),
            boxShadow: _generando
                ? const [BoxShadow(color: _neonGlow, blurRadius: 16)]
                : null,
          ),
          child: Icon(_consolas[tema], size: 34, color: _neon),
        ),
        const SizedBox(height: 5),
        Text(
          tema.toUpperCase(),
          style: const TextStyle(
            color: _texto,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }

  /// Un icono por tema REAL del blog: si publicas una categoría nueva,
  /// aparece aquí sola tras el siguiente refresco.
  Widget _tiraTemas() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _temas.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Icon(
              _consolas[_temas[i]] ?? Icons.article_outlined,
              size: 15,
              color: i == _temaIdx ? _neon : _tenue,
            ),
          ),
      ],
    );
  }

  Widget _metricas(bool critico) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_sinLeer',
          style: TextStyle(
            color: critico ? _neon : _texto,
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          // "de N" es el total publicado en el blog: dato real, no inventado.
          'sin leer de ${_blog.total} · ${_minutos.toStringAsFixed(1)} min',
          style: const TextStyle(color: _tenue, fontSize: 10.5),
        ),
      ],
    );
  }

  Widget _boton() {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: _alternar,
        icon: Icon(_generando ? Icons.pause : Icons.play_arrow, size: 15),
        label: Text(
          _generando ? 'Detener' : 'Iniciar',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _generando ? _superficie : _neon,
          foregroundColor: _texto,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}
