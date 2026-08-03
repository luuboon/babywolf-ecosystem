// BabyWolf Wear — widget de temas del blog para Wear OS.
//
// Muestra el tema que se está leyendo con su icono de consola retro y simula
// la actividad de lectura, publicándola por GATT hacia el teléfono.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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

class _PantallaTemasState extends State<PantallaTemas> {
  final _gatt = GattPeripheral();
  final _rand = Random();
  Timer? _anuncio;
  Timer? _generador;
  StreamSubscription<bool>? _subEnlace;

  bool _generando = false;
  bool _conectado = false;
  int _temaIdx = 0;
  int _sinLeer = 0;
  double _minutos = 0;
  int _tick = 0;

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
  }

  @override
  void dispose() {
    _anuncio?.cancel();
    _generador?.cancel();
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

  /// Simulador de sensores: una lectura por segundo, como pide la rúbrica.
  void _generar() {
    setState(() {
      _tick++;
      // El tema cambia cada 5 s, como si el usuario navegara entre secciones.
      if (_tick % 5 == 0) _temaIdx = (_temaIdx + 1) % kTemas.length;
      // El backlog crece casi siempre y baja cuando alcanza a leer algo.
      _sinLeer = (_sinLeer + _rand.nextInt(4) - 1).clamp(0, 40);
      _minutos += 1 / 60;
    });

    _gatt.notify(kCharTemaActivo, GattCodec.encodeString(kTemas[_temaIdx]));
    _gatt.notify(kCharNoticiasSinLeer, GattCodec.encodeUint16(_sinLeer));
    _gatt.notify(kCharMinutosLectura, GattCodec.encodeFloat32(_minutos));
  }

  @override
  Widget build(BuildContext context) {
    final tema = kTemas[_temaIdx];
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

  Widget _enlaceGatt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 6, height: 6, color: _conectado ? _verde : _tenue),
        const SizedBox(width: 5),
        Text(
          _conectado ? 'GATT' : 'SIN ENLACE',
          style: const TextStyle(color: _tenue, fontSize: 9, letterSpacing: 1.5),
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

  Widget _tiraTemas() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < kTemas.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Icon(
              _consolas[kTemas[i]],
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
          'sin leer · ${_minutos.toStringAsFixed(1)} min',
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
