import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harvesthub_mobile/data/api/farmer_data_api.dart';
import 'package:harvesthub_mobile/features/farmer/orders_page.dart';
import 'package:harvesthub_mobile/providers/farmer_data_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('farmer order shows product and stock details',
      (WidgetTester tester) async {
    final order = FarmerOrderData(
      id: 'ORD-1',
      customerName: 'Nguyễn A',
      deliveryAddress: '12 Main Street\nGPS: 10.0000000, 106.0000000',
      total: 120000,
      status: 'Pending',
      pickupTime: DateTime(2026, 9, 25, 9),
      pickupSlotId: 'SLOT-1',
      slotAvailable: true,
      items: const [
        FarmerOrderItemData(
          productId: 'PRD-1',
          name: 'Cà chua',
          quantity: 3,
          stock: 5,
          unit: 'kg',
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'lib/l10n',
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        child: ProviderScope(
          overrides: [
            farmerOrdersProvider.overrideWith((ref, status) async => [order]),
          ],
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const FarmerOrdersPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cà chua'), findsOneWidget);
    expect(find.textContaining('3 kg / 5 kg'), findsOneWidget);
    expect(find.textContaining('Khung giờ còn chỗ'), findsOneWidget);
    expect(find.textContaining('GPS: 10.0000000, 106.0000000'), findsOneWidget);
  });
}
