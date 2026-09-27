import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/api/customer_community_api.dart';

class CustomerNotificationsPage extends ConsumerStatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  ConsumerState<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends ConsumerState<CustomerNotificationsPage> {
  late Future<List<CustomerNotification>> _notifications;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _notifications = _load();
  }

  Future<List<CustomerNotification>> _load() {
    return ref.read(customerCommunityApiProvider).fetchNotifications();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _notifications = next);
    try {
      await next;
    } on ApiException {
      // FutureBuilder renders the same failed future with its server message.
    }
  }

  Future<void> _open(CustomerNotification notification) async {
    if (!notification.isRead) {
      try {
        await ref
            .read(customerCommunityApiProvider)
            .markNotificationRead(notification.id);
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
        return;
      } catch (error, stackTrace) {
        debugPrint(
            'Could not mark customer notification as read: $error\n$stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('account.notifications.updateError'.tr())),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() => _notifications = _load());
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Text(notification.body ?? ''),
        actions: [
          if (notification.orderId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/orders/${notification.orderId}');
              },
              child: Text('account.notifications.viewOrder'.tr()),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('account.notifications.close'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await ref.read(customerCommunityApiProvider).markAllNotificationsRead();
      if (mounted) setState(() => _notifications = _load());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error, stackTrace) {
      debugPrint(
          'Could not mark all customer notifications as read: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('account.notifications.updateError'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('account.notifications.title'.tr()),
        actions: [
          FutureBuilder<List<CustomerNotification>>(
            future: _notifications,
            builder: (context, snapshot) {
              final hasUnread =
                  snapshot.data?.any((item) => !item.isRead) ?? false;
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: _markingAll ? null : _markAllRead,
                child: Text('account.notifications.readAll'.tr()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<CustomerNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is ApiException
                        ? error.message
                        : 'account.notifications.loadError'.tr(),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _refresh,
                    child: Text('account.notifications.retry'.tr()),
                  ),
                ],
              ),
            );
          }
          final notifications = snapshot.data ?? const [];
          if (notifications.isEmpty) {
            return Center(child: Text('account.notifications.empty'.tr()));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  color: item.isRead
                      ? null
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: Icon(item.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active),
                    title: Text(item.title),
                    subtitle: Text(item.body ?? ''),
                    onTap: () => _open(item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
