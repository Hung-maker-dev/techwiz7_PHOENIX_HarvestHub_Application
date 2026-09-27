import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harvesthub_mobile/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'lib/l10n',
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        child: const ProviderScope(child: HarvestHubApp()),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
