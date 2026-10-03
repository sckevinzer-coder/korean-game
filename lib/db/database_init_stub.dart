import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

DatabaseFactory get databaseFactoryForPlatform => databaseFactory;

Future<String> defaultDbPath(String name) async {
  final dir = await getDatabasesPath();
  return p.join(dir, name);
}
