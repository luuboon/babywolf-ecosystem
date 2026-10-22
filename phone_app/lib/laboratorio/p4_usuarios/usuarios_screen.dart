// Práctica 4 — Registrar, consultar, modificar y eliminar usuarios en SQLite.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../widgets_lab.dart';
import 'base_datos.dart';
import 'usuario.dart';
import 'usuario_dao.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key, this.dao});

  /// Inyectable para pruebas; si es null se abre la base del teléfono.
  final UsuarioDao? dao;

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _edad = TextEditingController();
  final _profesion = TextEditingController();
  final _correo = TextEditingController(); // Caso 4

  UsuarioDao? _dao;
  Usuario? _editando;
  List<Usuario>? _usuarios; // null = todavía no se presiona "VER usuarios"
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final dao = widget.dao ?? UsuarioDao(await BaseDatos.abrir());
    if (mounted) setState(() => _dao = dao);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _edad.dispose();
    _profesion.dispose();
    _correo.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    _form.currentState?.reset();
    _nombre.clear();
    _edad.clear();
    _profesion.clear();
    _correo.clear();
    setState(() => _editando = null);
  }

  Future<void> _guardar() async {
    final dao = _dao;
    if (dao == null || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _ocupado = true);
    try {
      final datos = Usuario(
        id: _editando?.id,
        nombre: _nombre.text.trim(),
        edad: int.parse(_edad.text.trim()),
        profesion: _profesion.text.trim(),
        correo: _correo.text.trim(),
      );
      if (_editando == null) {
        final id = await dao.insertar(datos); // Caso 1
        if (mounted) avisar(context, 'Usuario registrado con id $id');
      } else {
        final n = await dao.actualizar(datos); // Caso 3
        if (mounted) avisar(context, n == 1 ? 'Usuario actualizado' : 'El usuario ya no existe', error: n != 1);
      }
      _limpiarFormulario();
      if (_usuarios != null) await _verUsuarios();
    } catch (_) {
      if (mounted) avisar(context, 'No fue posible guardar el usuario', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// "VER usuarios" → dao.obtenerTodos() (Caso 2).
  Future<void> _verUsuarios() async {
    final dao = _dao;
    if (dao == null) return;
    final lista = await dao.obtenerTodos();
    if (mounted) setState(() => _usuarios = lista);
  }

  void _editar(Usuario u) {
    setState(() => _editando = u);
    _nombre.text = u.nombre;
    _edad.text = '${u.edad}';
    _profesion.text = u.profesion;
    _correo.text = u.correo;
  }

  Future<void> _eliminar(Usuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSuperficie,
        title: const Text('Eliminar usuario', style: TextStyle(color: kTexto)),
        content: Text('¿Eliminar a ${u.nombre}? No se puede deshacer.', style: const TextStyle(color: kTenue)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || _dao == null || u.id == null) return;
    await _dao!.eliminar(u.id!);
    if (_editando?.id == u.id) _limpiarFormulario();
    if (mounted) avisar(context, 'Usuario eliminado');
    await _verUsuarios();
  }

  @override
  Widget build(BuildContext context) {
    final editando = _editando != null;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTexto),
        title: const Text('Usuarios · SQLite', style: TextStyle(color: kTexto, fontWeight: FontWeight.w800)),
      ),
      body: _dao == null
          ? const Center(child: CircularProgressIndicator(color: kNeon))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Seccion(
                  titulo: editando ? 'Modificar usuario #${_editando!.id}' : 'Registrar usuario',
                  child: Form(
                    key: _form,
                    child: Column(
                      children: [
                        TextFormField(
                          key: const Key('campo_nombre'),
                          controller: _nombre,
                          style: const TextStyle(color: kTexto),
                          decoration: campo('Nombre'),
                          textCapitalization: TextCapitalization.words,
                          validator: ValidadorUsuario.nombre,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('campo_edad'),
                          controller: _edad,
                          style: const TextStyle(color: kTexto),
                          decoration: campo('Edad'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: ValidadorUsuario.edad,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('campo_profesion'),
                          controller: _profesion,
                          style: const TextStyle(color: kTexto),
                          decoration: campo('Profesión (carrera)'),
                          validator: ValidadorUsuario.profesion,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('campo_correo'),
                          controller: _correo,
                          style: const TextStyle(color: kTexto),
                          decoration: campo('Correo'),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          validator: ValidadorUsuario.correo,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: BotonPrincipal(
                                texto: editando ? 'ACTUALIZAR' : 'GUARDAR',
                                icono: editando ? Icons.edit : Icons.save_outlined,
                                onPressed: _ocupado ? null : _guardar,
                              ),
                            ),
                            if (editando) ...[
                              const SizedBox(width: 10),
                              TextButton(onPressed: _limpiarFormulario, child: const Text('Cancelar')),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('boton_ver'),
                    onPressed: _verUsuarios,
                    icon: const Icon(Icons.list_alt, color: kNeonTexto),
                    label: const Text('VER usuarios', style: TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kNeon),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_usuarios != null) _lista(_usuarios!),
              ],
            ),
    );
  }

  Widget _lista(List<Usuario> usuarios) {
    if (usuarios.isEmpty) {
      return const Seccion(
        titulo: 'Usuarios registrados (0)',
        child: Text('No hay usuarios registrados.', style: TextStyle(color: kTenue)),
      );
    }
    return Seccion(
      titulo: 'Usuarios registrados (${usuarios.length})',
      child: Column(
        children: [
          for (final u in usuarios)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: kFondo,
                child: Text('${u.id}', style: const TextStyle(color: kNeonTexto, fontWeight: FontWeight.w800)),
              ),
              title: Text(u.nombre, style: const TextStyle(color: kTexto, fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${u.edad} años · ${u.profesion}\n${u.correo.isEmpty ? 'sin correo (registro de la versión 1)' : u.correo}',
                style: const TextStyle(color: kTenue),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Modificar',
                    icon: const Icon(Icons.edit_outlined, color: kTexto),
                    onPressed: () => _editar(u),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline, color: kNeonTexto),
                    onPressed: () => _eliminar(u),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
