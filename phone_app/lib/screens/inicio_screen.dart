// Navegación principal: Noticias · Guardadas · Cuenta.
//
// IndexedStack conserva cada pestaña viva: al volver al feed no se pierde el
// desplazamiento ni el filtro de tema.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sesion.dart';
import '../cuenta/cuenta_screen.dart';
import '../guardadas/guardadas.dart';
import '../guardadas/guardadas_screen.dart';
import '../theme.dart';
import 'feed_screen.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    final guardadas = context.watch<Guardadas>().lista.length;
    final sesion = context.watch<Sesion>();

    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: const [FeedScreen(), GuardadasScreen(), CuentaScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        backgroundColor: kSuperficie,
        indicatorColor: kNeonGlow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'Noticias',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: guardadas > 0,
              label: Text('$guardadas'),
              child: const Icon(Icons.bookmark_border),
            ),
            selectedIcon: const Icon(Icons.bookmark),
            label: 'Guardadas',
          ),
          NavigationDestination(
            icon: Icon(sesion.activa ? Icons.account_circle : Icons.account_circle_outlined),
            label: sesion.activa ? (sesion.cuenta?.apodo ?? 'Cuenta') : 'Cuenta',
          ),
        ],
      ),
    );
  }
}
