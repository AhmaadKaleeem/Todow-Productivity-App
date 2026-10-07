import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database_schema.dart';

class AppDatabase {
  AppDatabase._();
  static AppDatabase? _instance;
  static Database? _db;

  static Future<AppDatabase> open([String? pathOverride]) async {
    if (_instance != null) return _instance!;
    _instance = AppDatabase._();
    _db = await databaseFactoryFfiWeb.openDatabase(
      pathOverride ?? 'todow.db',
      options: OpenDatabaseOptions(
        version: 10,
        onCreate: createDatabaseSchema,
        onUpgrade: upgradeDatabaseSchema,
      ),
    );
    return _instance!;
  }

  Database get db {
    final database = _db;
    if (database == null) throw StateError('Database not opened.');
    return database;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
    _instance = null;
  }
}
