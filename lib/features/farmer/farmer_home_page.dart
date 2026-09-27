import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/farmer_products_api.dart';
import '../../models/product.dart';
import '../../providers/farmer_products_provider.dart';
import '../../shared_widgets/empty_state.dart';
import '../../shared_widgets/app_skeleton.dart';
import 'widgets/product_row.dart';
import 'widgets/product_status_filter_tabs.dart';

/// Trang chủ khu vực farmer — route `/farmer`. Liệt kê sản phẩm của
/// Người dùng farmer đã được duyệt xem, thêm, sửa và xoá sản phẩm của mình.
class FarmerHomePage extends ConsumerWidget {
  const FarmerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(farmerProductFilterProvider);
    final productsAsync = ref.watch(farmerProductsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý sản phẩm'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: ProductStatusFilterTabs(
            value: filter,
            onChanged: (status) {
              ref.read(farmerProductFilterProvider.notifier).state = status;
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/farmer/products/new');
          if (created == true) {
            ref.invalidate(farmerProductsProvider(filter));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(farmerProductsProvider(filter));
          await ref.read(farmerProductsProvider(filter).future);
        },
        child: productsAsync.when(
          loading: () => const AppSkeleton(variant: AppSkeletonVariant.row),
          error: (error, _) => _FarmerProductsError(
            message: error is ApiException
                ? error.message
                : 'Không tải được danh sách sản phẩm.',
            onRetry: () => ref.invalidate(farmerProductsProvider(filter)),
          ),
          data: (products) {
            if (products.isEmpty) {
              return const EmptyState(
                icon: Icons.eco_outlined,
                title: 'Chưa có sản phẩm nào',
                message: 'Bấm "Thêm sản phẩm" để đăng bán nông sản của bạn.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductRow(
                  product: product,
                  onTap: () async {
                    final updated = await context
                        .push<bool>('/farmer/products/${product.id}/edit');
                    if (updated == true) {
                      ref.invalidate(farmerProductsProvider(filter));
                    }
                  },
                  onDelete: () => _confirmDelete(context, ref, product, filter),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Product product,
    ProductStatus? filter,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá sản phẩm?'),
        content: Text('Bạn có chắc muốn xoá "${product.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(farmerProductsApiProvider).deleteProduct(product.id);
      ref.invalidate(farmerProductsProvider(filter));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá sản phẩm.')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _FarmerProductsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FarmerProductsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
