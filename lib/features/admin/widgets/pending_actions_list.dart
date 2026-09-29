import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/admin/dashboard_summary.dart';
import '../admin_localization.dart';

class PendingActionsList extends StatelessWidget {
  PendingActionsList({super.key, required this.actions});

  final List<PendingAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(adminText(context, 'Không có việc cần xử lý ngay.')),
      );
    }
    return Column(
      children: [
        for (final action in actions)
          Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                action.type == 'farmer_pending'
                    ? Icons.agriculture_outlined
                    : Icons.mark_email_unread_outlined,
              ),
              title: Text(action.title),
              subtitle: Text(action.subtitle),
              trailing: Icon(Icons.chevron_right),
              onTap: () => context.push(action.route),
            ),
          ),
      ],
    );
  }
}
