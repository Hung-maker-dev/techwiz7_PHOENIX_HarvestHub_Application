import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/api/farmer_data_api.dart';
import '../../providers/farmer_data_provider.dart';

class FarmerOrdersPage extends ConsumerStatefulWidget {
  const FarmerOrdersPage({super.key});

  @override
  ConsumerState<FarmerOrdersPage> createState() => _FarmerOrdersPageState();
}

class _FarmerOrdersPageState extends ConsumerState<FarmerOrdersPage> {
  String selectedFilter = 'Tất cả';

  static const filters = [
    'Tất cả',
    'Chờ xác nhận',
    'Đã xác nhận',
    'Sẵn sàng lấy',
    'Hoàn tất',
  ];

  String? get statusQuery {
    return switch (selectedFilter) {
      'Chờ xác nhận' => 'Pending',
      'Đã xác nhận' => 'Confirmed',
      'Sẵn sàng lấy' => 'Ready for Pickup',
      'Hoàn tất' => 'Completed',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(farmerOrdersProvider(statusQuery));
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                return ChoiceChip(
                  label: Text(filter),
                  selected: selectedFilter == filter,
                  onSelected: (_) => setState(() => selectedFilter = filter),
                );
              },
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error is ApiException
                    ? error.message
                    : 'Không tải được đơn hàng lúc này.',
                onRetry: () =>
                    ref.invalidate(farmerOrdersProvider(statusQuery)),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(
                    child: Text('Không có đơn hàng ở trạng thái này.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(farmerOrdersProvider(statusQuery));
                    await ref.read(farmerOrdersProvider(statusQuery).future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _OrderCard(
                      order: orders[index],
                      onUpdate: () => _updateOrder(orders[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrder(FarmerOrderData order) async {
    final nextStatus = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusOption('Confirmed', 'Đã xác nhận'),
            _StatusOption('Ready for Pickup', 'Sẵn sàng lấy'),
            _StatusOption('Completed', 'Hoàn tất'),
            _StatusOption('Cancelled', 'Đã hủy'),
          ],
        ),
      ),
    );
    if (!mounted || nextStatus == null) return;
    try {
      await ref
          .read(farmerDataApiProvider)
          .updateOrderStatus(order.id, nextStatus);
      ref.invalidate(farmerOrdersProvider(statusQuery));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _StatusOption extends StatelessWidget {
  final String value;
  final String label;

  const _StatusOption(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sync_alt_outlined),
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final FarmerOrderData order;
  final VoidCallback onUpdate;

  const _OrderCard({required this.order, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order.id} · ${order.customerName ?? 'Khách hàng'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Trạng thái: ${_statusLabel(order.status)}'),
            const SizedBox(height: 4),
            Text('Tổng tiền: ${order.total.toStringAsFixed(0)} đ'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Cập nhật trạng thái'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String value) {
    return switch (value) {
      'Pending' => 'Chờ xác nhận',
      'Confirmed' => 'Đã xác nhận',
      'Ready for Pickup' => 'Sẵn sàng lấy',
      'Completed' => 'Hoàn tất',
      'Cancelled' => 'Đã hủy',
      _ => value,
    };
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
