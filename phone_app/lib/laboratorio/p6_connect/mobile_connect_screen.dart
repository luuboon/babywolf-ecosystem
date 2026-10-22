// Práctica 6 — MobileConnect.
//
// 1. Nombres de los dos dispositivos.     5. Mensaje + emisor en la conversación.
// 2. Selección del dispositivo emisor.    6. No se envían mensajes vacíos.
// 3. Campo para redactar.                 7. Notificación visual al enviar.
// 4. Envío al otro dispositivo.
// + hora de envío, contador por dispositivo y botón para limpiar el historial.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../widgets_lab.dart';
import 'connect_api.dart';

class MobileConnectScreen extends StatefulWidget {
  const MobileConnectScreen({super.key, this.api});

  final ConnectApi? api;

  @override
  State<MobileConnectScreen> createState() => _MobileConnectScreenState();
}

class _MobileConnectScreenState extends State<MobileConnectScreen> {
  late final ConnectApi _api = widget.api ?? ConnectApi();

  final _sala = TextEditingController(text: 'BABYWOLF-1');
  final _nombreA = TextEditingController(text: 'Dispositivo A');
  final _nombreB = TextEditingController(text: 'Dispositivo B');
  final _texto = TextEditingController();
  final _scroll = ScrollController();

  String _emisor = 'A';
  final List<MensajeConnect> _mensajes = [];
  Map<String, int> _conteo = {'A': 0, 'B': 0};
  int _ultimo = 0;
  bool _enLinea = false;
  bool _enviando = false;
  String? _estado;
  Timer? _sondeo;

