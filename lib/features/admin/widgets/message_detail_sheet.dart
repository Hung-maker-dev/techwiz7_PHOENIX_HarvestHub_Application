import 'package:flutter/material.dart';

import '../../../models/admin/admin_contact_message.dart';
import '../admin_localization.dart';

Future<void> showMessageDetailSheet(
  BuildContext context, {
  required AdminContactMessage message,
  required Future<void> Function() onResolve,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        MessageDetailSheet(message: message, onResolve: onResolve),
  );
}

class MessageDetailSheet extends StatefulWidget {
  MessageDetailSheet({
    super.key,
    required this.message,
    required this.onResolve,
  });

  final AdminContactMessage message;
  final Future<void> Function() onResolve;

  @override
  State<MessageDetailSheet> createState() => _MessageDetailSheetState();
}

class _MessageDetailSheetState extends State<MessageDetailSheet> {
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.message;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.subject, style: theme.textTheme.titleLarge),
          SizedBox(height: 4),
          Text('${m.name} · ${m.email}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          SizedBox(height: 16),
          Text(m.message),
          SizedBox(height: 20),
          if (m.status == ContactMessageStatus.pending)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _resolving
                    ? null
                    : () async {
                        setState(() => _resolving = true);
                        await widget.onResolve();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                icon: _resolving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.check),
                label: Text(adminText(context, 'Đánh dấu đã xử lý')),
              ),
            )
          else
            Chip(label: Text(adminText(context, 'Đã xử lý'))),
        ],
      ),
    );
  }
}
