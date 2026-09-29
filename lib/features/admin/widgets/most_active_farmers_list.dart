import 'package:flutter/material.dart';

import '../../../models/admin/dashboard_summary.dart';
import '../admin_localization.dart';

class MostActiveFarmersList extends StatelessWidget {
  MostActiveFarmersList({super.key, required this.farmers});

  final List<ActiveFarmerSummary> farmers;

  @override
  Widget build(BuildContext context) {
    if (farmers.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(adminText(context, 'Chưa có dữ liệu.')),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < farmers.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(adminText(context, '${i + 1}'))),
            title: Text(farmers[i].farmName),
            subtitle: Text(adminText(context, '${farmers[i].orderCount} đơn')),
            trailing: Text(adminText(
                context, '${farmers[i].revenue.toStringAsFixed(0)}đ')),
          ),
      ],
    );
  }
}
