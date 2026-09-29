import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../data/api/customer_api.dart';
import '../../data/providers/shopping_providers.dart';
import '../../data/repositories/cart_repository.dart';
import '../../models/product.dart';
import '../../shared_widgets/empty_state.dart';
import '../../shared_widgets/current_location_button.dart';
import '../../shared_widgets/harvesthub_logo.dart';
import '../../shared_widgets/notification_bell.dart';
import '../../shared_widgets/product_favorite_button.dart';
import '../../shared_widgets/role_account_scaffold.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  late Future<List<Product>> _products;
  late Future<List<Map<String, dynamic>>> _categories;
  late Future<List<Map<String, dynamic>>> _markets;
  final _searchController = TextEditingController();
  String _search = '';
  late final ProviderSubscription _filterSubscription;
  late final ProviderSubscription _networkSubscription;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _load();
    _categories = _loadCategories();
    _markets = _loadMarkets();
    _filterSubscription = ref.listenManual(
      shopFilterProvider,
      (_, __) => _reload(),
    );
    _networkSubscription = ref.listenManual(
      isOnlineProvider,
      (_, __) => _reload(),
    );
  }

  void _load() {
    final filter = ref.read(shopFilterProvider);
    _products = ref.read(productRepositoryProvider).browse(
          online: ref.read(isOnlineProvider),
          categoryId: filter.categoryId,
          marketId: filter.marketId,
          farmerId: filter.farmerId,
          sort: filter.sort,
        );
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final local = ref.read(cartRepositoryProvider);
    if (!ref.read(isOnlineProvider)) return local.cachedCategories();
    try {
      final rows = await ref.read(customerApiProvider).fetchCategories();
      await local.cacheCatalog(
        categories: rows,
        markets: await local.cachedMarkets(),
      );
      return rows;
    } on ApiException catch (error) {
      final cached = await local.cachedCategories();
      if (error.isNetworkError && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadMarkets() async {
    final local = ref.read(cartRepositoryProvider);
    if (!ref.read(isOnlineProvider)) return local.cachedMarkets();
    try {
      final rows = await ref.read(customerApiProvider).fetchMarkets();
      await local.cacheCatalog(
        categories: await local.cachedCategories(),
        markets: rows,
      );
      return rows;
    } on ApiException catch (error) {
      final cached = await local.cachedMarkets();
      if (error.isNetworkError && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _currentPage = 0;
      _load();
      _categories = _loadCategories();
      _markets = _loadMarkets();
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _filterSubscription.close();
    _networkSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(shopFilterProvider);
    final cart = ref.watch(cartProvider).valueOrNull ?? const <CartItem>[];
    final wishlist =
        ref.watch(wishlistProvider).valueOrNull ?? const <Product>[];
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const RoleMenuButton(),
        title: const HarvestHubLogo(compact: true, showName: false),
        actions: [
          const NotificationBell(isFarmer: false),
          IconButton(
            tooltip: 'shop.browse.map'.tr(),
            onPressed: () => context.push('/shop/map'),
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            tooltip: 'account.wishlist.title'.tr(),
            onPressed: () => context.push('/wishlist'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.favorite_border),
                if (wishlist.isNotEmpty)
                  Positioned(
                    right: -7,
                    top: -5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          '${wishlist.length}',
                          style: TextStyle(
                            color: colors.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'shop.cart.title'.tr(),
                onPressed: () => context.push('/cart'),
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
              if (cart.isNotEmpty)
                Positioned(
                  right: 4,
                  top: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        '${cart.fold<int>(0, (sum, item) => sum + item.quantity)}',
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _search = value.trim().toLowerCase();
                  _currentPage = 0;
                });
                if (_pageController.hasClients) _pageController.jumpToPage(0);
              },
              decoration: InputDecoration(
                hintText: 'shop.browse.search'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: colors.primary, size: 19),
                      const SizedBox(width: 8),
                      Text(
                        'shop.browse.filters'.tr(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categories,
                  builder: (context, snapshot) {
                    final items =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    return SizedBox(
                      height: 46,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        children: [
                          _FilterChip(
                            label: 'shop.browse.all'.tr(),
                            selected: filters.categoryId == null,
                            onTap: () => ref
                                .read(shopFilterProvider.notifier)
                                .update(clearCategory: true),
                          ),
                          for (final item in items)
                            _FilterChip(
                              label: (item['name'] ?? '').toString(),
                              selected:
                                  filters.categoryId == item['id'].toString(),
                              onTap: () => ref
                                  .read(shopFilterProvider.notifier)
                                  .update(categoryId: item['id'].toString()),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _markets,
                          builder: (context, snapshot) {
                            final markets =
                                snapshot.data ?? const <Map<String, dynamic>>[];
                            return DropdownButtonFormField<String?>(
                              value: filters.marketId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.storefront_outlined,
                                ),
                                labelText: 'shop.browse.market'.tr(),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('shop.browse.allMarkets'.tr()),
                                ),
                                for (final market in markets)
                                  DropdownMenuItem<String?>(
                                    value: market['id'].toString(),
                                    child: Text(
                                      (market['name'] ?? '').toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  ref.read(shopFilterProvider.notifier).update(
                                        marketId: value,
                                        clearMarket: value == null,
                                      ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: filters.sort,
                          isExpanded: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.swap_vert_rounded),
                            labelText: 'shop.browse.sort'.tr(),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'newest',
                              child: Text('shop.browse.sortNewest'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'popular',
                              child: Text('shop.browse.sortPopular'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'price_asc',
                              child: Text('shop.browse.sortPriceLow'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'price_desc',
                              child: Text('shop.browse.sortPriceHigh'.tr()),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(shopFilterProvider.notifier)
                                  .update(sort: value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _products,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ShopError(
                    message: _apiMessage(snapshot.error),
                    retry: _reload,
                  );
                }
                final products = (snapshot.data ?? const <Product>[])
                    .where(
                      (p) =>
                          _search.isEmpty ||
                          '${p.name} ${p.farmerName ?? ''} ${p.categoryName ?? ''}'
                              .toLowerCase()
                              .contains(_search),
                    )
                    .toList();
                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'shop.browse.empty'.tr(),
                    message: 'shop.browse.emptyHelp'.tr(),
                    actionLabel: 'shop.browse.clearFilters'.tr(),
                    onAction: () {
                      _searchController.clear();
                      setState(() {
                        _search = '';
                        _currentPage = 0;
                        ref.read(shopFilterProvider.notifier).clear();
                      });
                    },
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 4
                        : constraints.maxWidth >= 640
                            ? 3
                            : 2;
                    final pageCount = (products.length / _pageSize).ceil();
                    final page = _currentPage.clamp(0, pageCount - 1).toInt();
                    final start = page * _pageSize;
                    final end =
                        (start + _pageSize).clamp(0, products.length).toInt();
                    return Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: pageCount,
                            onPageChanged: (page) =>
                                setState(() => _currentPage = page),
                            itemBuilder: (context, pageIndex) {
                              final pageStart = pageIndex * _pageSize;
                              final pageEnd = (pageStart + _pageSize)
                                  .clamp(0, products.length)
                                  .toInt();
                              final pageProducts = products.sublist(
                                pageStart,
                                pageEnd,
                              );
                              return RefreshIndicator(
                                onRefresh: () async {
                                  _reload();
                                  await _products;
                                },
                                child: GridView.builder(
                                  key: PageStorageKey<int>(pageIndex),
                                  padding: const EdgeInsets.all(14),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: .68,
                                  ),
                                  itemCount: pageProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = pageProducts[index];
                                    return _ProductCard(
                                      product: product,
                                      onTap: () => context.push(
                                        '/products/${product.id}',
                                      ),
                                      onAdd: () => _addToCart(product),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'shop.browse.resultsRange'.tr(
                                  args: [
                                    '${start + 1}',
                                    '$end',
                                    '${products.length}',
                                  ],
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'shop.browse.previousPage'.tr(),
                                    onPressed: page > 0
                                        ? () => _pageController.previousPage(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOut,
                                            )
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Text(
                                    'shop.browse.pageIndicator'.tr(
                                      args: ['${page + 1}', '$pageCount'],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'shop.browse.nextPage'.tr(),
                                    onPressed: page + 1 < pageCount
                                        ? () => _pageController.nextPage(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOut,
                                            )
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(Product product) async {
    if (product.stock <= 0) return;
    try {
      await ref.read(cartProvider.notifier).add(product, 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('shop.cart.added'.tr(args: [product.name]))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_apiMessage(error))));
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unavailable = product.stock <= 0 || !product.isActive;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.imageUrl != null)
                    Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _ProductPlaceholder(color: colors),
                    )
                  else
                    _ProductPlaceholder(color: colors),
                  if (unavailable)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'shop.product.outOfStock'.tr(),
                          style: TextStyle(color: colors.onError, fontSize: 11),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: ProductFavoriteButton(product: product),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 3),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '${_money(product.price)} / ${product.unit}',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 1, 10, 4),
              child: Text(
                product.farmerName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: unavailable ? null : onAdd,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(
                    unavailable
                        ? 'shop.product.unavailable'.tr()
                        : 'shop.product.add'.tr(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({required this.productId, super.key});
  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  late Future<Product?> _product;
  late Future<List<Map<String, dynamic>>> _reviews;
  late final ProviderSubscription<bool> _networkSubscription;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _load();
    _loadReviews();
    _networkSubscription = ref.listenManual(isOnlineProvider, (previous, next) {
      if (previous != next) {
        _load();
        _loadReviews();
        if (mounted) setState(() {});
      }
    });
  }

  void _load() {
    _product = ref
        .read(productRepositoryProvider)
        .detail(widget.productId, online: ref.read(isOnlineProvider));
  }

  void _loadReviews() {
    _reviews = ref.read(isOnlineProvider)
        ? ref.read(customerApiProvider).fetchProductReviews(widget.productId)
        : Future.value(const <Map<String, dynamic>>[]);
  }

  @override
  void dispose() {
    _networkSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const RoleMenuButton(),
        title: Text('shop.product.title'.tr()),
      ),
      body: FutureBuilder<Product?>(
        future: _product,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ShopError(
              message: _apiMessage(snapshot.error),
              retry: () => setState(_load),
            );
          }
          final product = snapshot.data;
          if (product == null) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'shop.product.notFound'.tr(),
              actionLabel: 'shop.product.backToShop'.tr(),
              onAction: () => context.go('/shop'),
            );
          }
          final colors = Theme.of(context).colorScheme;
          final images =
              product.imageUrl == null ? <String>[] : [product.imageUrl!];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (!online)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'shop.browse.offline'.tr(),
                    style: TextStyle(color: colors.tertiary),
                  ),
                ),
              AspectRatio(
                aspectRatio: 1.15,
                child: PageView(
                  children: images.isEmpty
                      ? [const _ProductPlaceholder()]
                      : images
                          .map(
                            (image) => Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _ProductPlaceholder(),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 7),
              Text(
                '${_money(product.price)} / ${product.unit}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: colors.primary),
              ),
              const SizedBox(height: 10),
              Text(
                'shop.product.stock'.tr(
                  args: ['${product.stock}', product.unit],
                ),
              ),
              if (product.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 18),
                Text(
                  'shop.product.description'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(product.description!),
              ],
              _reviewsSection(online),
              if (product.farmerName?.isNotEmpty ?? false) ...[
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.agriculture_outlined),
                    ),
                    title: Text(product.farmerName!),
                    subtitle: Text('shop.product.farmer'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/farmers/${product.farmerId}'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '$_quantity',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: _quantity < product.stock
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: product.stock <= 0
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(cartProvider.notifier)
                                  .add(product, _quantity);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'shop.cart.added'.tr(
                                        args: [product.name],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_apiMessage(error))),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text('shop.product.add'.tr()),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reviewsSection(bool online) {
    if (!online) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reviews,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '${'shop.product.reviews'.tr()}: ${_apiMessage(snapshot.error)}',
            ),
          );
        }
        final reviews = snapshot.data ?? const [];
        if (reviews.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'shop.product.reviews'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final review in reviews)
                Card(
                  child: ListTile(
                    title: Text(
                      review['reviewer_name']?.toString().trim().isNotEmpty ==
                              true
                          ? review['reviewer_name'].toString()
                          : 'account.farmerProfile.customerFallback'.tr(),
                    ),
                    subtitle: Text(review['comment']?.toString() ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(' ${review['rating']}'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: Text('shop.cart.clearTitle'.tr()),
        content: Text('shop.cart.clearMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('shop.cart.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('shop.cart.clearAll'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(cartProvider.notifier).clear();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiMessage(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const RoleMenuButton(),
        title: Text('shop.cart.title'.tr()),
      ),
      body: Column(
        children: [
          Expanded(
            child: cart.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ShopError(
                message: _apiMessage(error),
                retry: () => ref.read(cartProvider.notifier).refresh(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  final colors = Theme.of(context).colorScheme;
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Card(
                          elevation: 0,
                          color: colors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                            side: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 48,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'shop.cart.empty'.tr(),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'shop.cart.emptyHint'.tr(),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                        height: 1.45,
                                      ),
                                ),
                                const SizedBox(height: 26),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => context.go('/shop'),
                                    icon: const Icon(Icons.storefront_outlined),
                                    label: Text('shop.cart.browse'.tr()),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final groups = <String, List<CartItem>>{};
                for (final item in items) {
                  groups.putIfAbsent(item.farmerId, () => []).add(item);
                }
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _clearAll(context, ref),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: Text('shop.cart.clearAll'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(3, 12, 3, 6),
                        child: Text(
                          entry.value.first.farmerName ??
                              'shop.cart.farmer'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < entry.value.length; i++) ...[
                              _CartLine(
                                item: entry.value[i],
                                update: (quantity) => ref
                                    .read(cartProvider.notifier)
                                    .setQuantity(entry.value[i], quantity),
                                remove: () => ref
                                    .read(cartProvider.notifier)
                                    .remove(entry.value[i].productId),
                              ),
                              if (i != entry.value.length - 1)
                                const Divider(height: 1),
                            ],
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${'shop.cart.subtotal'.tr()}: ${_money(entry.value.fold<double>(0, (sum, item) => sum + item.subtotal))}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          if (cart.valueOrNull?.isNotEmpty ?? false)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('shop.cart.total'.tr()),
                          Text(
                            _money(
                              cart.value!.fold<double>(
                                0,
                                (sum, item) => sum + item.subtotal,
                              ),
                            ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => context.push('/checkout'),
                      child: Text('shop.cart.checkout'.tr()),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.update,
    required this.remove,
  });
  final CartItem item;
  final ValueChanged<int> update;
  final VoidCallback remove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: item.imageUrl == null
                  ? const _ProductPlaceholder()
                  : Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ProductPlaceholder(),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${_money(item.price)} / ${item.unit}'),
                  if (item.isDirty)
                    Text(
                      'shop.cart.syncing'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: item.quantity > 1
                            ? () => update(item.quantity - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${item.quantity}'),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: item.quantity < item.stock
                            ? () => update(item.quantity + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'shop.cart.remove'.tr(),
              onPressed: remove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      );
}

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _clientOrderId = const Uuid().v4();
  final Map<String, String> _selectedSlots = {};
  final Map<String, String> _selectedSlotTimes = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _slotLoads = {};
  int _step = 0;
  bool _submitting = false;
  bool _loadedProfile = false;
  final Set<String> _completedOnlineGroups = {};
  late final ProviderSubscription<bool> _checkoutNetworkSubscription;

  @override
  void initState() {
    super.initState();
    _checkoutNetworkSubscription = ref.listenManual(isOnlineProvider, (
      previous,
      next,
    ) {
      if (previous != next && mounted) {
        _slotLoads.clear();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _checkoutNetworkSubscription.close();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<CustomerProfile?> _profile() async {
    try {
      return await ref.read(customerApiProvider).fetchProfile();
    } on ApiException catch (error) {
      if (error.isNetworkError) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _slots(String farmerId) {
    return _slotLoads.putIfAbsent(farmerId, () async {
      final from = DateTime.now();
      final to = from.add(const Duration(days: 7));
      final local = ref.read(cartRepositoryProvider);
      if (!ref.read(isOnlineProvider)) {
        return local.cachedPickupSlots(farmerId, from, to);
      }
      try {
        final slots = await ref
            .read(customerApiProvider)
            .fetchPickupSlots(farmerId: farmerId, from: from, to: to);
        await local.cachePickupSlots(slots);
        return slots;
      } on ApiException catch (error) {
        final cached = await local.cachedPickupSlots(farmerId, from, to);
        if (error.isNetworkError && cached.isNotEmpty) return cached;
        rethrow;
      }
    });
  }

  void _useCurrentLocation(Position position) {
    setState(() {
      _address.text = addressWithGpsCoordinates(
        _address.text,
        position.latitude,
        position.longitude,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('shop.checkout.locationAdded'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).valueOrNull ?? const <CartItem>[];
    final online = ref.watch(isOnlineProvider);
    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: const RoleMenuButton(),
          title: Text('shop.checkout.title'.tr()),
        ),
        body: EmptyState(
          title: 'shop.cart.empty'.tr(),
          actionLabel: 'shop.cart.browse'.tr(),
          onAction: () => context.go('/shop'),
        ),
      );
    }
    final groups = <String, List<CartItem>>{};
    for (final item in cart) {
      groups.putIfAbsent(item.farmerId, () => []).add(item);
    }
    if (!_loadedProfile) {
      _loadedProfile = true;
      unawaited(
        _profile().then((profile) {
          if (!mounted || profile == null) return;
          _name.text = profile.fullName;
          _phone.text = profile.phone ?? '';
          _address.text = profile.address ?? '';
          setState(() {});
        }).catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'Unable to load checkout profile: $error\n$stackTrace',
          );
        }),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const RoleMenuButton(),
        title: Text('shop.checkout.title'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: i <= _step
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i <= _step
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            'shop.checkout.address'.tr(),
                            'shop.checkout.pickup'.tr(),
                            'shop.checkout.confirm'.tr(),
                          ][i],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _step,
              children: [
                _addressStep(),
                _pickupStep(groups),
                _confirmationStep(groups, cart),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed:
                          _submitting ? null : () => setState(() => _step--),
                      child: Text('shop.checkout.back'.tr()),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _submitting
                        ? null
                        : _step == 0
                            ? _nextFromAddress
                            : _step == 1
                                ? () => _nextFromPickup(groups)
                                : () => _submit(groups, cart, online),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _step == 2
                                ? 'shop.checkout.placeOrder'.tr()
                                : 'shop.checkout.continue'.tr(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressStep() => Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'shop.checkout.recipient'.tr(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'shop.checkout.required'.tr()
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  InputDecoration(labelText: 'shop.checkout.phone'.tr()),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'shop.checkout.required'.tr()
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'shop.checkout.addressLabel'.tr(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'shop.checkout.required'.tr()
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              'shop.checkout.locationHelp'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            CurrentLocationButton(
              label: 'account.profile.useLocation'.tr(),
              loadingLabel: 'account.profile.locating'.tr(),
              onLocation: _useCurrentLocation,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'shop.checkout.note'.tr()),
            ),
          ],
        ),
      );

  Widget _pickupStep(Map<String, List<CartItem>> groups) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('shop.checkout.pickupHelp'.tr()),
          const SizedBox(height: 12),
          for (final entry in groups.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.value.first.farmerName ?? 'shop.cart.farmer'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _slots(entry.key),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text(_apiMessage(snapshot.error));
                        }
                        final availableSlots = (snapshot.data ?? const [])
                            .where(
                              (slot) =>
                                  (slot['capacity'] as num).toInt() >
                                  (slot['booked_count'] as num).toInt(),
                            )
                            .toList();
                        final slots = availableSlots.where((slot) {
                          return DateTime.tryParse(
                                slot['start_time']?.toString() ?? '',
                              ) !=
                              null;
                        }).toList();
                        if (slots.isEmpty && availableSlots.isNotEmpty) {
                          return Text('shop.checkout.invalidSlots'.tr());
                        }
                        if (slots.isEmpty) {
                          return Text('shop.checkout.noSlots'.tr());
                        }
                        return Column(
                          children: [
                            for (final slot in slots)
                              RadioListTile<String>(
                                value: slot['id'].toString(),
                                groupValue: _selectedSlots[entry.key],
                                onChanged: (id) {
                                  if (id == null) return;
                                  setState(() {
                                    _selectedSlots[entry.key] = id;
                                    _selectedSlotTimes[entry.key] =
                                        slot['start_time'].toString();
                                  });
                                },
                                title: Text(_formatSlot(slot['start_time'])),
                                subtitle: Text(
                                  'shop.checkout.spotsLeft'.tr(
                                    args: [
                                      '${(slot['capacity'] as num).toInt() - (slot['booked_count'] as num).toInt()}',
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

  Widget _confirmationStep(
    Map<String, List<CartItem>> groups,
    List<CartItem> items,
  ) {
    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'shop.checkout.reviewDetails'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(_name.text),
            subtitle: Text('${_phone.text}\n${_address.text}'),
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in groups.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.agriculture_outlined),
            title: Text(
              entry.value.first.farmerName ?? 'shop.cart.farmer'.tr(),
            ),
            subtitle: Text(_formatSlot(_slotValue(entry.key))),
            trailing: Text(
              _money(
                entry.value.fold<double>(0, (sum, item) => sum + item.subtotal),
              ),
            ),
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('shop.cart.total'.tr()),
          trailing: Text(
            _money(total),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (_note.text.trim().isNotEmpty)
          Text('${'shop.checkout.note'.tr()}: ${_note.text.trim()}'),
      ],
    );
  }

  String _slotValue(String farmerId) {
    return _selectedSlotTimes[farmerId] ?? '';
  }

  void _nextFromAddress() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _step = 1);
  }

  void _nextFromPickup(Map<String, List<CartItem>> groups) {
    if (groups.keys.any(
      (farmerId) =>
          !_selectedSlots.containsKey(farmerId) ||
          DateTime.tryParse(_selectedSlotTimes[farmerId] ?? '') == null,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('shop.checkout.selectAllSlots'.tr())),
      );
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _submit(
    Map<String, List<CartItem>> groups,
    List<CartItem> items,
    bool online,
  ) async {
    setState(() => _submitting = true);
    final drafts = groups.entries.map((entry) {
      final clientId = '$_clientOrderId-${entry.key}';
      return <String, dynamic>{
        'client_order_id': clientId,
        'farmer_id': entry.key,
        'pickup_slot_id': _selectedSlots[entry.key],
        'recipient_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'note': _note.text.trim(),
        'items': entry.value
            .map(
              (item) => {
                'product_id': item.productId,
                'quantity': item.quantity,
              },
            )
            .toList(),
      };
    }).toList();
    try {
      if (online) {
        for (final draft in drafts) {
          final key = draft['farmer_id'] as String;
          if (_completedOnlineGroups.contains(key)) continue;
          await ref.read(customerApiProvider).createOrder(draft);
          _completedOnlineGroups.add(key);
        }
        await ref
            .read(cartRepositoryProvider)
            .clearProducts(items.map((item) => item.productId));
      } else {
        await ref.read(cartRepositoryProvider).saveOrderDrafts(drafts);
      }
      await ref.read(cartProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              online
                  ? 'shop.checkout.orderPlaced'.tr()
                  : 'shop.checkout.orderQueued'.tr(),
            ),
          ),
        );
        context.go('/orders');
      }
    } on ApiException catch (error) {
      if (online && error.isNetworkError && mounted) {
        final pendingDrafts = drafts
            .where(
              (draft) => !_completedOnlineGroups.contains(
                draft['farmer_id'] as String,
              ),
            )
            .toList();
        if (pendingDrafts.isNotEmpty) {
          await ref.read(cartRepositoryProvider).saveOrderDrafts(pendingDrafts);
          await ref.read(cartProvider.notifier).refresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('shop.checkout.orderQueued'.tr())),
            );
            context.go('/orders');
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.statusCode == 405
                  ? 'shop.checkout.methodNotAllowed'.tr()
                  : error.message,
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Checkout could not save the order: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_apiMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class ShopMapPage extends ConsumerStatefulWidget {
  const ShopMapPage({super.key});

  @override
  ConsumerState<ShopMapPage> createState() => _ShopMapPageState();
}

class _ShopMapPageState extends ConsumerState<ShopMapPage> {
  List<_MapPlace> _places = const [];
  LatLng _center = const LatLng(10.0452, 105.7469);
  final MapController _mapController = MapController();
  Position? _position;
  _MapPlace? _selectedPlace;
  List<LatLng> _routePoints = const [];
  double? _routeDistanceKm;
  double? _routeDurationMinutes;
  bool _mapReady = false;
  bool _routing = false;
  bool _loading = true;
  String? _error;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    Position? position;
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          position = await Geolocator.getCurrentPosition();
          _center = LatLng(position.latitude, position.longitude);
        }
      }
      final api = ref.read(customerApiProvider);
      final latitude = position?.latitude ?? _center.latitude;
      final longitude = position?.longitude ?? _center.longitude;
      final markets = await api.fetchNearbyMarkets(
        latitude: latitude,
        longitude: longitude,
      );
      final farmers = await api.fetchNearbyFarmers(
        latitude: latitude,
        longitude: longitude,
        radiusKm: 25,
      );
      final places = <_MapPlace>[];
      for (final row in markets) {
        final place = _MapPlace.fromJson(row, false, latitude, longitude);
        if (place != null) places.add(place);
      }
      for (final row in farmers) {
        final place = _MapPlace.fromJson(row, true, latitude, longitude);
        if (place != null) places.add(place);
      }
      places.sort(
        (first, second) => first.distanceKm.compareTo(second.distanceKm),
      );
      if (mounted) {
        setState(() {
          _position = position;
          _places = places;
          _selectedPlace = null;
          _routePoints = const [];
          _routeDistanceKm = null;
          _routeDurationMinutes = null;
          _routeError = null;
        });
        if (_mapReady) _mapController.move(_center, 12);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPlace(_MapPlace place) async {
    setState(() {
      _selectedPlace = place;
      _routePoints = const [];
      _routeDistanceKm = null;
      _routeDurationMinutes = null;
      _routeError = null;
    });
    _mapController.move(LatLng(place.latitude, place.longitude), 13);

    final position = _position;
    if (position == null) return;
    setState(() => _routing = true);
    try {
      final payload = await ref.read(customerApiProvider).fetchMarketRoute(
            fromLatitude: position.latitude,
            fromLongitude: position.longitude,
            toLatitude: place.latitude,
            toLongitude: place.longitude,
          );
      final route = _parseMapRoute(payload);
      if (route == null) {
        throw const FormatException('Could not find a route to this location.');
      }
      if (!mounted || _selectedPlace != place) return;
      setState(() {
        _routePoints = route.points;
        _routeDistanceKm = route.distanceMeters / 1000;
        _routeDurationMinutes = route.durationSeconds / 60;
      });
    } on ApiException catch (error) {
      if (mounted && _selectedPlace == place) {
        setState(() => _routeError = error.message);
      }
    } on FormatException catch (error) {
      if (mounted && _selectedPlace == place) {
        setState(() => _routeError = error.message);
      }
    } finally {
      if (mounted && _selectedPlace == place) {
        setState(() => _routing = false);
      }
    }
  }

  _MapRoute? _parseMapRoute(Map<String, dynamic> payload) {
    final routes = payload['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      return null;
    }
    final route = Map<String, dynamic>.from(routes.first as Map);
    final geometry = route['geometry'];
    final coordinates =
        geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
    final distance = route['distance'];
    final duration = route['duration'];
    if (coordinates is! List || distance is! num || duration is! num) {
      return null;
    }
    final points = <LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) return null;
      final longitude = coordinate[0];
      final latitude = coordinate[1];
      if (longitude is! num ||
          latitude is! num ||
          longitude < -180 ||
          longitude > 180 ||
          latitude < -90 ||
          latitude > 90) {
        return null;
      }
      points.add(LatLng(latitude.toDouble(), longitude.toDouble()));
    }
    if (points.length < 2 || distance < 0 || duration < 0) return null;
    return _MapRoute(
      points: points,
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
    );
  }

  Future<void> _openNavigation(_MapPlace place) async {
    final origin = _position;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (origin != null) 'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${place.latitude},${place.longitude}',
      'travelmode': 'driving',
    });
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('map.navigationUnavailable'.tr())),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Could not open map directions: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('map.navigationUnavailable'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: const RoleMenuButton(),
          title: Text('shop.browse.map'.tr()),
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 11,
                onMapReady: () {
                  _mapReady = true;
                  _mapController.move(_center, 12);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.harvesthub.mobile',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final place in _places)
                      Marker(
                        point: LatLng(place.latitude, place.longitude),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _selectPlace(place),
                          child: Icon(
                            place.isFarmer ? Icons.agriculture : Icons.store,
                            color: _selectedPlace == place
                                ? Colors.deepOrange
                                : place.isFarmer
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.tertiary,
                            size: 34,
                          ),
                        ),
                      ),
                    if (_position case final position?)
                      Marker(
                        point: LatLng(position.latitude, position.longitude),
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (_loading)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Align(
                alignment: Alignment.topCenter,
                child: Material(
                  child: ListTile(
                    title: Text(_error!),
                    trailing: IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              ),
            if (_routing || _routeError != null)
              Positioned(
                top: 56,
                left: 12,
                right: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _routing
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Text('map.findingRoute'.tr()),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: Text(_routeError!)),
                              TextButton.icon(
                                onPressed: _selectedPlace == null
                                    ? null
                                    : () => _openNavigation(_selectedPlace!),
                                icon: const Icon(Icons.navigation),
                                label: Text('map.directions'.tr()),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            DraggableScrollableSheet(
              initialChildSize: .22,
              minChildSize: .12,
              maxChildSize: .65,
              builder: (context, controller) => Material(
                elevation: 8,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(14),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Text(
                      'map.nearby'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_places.isEmpty && !_loading)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('map.noPlaces'.tr()),
                      ),
                    for (final place in _places)
                      ListTile(
                        leading: Icon(
                          place.isFarmer
                              ? Icons.agriculture_outlined
                              : Icons.store_outlined,
                        ),
                        title: Text(place.name),
                        subtitle: Text(
                          '${place.distanceKm.toStringAsFixed(1)} km'
                          '${_selectedPlace == place && _routeDistanceKm != null ? ' · ${_routeDistanceKm!.toStringAsFixed(1)} km, ${_routeDurationMinutes!.round()} min' : ''}'
                          '\n${place.address}',
                        ),
                        isThreeLine: true,
                        onTap: () => _selectPlace(place),
                        trailing: IconButton(
                          tooltip: 'map.directions'.tr(),
                          icon: const Icon(Icons.directions),
                          onPressed: () => _openNavigation(place),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _MapPlace {
  const _MapPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isFarmer,
    required this.distanceKm,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool isFarmer;
  final double distanceKm;

  static _MapPlace? fromJson(
    Map<String, dynamic> json,
    bool farmer,
    double fromLatitude,
    double fromLongitude,
  ) {
    final lat = double.tryParse((json['latitude'] ?? '').toString());
    final lng = double.tryParse((json['longitude'] ?? '').toString());
    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    final distance = double.tryParse('${json['distance_km']}') ??
        _distanceKm(fromLatitude, fromLongitude, lat, lng);
    return _MapPlace(
      name: (json[farmer ? 'farm_name' : 'name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      latitude: lat,
      longitude: lng,
      isFarmer: farmer,
      distanceKm: distance,
    );
  }

  static double _distanceKm(
    double fromLatitude,
    double fromLongitude,
    double toLatitude,
    double toLongitude,
  ) {
    const radiusKm = 6371.0;
    final latitudeDelta = _radians(toLatitude - fromLatitude);
    final longitudeDelta = _radians(toLongitude - fromLongitude);
    final haversine =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
            math.cos(_radians(fromLatitude)) *
                math.cos(_radians(toLatitude)) *
                math.sin(longitudeDelta / 2) *
                math.sin(longitudeDelta / 2);
    return radiusKm *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class _MapRoute {
  const _MapRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder({this.color});
  final ColorScheme? color;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: color?.surfaceContainerHighest ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.eco_outlined, size: 38)),
      );
}

class _ShopError extends StatelessWidget {
  const _ShopError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: Text('account.orders.retry'.tr()),
              ),
            ],
          ),
        ),
      );
}

String _money(num amount) {
  final value = amount.toInt().toString();
  return '\$${value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
}

String _apiMessage(Object? error) => error is ApiException
    ? error.message
    : error?.toString() ?? 'Unknown error';

String _formatSlot(dynamic raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  if (parsed == null) return 'shop.checkout.slotUnavailable'.tr();
  return DateFormat('EEE, d MMM · HH:mm').format(parsed.toLocal());
}
