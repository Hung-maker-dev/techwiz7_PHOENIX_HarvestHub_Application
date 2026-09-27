import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/api/customer_api.dart';
import '../../data/api/customer_community_api.dart';
import '../../models/product.dart';
import '../../shared_widgets/empty_state.dart';

class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
  String? _status;
  late Future<List<CustomerOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = _load();
  }

  Future<List<CustomerOrder>> _load() =>
      ref.read(customerApiProvider).fetchOrders(status: _status);

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _orders = future);
    try {
      await future;
    } on ApiException {
      // FutureBuilder renders the failed request with its API message.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('account.orders.title'.tr())),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _OrderFilter(
                    label: 'account.orders.all'.tr(),
                    selected: _status == null,
                    onTap: () => _setStatus(null),
                  ),
                  for (final status in CustomerOrderStatus.values)
                    _OrderFilter(
                      label: _statusLabel(status),
                      selected: _status == status.value,
                      onTap: () => _setStatus(status.value),
                    ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CustomerOrder>>(
                future: _orders,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _RetryState(
                      message: _errorMessage(snapshot.error),
                      onRetry: _refresh,
                    );
                  }
                  final orders = snapshot.data ?? const [];
                  if (orders.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: _status == null
                          ? 'account.orders.emptyTitle'.tr()
                          : 'account.orders.emptyFiltered'.tr(),
                      message: _status == null
                          ? '${'account.orders.emptyMessage'.tr()}\n\n'
                              '${'account.orders.offlinePending'.tr()}'
                          : 'account.orders.emptyFilteredMessage'.tr(),
                      actionLabel:
                          _status == null ? 'account.orders.browse'.tr() : null,
                      onAction:
                          _status == null ? () => context.push('/shop') : null,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: Text(
                                'account.orders.offlinePending'.tr(),
                              ),
                            ),
                          );
                        }
                        final order = orders[index - 1];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long),
                            title: Text(
                              order.farmerName ??
                                  'account.farmerProfile.farmFallback'.tr(),
                            ),
                            subtitle: Text(
                              '#${order.id} · ${_statusLabel(order.status)}\n'
                              '${DateFormat.yMd().add_Hm().format(order.createdAt)}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              '${order.total.toStringAsFixed(0)} đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => context.push('/orders/${order.id}'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  void _setStatus(String? status) {
    setState(() {
      _status = status;
      _orders = _load();
    });
  }
}

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({required this.orderId, super.key});
  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  late Future<CustomerOrder> _order;
  CustomerOrderStatus? _loadedStatus;
  int _timelineAnimationVersion = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _order = _load();
  }

  Future<CustomerOrder> _load() async {
    final order =
        await ref.read(customerApiProvider).fetchOrder(widget.orderId);
    final previousStatus = _loadedStatus;
    _loadedStatus = order.status;
    if (previousStatus != null && previousStatus != order.status && mounted) {
      setState(() => _timelineAnimationVersion++);
    }
    return order;
  }

  Future<void> _cancel(CustomerOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('account.orders.cancelTitle'.tr()),
        content: Text('account.orders.cancelBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('account.orders.back'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('account.orders.cancel'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(customerApiProvider).cancelOrder(order.id);
      if (!mounted) return;
      setState(() => _order = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('account.orders.cancelled'.tr())),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(CustomerOrder order) async {
    if (order.items.isEmpty) {
      _showError('account.orders.reviewMissing'.tr());
      return;
    }
    try {
      final connection = await Connectivity().checkConnectivity();
      if (!connection.any((result) => result != ConnectivityResult.none)) {
        _showError('account.orders.reviewOffline'.tr());
        return;
      }
    } catch (error, stackTrace) {
      debugPrint(
          'Could not check connectivity before review: $error\n$stackTrace');
      _showError(error.toString());
      return;
    }
    if (!mounted) return;
    final comment = TextEditingController();
    var rating = 5;
    final values = await showDialog<(int, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('account.orders.reviewTitle'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: rating,
                decoration:
                    InputDecoration(labelText: 'account.orders.rating'.tr()),
                items: List.generate(
                  5,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(
                      'account.orders.stars'.tr(args: ['${index + 1}']),
                    ),
                  ),
                ),
                onChanged: (value) =>
                    setDialogState(() => rating = value ?? rating),
              ),
              TextField(
                controller: comment,
                maxLines: 3,
                maxLength: 2000,
                decoration:
                    InputDecoration(labelText: 'account.orders.comment'.tr()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('account.orders.close'.tr()),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (rating, comment.text.trim())),
              child: Text('account.orders.submitReview'.tr()),
            ),
          ],
        ),
      ),
    );
    comment.dispose();
    if (values == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(customerApiProvider).submitReview(
            orderId: order.id,
            productId: order.items.first.productId,
            farmerId: order.farmerId,
            rating: values.$1,
            comment: values.$2,
          );
      if (!mounted) return;
      setState(() => _order = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('account.orders.reviewSent'.tr())),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('account.orders.detailTitle'.tr()),
          actions: [
            IconButton(
              tooltip: 'account.orders.reload'.tr(),
              onPressed: () => setState(() => _order = _load()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<CustomerOrder>(
          future: _order,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RetryState(
                message: _errorMessage(snapshot.error),
                onRetry: () => setState(() => _order = _load()),
              );
            }
            final order = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  order.farmerName ?? 'Đơn hàng ${order.id}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('#${order.id} · ${_statusLabel(order.status)}'),
                const SizedBox(height: 16),
                _OrderTimeline(
                  status: order.status,
                  animationVersion: _timelineAnimationVersion,
                ),
                const SizedBox(height: 12),
                for (final item in order.items)
                  Card(
                    child: ListTile(
                      leading: item.imageUrl == null
                          ? const Icon(Icons.eco)
                          : Image.network(
                              item.imageUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.eco),
                            ),
                      title: Text(item.name),
                      subtitle: Text('${item.quantity} ${item.unit ?? ''}'),
                      trailing: Text(
                          '${(item.price * item.quantity).toStringAsFixed(0)} đ'),
                    ),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('account.orders.total'.tr()),
                  trailing: Text('${order.total.toStringAsFixed(0)} đ'),
                ),
                if (order.status == CustomerOrderStatus.pending)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _cancel(order),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text('account.orders.cancelAction'.tr()),
                  ),
                if (order.status == CustomerOrderStatus.completed &&
                    !order.hasReview)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _review(order),
                    icon: const Icon(Icons.star_outline),
                    label: Text('account.orders.reviewAction'.tr()),
                  ),
              ],
            );
          },
        ),
      );
}

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  late Future<List<Product>> _products;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _products = _load();
  }

  Future<List<Product>> _load() =>
      ref.read(customerApiProvider).fetchWishlist();

  Future<void> _remove(Product product) async {
    if (!_busy.add(product.id)) return;
    setState(() {});
    try {
      await ref.read(customerApiProvider).removeWishlist(product.id);
      if (mounted) setState(() => _products = _load());
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      _busy.remove(product.id);
      if (mounted) setState(() {});
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('account.wishlist.title'.tr())),
        body: FutureBuilder<List<Product>>(
          future: _products,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RetryState(
                message: _errorMessage(snapshot.error),
                onRetry: () => setState(() => _products = _load()),
              );
            }
            final products = snapshot.data ?? const [];
            if (products.isEmpty) {
              return EmptyState(
                icon: Icons.favorite_border,
                title: 'account.wishlist.emptyTitle'.tr(),
                message: 'account.wishlist.emptyMessage'.tr(),
                actionLabel: 'account.wishlist.browse'.tr(),
                onAction: () => context.push('/shop'),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                final next = _load();
                setState(() => _products = next);
                await next;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: products.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text('account.wishlist.onlineTitle'.tr()),
                        subtitle: Text('account.wishlist.onlineMessage'.tr()),
                      ),
                    );
                  }
                  final product = products[index - 1];
                  return Card(
                    child: ListTile(
                      leading: _ProductImage(product.imageUrl),
                      title: Text(product.name),
                      subtitle: Text(
                        '${product.price.toStringAsFixed(0)} đ / ${product.unit}'
                        '${product.stock <= 0 ? ' · ${'account.wishlist.outOfStock'.tr()}' : ''}',
                      ),
                      onTap: () => context.push('/farmers/${product.farmerId}'),
                      trailing: IconButton(
                        tooltip: 'account.wishlist.remove'.tr(),
                        onPressed: _busy.contains(product.id)
                            ? null
                            : () => _remove(product),
                        icon: const Icon(Icons.favorite, color: Colors.red),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: () => context.push('/shop'),
            icon: const Icon(Icons.storefront_outlined),
            label: Text('account.wishlist.browse'.tr()),
          ),
        ),
      );
}

