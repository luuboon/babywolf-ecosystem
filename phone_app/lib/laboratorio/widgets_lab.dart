// Piezas visuales compartidas por las pantallas de prácticas, con la misma
// paleta del blog (theme.dart) para que el laboratorio no parezca otra app.

import 'package:flutter/material.dart';

import '../theme.dart';

/// Notificación visual breve (SnackBar). La usan las prácticas 6 y 7 para
/// confirmar envíos.
void avisar(BuildContext context, String texto, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? kNeon : kSuperficie,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Tarjeta con título pequeño en mayúsculas, como las secciones del blog.
class Seccion extends StatelessWidget {
  const Seccion({
    super.key,
    required this.titulo,
    required this.child,
    this.accion,
  });

  final String titulo;
  final Widget child;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: kSuperficie,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: const TextStyle(
                    color: kNeonTexto,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (accion != null) accion!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Botón principal rojo neón.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
  });

  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final estilo = ElevatedButton.styleFrom(
      backgroundColor: kNeon,
      foregroundColor: Colors.white,
      disabledBackgroundColor: kNeon.withValues(alpha: 0.35),
      disabledForegroundColor: Colors.white70,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
    );
    if (icono == null) {
      return ElevatedButton(onPressed: onPressed, style: estilo, child: Text(texto));
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: estilo,
      icon: Icon(icono, size: 18),
      label: Text(texto),
    );
  }
}

/// Decoración de los campos de texto del laboratorio.
InputDecoration campo(String etiqueta, {String? ayuda, Widget? sufijo, String? error}) {
  return InputDecoration(
    labelText: etiqueta,
    helperText: ayuda,
    errorText: error,
    suffixIcon: sufijo,
    filled: true,
    fillColor: kFondo,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0x33FFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kNeon, width: 1.5),
    ),
  );
}

/// Hora local hh:mm:ss para los mensajes.
String horaCorta(DateTime t) {
  final l = t.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(l.hour)}:${dos(l.minute)}:${dos(l.second)}';
}
