import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';
import '../models/word.dart';

class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({
    super.key,
    this.words = const [],
    this.locale = AppLocale.japanese,
    this.pairs = 4,
    this.loadWords = loadWordsForLevel,
    this.level = 1,
  });

  final List<Word> words;
  final AppLocale locale;
  final int pairs;
  final Future<List<Word>> Function(int level) loadWords;
  final int level;

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class _MiniGameScreenState extends State<MiniGameScreen> {
  List<_Tile> _tiles = const [];
  int? _selectedIndex;
  int _score = 0;
  int _mistakes = 0;
  int _matched = 0;
  late final Future<void> _boot;

  @override
  void initState() {
    super.initState();
    _boot = _start();
  }

  Future<void> _start() async {
    var source = widget.words;
    if (source.length < widget.pairs) {
      try {
        source = await widget.loadWords(widget.level);
      } catch (_) {
        source = const [];
      }
    }
    final shuffled = List<Word>.of(source)..shuffle();
    final picked = shuffled.take(widget.pairs).toList();
    final tiles = <_Tile>[];
    for (final w in picked) {
      tiles.add(_Tile(text: w.korean, pairId: w.id, kind: _Kind.word));
      tiles.add(_Tile(text: w.meaningJa, pairId: w.id, kind: _Kind.meaning));
    }
    tiles.shuffle();
    if (mounted) {
      setState(() {
        _tiles = tiles;
        _selectedIndex = null;
        _score = 0;
        _mistakes = 0;
        _matched = 0;
      });
    }
  }

  void _onTap(int index) {
    final tile = _tiles[index];
    if (tile.done) return;
    final selected = _selectedIndex;
    if (selected == null) {
      setState(() => _selectedIndex = index);
      return;
    }
    if (selected == index) {
      setState(() => _selectedIndex = null);
      return;
    }
    final other = _tiles[selected];
    if (other.pairId == tile.pairId && other.kind != tile.kind) {
      setState(() {
        _tiles[selected].done = true;
        tile.done = true;
        _tiles = List.of(_tiles);
        _selectedIndex = null;
        _score += 100;
        _matched += 1;
      });
    } else {
      setState(() {
        _mistakes += 1;
        _score = (_score - 20).clamp(0, 1 << 30);
        _selectedIndex = null;
      });
    }
  }

  bool get _complete => _matched >= widget.pairs && _tiles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return Scaffold(
      appBar: AppBar(title: Text(tr(locale, 'game.title'))),
      body: FutureBuilder<void>(
        future: _boot,
        builder: (context, snapshot) {
          if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_tiles.isEmpty) {
            return Center(child: Text(tr(locale, 'game.empty')));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(trParams(locale, 'game.score', {'n': _score})),
                    const SizedBox(width: 16),
                    Text(trParams(locale, 'game.mistakes', {'n': _mistakes})),
                  ],
                ),
              ),
              if (_complete)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    trParams(locale, 'game.clear', {'n': _score}),
                    style:
                        const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                  for (var i = 0; i < _tiles.length; i++)
                    Builder(builder: (context) {
                      final tile = _tiles[i];
                      final selected = _selectedIndex == i;
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 32) / 2 - 4,
                        child: GestureDetector(
                          onTap: tile.done ? null : () => _onTap(i),
                          child: Container(
                            height: 64,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tile.done
                                  ? Colors.green[100]
                                  : selected
                                      ? Colors.amber[200]
                                      : Colors.blueGrey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Colors.orange
                                    : Colors.blueGrey[200]!,
                              ),
                            ),
                            child: Text(
                              tile.done ? '✓' : tile.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: tile.text.length > 8 ? 12 : 16,
                                fontWeight: FontWeight.w600,
                                color: tile.done
                                    ? Colors.green[800]
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _Kind { word, meaning }

class _Tile {
  _Tile({required this.text, required this.pairId, required this.kind});

  final String text;
  final String pairId;
  final _Kind kind;
  bool done = false;
}
