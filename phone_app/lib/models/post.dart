// Noticia del blog BabyWolf, tal como la devuelve GET /api/posts.

class Post {
  final String id;
  final String title;
  final String slug;
  final String content;
  final String category;
  final String coverImageUrl;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.title,
    required this.slug,
    required this.content,
    required this.category,
    required this.coverImageUrl,
    required this.createdAt,
  });

  /// Tolerante a campos ausentes: `cover_image_url` viaja con omitempty y
  /// `category` sólo existe desde que se agregó al backend.
  factory Post.fromJson(Map<String, dynamic> j) {
    return Post(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? 'Sin título',
      slug: j['slug'] as String? ?? '',
      content: j['content'] as String? ?? '',
      category: j['category'] as String? ?? 'general',
      coverImageUrl: j['cover_image_url'] as String? ?? '',
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime(2000),
    );
  }

  String get fechaCorta =>
      '${createdAt.day.toString().padLeft(2, '0')}/'
      '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
}
