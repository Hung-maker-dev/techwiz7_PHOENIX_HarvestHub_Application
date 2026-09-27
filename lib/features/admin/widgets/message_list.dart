// lib/features/admin/widgets/message_list.dart
import 'package:flutter/material.dart';

import '../../../models/admin/admin_contact_message.dart';
import '../admin_localization.dart';

class MessageList extends StatelessWidget {
  MessageList({super.key, required this.messages, required this.onTap});

  final List<AdminContactMessage> messages;
  final ValueChanged<AdminContactMessage> onTap;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child:
            Center(child: Text(adminText(context, 'Không có phản hồi nào.'))),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final m = messages[index];
        return ListTile(
          leading: Icon(
            m.status == ContactMessageStatus.resolved
                ? Icons.mark_email_read_outlined
                : Icons.mark_email_unread_outlined,
            color: m.status == ContactMessageStatus.resolved
                ? null
                : Colors.orange,
          ),
          title: Text(m.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(adminText(context, '${m.name} · ${m.email}')),
          onTap: () => onTap(m),
        );
      },
    );
  }
}
