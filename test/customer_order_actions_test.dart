import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/data/api/customer_api.dart';

void main() {
  test('changing pickup slot sends a customer order schedule update', () async {
    final adapter = _CustomerOrderAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    final api = CustomerApi(dio);

    await api.changePickupSlot(
      orderId: 'order-1',
      pickupSlotId: 'slot-2',
    );

    expect(adapter.path, '/api/orders/order-1/pickup-slot');
    expect(adapter.method, 'PATCH');
    expect(adapter.body, {'pickup_slot_id': 'slot-2'});
  });

  test('cancellation remains a customer order cancellation patch', () async {
    final adapter = _CustomerOrderAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    final api = CustomerApi(dio);

    await api.cancelOrder('order-1');

    expect(adapter.path, '/api/orders/order-1/cancel');
    expect(adapter.method, 'PATCH');
  });
}

class _CustomerOrderAdapter implements HttpClientAdapter {
  String? path;
  String? method;
  Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    method = options.method;
    if (options.data is Map) {
      body = Map<String, dynamic>.from(options.data as Map);
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
