// Reportes de noticias (Prácticas 9 y 10).
//
// Un lector reporta un problema en una noticia (imagen rota, dato incorrecto…)
// y el admin del blog lo atiende desde su propio teléfono. Todos los
// dispositivos leen y escriben la MISMA tabla de Supabase (incidencias), no
// una copia local: eso es lo que pide la Práctica 9.
//
// La app no filtra nada: pide "todos los reportes" y la base (RLS, 006 y 007)
// devuelve sólo los del lector, o todos si es admin (Práctica 10).
//
// Ediciones simultáneas (Práctica 9, DB-07): cada reporte tiene un número de
// versión que la base sube en cada cambio. La app guarda con "versión = la
// que yo abrí"; si otro dispositivo guardó antes, la base no cambia nada y la
// app avisa en lugar de pisar el cambio ajeno. Además sólo se envían los
// campos que el usuario cambió, no el registro entero.

import 'package:http/http.dart' as http;

import '../core/supabase.dart';
import '../models/post.dart';

const kEstados = {'abierta': 'Pendiente', 'en_proceso': 'En proceso', 'cerrada': 'Resuelto'};
const kPrioridades = {'baja': 'Baja', 'media': 'Media', 'alta': 'Alta', 'critica': 'Crítica'};
const kMotivos = ['Imagen rota', 'Dato incorrecto', 'Enlace roto', 'Texto con errores', 'Contenido inapropiado', 'Otro'];

class Reporte {
  const Reporte({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.prioridad,
    required this.creadoPor,
    required this.postSlug,
    required this.postTitulo,
    required this.version,
    required this.creado,
    required this.actualizado,
    required this.actualizadoPor,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String estado;
  final String prioridad;
  final String creadoPor;
  final String postSlug;
  final String postTitulo;
  final int version;
  final DateTime? creado;
  final DateTime? actualizado;
  final String? actualizadoPor;

  String get estadoTexto => kEstados[estado] ?? estado;
  String get prioridadTexto => kPrioridades[prioridad] ?? prioridad;

  factory Reporte.desdeJson(Map<String, dynamic> j) => Reporte(
        id: j['id'] as String? ?? '',
        titulo: j['titulo'] as String? ?? '',
        descripcion: j['descripcion'] as String? ?? '',
        estado: j['estado'] as String? ?? 'abierta',
        prioridad: j['prioridad'] as String? ?? 'media',
        creadoPor: j['creado_por'] as String? ?? '',
        postSlug: j['post_slug'] as String? ?? '',
        postTitulo: j['post_titulo'] as String? ?? '',
        version: (j['version'] as num?)?.toInt() ?? 1,
        creado: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal(),
        actualizado: DateTime.tryParse(j['updated_at'] as String? ?? '')?.toLocal(),
        actualizadoPor: j['actualizado_por'] as String?,
      );

  /// Campos que cambian entre esta versión y [otra], para explicar un conflicto.
  List<String> diferencias(Reporte otra) => [
        if (estado != otra.estado) 'estado',
        if (prioridad != otra.prioridad) 'prioridad',
        if (descripcion != otra.descripcion) 'descripción',
        if (titulo != otra.titulo) 'título',
      ];
}

class ReglasReporte {
  static const minTitulo = 3;
  static const maxTitulo = 80;
  static const maxDescripcion = 500;

  static String? titulo(String t) {
    final v = t.trim();
    if (v.length < minTitulo) return 'Elige un motivo o escribe al menos $minTitulo caracteres';
    if (v.length > maxTitulo) return 'Máximo $maxTitulo caracteres';
    return null;
  }

  static String? descripcion(String d) =>
      d.trim().length > maxDescripcion ? 'Máximo $maxDescripcion caracteres' : null;
}

class ReporteFallo implements Exception {
  const ReporteFallo(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Otro dispositivo guardó el reporte después de que lo abriste.
class ConflictoVersion implements Exception {
  const ConflictoVersion(this.actual);

  /// Cómo quedó el reporte en la base.
  final Reporte actual;

  @override
  String toString() => 'Otro dispositivo guardó este reporte antes que tú.';
}

class ReportesApi {
  ReportesApi({http.Client? cliente}) : _c = cliente ?? http.Client();

  final http.Client _c;

  Future<http.Response> _enviar(String metodo, Map<String, String> q, String token, {Object? cuerpo}) =>
      Supabase.enviar(
        _c,
        Supabase.peticion(metodo, Supabase.rest('incidencias', q), token: token, cuerpo: cuerpo, devolverFilas: true),
      );

  List<Reporte> _filas(http.Response r, {int esperado = 200}) {
    final j = Supabase.json(r);
    if (r.statusCode != esperado || j is! List) throw ReporteFallo(Supabase.detalle(r));
    return j.whereType<Map<String, dynamic>>().map(Reporte.desdeJson).toList();
  }

  /// Los reportes que la base deja ver: los propios, o todos si es admin.
  Future<List<Reporte>> listar(String token, {String? estado}) async {
    final r = await _enviar('GET', {
      'select': '*',
      'order': 'updated_at.desc',
      if (estado != null) 'estado': 'eq.$estado',
    }, token);
    return _filas(r);
  }

  /// null = no existe o la base no te deja verlo.
  Future<Reporte?> leer(String token, String id) async {
    final f = _filas(await _enviar('GET', {'select': '*', 'id': 'eq.$id'}, token));
    return f.isEmpty ? null : f.first;
  }

  /// El dueño no se manda: la base lo toma del token (creado_por = auth.uid()).
  Future<Reporte> crear(String token, {required String titulo, String descripcion = '', String prioridad = 'media', Post? post}) async {
    final invalido = ReglasReporte.titulo(titulo) ?? ReglasReporte.descripcion(descripcion);
    if (invalido != null) throw ReporteFallo(invalido);
    final f = _filas(
      await _enviar('POST', {'select': '*'}, token, cuerpo: {
        'titulo': titulo.trim(),
        'descripcion': descripcion.trim(),
        'prioridad': prioridad,
        if (post != null) 'post_slug': post.slug,
        if (post != null) 'post_titulo': post.title,
      }),
      esperado: 201,
    );
    if (f.isEmpty) throw const ReporteFallo('La base no confirmó el reporte.');
    return f.first;
  }

  /// Guarda SOLO [cambios] y sólo si el reporte sigue en la versión que se
  /// abrió. Lanza [ConflictoVersion] si otro dispositivo guardó antes.
  Future<Reporte> guardar(String token, Reporte abierto, Map<String, Object> cambios) async {
    if (cambios.isEmpty) return abierto;
    final d = cambios['descripcion'];
    if (d is String) {
      final invalido = ReglasReporte.descripcion(d);
      if (invalido != null) throw ReporteFallo(invalido);
    }
    final f = _filas(await _enviar(
      'PATCH',
      {'select': '*', 'id': 'eq.${abierto.id}', 'version': 'eq.${abierto.version}'},
      token,
      cuerpo: cambios,
    ));
    if (f.isNotEmpty) return f.first;

    // 0 filas: o cambió la versión (conflicto) o no tienes permiso.
    final actual = await leer(token, abierto.id);
    if (actual == null) throw const ReporteFallo('Este reporte ya no existe o no tienes permiso para cambiarlo.');
    if (actual.version != abierto.version) throw ConflictoVersion(actual);
    throw const ReporteFallo('La base no permitió el cambio.');
  }

  /// true = se borró; false = la base no lo permitió.
  Future<bool> eliminar(String token, String id) async =>
      _filas(await _enviar('DELETE', {'id': 'eq.$id'}, token)).isNotEmpty;
}
