import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/core/network/dio_client.dart';
import 'package:harvesthub_mobile/features/common/forgot_password_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('forgot password requests a PIN, verifies it, then resets', (
    tester,
  ) async {
    final adapter = _PasswordResetAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'lib/l10n',
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        child: ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const ForgotPasswordPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, 'customer@example.test');
    await tester.tap(find.text('Gửi mã PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Mã PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Xác minh mã'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu mới'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'HarvestHub2026!');
    await tester.enterText(find.byType(TextField).at(1), 'HarvestHub2026!');
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mật khẩu đã được đổi'), findsOneWidget);
    expect(
      adapter.paths,
      [
        '/api/auth/password-reset/request',
        '/api/auth/password-reset/verify-code',
        '/api/auth/password-reset/complete',
      ],
    );
    expect(adapter.requests[0]['email'], 'customer@example.test');
    expect(adapter.requests[1]['code'], '123456');
    expect(adapter.requests[2]['reset_token'], 'a' * 64);
    expect(adapter.requests[2]['password'], 'HarvestHub2026!');
  });
}

class _PasswordResetAdapter implements HttpClientAdapter {
  final paths = <String>[];
  final requests = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    requests.add(Map<String, dynamic>.from(options.data as Map));
    final response = switch (options.path) {
      '/api/auth/password-reset/request' => {'message': 'If registered, sent.'},
      '/api/auth/password-reset/verify-code' => {'reset_token': 'a' * 64},
      '/api/auth/password-reset/complete' => {'message': 'Password updated.'},
      _ => throw StateError('Unexpected request path: ${options.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
