// Feed de noticias de BabyWolf: la pantalla principal, igual que el blog web.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble_client.dart';
import '../models/post.dart';
import '../providers/activity_provider.dart';
import '../resumen/resumen_api.dart';
import '../resumen/resumen_tarjeta.dart';
import '../services/blog_api.dart';
import '../services/busqueda.dart';
import '../theme.dart';
import '../widgets/wearable_sheet.dart';
import 'detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _api = BlogApi();
  final _resumen = ResumenServicio();
  late Future<List<Post>> _futuro;

  /// Tema elegido en la tarjeta de resumen (null = todas las noticias).
  String? _categoria;
  int _recargas = 0;

  /// Búsqueda por texto (lupa de la barra superior).
  final _buscador = TextEditingController();
  bool _buscando = false;
  String _consulta = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  void _abrirBusqueda() => setState(() => _buscando = true);

  void _cerrarBusqueda() {
    _buscador.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _buscando = false;
      _consulta = '';
    });
  }

  void _borrarConsulta() {
    _buscador.clear();
    setState(() => _consulta = '');
  }

  @override
  void initState() {
    super.initState();
    _futuro = _api.posts();
  }

  Future<void> _recargar() async {
    // setState no debe devolver un Future: con la flecha devolvía el de la
    // asignación y Flutter lanzaba "setState() callback argument returned a
    // Future", así que "Reintentar" nunca refrescaba la pantalla.
    setState(() {
      _futuro = _api.posts();
      _recargas++;
    });
    await _futuro.catchError((_) => <Post>[]);
  }

  Future<void> _abrir(Post post) async {
    // La TV sigue al teléfono: al abrir una noticia se publica la selección.
    publicarSeleccion(post);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DetailScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Con la búsqueda abierta, el botón atrás de Android la cierra en vez de
    // salir de la app.
    return PopScope(
      canPop: !_buscando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _buscando) _cerrarBusqueda();
      },
      child: Scaffold(
        appBar: _buscando ? _barraBusqueda() : AppBar(
          titleSpacing: 20,
          title: const Text(
            'BabyWolf',
            style: TextStyle(
              color: kTexto,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Buscar noticias',
              onPressed: _abrirBusqueda,
              icon: const Icon(Icons.search, color: kTexto),
            ),
            _botonWearable(),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _bannerAlerta(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _recargar,
                color: kNeon,
                backgroundColor: kSuperficie,
                child: FutureBuilder<List<Post>>(
                  future: _futuro,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _esqueleto();
                    }
                    if (snap.hasError) {
                      return _error(snap.error!);
                    }
                    final todos = snap.data ?? const <Post>[];
                    if (todos.isEmpty) {
                      return _vacio();
                    }
                    final delTema = _categoria == null
                        ? todos
                        : todos.where((p) => p.category == _categoria).toList();
                    final posts = buscarPosts(delTema, _consulta);
                    final conConsulta = _consulta.trim().isNotEmpty;
                    return ListView.separated(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                      itemCount: posts.length + 1,
                      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 16),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          // Mientras se busca, en vez del resumen va cuántas
                          // noticias coinciden (o el aviso de que no hay).
                          if (conConsulta) return _resultados(posts.length);
                          return ResumenTarjeta(
                            servicio: _resumen,
                            categoria: _categoria,
                            recarga: _recargas,
                            alElegir: (c) => setState(() => _categoria = c),
                          );
                        }
                        final post = posts[i - 1];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _PostCard(post: post, onTap: () => _abrir(post)),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _barraBusqueda() {
    return AppBar(
      leading: IconButton(
        tooltip: 'Cerrar búsqueda',
        onPressed: _cerrarBusqueda,
        icon: const Icon(Icons.arrow_back, color: kTexto),
      ),
      titleSpacing: 0,
      title: TextField(
        controller: _buscador,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: kTexto, fontSize: 17),
        cursorColor: kNeon,
        decoration: const InputDecoration(
          hintText: 'Buscar noticias',
          hintStyle: TextStyle(color: kTenue),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
        onChanged: (t) => setState(() => _consulta = t),
      ),
      actions: [
        if (_consulta.isNotEmpty)
          IconButton(
            tooltip: 'Borrar',
            onPressed: _borrarConsulta,
            icon: const Icon(Icons.close, color: kTenue),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _resultados(int n) {
    final tema = _categoria == null ? '' : ' en ${_categoria!.toUpperCase()}';
    if (n == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
        child: Column(
          children: [
            const Icon(Icons.search_off, color: kTenue, size: 48),
            const SizedBox(height: 14),
            Text(
              'Sin resultados para "${_consulta.trim()}"$tema',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTexto, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Prueba con otra palabra o revisa la ortografía.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTenue),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _borrarConsulta, child: const Text('Borrar búsqueda')),
            if (_categoria != null)
              TextButton(
                onPressed: () => setState(() => _categoria = null),
                child: const Text('Buscar en todos los temas'),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(
        '$n ${n == 1 ? 'noticia' : 'noticias'}$tema',
        style: const TextStyle(color: kTenue, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Estado del wearable siempre visible en la barra superior.
  Widget _botonWearable() {
    final a = context.watch<ActivityProvider>();
    final color = switch (a.estado) {
      EstadoBle.conectado => a.alertaCritica ? kNeon : kVerde,
      EstadoBle.buscando => Colors.amber,
      EstadoBle.error => kNeon,
      EstadoBle.desconectado => kTenue,
    };

    return IconButton(
      tooltip: a.textoEstado,
      onPressed: () => WearableSheet.mostrar(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.watch_outlined, color: kTexto),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(width: 9, height: 9, color: color),
          ),
        ],
      ),
    );
  }

  Widget _bannerAlerta() {
    final a = context.watch<ActivityProvider>();
    if (!a.alertaCritica) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => WearableSheet.mostrar(context),
      child: Container(
        width: double.infinity,
        color: kNeon,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Backlog crítico: ${a.sinLeer} noticias sin leer'
                '${a.temaActivo != null ? ' en ${a.temaActivo}' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _esqueleto() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) => Container(
        height: 250,
        decoration: BoxDecoration(
          color: kSuperficie,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _error(Object err) {
    // Requisito de la rúbrica: la app maneja el error de red sin romperse.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.wifi_off_rounded, color: kTenue, size: 52),
        const SizedBox(height: 18),
        const Text(
          'No se pudieron cargar las noticias',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kTexto,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$err',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTenue, fontSize: 12),
        ),
        const SizedBox(height: 22),
        Center(
          child: ElevatedButton.icon(
            onPressed: _recargar,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeon,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _vacio() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 80),
        Icon(Icons.article_outlined, color: kTenue, size: 48),
        SizedBox(height: 14),
        Text(
          'Todavía no hay noticias publicadas',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTenue),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSuperficie,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: post.coverImageUrl.isEmpty
                  ? _portadaFallback()
                  : Image.network(
                      post.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _portadaFallback(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(consolaDe(post.category), color: kNeon, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        post.category.toUpperCase(),
                        style: const TextStyle(
                          color: kNeonTexto,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        post.fechaCorta,
                        style: const TextStyle(color: kTenue, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: kTexto,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kTenue,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portadaFallback() => Container(
        color: kFondo,
        child: Center(
          child: Icon(consolaDe(post.category), color: kNeon, size: 44),
        ),
      );
}
