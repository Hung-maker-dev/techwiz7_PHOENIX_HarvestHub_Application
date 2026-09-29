import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/admin/admin_customer.dart';
import '../../../providers/admin/admin_providers.dart';
import '../admin_localization.dart';

Future<void> showCustomerDetailSheet(
  BuildContext context, {
  required AdminCustomer customer,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final detailAsync = ref.watch(customerDetailProvider(customer.id));
        return CustomerDetailSheet(
          customer: detailAsync.maybeWhen(
            data: (full) => full,
            orElse: () => customer,
          ),
        );
      },
    ),
  );
}

class CustomerDetailSheet extends StatelessWidget {
  CustomerDetailSheet({super.key, required this.customer});

  final AdminCustomer customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          CircleAvatar(
            radius: 32,
            backgroundImage: customer.avatarUrl != null
                ? NetworkImage(customer.avatarUrl!)
                : null,
            child: customer.avatarUrl == null
                ? Text(customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase()
                    : '?')
                : null,
          ),
          SizedBox(height: 12),
          Text(customer.name, style: theme.textTheme.titleLarge),
          Text(customer.email, style: theme.textTheme.bodyMedium),
          SizedBox(height: 16),
          _InfoRow(
              label: adminText(context, 'Điện thoại'),
              value: customer.phone ?? '—'),
          _InfoRow(
            label: adminText(context, 'Đăng nhập bằng'),
            value:
                customer.authProvider == 'google' ? 'Google' : 'Email/mật khẩu',
          ),
          _InfoRow(
            label: adminText(context, 'Ngôn ngữ'),
            value:
                customer.preferredLanguage == 'en' ? 'English' : 'Tiếng Việt',
          ),
          _InfoRow(
            label: adminText(context, 'Ngày tham gia'),
            value:
                '${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}',
          ),
          if (customer.orderCount != null)
            _InfoRow(
                label: adminText(context, 'Số đơn hàng'),
                value: '${customer.orderCount}'),
          if (customer.totalSpent != null)
            _InfoRow(
              label: adminText(context, 'Tổng chi tiêu'),
              value: '${customer.totalSpent!.toStringAsFixed(0)}đ',
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
