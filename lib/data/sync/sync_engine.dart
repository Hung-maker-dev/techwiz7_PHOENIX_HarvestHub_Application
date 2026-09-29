import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/network/api_exception.dart';
import '../../models/product.dart';
import '../api/customer_api.dart';
import '../local/app_database.dart';
import '../repositories/cart_repository.dart';
import 'outbox.dart';

class SyncEngine {
  SyncEngine(this._api, this._cart);

  final CustomerApi _api;
  final CartRepository _cart;
  final Outbox _outbox = const Outbox();
  bool _running = false;

  Future<List<String>> synchronize(String userUid) async {
    if (_running) return const [];
    _running = true;
    try {
      try {
        await _pullProducts();
      } on ApiException catch (error) {
        debugPrint('Product delta pull failed: $error');
      }
      return await _push(userUid);
    } finally {
      _running = false;
    }
  }

  Future<void> _pullProducts() async {
    final db = await AppDatabase.instance.database;
    final meta = await db.query(
      'sync_meta',
      columns: ['last_synced_at'],
      where: 'table_name = ?',
      whereArgs: ['products'],
      limit: 1,
    );
    final delta = await _api.fetchProductDelta(
      meta.isEmpty ? null : meta.first['last_synced_at'] as String,
    );
    await _cart.cacheProducts(delta['items'] as List<Product>);
    await _cart.deleteCachedProducts(
      (delta['deletedIds'] as List).map((id) => id.toString()),
    );
    await db.insert(
      'sync_meta',
      {
        'table_name': 'products',
        'last_synced_at': delta['syncedAt'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> _push(String userUid) async {
    final errors = <String>[];
    final db = await AppDatabase.instance.database;
    for (final entry in await _outbox.pendingFor(userUid)) {
      await db.update(
        'outbox',
        {'status': 'syncing'},
        where: 'id = ? AND user_uid = ?',
        whereArgs: [entry.id, userUid],
      );
      try {
        switch (entry.actionType) {
          case 'cart_upsert':
            await _api.upsertCartItem(
              productId: entry.payload['product_id'] as String,
              quantity: entry.payload['quantity'] as int,
            );
            await _cart.markSynced(entry.payload['product_id'] as String);
            break;
          case 'cart_remove':
            await _api.removeCartItem(entry.payload['product_id'] as String);
            break;
          case 'order_draft':
            await _api.createOrder(entry.payload);
            await _cart.clearProducts(
              (entry.payload['items'] as List<dynamic>)
                  .map((item) => (item as Map)['product_id'].toString()),
            );
            break;
          case 'review_create':
            await _api.submitReview(
              orderId: entry.payload['order_id'] as String,
              productId: entry.payload['product_id'] as String,
              farmerId: entry.payload['farmer_id'] as String,
              rating: entry.payload['rating'] as int,
              comment: entry.payload['comment'] as String?,
            );
            break;
          default:
            throw StateError('Unsupported outbox action: ${entry.actionType}');
        }
        await db.delete('outbox', where: 'id = ?', whereArgs: [entry.id]);
      } on ApiException catch (error) {
        if (error.statusCode != null &&
            error.statusCode! >= 400 &&
            error.statusCode! < 500) {
          await db.update(
            'outbox',
            {
              'status': 'failed',
              'last_error': error.message,
              'retry_count': 1,
            },
            where: 'id = ?',
            whereArgs: [entry.id],
          );
          errors.add(error.message);
          continue;
        }
        await db.update(
          'outbox',
          {'status': 'pending'},
          where: 'id = ?',
          whereArgs: [entry.id],
        );
        break;
      } catch (error, stackTrace) {
        await db.update(
          'outbox',
          {
            'status': 'failed',
            'last_error': error.toString(),
            'retry_count': 1,
          },
          where: 'id = ?',
          whereArgs: [entry.id],
        );
        debugPrint('Outbox action ${entry.id} failed: $error\n$stackTrace');
        errors.add(error.toString());
      }
    }
    return errors;
  }
}
