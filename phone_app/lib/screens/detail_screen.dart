// Detalle de una noticia. Al abrirse avisa al hub, y con eso la Smart TV
// muestra la misma noticia.
//
// Arriba: guardar para leer sin internet (Práctica 4) y reportar un problema
// (Práctica 9). Abajo: la nota personal si está guardada y los comentarios
// (Práctica 6).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../comentarios/comentarios_seccion.dart';
import '../core/widgets.dart';
import '../guardadas/guardadas.dart';
import '../models/post.dart';
import '../reportes/reportar_sheet.dart';
import '../theme.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.post});

  final Post post;

  Future<void> _alternarGuardada(BuildContext context, bool guardada) async {
    final g = context.read<Guardadas>();
    if (guardada) {
      await g.quitar(post.id);
      if (context.mounted) avisar(context, 'Se quitó de guardadas');
    } else {
      await g.guardar(post);
      if (context.mounted) avisar(context, 'Guardada: la puedes leer sin internet');
    }
  }

  Future<void> _editarNota(BuildContext context, Guardada g) async {
    final texto = TextEditingController(text: g.nota);
    final nueva = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: kSuperficie,
        title: const Text('Nota personal', style: TextStyle(color: kTexto)),
        content: TextField(
          controller: texto,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          maxLength: Guardada.maxNota,
          style: const TextStyle(color: kTexto),
          decoration: campo('Sólo se guarda en este teléfono'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(d, texto.text), child: const Text('Guardar')),
        ],
      ),
    );
    texto.dispose();
    if (nueva == null || !context.mounted) return;
    try {
      await context.read<Guardadas>().cambiarNota(post.id, nueva);
      if (context.mounted) avisar(context, nueva.trim().isEmpty ? 'Nota borrada' : 'Nota guardada');
    } on ArgumentError catch (e) {
      if (context.mounted) avisar(context, '${e.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardada = context.watch<Guardadas>().de(post.id);

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        actions: [
          IconButton(
            tooltip: guardada == null ? 'Guardar para leer después' : 'Quitar de guardadas',
            icon: Icon(guardada == null ? Icons.bookmark_border : Icons.bookmark, color: kTexto),
            onPressed: () => _alternarGuardada(context, guardada != null),
          ),
          IconButton(
            tooltip: 'Reportar un problema',
            icon: const Icon(Icons.outlined_flag, color: kTexto),
            onPressed: () => ReportarSheet.mostrar(context, post),
          ),
        ],
        title: Text(
          post.category.toUpperCase(),
          style: const TextStyle(
            color: kNeonTexto,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (post.coverImageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                post.coverImageUrl,
                fit: BoxFit.cover,
                // Fallback si la portada no carga.
                errorBuilder: (_, _, _) => Container(
                  color: kSuperficie,
                  child: Icon(consolaDe(post.category),
                      color: kNeon, size: 56),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    color: kTexto,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.fechaCorta,
                  style: const TextStyle(color: kTenue, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Text(
                  post.content,
                  style: const TextStyle(
                    color: kTexto,
                    fontSize: 16,
                    height: 1.6, // "párrafos con respiro visual" de la guía
                  ),
                ),
                if (guardada != null) ...[
                  const SizedBox(height: 24),
                  _nota(context, guardada),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Icon(Icons.tv, color: kTenue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta noticia se está mostrando en la Smart TV',
                        style: TextStyle(color: kTenue.withAlpha(160), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ComentariosSeccion(post: post),
        ],
      ),
    );
  }

  Widget _nota(BuildContext context, Guardada g) {
    return Material(
      color: kSuperficie,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _editarNota(context, g),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sticky_note_2_outlined, color: kNeonTexto, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  g.nota.isEmpty ? 'Agregar una nota personal…' : g.nota,
                  style: TextStyle(color: g.nota.isEmpty ? kTenue : kTexto, height: 1.4),
                ),
              ),
              const Icon(Icons.edit_outlined, color: kTenue, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
