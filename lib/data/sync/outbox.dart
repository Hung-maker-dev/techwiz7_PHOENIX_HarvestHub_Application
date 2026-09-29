import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.userUid,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String userUid;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String status;

  factory OutboxEntry.fromMap(Map<String, Object?> row) => OutboxEntry(
        id: row['id']! as String,
        userUid: row['user_uid']! as String,
        actionType: row['action_type']! as String,
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload']! as String) as Map,
        ),
        createdAt: DateTime.parse(row['created_at']! as String),
        status: row['status']! as String,
      );
}

class Outbox {
  const Outbox();

  Future<String> enqueue(
    Transaction txn, {
    required String userUid,
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    final id = const Uuid().v4();
    await txn.insert('outbox', {
      'id': id,
      'user_uid': userUid,
      'action_type': actionType,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
      'retry_count': 0,
    });
    return id;
  }

  Future<List<OutboxEntry>> pendingFor(String userUid) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'outbox',
      {'status': 'pending'},
      where: "user_uid = ? AND status = 'syncing'",
      whereArgs: [userUid],
    );
    final rows = await db.query(
      'outbox',
      where: "user_uid = ? AND status = 'pending'",
      whereArgs: [userUid],
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboxEntry.fromMap).toList();
  }
}
