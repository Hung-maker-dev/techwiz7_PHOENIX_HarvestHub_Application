// lib/features/admin/products_page.dart
// Route: /admin/products (NGUOI_5_MOBILE.md, 4.4)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/admin_product_list_tile.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'widgets/hide_product_dialog.dart';
import 'admin_localization.dart';

class AdminProductsPage extends ConsumerWidget {
  const AdminProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminProductsProvider);
    final filter = ref.watch(productFilterProvider);
    final hideProduct = ref.watch(hideProductProvider);

    return AdminShell(
      currentRoute: '/admin/products',
      title: adminText(context, 'Sản phẩm'), // i18n: admin.products.title
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: filter.farmerId != null ||
                filter.categoryId != null ||
                filter.status != null,
            child: Icon(Icons.filter_list),
          ),
          onPressed: () => _openFilterSheet(context, ref, filter),
        ),
      ],
      child: productsAsync.when(
        loading: () => Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: ListView.builder(
            itemCount: 6,
            itemBuilder: (_, __) => Container(
              height: 76,
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        error: (err, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(adminProductsProvider),
            child:
                Text(adminText(context, 'Không tải được danh sách — thử lại')),
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return Center(
                child: Text(
                    adminText(context, 'Không có sản phẩm phù hợp bộ lọc.')));
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return AdminProductListTile(
                product: p,
                onHide: () async {
                  final reason =
                      await showHideProductDialog(context, productName: p.name);
                  if (reason != null) {
                    await hideProduct(p.id, reason);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    WidgetRef ref,
    ProductFilter filter,
  ) async {
    final farmers = await ref.read(allFarmersProvider.future);
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;
    String? farmerId = filter.farmerId;
    String? categoryId = filter.categoryId;
    String? status = filter.status;

    showAppFilterSheet(
      context,
      title: adminText(context, 'Lọc sản phẩm'),
      onReset: () =>
          ref.read(productFilterProvider.notifier).state = ProductFilter(),
      onApply: () =>
          ref.read(productFilterProvider.notifier).state = ProductFilter(
        farmerId: farmerId,
        categoryId: categoryId,
        status: status,
      ),
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              value: farmerId,
              decoration:
                  InputDecoration(labelText: adminText(context, 'Nông dân')),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(adminText(context, 'Tất cả nông dân')),
                ),
                for (final farmer in farmers)
                  DropdownMenuItem<String?>(
                    value: farmer.id,
                    child: Text(adminText(
                        context, '${farmer.farmName} (${farmer.id})')),
                  ),
              ],
              onChanged: (value) => setState(() => farmerId = value),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: categoryId,
              decoration:
                  InputDecoration(labelText: adminText(context, 'Danh mục')),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(adminText(context, 'Tất cả danh mục')),
                ),
                for (final category in categories)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(adminText(
                        context, '${category.name} (${category.id})')),
                  ),
              ],
              onChanged: (value) => setState(() => categoryId = value),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: status,
              decoration:
                  InputDecoration(labelText: adminText(context, 'Trạng thái')),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(adminText(context, 'Tất cả'))),
                DropdownMenuItem(
                    value: 'active',
                    child: Text(adminText(context, 'Đang bán'))),
                DropdownMenuItem(
                    value: 'hidden', child: Text(adminText(context, 'Đã ẩn'))),
              ],
              onChanged: (v) => setState(() => status = v),
            ),
          ],
        ),
      ),
    );
  }
}
