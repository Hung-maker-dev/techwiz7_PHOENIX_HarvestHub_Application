// lib/features/admin/contact_messages_page.dart
// Route: /admin/contact-messages (NGUOI_5_MOBILE.md, 4.8)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin/admin_contact_message.dart';
import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/message_detail_sheet.dart';
import 'widgets/message_list.dart';
import 'widgets/status_filter_tabs.dart';
import 'admin_localization.dart';

class AdminContactMessagesPage extends ConsumerStatefulWidget {
  const AdminContactMessagesPage({super.key, this.initialStatus});

  /// Điều hướng thẳng từ Dashboard (4.1 PendingActionsList) với tab "Mới"
  /// đã chọn sẵn.
  final ContactMessageStatus? initialStatus;

  @override
  ConsumerState<AdminContactMessagesPage> createState() =>
      _AdminContactMessagesPageState();
}

class _AdminContactMessagesPageState
    extends ConsumerState<AdminContactMessagesPage> {
  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(contactStatusFilterProvider.notifier).state =
            widget.initialStatus!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(contactMessagesProvider);
    final statusFilter = ref.watch(contactStatusFilterProvider);
    final resolve = ref.watch(resolveContactMessageProvider);

    return AdminShell(
      currentRoute: '/admin/contact-messages',
      title: adminText(
          context, 'Phản hồi liên hệ'), // i18n: admin.contactMessages.title
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: StatusFilterTabs<ContactMessageStatus>(
              selected: statusFilter,
              onSelected: (v) =>
                  ref.read(contactStatusFilterProvider.notifier).state = v,
              options: [
                StatusFilterOption('Mới', ContactMessageStatus.pending),
                StatusFilterOption('Đã xử lý', ContactMessageStatus.resolved),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(contactMessagesProvider),
                  child: Text(
                      adminText(context, 'Không tải được danh sách — thử lại')),
                ),
              ),
              data: (messages) => MessageList(
                messages: messages,
                onTap: (m) => showMessageDetailSheet(
                  context,
                  message: m,
                  onResolve: () => resolve(m.id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
