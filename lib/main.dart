import 'package:flutter/material.dart';

import 'db/progress_store.dart';
import 'screens/home_screen.dart';
import 'stats/bookmark_store.dart';
import 'stats/error_stats.dart';
import 'stats/stats_store.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.store, this.stats, this.errors, this.bookmarks});

  final ProgressStore? store;
  final StatsStore? stats;
  final ErrorStatsStore? errors;
  final BookmarkStore? bookmarks;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '韓国語単語',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: HomeScreen(
        store: store ?? ProgressStore(),
        stats: stats ?? StatsStore(),
        errors: errors ?? ErrorStatsStore(),
        bookmarks: bookmarks ?? BookmarkStore(),
      ),
    );
  }
}
