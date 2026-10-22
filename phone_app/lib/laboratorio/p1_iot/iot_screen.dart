// Prácticas 1 y 2 — Sensor infrarrojo y botón del ESP32 en el teléfono.
//
// Modo real: Bluetooth clásico (SPP) con el ESP32 "ESP32_SENSOR_IR",
// emparejado antes en los ajustes del teléfono.
// Modo simulado: genera las mismas líneas que el firmware para poder
// mostrar la pantalla en el emulador, que no tiene radio Bluetooth.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../widgets_lab.dart';
import 'lectura_iot.dart';
import 'spp_service.dart';

const kNombreEsp32 = 'ESP32_SENSOR_IR';

class IotScreen extends StatefulWidget {
  const IotScreen({super.key});

  @override
  State<IotScreen> createState() => _IotScreenState();
}

class _IotScreenState extends State<IotScreen> {
  final _spp = SppService();
  StreamSubscription<String>? _sub;
  Timer? _simulador;
  int _tick = 0;

  bool _simulado = false;
  bool _conectado = false;
  bool _ocupado = false;
  String _estadoBt = 'Sin revisar';
  List<DispositivoBt> _emparejados = const [];

  LecturaIot? _sensor;
  LecturaIot? _boton;
  final List<LecturaIot> _historial = [];

  @override
  void initState() {
    super.initState();
    _revisarEstado();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _simulador?.cancel();
    if (_conectado && !_simulado) _spp.desconectar();
    super.dispose();
  }

  Future<void> _revisarEstado() async {
    final e = await _spp.estado();
    if (!mounted) return;
    setState(() {
      _estadoBt = switch (e) {
        'sin_bluetooth' => 'Este dispositivo no tiene Bluetooth (¿emulador?). Usa el modo simulado.',
        'sin_permiso' => 'Falta el permiso de Bluetooth.',
        'apagado' => 'El Bluetooth está apagado.',
        'conectado' => 'Conectado.',
        _ => 'Bluetooth listo.',
      };
    });
  }

  void _recibir(String linea) {
    if (!mounted) return;
    if (linea == kSppDesconectado) {
      setState(() => _conectado = false);
      avisar(context, 'Se perdió la conexión con el ESP32', error: true);
      return;
    }
    final l = LecturaIot.interpretar(linea);
    setState(() {
      if (l.tipo == TipoLectura.sensor) _sensor = l;
      if (l.tipo == TipoLectura.boton) _boton = l;
      _historial.insert(0, l);
      if (_historial.length > 40) _historial.removeLast();
    });
  }

