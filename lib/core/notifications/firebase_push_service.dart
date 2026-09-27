import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';
import '../network/dio_client.dart';
import '../router/app_router.dart';

const _announcementChannelId = 'harvesthub_announcements';
const _announcementChannelName = 'Thông báo nông trại';

final firebasePushServiceProvider = Provider<FirebasePushService>((ref) {
  final service = FirebasePushService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class FirebasePushService {
  FirebasePushService(this._ref);

  final Ref _ref;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) {
      debugPrint('Firebase is not initialized; skipping push setup.');
      return;
    }
    if (kIsWeb ||
        !{TargetPlatform.android, TargetPlatform.iOS}
            .contains(defaultTargetPlatform)) {
      debugPrint('Push notifications are not configured for this platform.');
      return;
    }

    _initialized = true;
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => _openInbox(),
    );

    final androidNotifications =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        _announcementChannelId,
        _announcementChannelName,
        description: 'Thông báo mới từ các nông trại bạn theo dõi',
        importance: Importance.max,
      ),
    );

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_showForegroundNotification(message)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM foreground listener failed: $error\n$stackTrace');
      },
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => _openInbox(),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
            'FCM notification-open listener failed: $error\n$stackTrace');
      },
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) => unawaited(_registerToken(token)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh listener failed: $error\n$stackTrace');
      },
    );
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        if (user != null) unawaited(_registerIfAlreadyAuthorized());
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM auth listener failed: $error\n$stackTrace');
      },
    );

    final initialMessage = await _messaging.getInitialMessage();
    final localLaunch =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (initialMessage != null ||
        localLaunch?.didNotificationLaunchApp == true) {
      unawaited(_openInbox());
    }
  }

  Future<void> unregisterCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _ref.read(dioProvider).delete(
      '/api/devices/fcm-token',
      data: {'token': token},
    );
  }

  Future<void> requestPermissionAndRegister() =>
      _requestPermissionAndRegister();

  Future<void> _registerIfAlreadyAuthorized() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) await _registerToken(token);
      }
    } catch (error, stackTrace) {
      debugPrint(
          'Could not restore FCM token registration: $error\n$stackTrace');
    }
  }

  Future<void> _requestPermissionAndRegister() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) {
        debugPrint(
          'FCM notifications not registered: permission ${settings.authorizationStatus}.',
        );
        return;
      }
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (error, stackTrace) {
      debugPrint('FCM permission/token setup failed: $error\n$stackTrace');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _ref.read(dioProvider).post(
        '/api/devices/fcm-token',
        data: {
          'token': token,
          'platform':
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        },
      );
    } catch (error, stackTrace) {
      if (error is DioException) {
        debugPrint(
          'Could not register FCM device token: '
          '${error.response?.statusCode ?? error.type}',
        );
      } else {
        debugPrint('Could not register FCM device token: $error\n$stackTrace');
      }
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _announcementChannelId,
          _announcementChannelName,
          channelDescription: 'Thông báo mới từ các nông trại bạn theo dõi',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['screen'] as String?,
    );
  }

  Future<void> _openInbox() async {
    try {
      final role = await _ref.read(authRepositoryProvider).fetchCurrentRole();
      final router = _ref.read(appRouterProvider);
      if (role == 'farmer') {
        router.go('/farmer/notifications');
      } else if (role == 'customer') {
        router.go('/customer/notifications');
      } else if (role == 'admin') {
        router.go('/admin');
      }
    } catch (error, stackTrace) {
      debugPrint('Could not open notification inbox: $error\n$stackTrace');
    }
  }

  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
  }
}
