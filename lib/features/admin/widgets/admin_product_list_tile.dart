import 'package:flutter/material.dart';

import '../../../models/admin/admin_product.dart';
import '../admin_localization.dart';

class AdminProductListTile extends StatelessWidget {
  AdminProductListTile({
    super.key,
    required this.product,
    required this.onHide,
  });

  final AdminProduct product;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: product.imageUrl != null
              ? Image.network(product.imageUrl!,
                  width: 48, height: 48, fit: BoxFit.cover)
              : Container(
                  width: 48,
                  height: 48,
                  color: theme.colorScheme.surfaceVariant,
                  child: Icon(Icons.image_not_supported_outlined),
                ),
        ),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${product.farmerName ?? '—'} · ${product.categoryName ?? '—'}\n'
          '${product.price.toStringAsFixed(0)}đ/${product.unit} · Tồn: ${product.stock}',
        ),
        isThreeLine: true,
        trailing: product.isHidden
            ? OutlinedButton(
                onPressed: null,
                child: Text(adminText(context, 'Đã ẩn')),
              )
            : TextButton(
                onPressed: onHide,
                child: Text(adminText(context, 'Ẩn')),
              ),
      ),
    );
  }
}
