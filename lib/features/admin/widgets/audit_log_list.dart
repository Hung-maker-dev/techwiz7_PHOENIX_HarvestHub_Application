// lib/features/admin/widgets/audit_log_list.dart
//
// 4.10: "AuditLogList (chỉ đọc, không hành động nào trên danh sách này)".

import 'package:flutter/material.dart';

import '../../../models/admin/audit_log_entry.dart';
import '../admin_localization.dart';

class AuditLogList extends StatelessWidget {
  AuditLogList({super.key, required this.entries});

  final List<AuditLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Text(adminText(
                context, 'Không có nhật ký nào trong khoảng đã chọn.'))),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final e = entries[index];
        return ListTile(
          leading: Icon(
            e.actorId == null ? Icons.smart_toy_outlined : Icons.person_outline,
          ),
          title:
              Text(adminText(context, '${e.actorDisplayName} · ${e.action}')),
          subtitle: Text('${e.entityType} #${e.entityId}'
              '${e.details != null ? ' — ${e.details}' : ''}'),
          trailing: Text(
            '${e.createdAt.hour.toString().padLeft(2, '0')}:'
            '${e.createdAt.minute.toString().padLeft(2, '0')}\n'
            '${e.createdAt.day}/${e.createdAt.month}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          isThreeLine: false,
        );
      },
    );
  }
}
