// Práctica 3 — ConsultaWeb (extensión del sitio BabyWolf).
//
// RF01 título "Consulta de información" · RF02 botón CONSULTAR ·
// RF03 petición HTTP a la URL preasignada · RF04 resultado en pantalla ·
// RF05 "Consultando..." · RF06 "No fue posible obtener la información."

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../widgets_lab.dart';
import 'consulta_api.dart';

class ConsultaWebScreen extends StatefulWidget {
  const ConsultaWebScreen({super.key, this.api});

  /// Inyectable para las pruebas de widget.
  final ConsultaApi? api;

  @override
  State<ConsultaWebScreen> createState() => _ConsultaWebScreenState();
}

class _ConsultaWebScreenState extends State<ConsultaWebScreen> {
  static const textoTitulo = 'Consulta de información';
  static const textoCargando = 'Consultando...';
  static const textoError = 'No fue posible obtener la información.';

  late final ConsultaApi _api = widget.api ?? ConsultaApi();
  final _urlCtrl = TextEditingController();

  bool _cargando = false;
  bool _modificarUrl = false; // Prueba 3
  ResumenSitio? _resultado;
  ConsultaException? _error;
  String? _urlUsada;
  DateTime? _expira;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    setState(() {
      _cargando = true;
      _error = null;
      _resultado = null;
    });
    try {
      String url;
      if (_modificarUrl && _urlCtrl.text.trim().isNotEmpty) {
        // Prueba 3: se usa la URL tal como la editó el alumno.
        url = _urlCtrl.text.trim();
      } else {
        final pre = await _api.obtenerUrl(); // paso 1
        url = pre.url;
        _expira = pre.expira;
        _urlCtrl.text = url;
      }
      _urlUsada = url;
      final r = await _api.consultar(url); // pasos 2 y 3
      if (!mounted) return;
      setState(() => _resultado = r);
    } on ConsultaException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = const ConsultaException(FalloConsulta.formato, 'Respuesta inesperada.'));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('ConsultaWeb', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            textoTitulo,
            style: TextStyle(color: kTexto, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Extensión del sitio BabyWolf: pide una URL preasignada al backend y '
            'muestra el resumen que devuelve.',
            style: TextStyle(color: kTenue, height: 1.4),
          ),
          const SizedBox(height: 18),
          Tooltip(
            message: 'Consultar información',
            child: SizedBox(
              width: double.infinity,
              child: BotonPrincipal(
                texto: 'CONSULTAR',
                icono: Icons.cloud_download_outlined,
                onPressed: _cargando ? null : _consultar,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: kNeon,
            title: const Text('Modificar la URL (Prueba 3)', style: TextStyle(color: kTexto, fontSize: 14)),
            subtitle: const Text(
              'Edita la URL antes de consultar: si cambias cualquier carácter, la firma deja de valer.',
              style: TextStyle(color: kTenue, fontSize: 12),
            ),
            value: _modificarUrl,
            onChanged: (v) => setState(() => _modificarUrl = v),
          ),
          if (_modificarUrl)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _urlCtrl,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(color: kTexto, fontSize: 12, fontFamily: 'monospace'),
                decoration: campo('URL preasignada', ayuda: 'Primero consulta una vez para obtenerla'),
              ),
            ),
          if (_cargando) _cargandoWidget(),
          if (_error != null) _errorWidget(_error!),
          if (_resultado != null) _resultadoWidget(_resultado!),
        ],
      ),
    );
  }

  Widget _cargandoWidget() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(color: kNeon),
          SizedBox(height: 12),
          Text(textoCargando, style: TextStyle(color: kTexto, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _errorWidget(ConsultaException e) {
    final explicacion = switch (e.tipo) {
      FalloConsulta.sinConexion => 'Revisa tu conexión (Prueba 2).',
      FalloConsulta.urlRechazada => 'El servidor rechazó la URL: fue modificada (Prueba 3).',
      FalloConsulta.urlExpirada => 'La URL expiró: consulta de nuevo para obtener otra.',
      FalloConsulta.servidor => 'El servidor no pudo responder.',
      FalloConsulta.formato => 'La respuesta no tiene el formato esperado.',
    };
    return Seccion(
      titulo: 'Error',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: kNeonTexto),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  textoError,
                  style: TextStyle(color: kTexto, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(explicacion, style: const TextStyle(color: kTenue, fontSize: 13)),
          const SizedBox(height: 4),
          Text(e.detalle, style: const TextStyle(color: kTenue, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _resultadoWidget(ResumenSitio r) {
    const estilo = TextStyle(color: kTexto, fontSize: 14, height: 1.5);
    return Column(
      children: [
        Seccion(
          titulo: 'Respuesta',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.sitio, style: const TextStyle(color: kTexto, fontSize: 20, fontWeight: FontWeight.w800)),
              Text(r.descripcion, style: const TextStyle(color: kTenue)),
              const SizedBox(height: 10),
              Text('Noticias publicadas: ${r.totalNoticias}', style: estilo),
              for (final e in r.porCategoria.entries) Text('• ${e.key}: ${e.value}', style: estilo),
              const SizedBox(height: 8),
              const Text('Más recientes', style: TextStyle(color: kNeonTexto, fontWeight: FontWeight.w700)),
              for (final t in r.ultimas) Text('• $t', style: estilo),
              if (r.generado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Generado: ${r.generado!.toLocal()}', style: const TextStyle(color: kTenue, fontSize: 12)),
                ),
            ],
          ),
        ),
        Seccion(
          titulo: 'URL preasignada usada',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                _urlUsada ?? '',
                style: const TextStyle(color: kTenue, fontSize: 11.5, fontFamily: 'monospace'),
              ),
              if (_expira != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Expira: ${_expira!.toLocal()}', style: const TextStyle(color: kTenue, fontSize: 12)),
                ),
            ],
          ),
        ),
        Seccion(
          titulo: 'JSON recibido',
          child: SelectableText(
            r.crudo,
            style: const TextStyle(color: kTenue, fontSize: 11.5, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
