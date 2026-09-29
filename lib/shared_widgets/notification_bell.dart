import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers/notification_providers.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key, required this.isFarmer});

  final bool isFarmer;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (widget.isFarmer) {
        ref.invalidate(farmerUnreadNotificationCountProvider);
      } else {
        ref.invalidate(customerUnreadNotificationCountProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationCount = widget.isFarmer
        ? ref.watch(farmerUnreadNotificationCountProvider)
        : ref.watch(customerUnreadNotificationCountProvider);
    final count = notificationCount.asData?.value;
    final hasError = notificationCount.hasError;
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: hasError
          ? 'account.notifications.loadError'.tr()
          : 'account.home.notifications'.tr(),
      onPressed: () => context.go(
        widget.isFarmer ? '/farmer/notifications' : '/customer/notifications',
      ),
      icon: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded),
            if (hasError || (count != null && count > 0))
              Positioned(
                top: 0,
                right: -1,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    hasError ? '!' : (count! > 99 ? '99+' : '$count'),
                    style: TextStyle(
                      color: colorScheme.onError,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
