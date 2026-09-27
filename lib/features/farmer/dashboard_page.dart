import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/farmer_data_api.dart';
import '../../models/product.dart';
import '../../providers/farmer_data_provider.dart';
import '../../providers/farmer_products_provider.dart';

class FarmerDashboardPage extends ConsumerWidget {
  const FarmerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(farmerProductsProvider(null));
    final reportAsync = ref.watch(farmerReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tổng quan nông trại',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Số liệu tổng hợp trong 7 ngày gần nhất',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          productsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _DataNotice(
              message: 'Không tải được số liệu sản phẩm.',
              onRetry: () => ref.invalidate(farmerProductsProvider(null)),
            ),
            data: (products) => _ProductMetrics(products: products),
          ),
          const SizedBox(height: 20),
          reportAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => const _DataNotice(
              message: 'Không tải được báo cáo đơn hàng.',
            ),
            data: (report) => _ReportMetrics(report: report),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cần xử lý',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          productsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const _DataNotice(
              message: 'Chưa có dữ liệu cần xử lý.',
            ),
            data: (products) => _LowStockActions(products: products),
          ),
        ],
      ),
    );
  }
}

class _ProductMetrics extends StatelessWidget {
  final List<Product> products;

  const _ProductMetrics({required this.products});

  @override
  Widget build(BuildContext context) {
    final lowStock = products.where((p) => p.stock <= p.minStock).length;
    final active = products.where((p) => p.isActive).length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Sản phẩm đang bán',
                value: '$active sản phẩm',
                description: 'Đang hoạt động',
                accent: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Sắp hết hàng',
                value: '$lowStock sản phẩm',
                description: 'Theo ngưỡng đã đặt',
                accent: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportMetrics extends StatelessWidget {
  final FarmerReportData report;

  const _ReportMetrics({required this.report});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Đơn hoàn tất',
            value: '${report.completedOrders} đơn',
            description: 'Đã hoàn tất',
            accent: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Doanh thu',
            value: '${report.revenue.toStringAsFixed(0)} đ',
            description: 'Đơn đã hoàn tất',
            accent: Colors.teal,
          ),
        ),
      ],
    );
  }
}

class _LowStockActions extends StatelessWidget {
  final List<Product> products;

  const _LowStockActions({required this.products});

  @override
  Widget build(BuildContext context) {
    final lowStock = products.where((p) => p.stock <= p.minStock).toList();
    if (lowStock.isEmpty) {
      return const _DataNotice(message: 'Không có sản phẩm nào cần xử lý.');
    }
    return Column(
      children: lowStock
          .map(
            (product) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${product.name} sắp dưới ngưỡng'),
                subtitle: Text(
                  'Tồn kho ${product.stock} ${product.unit} · Ngưỡng ${product.minStock}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/farmer/products/${product.id}/edit'),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DataNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _DataNotice({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(message),
        trailing: onRetry == null
            ? null
            : IconButton(
                tooltip: 'Tải lại',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final Color accent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.description,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
