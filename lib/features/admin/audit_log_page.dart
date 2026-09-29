import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/audit_log_list.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'admin_localization.dart';

class AdminAuditLogPage extends ConsumerWidget {
  const AdminAuditLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(auditLogProvider);
    final filter = ref.watch(auditLogFilterProvider);

    return AdminShell(
      currentRoute: '/admin/audit-log',
      title:
          adminText(context, 'Nhật ký hoạt động'), // i18n: admin.auditLog.title
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: filter.actorId != null || filter.from != null,
            child: Icon(Icons.filter_list),
          ),
          onPressed: () => _openFilterSheet(context, ref, filter),
        ),
      ],
      child: logAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(auditLogProvider),
            child: Text(adminText(context, 'Không tải được nhật ký — thử lại')),
          ),
        ),
        data: (entries) => AuditLogList(entries: entries),
      ),
    );
  }

  Future<void> _openFilterSheet(
      BuildContext context, WidgetRef ref, AuditLogFilter filter) async {
    final users = await ref.read(adminUsersProvider.future);
    if (!context.mounted) return;
    String? actorId = filter.actorId;
    DateTime? from = filter.from;
    DateTime? to = filter.to;

    showAppFilterSheet(
      context,
      title: adminText(context, 'Lọc nhật ký hoạt động'),
      onReset: () =>
          ref.read(auditLogFilterProvider.notifier).state = AuditLogFilter(),
      onApply: () =>
          ref.read(auditLogFilterProvider.notifier).state = AuditLogFilter(
        actorId: actorId,
        from: from,
        to: to,
      ),
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              value: actorId,
              decoration: InputDecoration(
                  labelText: adminText(context, 'Người thực hiện')),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(adminText(context, 'Tất cả người dùng')),
                ),
                for (final user in users)
                  DropdownMenuItem<String?>(
                    value: user.id,
                    child:
                        Text(adminText(context, '${user.name} (${user.id})')),
                  ),
              ],
              onChanged: (value) => setState(() => actorId = value),
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