  @override
  void initState() {
    super.initState();
    _texto.addListener(() => setState(() {})); // habilita/inhabilita "Enviar"
    _reiniciar();
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    _sala.dispose();
    _nombreA.dispose();
    _nombreB.dispose();
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _otro => _emisor == 'A' ? 'B' : 'A';
  String _nombre(String e) => (e == 'A' ? _nombreA.text : _nombreB.text).trim().isEmpty
      ? 'Dispositivo $e'
      : (e == 'A' ? _nombreA.text : _nombreB.text).trim();

  /// Al cambiar de sala se empieza de cero.
  void _reiniciar() {
    _sondeo?.cancel();
    setState(() {
      _mensajes.clear();
      _ultimo = 0;
      _conteo = {'A': 0, 'B': 0};
    });
    _leer();
    _sondeo = Timer.periodic(const Duration(seconds: 2), (_) => _leer());
  }

  Future<void> _leer() async {
    try {
      final lote = await _api.leer(_sala.text, desde: _ultimo);
      if (!mounted) return;
      // En la primera lectura llega el historial: eso no es "nuevo".
      final primeraLectura = _ultimo == 0;
      final nuevosDelOtro = lote.mensajes.where((m) => m.emisor != _emisor && m.id > _ultimo).toList();
      setState(() {
        _enLinea = true;
        _estado = null;
        for (final m in lote.mensajes) {
          if (m.id > _ultimo) {
            _mensajes.add(m);
            _ultimo = m.id;
          }
        }
        _conteo = lote.conteo;
      });
      if (nuevosDelOtro.isNotEmpty && !primeraLectura) {
        final m = nuevosDelOtro.last;
        avisar(context, 'Nuevo mensaje de ${m.dispositivo}');
        _bajar();
      }
    } on ConnectException catch (e) {
      if (mounted) {
        setState(() {
          _enLinea = false;
          _estado = e.mensaje;
        });
      }
    }
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final invalido = ReglasConnect.validar(_texto.text);
    if (invalido != null) {
      avisar(context, invalido, error: true);
      return;
    }
    setState(() => _enviando = true);
    try {
      final m = await _api.enviar(_sala.text, _emisor, _nombre(_emisor), _texto.text);
      if (!mounted) return;
      _texto.clear();
      setState(() {
        if (m.id > _ultimo) {
          _mensajes.add(m);
          _ultimo = m.id;
        }
        _conteo = {..._conteo, _emisor: (_conteo[_emisor] ?? 0) + 1};
      });
      avisar(context, 'Mensaje enviado a ${_nombre(_otro)} · ${horaCorta(m.hora)}');
      _bajar();
    } on ConnectException catch (e) {
      if (mounted) avisar(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _limpiar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSuperficie,
        title: const Text('Limpiar historial', style: TextStyle(color: kTexto)),
        content: const Text('Se borran los mensajes y contadores de la sala para ambos dispositivos.',
            style: TextStyle(color: kTenue)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Limpiar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.limpiar(_sala.text);
      if (!mounted) return;
      setState(() {
        _mensajes.clear();
        _conteo = {'A': 0, 'B': 0};
      });
      avisar(context, 'Historial limpio');
    } on ConnectException catch (e) {
      if (mounted) avisar(context, e.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final puedeEnviar = !_enviando && _texto.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('MobileConnect', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Limpiar historial',
            icon: const Icon(Icons.delete_sweep_outlined, color: kTexto),
            onPressed: _limpiar,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                Seccion(
                  titulo: 'Dispositivos',
                  accion: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 9, color: _enLinea ? kVerde : kNeon),
                      const SizedBox(width: 6),
                      Text(_enLinea ? 'En línea' : 'Sin conexión',
                          style: const TextStyle(color: kTenue, fontSize: 12)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nombreA,
                              maxLength: 30,
                              style: const TextStyle(color: kTexto),
                              decoration: campo('Dispositivo A'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _nombreB,
                              maxLength: 30,
                              style: const TextStyle(color: kTexto),
                              decoration: campo('Dispositivo B'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _sala,
                        style: const TextStyle(color: kTexto),
                        textCapitalization: TextCapitalization.characters,
                        decoration: campo('Sala compartida',
                            ayuda: 'Ambos teléfonos deben usar el mismo código'),
                        onSubmitted: (_) => _reiniciar(),
                      ),
                      if (_estado != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_estado!, style: const TextStyle(color: kNeonTexto, fontSize: 12)),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Emisor:', style: TextStyle(color: kTenue)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: [
                                ButtonSegment(value: 'A', label: Text(_nombre('A'), overflow: TextOverflow.ellipsis)),
                                ButtonSegment(value: 'B', label: Text(_nombre('B'), overflow: TextOverflow.ellipsis)),
                              ],
                              selected: {_emisor},
                              onSelectionChanged: (s) => setState(() => _emisor = s.first),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _contador('A'),
                          const SizedBox(width: 10),
                          _contador('B'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_mensajes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Text('La conversación está vacía.',
                        textAlign: TextAlign.center, style: TextStyle(color: kTenue)),
                  ),
                for (final m in _mensajes) _burbuja(m),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: kSuperficie,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('campo_mensaje'),
                      controller: _texto,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: ReglasConnect.maxTexto,
                      style: const TextStyle(color: kTexto),
                      decoration: campo('Mensaje como ${_nombre(_emisor)}').copyWith(counterText: ''),
                      onSubmitted: (_) => puedeEnviar ? _enviar() : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    key: const Key('boton_enviar'),
                    tooltip: 'Enviar',
                    style: IconButton.styleFrom(backgroundColor: kNeon, foregroundColor: Colors.white),
                    onPressed: puedeEnviar ? _enviar : null,
                    icon: _enviando
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contador(String e) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: kFondo, borderRadius: BorderRadius.circular(8)),
        child: Text(
          '${_nombre(e)}: ${_conteo[e] ?? 0} enviados',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kTexto, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _burbuja(MensajeConnect m) {
    final mio = m.emisor == _emisor;
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: mio ? kNeon.withValues(alpha: 0.85) : kSuperficie,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.dispositivo} (${m.emisor})',
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(m.texto, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),
            const SizedBox(height: 3),
            Text(horaCorta(m.hora), style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
