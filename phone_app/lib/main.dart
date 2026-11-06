// BabyWolf — noticias de retro y consolas.
//
// La app del teléfono del blog BabyWolf:
//   Noticias  · el feed de la web, con el resumen del blog (Práctica 3).
//   Guardadas · noticias para leer sin internet en SQLite (Práctica 4).
//   Cuenta    · la cuenta de la web (Prácticas 5 y 10), los reportes de
//               noticias compartidos entre dispositivos (Práctica 9) y la
//               mesa de ayuda del equipo (Práctica 7).
// En cada noticia: comentarios entre lectores (Práctica 6).
//
// Además recibe las métricas del wearable por GATT NOTIFY y, al abrir una
// noticia, avisa al hub para que la Smart TV la muestre.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/sesion.dart';
import 'guardadas/guardadas.dart';
import 'providers/activity_provider.dart';
import 'screens/inicio_screen.dart';
import 'theme.dart';

void main() => runApp(const BabyWolfPhoneApp());

class BabyWolfPhoneApp extends StatelessWidget {
  const BabyWolfPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Los providers quedan por encima de MaterialApp para que las hojas
    // inferiores (wearable, reportar), que se montan en el Navigator raíz,
    // también los encuentren.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ActivityProvider()..iniciar()),
        ChangeNotifierProvider(create: (_) => Sesion()..restaurar()),
        ChangeNotifierProvider(create: (_) => Guardadas()..cargar()),
      ],
      child: MaterialApp(
        title: 'BabyWolf',
        debugShowCheckedModeBanner: false,
        theme: babywolfTheme(),
        home: const InicioScreen(),
      ),
    );
  }
}