class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<FollowingPage> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late Future<List<PublicFarmer>> _farmers;
  final Set<String> _busy = {};
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _farmers = _load();
    _refreshConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() => _online =
            results.any((result) => result != ConnectivityResult.none));
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (mounted) {
        setState(() => _online =
            results.any((result) => result != ConnectivityResult.none));
      }
    } catch (error, stackTrace) {
      debugPrint('Could not check network status: $error\n$stackTrace');
      if (mounted) setState(() => _online = false);
    }
  }

  Future<List<PublicFarmer>> _load() =>
      ref.read(customerCommunityApiProvider).fetchFollowing();

  Future<void> _unfollow(PublicFarmer farmer) async {
    if (!_busy.add(farmer.id)) return;
    setState(() {});
    try {
      await ref
          .read(customerCommunityApiProvider)
          .setFollowing(farmer.id, following: false);
      if (mounted) setState(() => _farmers = _load());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      _busy.remove(farmer.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('account.following.title'.tr())),
        body: FutureBuilder<List<PublicFarmer>>(
          future: _farmers,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RetryState(
                message: _errorMessage(snapshot.error),
                onRetry: () => setState(() => _farmers = _load()),
              );
            }
            final farmers = snapshot.data ?? const [];
            if (farmers.isEmpty) {
              return EmptyState(
                icon: Icons.agriculture_outlined,
                title: 'account.following.emptyTitle'.tr(),
                message: 'account.following.emptyMessage'.tr(),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: farmers.length,
              itemBuilder: (context, index) {
                final farmer = farmers[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: farmer.avatarUrl == null
                          ? null
                          : NetworkImage(farmer.avatarUrl!),
                      child: farmer.avatarUrl == null
                          ? const Icon(Icons.agriculture)
                          : null,
                    ),
                    title: Text(farmer.farmName),
                    subtitle: Text(
                      '★ ${farmer.rating.toStringAsFixed(1)} '
                      '(${farmer.ratingCount})',
                    ),
                    onTap: () => context.push('/farmers/${farmer.id}'),
                    trailing: IconButton(
                      tooltip: _online
                          ? 'account.following.remove'.tr()
                          : 'account.farmerProfile.needsInternet'.tr(),
                      onPressed: !_online || _busy.contains(farmer.id)
                          ? null
                          : () => _unfollow(farmer),
                      icon: const Icon(Icons.person_remove_outlined),
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/customer/farmers'),
          icon: const Icon(Icons.search),
          label: Text('account.following.search'.tr()),
        ),
      );
}

class FarmerProfilePage extends ConsumerStatefulWidget {
  const FarmerProfilePage({required this.farmerId, super.key});
  final String farmerId;

  @override
  ConsumerState<FarmerProfilePage> createState() => _FarmerProfilePageState();
}

class _FarmerProfilePageState extends ConsumerState<FarmerProfilePage> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late Future<Map<String, dynamic>> _profile;
  late Future<List<Product>> _products;
  bool _busy = false;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
    _products = _loadProducts();
    _refreshConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() => _online =
            results.any((result) => result != ConnectivityResult.none));
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (mounted) {
        setState(() => _online =
            results.any((result) => result != ConnectivityResult.none));
      }
    } catch (error, stackTrace) {
      debugPrint('Could not check network status: $error\n$stackTrace');
      if (mounted) setState(() => _online = false);
    }
  }

  Future<Map<String, dynamic>> _loadProfile() =>
      ref.read(customerApiProvider).fetchFarmer(widget.farmerId);

  Future<List<Product>> _loadProducts() =>
      ref.read(customerApiProvider).fetchProducts(farmerId: widget.farmerId);

  Future<void> _toggleFollow(bool following) async {
    if (!_online) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('account.farmerProfile.needsInternet'.tr())),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(customerCommunityApiProvider).setFollowing(
            widget.farmerId,
            following: !following,
          );
      if (mounted) setState(() => _profile = _loadProfile());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('account.farmerProfile.title'.tr())),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RetryState(
                message: _errorMessage(snapshot.error),
                onRetry: () => setState(() => _profile = _loadProfile()),
              );
            }
            final profile = snapshot.data!;
            final following =
                profile['is_following'] == true || profile['is_following'] == 1;
            final reviews = profile['reviews'] as List<dynamic>? ?? const [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundImage: profile['avatar_url'] is String
                              ? NetworkImage(profile['avatar_url'] as String)
                              : null,
                          child: profile['avatar_url'] == null
                              ? const Icon(Icons.agriculture, size: 36)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile['farm_name'] as String? ??
                              'account.farmerProfile.farmFallback'.tr(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '★ ${_asDouble(profile['rating']).toStringAsFixed(1)} '
                          '(${profile['rating_count'] ?? 0}) · '
                          '${profile['follower_count'] ?? 0} '
                          '${'account.farmerProfile.followers'.tr()}',
                        ),
                        if ((profile['market_name'] as String? ?? '')
                            .isNotEmpty)
                          Text(profile['market_name'] as String),
                        if ((profile['description'] as String? ?? '')
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(profile['description'] as String),
                          ),
                        const SizedBox(height: 8),
                        Tooltip(
                          message: _online
                              ? ''
                              : 'account.farmerProfile.needsInternet'.tr(),
                          child: FilledButton(
                            onPressed: !_online || _busy
                                ? null
                                : () => _toggleFollow(following),
                            child: Text(
                              following
                                  ? 'account.farmerProfile.unfollow'.tr()
                                  : 'account.farmerProfile.follow'.tr(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'account.farmerProfile.products'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FutureBuilder<List<Product>>(
                  future: _products,
                  builder: (context, productsSnapshot) {
                    if (productsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    if (productsSnapshot.hasError) {
                      return Text(_errorMessage(productsSnapshot.error));
                    }
                    final products = productsSnapshot.data ?? const [];
                    if (products.isEmpty) {
                      return Text('account.farmerProfile.noProducts'.tr());
                    }
                    return Column(
                      children: products
                          .map(
                            (product) => Card(
                              child: ListTile(
                                leading: _ProductImage(product.imageUrl),
                                title: Text(product.name),
                                subtitle: Text(
                                  '${product.price.toStringAsFixed(0)} đ / ${product.unit}',
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'account.farmerProfile.reviews'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (reviews.isEmpty)
                  Text('account.farmerProfile.noReviews'.tr())
                else
                  for (final raw in reviews)
                    Card(
                      child: ListTile(
                        title: Text(
                          raw['user_name'] as String? ??
                              'account.farmerProfile.customerFallback'.tr(),
                        ),
                        subtitle: Text(
                          '★ ${raw['rating']} · '
                          '${raw['comment'] as String? ?? ''}',
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      );
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _currentPassword = TextEditingController();
  CustomerProfile? _profile;
  String _language = 'vi';
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _password.dispose();
    _currentPassword.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(customerApiProvider).fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _name.text = profile.fullName;
        _phone.text = profile.phone ?? '';
        _address.text = profile.address ?? '';
        _language = profile.preferredLanguage;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not load customer profile: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(error))),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(customerApiProvider).updateProfile({
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'preferred_language': _language,
      });
      try {
        await FirebaseAuth.instance.currentUser
            ?.updateDisplayName(updated.fullName);
      } on FirebaseAuthException catch (error, stackTrace) {
        debugPrint(
          'Profile saved to MySQL but Firebase display name was not updated: '
          '$error\n$stackTrace',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('account.profile.saved'.tr())),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final value = _password.text;
    if (value.length < 6 || _currentPassword.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('account.profile.passwordRequired'.tr()),
        ),
      );
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email;
      if (email == null) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: 'account.profile.emailMissing'.tr(),
        );
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: email,
          password: _currentPassword.text,
        ),
      );
      await user.updatePassword(value);
      _password.clear();
      _currentPassword.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('account.profile.passwordChanged'.tr())),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? error.code)),
        );
      }
    }
  }

  Future<void> _uploadAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image == null) return;
    setState(() => _uploading = true);
    try {
      final reference = FirebaseStorage.instance.ref(
        'avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await reference.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await reference.getDownloadURL();
      final updated = await ref
          .read(customerApiProvider)
          .updateProfile({'avatar_url': url});
      try {
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
      } on FirebaseAuthException catch (error, stackTrace) {
        debugPrint(
          'Profile photo saved but Firebase photo URL was not updated: '
          '$error\n$stackTrace',
        );
      }
      if (mounted) setState(() => _profile = updated);
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? error.code)),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('account.profile.title'.tr())),
        body: _profile == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundImage: _profile!.avatarUrl == null
                                ? null
                                : NetworkImage(_profile!.avatarUrl!),
                            child: _profile!.avatarUrl == null
                                ? const Icon(Icons.person, size: 42)
                                : null,
                          ),
                          IconButton.filled(
                            onPressed: _uploading ? null : _uploadAvatar,
                            icon: _uploading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_profile!.email, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'account.profile.name'.tr(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'account.profile.nameRequired'.tr()
                              : null,
                    ),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'account.profile.phone'.tr(),
                      ),
                    ),
                    TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'account.profile.address'.tr(),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: InputDecoration(
                        labelText: 'account.profile.language'.tr(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'vi',
                          child: Text('account.profile.vietnamese'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text('account.profile.english'.tr()),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _language = value);
                          unawaited(context.setLocale(Locale(value)));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving
                            ? 'account.profile.saving'.tr()
                            : 'account.profile.save'.tr(),
                      ),
                    ),
                    if (_profile!.authProvider == 'password') ...[
                      const Divider(height: 32),
                      TextField(
                        controller: _currentPassword,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'account.profile.currentPassword'.tr(),
                        ),
                      ),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'account.profile.newPassword'.tr(),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _changePassword,
                        child: Text('account.profile.changePassword'.tr()),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/');
                      },
                      icon: const Icon(Icons.logout),
                      label: Text('account.profile.logout'.tr()),
                    ),
                  ],
                ),
              ),
      );
}

