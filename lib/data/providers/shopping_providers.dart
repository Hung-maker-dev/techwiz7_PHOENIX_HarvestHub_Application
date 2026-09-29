import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/customer_api.dart';
import '../repositories/cart_repository.dart';
import '../repositories/product_repository.dart';
import '../sync/sync_engine.dart';
import '../../models/product.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository();
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    ref.watch(customerApiProvider),
    ref.watch(cartRepositoryProvider),
  );
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    ref.watch(customerApiProvider),
    ref.watch(cartRepositoryProvider),
  );
});

final shoppingConnectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  var wasOnline = initial.any((item) => item != ConnectivityResult.none);
  yield wasOnline;
  if (wasOnline) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final errors = await ref.read(syncEngineProvider).synchronize(uid);
        for (final error in errors) {
          debugPrint('A queued shopping action needs attention: $error');
        }
        ref.invalidate(cartProvider);
      } catch (error, stackTrace) {
        debugPrint('Initial shopping sync failed: $error\n$stackTrace');
      }
    }
  }
  await for (final state in connectivity.onConnectivityChanged) {
    final online = state.any((item) => item != ConnectivityResult.none);
    if (online && !wasOnline) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final errors = await ref.read(syncEngineProvider).synchronize(uid);
          for (final error in errors) {
            debugPrint('A queued shopping action needs attention: $error');
          }
          ref.invalidate(cartProvider);
        } catch (error, stackTrace) {
          debugPrint('Shopping sync failed: $error\n$stackTrace');
        }
      }
    }
    wasOnline = online;
    yield online;
  }
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(shoppingConnectivityProvider).maybeWhen(
        data: (value) => value,
        orElse: () => true,
      );
});

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  @override
  Future<List<CartItem>> build() async {
    ref.watch(shoppingConnectivityProvider);
    return ref.watch(cartRepositoryProvider).load();
  }

  Future<void> add(Product product, int quantity) async {
    await ref.read(cartRepositoryProvider).add(product, quantity);
    state = AsyncData(await ref.read(cartRepositoryProvider).load());
    if (ref.read(isOnlineProvider)) {
      unawaited(_sync());
    }
  }

  Future<void> setQuantity(CartItem item, int quantity) async {
    await ref.read(cartRepositoryProvider).setQuantity(item, quantity);
    state = AsyncData(await ref.read(cartRepositoryProvider).load());
    if (ref.read(isOnlineProvider)) unawaited(_sync());
  }

  Future<void> remove(String productId) async {
    await ref.read(cartRepositoryProvider).remove(productId);
    state = AsyncData(await ref.read(cartRepositoryProvider).load());
    if (ref.read(isOnlineProvider)) unawaited(_sync());
  }

  Future<void> clear() async {
    await ref.read(cartRepositoryProvider).clear();
    state = const AsyncData([]);
    if (ref.read(isOnlineProvider)) unawaited(_sync());
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(cartRepositoryProvider).load());
  }

  int get totalQuantity =>
      state.value?.fold<int>(0, (total, item) => total + item.quantity) ?? 0;

  Future<void> _sync() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final errors = await ref.read(syncEngineProvider).synchronize(uid);
      for (final error in errors) {
        debugPrint('A queued shopping action needs attention: $error');
      }
      state = AsyncData(await ref.read(cartRepositoryProvider).load());
    } catch (error, stackTrace) {
      debugPrint('Shopping sync failed: $error\n$stackTrace');
    }
  }
}

final cartProvider =
    AsyncNotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final wishlistProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(customerApiProvider).fetchWishlist();
});

class ShopFilterState {
  const ShopFilterState({
    this.categoryId,
    this.marketId,
    this.farmerId,
    this.sort = 'newest',
  });

  final String? categoryId;
  final String? marketId;
  final String? farmerId;
  final String sort;
}

class ShopFilterNotifier extends Notifier<ShopFilterState> {
  @override
  ShopFilterState build() => const ShopFilterState();

  void update({
    String? categoryId,
    String? marketId,
    String? farmerId,
    String? sort,
    bool clearCategory = false,
    bool clearMarket = false,
    bool clearFarmer = false,
  }) {
    state = ShopFilterState(
      categoryId: clearCategory ? null : categoryId ?? state.categoryId,
      marketId: clearMarket ? null : marketId ?? state.marketId,
      farmerId: clearFarmer ? null : farmerId ?? state.farmerId,
      sort: sort ?? state.sort,
    );
  }

  void clear() => state = const ShopFilterState();
}

final shopFilterProvider =
    NotifierProvider<ShopFilterNotifier, ShopFilterState>(
        ShopFilterNotifier.new);
