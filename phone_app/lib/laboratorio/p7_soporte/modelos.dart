// Práctica 7 — Modelos de la mesa de ayuda (espejo de las tablas soporte_*).

const kRolAdmin = 'admin';
const kRolAgente = 'agente';
const kRolUsuario = 'usuario';
const kRolAdminTemporal = 'admin_temporal';

const kPrioridades = ['Baja', 'Media', 'Alta'];
const kEstados = ['abierto', 'asignado', 'en_proceso', 'resuelto'];
const kTipos = {'falla': 'Reporte de falla', 'atencion': 'Proceso de atención', 'acceso': 'Acceso perdido'};

String etiquetaRol(String rol) => switch (rol) {
      kRolAdmin => 'Administrador',
      kRolAgente => 'Agente de atención',
      kRolAdminTemporal => 'Agente (cubre al admin)',
      _ => 'Usuario',
    };

bool puedeAdministrar(String rolEfectivo) => rolEfectivo == kRolAdmin || rolEfectivo == kRolAdminTemporal;

/// Tiempo real sólo para administrador y agente (la matriz lo pide así).
bool puedeMonitorear(String rolEfectivo) => rolEfectivo != kRolUsuario;

DateTime? _fecha(Object? v) => v is String ? DateTime.tryParse(v) : null;

class Participante {
  const Participante({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.dispositivo,
    this.conectado = false,
    this.rolEfectivo,
  });

  final String id;
  final String nombre;
  final String rol;
  final String dispositivo;
  final bool conectado;
  final String? rolEfectivo;

  factory Participante.desdeJson(Map<String, dynamic> j) => Participante(
        id: j['id'] as String? ?? '',
        nombre: j['nombre'] as String? ?? '',
        rol: j['rol'] as String? ?? kRolUsuario,
        dispositivo: j['dispositivo'] as String? ?? '',
        conectado: j['conectado'] as bool? ?? false,
        rolEfectivo: j['rol_efectivo'] as String?,
      );

  Map<String, dynamic> aJson() => {'id': id, 'nombre': nombre, 'rol': rol, 'dispositivo': dispositivo};
}

class Reporte {
  const Reporte({
    required this.id,
    required this.equipo,
    required this.descripcion,
    required this.tipo,
    required this.prioridad,
    required this.estado,
    required this.solicitanteId,
    required this.agenteId,
    required this.directoAdmin,
    required this.actualizado,
  });

  final String id;
  final String equipo;
  final String descripcion;
  final String tipo;
  final String prioridad;
  final String estado;
  final String solicitanteId;
  final String? agenteId;
  final bool directoAdmin;
  final DateTime? actualizado;

  factory Reporte.desdeJson(Map<String, dynamic> j) => Reporte(
        id: j['id'] as String? ?? '',
        equipo: j['equipo'] as String? ?? '',
        descripcion: j['descripcion'] as String? ?? '',
        tipo: j['tipo'] as String? ?? 'falla',
        prioridad: j['prioridad'] as String? ?? 'Media',
        estado: j['estado'] as String? ?? 'abierto',
        solicitanteId: j['solicitante_id'] as String? ?? '',
        agenteId: j['agente_id'] as String?,
        directoAdmin: j['directo_admin'] as bool? ?? false,
        actualizado: _fecha(j['updated_at']),
      );
}

class MensajeSoporte {
  const MensajeSoporte({
    required this.id,
    required this.emisorId,
    required this.emisorNombre,
    required this.emisorRol,
    required this.paraId,
    required this.reporteId,
    required this.texto,
    required this.archivoPath,
    required this.archivoNombre,
    required this.hora,
  });

  final int id;
  final String emisorId;
  final String emisorNombre;
  final String emisorRol;
  final String? paraId;
  final String? reporteId;
  final String texto;
  final String? archivoPath;
  final String? archivoNombre;
  final DateTime hora;

  bool get esImagen {
    final n = (archivoNombre ?? '').toLowerCase();
    return n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg');
  }

  factory MensajeSoporte.desdeJson(Map<String, dynamic> j) => MensajeSoporte(
        id: (j['id'] as num?)?.toInt() ?? 0,
        emisorId: j['emisor_id'] as String? ?? '',
        emisorNombre: j['emisor_nombre'] as String? ?? '',
        emisorRol: j['emisor_rol'] as String? ?? '',
        paraId: j['para_id'] as String?,
        reporteId: j['reporte_id'] as String?,
        texto: j['texto'] as String? ?? '',
        archivoPath: j['archivo_path'] as String?,
        archivoNombre: j['archivo_nombre'] as String?,
        hora: _fecha(j['created_at']) ?? DateTime.now(),
      );
}

class ConteoEmisor {
  const ConteoEmisor(this.emisorId, this.nombre, this.total);
  final String emisorId;
  final String nombre;
  final int total;
}

/// Validación local del formulario de reporte (el backend la repite).
class ValidadorReporte {
  static final _id = RegExp(r'^REP[0-9]{3,6}$');

  static String? id(String? v) {
    final t = (v ?? '').trim().toUpperCase();
    if (t.isEmpty) return null; // opcional: el backend numera
    if (!_id.hasMatch(t)) return 'Formato REP seguido de 3 a 6 dígitos (REP001)';
    return null;
  }

  static String? equipo(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'El equipo es obligatorio';
    if (t.length > 80) return 'Máximo 80 caracteres';
    return null;
  }

  static String? descripcion(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'La descripción es obligatoria';
    if (t.length > 500) return 'Máximo 500 caracteres';
    return null;
  }
}
