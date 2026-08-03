// Detalle de una noticia. Al abrirse avisa al hub, y con eso la Smart TV
// muestra la misma noticia.

import 'package:flutter/material.dart';

import '../models/post.dart';
import '../theme.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: Text(
          post.category.toUpperCase(),
          style: const TextStyle(
            color: kNeon,
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
        ],
      ),
    );
  }
}