  Future<void> _buscar() async {
    setState(() => _ocupado = true);
    try {
      final lista = await _spp.emparejados();
      if (!mounted) return;
      setState(() => _emparejados = lista);
      if (lista.isEmpty) {
        avisar(context, 'No hay dispositivos emparejados. Empareja $kNombreEsp32 en Ajustes.');
      }
    } on SppException catch (e) {
      if (mounted) avisar(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
      _revisarEstado();
    }
  }

  Future<void> _conectar(DispositivoBt d) async {
    setState(() => _ocupado = true);
    try {
      _sub ??= _spp.lineas.listen(_recibir);
      await _spp.conectar(d.direccion);
      if (!mounted) return;
      setState(() => _conectado = true);
      avisar(context, 'Conectado a ${d.nombre}');
    } on SppException catch (e) {
      if (mounted) avisar(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _desconectar() async {
    await _spp.desconectar();
    if (mounted) setState(() => _conectado = false);
  }

  void _cambiarSimulado(bool v) {
    _simulador?.cancel();
    setState(() {
      _simulado = v;
      _sensor = null;
      _boton = null;
      _historial.clear();
    });
    if (!v) return;
    _tick = 0;
    // Mismo ritmo que el firmware: una lectura cada 500 ms.
    _simulador = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _tick++;
      final hayObjeto = (_tick ~/ 6).isOdd; // 3 s con objeto, 3 s sin objeto
      _recibir(hayObjeto ? 'OBJETO DETECTADO' : 'SIN OBJETO');
      if (_tick % 4 == 0) {
        final presionado = (_tick ~/ 8).isOdd;
        _recibir(presionado ? 'BOTON PRESIONADO - LED ENCENDIDO' : 'BOTON LIBERADO - LED APAGADO');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('Sensor IR · ESP32', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _indicadorSensor(),
          _indicadorBoton(),
          Seccion(
            titulo: 'Conexión',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kNeon,
                  value: _simulado,
                  onChanged: _cambiarSimulado,
                  title: const Text('Modo simulado (sin hardware)', style: TextStyle(color: kTexto, fontSize: 14)),
                  subtitle: const Text(
                    'Genera las mismas líneas que el firmware, cada 500 ms.',
                    style: TextStyle(color: kTenue, fontSize: 12),
                  ),
                ),
                if (!_simulado) ...[
                  Text(_estadoBt, style: const TextStyle(color: kTenue, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: BotonPrincipal(
                          texto: _conectado ? 'DESCONECTAR' : 'BUSCAR EMPAREJADOS',
                          icono: _conectado ? Icons.link_off : Icons.bluetooth_searching,
                          onPressed: _ocupado ? null : (_conectado ? _desconectar : _buscar),
                        ),
                      ),
                    ],
                  ),
                  for (final d in _emparejados)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.memory,
                        color: d.nombre == kNombreEsp32 ? kNeon : kTenue,
                      ),
                      title: Text(d.nombre, style: const TextStyle(color: kTexto)),
                      subtitle: Text(d.direccion, style: const TextStyle(color: kTenue, fontSize: 12)),
                      trailing: d.nombre == kNombreEsp32
                          ? const Text('ESP32', style: TextStyle(color: kNeonTexto, fontWeight: FontWeight.w800))
                          : null,
                      onTap: _ocupado || _conectado ? null : () => _conectar(d),
                    ),
                ],
              ],
            ),
          ),
          const Seccion(
            titulo: 'Arquitectura IoT',
            child: Text(
              '1. Percepción: sensor infrarrojo (GPIO 27) y botón (GPIO 4).\n'
              '2. Procesamiento: el ESP32 decide si hay objeto y enciende el LED (GPIO 2).\n'
              '3. Red: Bluetooth clásico, perfil SPP (puerto serie).\n'
              '4. Aplicación: este teléfono muestra el estado y el historial.',
              style: TextStyle(color: kTexto, fontSize: 13.5, height: 1.6),
            ),
          ),
          Seccion(
            titulo: 'Mensajes recibidos (${_historial.length})',
            child: _historial.isEmpty
                ? const Text('Todavía no llega nada.', style: TextStyle(color: kTenue))
                : Column(
                    children: [
                      for (final l in _historial.take(15))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(horaCorta(l.hora), style: const TextStyle(color: kTenue, fontSize: 12)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l.texto,
                                  style: TextStyle(
                                    color: l.activo ? kNeonTexto : kTexto,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _indicadorSensor() {
    final s = _sensor;
    final hay = s?.activo ?? false;
    final texto = s == null ? 'ESPERANDO DATOS' : (hay ? 'OBJETO DETECTADO' : 'SIN OBJETO');
    return Seccion(
      titulo: 'Práctica 1 · Sensor infrarrojo',
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hay ? kNeon : kFondo,
              border: Border.all(color: hay ? kNeon : kTenue, width: 2),
              boxShadow: hay ? const [BoxShadow(color: kNeonGlow, blurRadius: 18, spreadRadius: 2)] : null,
            ),
            child: Icon(hay ? Icons.sensors : Icons.sensors_off, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto, style: const TextStyle(color: kTexto, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(
                  s == null ? 'LED del ESP32: —' : 'LED del ESP32: ${hay ? 'encendido' : 'apagado'} · ${horaCorta(s.hora)}',
                  style: const TextStyle(color: kTenue, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicadorBoton() {
    final b = _boton;
    if (b == null) {
      return const Seccion(
        titulo: 'Práctica 2 · Botón y LED',
        child: Text(
          'Con el firmware combinado (firmware/iot_combinado) aquí aparece el estado del botón.',
          style: TextStyle(color: kTenue, fontSize: 13),
        ),
      );
    }
    return Seccion(
      titulo: 'Práctica 2 · Botón y LED',
      child: Row(
        children: [
          Icon(b.activo ? Icons.lightbulb : Icons.lightbulb_outline, color: b.activo ? Colors.amber : kTenue, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(b.texto, style: const TextStyle(color: kTexto, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
