import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../network/dio_client.dart';

/// Kết quả đăng nhập/đăng ký, đã map lỗi Firebase sang khoá i18n
/// (không hiện mã lỗi gốc cho người dùng — xem login_page.dart).
class AuthFailure implements Exception {
  AuthFailure(this.i18nKey);
  final String i18nKey; // vd: 'common.auth.errorWrongPassword'
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;
  final _googleSignIn = GoogleSignIn(
    serverClientId:
        '813757604404-kaptg0lcjm4u1p27ilab10kpq2echj81.apps.googleusercontent.com',
    scopes: ['email'],
  );

  Stream<User?> authStateChanges() => FirebaseAuth.instance.authStateChanges();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<void> loginWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapFirebaseError(e.code));
    }
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(fullName);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapFirebaseError(e.code));
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      debugPrint('Google sign-in: start');
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google sign-in: cancelled by user');
        return false; // người dùng huỷ
      }

      final googleAuth = await googleUser.authentication;
      debugPrint(
        'Google sign-in: token check -> accessToken=${googleAuth.accessToken != null}, idToken=${googleAuth.idToken != null}',
      );

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint(
          'Google sign-in: Firebase success -> ${userCredential.user?.uid}');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'Google sign-in: FirebaseAuthException -> code=${e.code}, msg=${e.message}');
      throw AuthFailure(_mapFirebaseError(e.code));
    } on Exception catch (e) {
      debugPrint('Google sign-in: generic exception -> $e');
      throw AuthFailure('common.auth.errorGeneric');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    // Luôn thành công về mặt UI bất kể email có tồn tại hay không
    // (chống dò email) — lỗi mạng thật sự vẫn được ném ra để UI xử lý riêng.
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return; // im lặng — không tiết lộ email có tồn tại hay không
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _dio.delete(
          '/api/devices/fcm-token',
          data: {'token': token},
        );
      }
    } on DioException catch (error) {
      debugPrint(
        'Could not unregister FCM token before sign-out: '
        '${error.response?.statusCode ?? error.type}',
      );
    } catch (error, stackTrace) {
      debugPrint('Could not unregister FCM token: $error\n$stackTrace');
    }
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
  }

  /// Lấy role THẬT của user hiện tại từ backend — nguồn duy nhất được tin
  /// cậy để xác định quyền hạn trong toàn app.
  ///
  /// Trả về `null` nếu chưa đăng nhập hoặc chưa có MySQL profile. Nơi gọi
  /// (userRoleProvider) sẽ luôn fallback về 'customer' khi nhận `null` —
  /// KHÔNG BAO GIỜ được suy đoán hay mặc định một role có quyền cao hơn.
  ///
  /// Endpoint GET /api/auth/me trả về hồ sơ MySQL của Firebase UID hiện tại.
  /// Null means the account is authenticated but has not completed setup.
  Future<String?> fetchCurrentRole() async {
    if (currentUser == null) {
      return null;
    }

    try {
      final response = await _dio.get('/api/auth/me');
      final data = response.data;
      final role = data is Map ? data['role'] : null;
      if (role is String &&
          const {'admin', 'farmer', 'customer'}.contains(role)) {
        return role;
      }
      debugPrint(
          'fetchCurrentRole: response không có field role hợp lệ: $data');
      throw const FormatException(
          'The current user response has no valid role');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      debugPrint(
        'fetchCurrentRole failed: ${e.response?.statusCode ?? e.type}',
      );
      rethrow;
    }
  }

  Future<String> completeAccountSetup({required bool applyAsFarmer}) async {
    final user = currentUser;
    if (user == null) throw AuthFailure('common.auth.errorGeneric');
    final isGoogleAccount = user.providerData
        .any((provider) => provider.providerId == 'google.com');
    await _syncWithBackend(
      authProvider: isGoogleAccount ? 'google' : 'password',
      fullName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email,
    );
    final role = await fetchCurrentRole();
    if (role == null) throw AuthFailure('common.auth.errorGeneric');
    if (applyAsFarmer && role == 'customer') return 'farmer_application';
    return role;
  }

  /// Đồng bộ user Firebase với backend HarvestHub, giữ nguyên hợp đồng
  /// API hiện có: POST /api/auth/sync { auth_provider, full_name? }.
  Future<void> _syncWithBackend({
    required String authProvider,
    String? fullName,
  }) async {
    try {
      await _dio.post('/api/auth/sync', data: {
        'auth_provider': authProvider,
        if (fullName != null) 'full_name': fullName,
      });
      await _registerFcmDeviceToken();
    } on DioException catch (e) {
      debugPrint(
        'Account setup sync failed for authProvider=$authProvider: ${e.response?.statusCode ?? e.type}',
      );
      throw AuthFailure('common.auth.errorGeneric');
    }
  }

  Future<void> _registerFcmDeviceToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _dio.post(
        '/api/devices/fcm-token',
        data: {
          'token': token,
          'platform':
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        },
      );
    } on DioException catch (error) {
      debugPrint(
        'Could not register FCM token after account sync: '
        '${error.response?.statusCode ?? error.type}',
      );
    } catch (error, stackTrace) {
      debugPrint('Could not register FCM token: $error\n$stackTrace');
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return 'common.auth.errorWrongPassword';
      case 'email-already-in-use':
        return 'common.auth.errorEmailInUse';
      case 'invalid-email':
        return 'common.auth.errorInvalidEmail';
      case 'weak-password':
        return 'common.auth.errorWeakPassword';
      default:
        return 'common.auth.errorGeneric';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
