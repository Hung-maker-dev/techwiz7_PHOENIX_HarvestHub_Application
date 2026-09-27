// lib/features/admin/widgets/market_list_tile.dart
import 'package:flutter/material.dart';

import '../../../models/admin/admin_market.dart';

class MarketListTile extends StatelessWidget {
  const MarketListTile({
    super.key,
    required this.market,
    required this.onToggleActive,
    required this.onTap,
  });

  final AdminMarket market;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        title: Text(market.name),
        subtitle: Text(
          '${market.address ?? '—'}\n'
          '${market.openHours ?? '—'} · ${market.farmerCount} nông dân',
        ),
        isThreeLine: true,
        trailing: Switch(value: market.isActive, onChanged: onToggleActive),
      ),
    );
  }
}
