import 'package:flutter/material.dart';

import 'db/progress_store.dart';
import 'screens/home_screen.dart';
import 'stats/stats_store.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.store, this.stats});

  final ProgressStore? store;
  final StatsStore? stats;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Korean Vocab',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: HomeScreen(
        store: store ?? ProgressStore(),
        stats: stats ?? StatsStore(),
      ),
    );
  }
}
