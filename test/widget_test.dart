import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/main.dart';

void main() {
  late ProgressStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    store = ProgressStore(path: inMemoryDatabasePath);
    await store.dueCards(DateTime(2026, 10, 3));
  });

  tearDown(() async {
    await store.close();
  });

  testWidgets('app boots to home screen', (tester) async {
    await tester.pumpWidget(MyApp(store: store));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('今日の復習: 0 / 5 枚'), findsOneWidget);
    expect(find.text('連続学習: 0日'), findsOneWidget);
  });
}
