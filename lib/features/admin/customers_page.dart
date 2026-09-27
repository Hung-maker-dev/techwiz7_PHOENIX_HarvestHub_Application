// lib/features/admin/customers_page.dart
// Route: /admin/customers (NGUOI_5_MOBILE.md, 4.2)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/customer_detail_sheet.dart';
import 'widgets/customer_list_tile.dart';
import 'admin_localization.dart';

class AdminCustomersPage extends ConsumerStatefulWidget {
  const AdminCustomersPage({super.key});

  @override
  ConsumerState<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends ConsumerState<AdminCustomersPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 350), () {
      ref.read(customerSearchQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final customers = customersAsync.valueOrNull ?? [];
    final topSpender = customers.isEmpty
        ? null
        : customers.reduce(
            (a, b) => (a.totalSpent ?? 0) >= (b.totalSpent ?? 0) ? a : b);
    final topBuyer = customers.isEmpty
        ? null
        : customers.reduce(
            (a, b) => (a.orderCount ?? 0) >= (b.orderCount ?? 0) ? a : b);

    return AdminShell(
      currentRoute: '/admin/customers',
      title: adminText(context, 'Khách hàng'), // i18n: admin.customers.title
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: adminText(context, 'Tìm theo tên hoặc email'),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (customersAsync.hasValue && customers.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _CustomerStatCard(
                      label: adminText(context, 'Chi tiêu cao nhất'),
                      value: topSpender == null
                          ? '0đ'
                          : '${(topSpender.totalSpent ?? 0).toStringAsFixed(0)}đ',
                      detail: topSpender?.name ?? '',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _CustomerStatCard(
                      label: adminText(context, 'Mua nhiều nhất'),
                      value: '${topBuyer?.orderCount ?? 0} đơn',
                      detail: topBuyer?.name ?? '',
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: customersAsync.when(
              loading: () => Shimmer.fromColors(
                baseColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                highlightColor: Theme.of(context).colorScheme.surface,
                child: ListView.builder(
                  itemCount: 8,
                  itemBuilder: (_, __) => ListTile(
                    leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.surface),
                    title: SizedBox(
                        height: 12,
                        child: ColoredBox(
                            color: Theme.of(context).colorScheme.surface)),
                  ),
                ),
              ),
              error: (err, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(customersProvider),
                  child: Text(
                      adminText(context, 'Không tải được danh sách — thử lại')),
                ),
              ),
              data: (customers) {
                // Danh sách thay đổi do tìm kiếm — pattern #5: fade toàn
                // khối 150ms, KHÔNG stagger từng thẻ (danh sách có thể dài).
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 150),
                  child: customers.isEmpty
                      ? Center(
                          key: ValueKey('empty'),
                          child: Text(adminText(
                              context, 'Không tìm thấy khách hàng nào.')),
                        )
                      : ListView.separated(
                          key: ValueKey(customers.length.toString() +
                              (customers.isNotEmpty ? customers.first.id : '')),
                          itemCount: customers.length,
                          separatorBuilder: (_, __) => Divider(height: 1),
                          itemBuilder: (context, index) {
                            final c = customers[index];
                            return CustomerListTile(
                              customer: c,
                              onTap: () =>
                                  showCustomerDetailSheet(context, customer: c),
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
  }
}

class _CustomerStatCard extends StatelessWidget {
  _CustomerStatCard({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
