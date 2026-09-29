import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/product.dart';
import '../local/app_database.dart';
import '../sync/outbox.dart';

class CartItem {
  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.unit,
    required this.quantity,
    required this.stock,
    required this.farmerId,
    required this.farmerName,
    required this.imageUrl,
    required this.updatedAt,
    required this.isDirty,
  });

  final String productId;
  final String name;
  final double price;
  final String unit;
  final int quantity;
  final int stock;
  final String farmerId;
  final String? farmerName;
  final String? imageUrl;
  final DateTime updatedAt;
  final bool isDirty;
  double get subtotal => price * quantity;

  factory CartItem.fromMap(Map<String, Object?> row) => CartItem(
        productId: row['product_id']! as String,
        name: row['name']! as String,
        price: (row['price']! as num).toDouble(),
        unit: row['unit']! as String,
        quantity: row['quantity']! as int,
        stock: row['stock']! as int,
        farmerId: row['farmer_id']! as String,
        farmerName: row['farmer_name'] as String?,
        imageUrl: row['image_url'] as String?,
        updatedAt: DateTime.parse(row['updated_at']! as String),
        isDirty: (row['is_dirty']! as int) == 1,
      );

  Map<String, Object?> toMap(String userUid) => {
        'user_uid': userUid,
        'product_id': productId,
        'name': name,
        'price': price,
        'unit': unit,
        'quantity': quantity,
        'stock': stock,
        'farmer_id': farmerId,
        'farmer_name': farmerName,
        'image_url': imageUrl,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_dirty': isDirty ? 1 : 0,
      };
}

class CartRepository {
  CartRepository({Outbox outbox = const Outbox()}) : _outbox = outbox;

  final Outbox _outbox;

