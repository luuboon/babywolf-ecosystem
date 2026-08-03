// BabyWolf — noticias de retro y consolas.
//
// Feed del blog en el teléfono, más el monitor del wearable que llega por
// GATT NOTIFY. Al abrir una noticia se avisa al hub y la Smart TV la refleja.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/activity_provider.dart';
import 'screens/feed_screen.dart';
import 'theme.dart';

void main() => runApp(const BabyWolfPhoneApp());

class BabyWolfPhoneApp extends StatelessWidget {
  const BabyWolfPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    // El provider queda por encima de MaterialApp para que el bottom sheet
    // del wearable, que se monta en el Navigator raíz, también lo encuentre.
    return ChangeNotifierProvider(
      create: (_) => ActivityProvider()..iniciar(),
      child: MaterialApp(
        title: 'BabyWolf',
        debugShowCheckedModeBanner: false,
        theme: babywolfTheme(),
        home: const FeedScreen(),
      ),
    );
  }
}
