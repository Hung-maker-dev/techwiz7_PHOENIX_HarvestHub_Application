// lib/features/admin/widgets/customer_list_tile.dart
import 'package:flutter/material.dart';

import '../../../models/admin/admin_customer.dart';

class CustomerListTile extends StatelessWidget {
  const CustomerListTile({super.key, required this.customer, this.onTap});

  final AdminCustomer customer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: customer.avatarUrl != null
            ? NetworkImage(customer.avatarUrl!)
            : null,
        child: customer.avatarUrl == null
            ? Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?')
            : null,
      ),
      title: Text(customer.name),
      subtitle: Text(customer.email),
      trailing: customer.isLocked
          ? const Icon(Icons.lock_outline, size: 18)
          : (customer.authProvider == 'google'
              ? const Icon(Icons.g_mobiledata, size: 22)
              : null),
      onTap: onTap,
    );
  }
}
