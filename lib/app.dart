import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_repository.dart';
import 'core/notifications/firebase_push_service.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/user_role_provider.dart';
import 'features/customer/widgets/chatbot_widget.dart';
import 'shared_widgets/offline_banner.dart';
import 'shared_widgets/toast_queue.dart';

class HarvestHubApp extends ConsumerStatefulWidget {
  const HarvestHubApp({super.key});

  @override
  ConsumerState<HarvestHubApp> createState() => _HarvestHubAppState();
}

class _HarvestHubAppState extends ConsumerState<HarvestHubApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(firebasePushServiceProvider).initialize().catchError(
        (Object error, StackTrace stackTrace) {
          debugPrint('Could not initialize Firebase push: $error\n$stackTrace');
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final role = ref.watch(userRoleProvider).valueOrNull;
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;

    return MaterialApp.router(
      title: 'HarvestHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: ref.watch(appRouterProvider),
      // Mount ToastOverlay + offline banner MỘT LẦN ở gốc cây widget —
      // không lặp lại ở từng màn hình (xem yêu cầu mục A).
      builder: (context, child) {
        return ToastOverlay(
          key: toastOverlayKey,
          child: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: child ?? const SizedBox.shrink()),
                    if (signedIn && role == 'customer')
                      const Positioned(
                        right: 16,
                        bottom: 16,
                        child: ChatbotWidget(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
