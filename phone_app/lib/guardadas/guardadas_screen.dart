// Pestaña "Guardadas" (Práctica 4): las noticias que el lector guardó en el
// teléfono. Se leen sin internet porque la noticia completa está en SQLite.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/widgets.dart';
import '../screens/detail_screen.dart';
import '../theme.dart';
import 'guardadas.dart';

class GuardadasScreen extends StatelessWidget {
  const GuardadasScreen({super.key});

  Future<bool> _confirmarQuitar(BuildContext context, Guardada g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSuperficie,
        title: const Text('Quitar de guardadas', style: TextStyle(color: kTexto)),
        content: Text(
          '¿Quitar "${g.post.title}"? También se borra tu nota.',
          style: const TextStyle(color: kTenue),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitar')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final guardadas = context.watch<Guardadas>();
    final lista = guardadas.lista;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Guardadas', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
      ),
      body: !guardadas.cargada
          ? const Center(child: CircularProgressIndicator(color: kNeon))
          : lista.isEmpty
              ? const _Vacio()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: lista.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        '${lista.length} ${lista.length == 1 ? 'noticia' : 'noticias'} · disponibles sin internet',
                        style: const TextStyle(color: kTenue, fontSize: 12),
                      );
                    }
                    final g = lista[i - 1];
                    return Dismissible(
                      key: ValueKey(g.post.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmarQuitar(context, g),
                      onDismissed: (_) {
                        context.read<Guardadas>().quitar(g.post.id);
                        avisar(context, 'Se quitó de guardadas');
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: kNeon, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      child: _Fila(guardada: g),
                    );
                  },
                ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.guardada});
  final Guardada guardada;

  @override
  Widget build(BuildContext context) {
    final g = guardada;
    return Material(
      color: kSuperficie,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DetailScreen(post: g.post)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(consolaDe(g.post.category), color: kNeon, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.post.title,
                      style: const TextStyle(color: kTexto, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${g.post.category.toUpperCase()} · guardada el ${_fecha(g.guardadaEn)}',
                      style: const TextStyle(color: kTenue, fontSize: 11.5),
                    ),
                    if (g.nota.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.sticky_note_2_outlined, color: kNeonTexto, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              g.nota,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTexto, fontSize: 12.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, color: kTenue, size: 48),
          SizedBox(height: 14),
          Text(
            'Aún no guardas noticias',
            style: TextStyle(color: kTexto, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Toca el marcador en una noticia para guardarla y leerla después, incluso sin internet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTenue, height: 1.4),
          ),
        ],
      ),
    );
  }
}
