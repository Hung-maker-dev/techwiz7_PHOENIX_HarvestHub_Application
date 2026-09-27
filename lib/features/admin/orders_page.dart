// lib/features/admin/orders_page.dart
// Route: /admin/orders (NGUOI_5_MOBILE.md, 4.7 — chỉ xem, farmer mới được
// đổi trạng thái đơn).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/admin/admin_order.dart';
import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'admin_localization.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  static const _pageSize = 10;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final filter = ref.watch(orderFilterProvider);

    return AdminShell(
      currentRoute: '/admin/orders',
      title: adminText(context, 'Đơn hàng'), // i18n: admin.orders.title
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: filter.status != null ||
                filter.marketId != null ||
                filter.from != null,
            child: Icon(Icons.filter_list),
          ),
          onPressed: () => _openFilterSheet(context, ref, filter),
        ),
      ],
      child: ordersAsync.when(
        loading: () => Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: ListView.builder(
            itemCount: 8,
            itemBuilder: (_, __) => Container(
              height: 64,
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        error: (err, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(adminOrdersProvider),
            child:
                Text(adminText(context, 'Không tải được danh sách — thử lại')),
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
                child: Text(
                    adminText(context, 'Không có đơn hàng phù hợp bộ lọc.')));
          }
          final pageCount = (orders.length / _pageSize).ceil();
          final page = _page.clamp(0, pageCount - 1);
          final visible =
              orders.skip(page * _pageSize).take(_pageSize).toList();
          return Column(
            children: [
              _OrderStats(orders: orders),
              Expanded(
                child: ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final o = visible[index];
                    return ListTile(
                      title: Text(
                          '#${o.id} · ${o.customerName ?? adminText(context, 'Khách hàng')}'),
                      subtitle: Text(
                        '${o.marketName ?? '—'} · '
                        '${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year}'
                        '${o.source.name == 'offlineSync' ? ' · ${adminText(context, 'Đồng bộ ngoại tuyến')}' : ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(adminText(
                              context, '${o.totalAmount.toStringAsFixed(0)}đ')),
                          Chip(
                            label: Text(adminText(context, o.status),
                                style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: page > 0 ? () => setState(() => _page--) : null,
                    icon: Icon(Icons.chevron_left),
                  ),
                  Text(adminText(context, 'Trang ${page + 1}/$pageCount')),
                  IconButton(
                    onPressed: page < pageCount - 1
                        ? () => setState(() => _page++)
                        : null,
                    icon: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openFilterSheet(
      BuildContext context, WidgetRef ref, OrderFilter filter) async {
    final markets = await ref.read(marketsProvider.future);
    if (!context.mounted) return;
    String? status = filter.status;
    String? marketId = filter.marketId;
    DateTime? from = filter.from;
    DateTime? to = filter.to;

    showAppFilterSheet(
      context,
      title: adminText(context, 'Lọc đơn hàng'),
      onReset: () =>
          ref.read(orderFilterProvider.notifier).state = const OrderFilter(),
      onApply: () {
        ref.read(orderFilterProvider.notifier).state = OrderFilter(
          status: status,
          marketId: marketId,
          from: from,
          to: to,
        );
        setState(() => _page = 0);
      },
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              value: status,
              decoration:
                  InputDecoration(labelText: adminText(context, 'Trạng thái')),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(adminText(context, 'Tất cả'))),
                DropdownMenuItem(
                    value: 'pending',
                    child: Text(adminText(context, 'Chờ xử lý'))),
                DropdownMenuItem(
                    value: 'confirmed',
                    child: Text(adminText(context, 'Đã xác nhận'))),
                DropdownMenuItem(
                    value: 'completed',
                    child: Text(adminText(context, 'Hoàn tất'))),
                DropdownMenuItem(
                    value: 'cancelled',
                    child: Text(adminText(context, 'Đã huỷ'))),
              ],
              onChanged: (v) => setState(() => status = v),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: marketId,
              decoration: InputDecoration(labelText: adminText(context, 'Chợ')),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(adminText(context, 'Tất cả chợ')),
                ),
                for (final market in markets)
                  DropdownMenuItem<String?>(
                    value: market.id,
                    child: Text(
                        adminText(context, '${market.name} (${market.id})')),
                  ),
              ],
              onChanged: (value) => setState(() => marketId = value),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: from ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => from = picked);
                    },
                    child: Text(from == null
                        ? 'Từ ngày'
                        : '${from!.day}/${from!.month}/${from!.year}'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: to ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => to = picked);
                    },
                    child: Text(to == null
                        ? 'Đến ngày'
                        : '${to!.day}/${to!.month}/${to!.year}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStats extends StatelessWidget {
  _OrderStats({required this.orders});

  final List<AdminOrder> orders;

  @override
  Widget build(BuildContext context) {
    final highest =
        orders.reduce((a, b) => a.totalAmount >= b.totalAmount ? a : b);
    final monthlyBuyers = <String, Set<String>>{};
    final daily = <String, int>{};
    for (final order in orders) {
      final month =
          '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}';
      final day =
          '${order.createdAt.year}-${order.createdAt.month}-${order.createdAt.day}';
      monthlyBuyers
          .putIfAbsent(month, () => <String>{})
          .add(order.customerName ?? order.id);
      daily[day] = (daily[day] ?? 0) + 1;
    }
    final busiestMonth = _maxEntry({
      for (final entry in monthlyBuyers.entries) entry.key: entry.value.length,
    });
    final busiestDay = _maxEntry(daily);
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
              child: _OrderStat(
                  label: adminText(context, 'Đơn cao nhất'),
                  value: '${highest.totalAmount.toStringAsFixed(0)}đ')),
          Expanded(
              child: _OrderStat(
                  label: adminText(context, 'Tháng nhiều đơn'),
                  value:
                      '${busiestMonth?.key ?? '—'} (${busiestMonth?.value ?? 0})')),
          Expanded(
              child: _OrderStat(
                  label: adminText(context, 'Ngày nhiều đơn'),
                  value:
                      '${busiestDay?.key ?? '—'} (${busiestDay?.value ?? 0})')),
        ],
      ),
    );
  }

  MapEntry<String, int>? _maxEntry(Map<String, int> values) {
    if (values.isEmpty) return null;
    return values.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }
}

class _OrderStat extends StatelessWidget {
  _OrderStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall),
            Text(value,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}
