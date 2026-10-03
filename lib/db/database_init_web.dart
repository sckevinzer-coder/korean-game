import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

DatabaseFactory get databaseFactoryForPlatform =>
    createDatabaseFactoryFfiWeb();

/// On web there is no filesystem path; the name is used as the
/// IndexedDB database key.
Future<String> defaultDbPath(String name) async => name;