class ProductShopPage extends ConsumerStatefulWidget {
  const ProductShopPage({super.key});

  @override
  ConsumerState<ProductShopPage> createState() => _ProductShopPageState();
}

class _ProductShopPageState extends ConsumerState<ProductShopPage> {
  late Future<List<Product>> _products;

  @override
  void initState() {
    super.initState();
    _products = ref.read(customerApiProvider).fetchProducts();
  }

  Future<void> _save(Product product) async {
    try {
      await ref.read(customerApiProvider).addWishlist(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('account.shop.saved'.tr())),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('account.shop.title'.tr()),
          actions: [
            IconButton(
              tooltip: 'account.shop.wishlist'.tr(),
              onPressed: () => context.push('/wishlist'),
              icon: const Icon(Icons.favorite_border),
            ),
          ],
        ),
        body: FutureBuilder<List<Product>>(
          future: _products,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RetryState(
                message: _errorMessage(snapshot.error),
                onRetry: () => setState(
                  () =>
                      _products = ref.read(customerApiProvider).fetchProducts(),
                ),
              );
            }
            final products = snapshot.data ?? const [];
            if (products.isEmpty) {
              return EmptyState(
                icon: Icons.storefront_outlined,
                title: 'account.shop.emptyTitle'.tr(),
                message: 'account.shop.emptyMessage'.tr(),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: products.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text('account.shop.onlineTitle'.tr()),
                      subtitle: Text('account.shop.onlineMessage'.tr()),
                    ),
                  );
                }
                final product = products[index - 1];
                return Card(
                  child: ListTile(
                    leading: _ProductImage(product.imageUrl),
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.price.toStringAsFixed(0)} đ / ${product.unit}\n'
                      '${product.farmerName ?? 'account.farmerProfile.farmFallback'.tr()}',
                    ),
                    isThreeLine: true,
                    onTap: () => context.push('/farmers/${product.farmerId}'),
                    trailing: IconButton(
                      tooltip: 'account.shop.save'.tr(),
                      onPressed: () => _save(product),
                      icon: const Icon(Icons.favorite_border),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _OrderFilter extends StatelessWidget {
  const _OrderFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({
    required this.status,
    required this.animationVersion,
  });
  final CustomerOrderStatus status;
  final int animationVersion;

  @override
  Widget build(BuildContext context) {
    final steps = [
      CustomerOrderStatus.pending,
      CustomerOrderStatus.confirmed,
      CustomerOrderStatus.readyForPickup,
      CustomerOrderStatus.completed,
    ];
    return AnimatedSwitcher(
      duration: animationVersion == 0
          ? Duration.zero
          : const Duration(milliseconds: 500),
      child: Card(
        key: ValueKey('$status-$animationVersion'),
        child: Column(
          children: [
            for (final step in steps)
              ListTile(
                dense: true,
                leading: Icon(
                  steps.indexOf(step) <= steps.indexOf(status) &&
                          status != CustomerOrderStatus.cancelled
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(_statusLabel(step)),
              ),
            if (status == CustomerOrderStatus.cancelled)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: Text('account.orderStatus.cancelled'.tr()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage(this.url);
  final String? url;

  @override
  Widget build(BuildContext context) => url == null
      ? const CircleAvatar(child: Icon(Icons.eco))
      : CircleAvatar(backgroundImage: NetworkImage(url!));
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: Text('account.orders.retry'.tr()),
              ),
            ],
          ),
        ),
      );
}

String _errorMessage(Object? error) =>
    error is ApiException ? error.message : 'account.orders.error'.tr();

String _statusLabel(CustomerOrderStatus status) => switch (status) {
      CustomerOrderStatus.pending => 'account.orderStatus.pending'.tr(),
      CustomerOrderStatus.confirmed => 'account.orderStatus.confirmed'.tr(),
      CustomerOrderStatus.readyForPickup => 'account.orderStatus.ready'.tr(),
      CustomerOrderStatus.completed => 'account.orderStatus.completed'.tr(),
      CustomerOrderStatus.cancelled => 'account.orderStatus.cancelled'.tr(),
    };

double _asDouble(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
