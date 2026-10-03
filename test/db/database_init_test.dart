import 'package:flutter_test/flutter_test.dart';
import 'package:korean_game/db/database_init.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('platform database factory resolves on VM', () {
    expect(databaseFactoryForPlatform, isNotNull);
  });
}