  String _uid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to use the shopping cart.');
    return uid;
  }

  Future<List<CartItem>> load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'cart_items',
      where: 'user_uid = ?',
      whereArgs: [_uid()],
      orderBy: 'updated_at ASC',
    );
    return rows.map(CartItem.fromMap).toList();
  }

  Future<void> add(Product product, int quantity) async {
    if (quantity < 1 || quantity > product.stock) {
      throw ArgumentError.value(quantity, 'quantity', 'Invalid stock quantity');
    }
    final uid = _uid();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cart_items',
        columns: ['quantity'],
        where: 'user_uid = ? AND product_id = ?',
        whereArgs: [uid, product.id],
        limit: 1,
      );
      final newQuantity =
          quantity + (rows.isEmpty ? 0 : rows.first['quantity']! as int);
      if (newQuantity > product.stock) {
        throw StateError('Only ${product.stock} ${product.unit} available.');
      }
      final item = CartItem(
        productId: product.id,
        name: product.name,
        price: product.price,
        unit: product.unit,
        quantity: newQuantity,
        stock: product.stock,
        farmerId: product.farmerId,
        farmerName: product.farmerName,
        imageUrl: product.imageUrl,
        updatedAt: DateTime.now(),
        isDirty: true,
      );
      await txn.insert(
        'cart_items',
        item.toMap(uid),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _outbox.enqueue(
        txn,
        userUid: uid,
        actionType: 'cart_upsert',
        payload: {'product_id': product.id, 'quantity': newQuantity},
      );
    });
  }

  Future<void> setQuantity(CartItem item, int quantity) async {
    if (quantity < 1 || quantity > item.stock) {
      throw StateError('Quantity must be between 1 and ${item.stock}.');
    }
    final uid = _uid();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'cart_items',
        {
          'quantity': quantity,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'is_dirty': 1,
        },
        where: 'user_uid = ? AND product_id = ?',
        whereArgs: [uid, item.productId],
      );
      await _outbox.enqueue(
        txn,
        userUid: uid,
        actionType: 'cart_upsert',
        payload: {'product_id': item.productId, 'quantity': quantity},
      );
    });
  }

  Future<void> remove(String productId) async {
    final uid = _uid();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'cart_items',
        where: 'user_uid = ? AND product_id = ?',
        whereArgs: [uid, productId],
      );
      await _outbox.enqueue(
        txn,
        userUid: uid,
        actionType: 'cart_remove',
        payload: {'product_id': productId},
      );
    });
  }

  Future<void> clear() async {
    final items = await load();
    final uid = _uid();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('cart_items', where: 'user_uid = ?', whereArgs: [uid]);
      for (final item in items) {
        await _outbox.enqueue(
          txn,
          userUid: uid,
          actionType: 'cart_remove',
          payload: {'product_id': item.productId},
        );
      }
    });
  }

  Future<void> clearProducts(Iterable<String> productIds) async {
    final uid = _uid();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final id in productIds) {
        await txn.delete(
          'cart_items',
          where: 'user_uid = ? AND product_id = ?',
          whereArgs: [uid, id],
        );
      }
    });
  }

  Future<void> markSynced(String productId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'cart_items',
      {'is_dirty': 0},
      where: 'user_uid = ? AND product_id = ?',
      whereArgs: [_uid(), productId],
    );
  }

  Future<List<Map<String, dynamic>>> pendingOrderDrafts() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'outbox',
      where: "user_uid = ? AND action_type = 'order_draft' "
          "AND status IN ('pending','failed')",
      whereArgs: [_uid()],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      final data = Map<String, dynamic>.from(row);
      data['payload'] = jsonDecode(row['payload']! as String);
      return data;
    }).toList();
  }

  Future<bool> enqueueReview(Map<String, dynamic> payload) async {
    final uid = _uid();
    final db = await AppDatabase.instance.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'outbox',
        columns: ['payload'],
        where: "user_uid = ? AND action_type = 'review_create' "
            "AND status IN ('pending','syncing','failed')",
        whereArgs: [uid],
      );
      final alreadyQueued = rows.any((row) {
        final queued = jsonDecode(row['payload']! as String) as Map;
        return queued['order_id']?.toString() ==
            payload['order_id']?.toString();
      });
      if (alreadyQueued) return false;
      await _outbox.enqueue(
        txn,
        userUid: uid,
        actionType: 'review_create',
        payload: payload,
      );
      return true;
    });
  }

  Future<Set<String>> pendingReviewOrderIds() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'outbox',
      columns: ['payload'],
      where: "user_uid = ? AND action_type = 'review_create' "
          "AND status IN ('pending','syncing','failed')",
      whereArgs: [_uid()],
    );
    return rows
        .map((row) => (jsonDecode(row['payload']! as String) as Map)['order_id']
            ?.toString())
        .whereType<String>()
        .toSet();
  }

  Future<void> saveOrderDrafts(List<Map<String, dynamic>> drafts) async {
    final uid = _uid();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final draft in drafts) {
        await _outbox.enqueue(
          txn,
          userUid: uid,
          actionType: 'order_draft',
          payload: draft,
        );
      }
      await txn.delete('cart_items', where: 'user_uid = ?', whereArgs: [uid]);
    });
  }

  Future<void> cacheProducts(List<Product> products) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final product in products) {
        await txn.insert(
          'products',
          {
            'id': product.id,
            'farmer_id': product.farmerId,
            'farmer_name': product.farmerName,
            'name': product.name,
            'description': product.description,
            'price': product.price,
            'unit': product.unit,
            'stock': product.stock,
            'min_stock': product.minStock,
            'category_id': product.categoryId,
            'category_name': product.categoryName,
            'market_id': product.marketId,
            'image_url': product.imageUrl,
            'is_active': product.isActive ? 1 : 0,
            'sold_count': product.soldCount,
            'status': product.status.value,
            'created_at': product.createdAt.toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Product>> cachedProducts({
    String? categoryId,
    String? marketId,
    String? farmerId,
    String sort = 'newest',
  }) async {
    final db = await AppDatabase.instance.database;
    final conditions = <String>['is_active = 1'];
    final args = <Object?>[];
    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    if (farmerId != null) {
      conditions.add('farmer_id = ?');
      args.add(farmerId);
    }
    if (marketId != null) {
      conditions.add('market_id = ?');
      args.add(marketId);
    }
    final orderBy = switch (sort) {
      'price_asc' => 'price ASC',
      'price_desc' => 'price DESC',
      'popular' => 'sold_count DESC',
      _ => 'created_at DESC',
    };
    final rows = await db.query(
      'products',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: orderBy,
    );
    return rows.map((row) {
      final data = <String, dynamic>{...row};
      data['is_active'] = (row['is_active']! as int) == 1 ? 1 : 0;
      return Product.fromJson(data);
    }).toList();
  }

  Future<Product?> cachedProduct(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'products',
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final data = <String, dynamic>{...rows.single};
    data['is_active'] = (rows.single['is_active']! as int) == 1 ? 1 : 0;
    return Product.fromJson(data);
  }

  Future<void> cacheCatalog({
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> markets,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final row in categories) {
        await txn.insert(
          'cached_categories',
          {
            'id': row['id'].toString(),
            'name': row['name']?.toString() ?? '',
            'name_en': row['name_en']?.toString(),
            'display_order': int.tryParse('${row['display_order']}') ?? 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in markets) {
        await txn.insert(
          'cached_markets',
          {
            'id': row['id'].toString(),
            'name': row['name']?.toString() ?? '',
            'name_en': row['name_en']?.toString(),
            'address': row['address']?.toString(),
            'latitude': double.tryParse('${row['latitude']}'),
            'longitude': double.tryParse('${row['longitude']}'),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> cachedCategories() async {
    final db = await AppDatabase.instance.database;
    final rows =
        await db.query('cached_categories', orderBy: 'display_order,id');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> cachedMarkets() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('cached_markets', orderBy: 'name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> cachePickupSlots(List<Map<String, dynamic>> slots) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final slot in slots) {
        await txn.insert(
          'cached_pickup_slots',
          {
            'id': slot['id'].toString(),
            'farmer_id': slot['farmer_id'].toString(),
            'farmer_name': slot['farmer_name']?.toString(),
            'start_time': slot['start_time'].toString(),
            'end_time': slot['end_time'].toString(),
            'capacity': int.parse(slot['capacity'].toString()),
            'booked_count': int.parse(slot['booked_count'].toString()),
            'is_open': int.parse(slot['is_open'].toString()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> cachedPickupSlots(
    String farmerId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'cached_pickup_slots',
      where:
          'farmer_id = ? AND start_time >= ? AND start_time < ? AND is_open = 1',
      whereArgs: [
        farmerId,
        from.toLocal().toIso8601String().substring(0, 19),
        to.toLocal().toIso8601String().substring(0, 19),
      ],
      orderBy: 'start_time ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> deleteCachedProducts(Iterable<String> ids) async {
    final values = ids.toList();
    if (values.isEmpty) return;
    final db = await AppDatabase.instance.database;
    await db.delete(
      'products',
      where: 'id IN (${List.filled(values.length, '?').join(',')})',
      whereArgs: values,
    );
  }
}
