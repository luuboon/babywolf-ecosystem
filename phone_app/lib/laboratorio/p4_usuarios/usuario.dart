// Práctica 4 — Entidad Usuario (equivale a la @Entity de Room).

class Usuario {
  const Usuario({
    this.id,
    required this.nombre,
    required this.edad,
    required this.profesion,
  });

  /// null hasta que SQLite asigna el AUTOINCREMENT.
  final int? id;
  final String nombre;
  final int edad;
  final String profesion; // carrera

  Map<String, Object?> aMapa() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'edad': edad,
        'profesion': profesion,
      };

  factory Usuario.desdeMapa(Map<String, Object?> m) => Usuario(
        id: m['id'] as int?,
        nombre: m['nombre'] as String? ?? '',
        edad: m['edad'] as int? ?? 0,
        profesion: m['profesion'] as String? ?? '',
      );

  Usuario copiar({String? nombre, int? edad, String? profesion}) => Usuario(
        id: id,
        nombre: nombre ?? this.nombre,
        edad: edad ?? this.edad,
        profesion: profesion ?? this.profesion,
      );
}

/// Reglas de captura. Se validan antes de llegar a la base de datos.
class ValidadorUsuario {
  static const maxNombre = 60;
  static const maxProfesion = 60;

  static String? nombre(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'El nombre es obligatorio';
    if (t.length > maxNombre) return 'Máximo $maxNombre caracteres';
    return null;
  }

  static String? edad(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null) return 'Escribe la edad con números';
    if (n < 15 || n > 99) return 'La edad debe estar entre 15 y 99';
    return null;
  }

  static String? profesion(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'La carrera es obligatoria';
    if (t.length > maxProfesion) return 'Máximo $maxProfesion caracteres';
    return null;
  }
}
