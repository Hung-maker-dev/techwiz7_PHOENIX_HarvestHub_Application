import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const _databaseName = 'harvesthub_offline.db';
  static const _version = 1;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final directory = await getDatabasesPath();
    final path = p.join(directory, _databaseName);
    _database = await openDatabase(
      path,
      version: _version,
      onCreate: (db, _) async {
        final schema = await rootBundle.loadString('lib/data/local/schema.sql');
        final batch = db.batch();
        for (final statement in schema.split(';')) {
          final sql = statement.trim();
          if (sql.isNotEmpty) batch.execute(sql);
        }
        await batch.commit(noResult: true);
      },
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
