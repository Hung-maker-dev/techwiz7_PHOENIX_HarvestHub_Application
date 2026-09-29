import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/features/customer/data/api/chatbot/chatbot_farmer_handler.dart';

void main() {
  final handler = ChatbotFarmerHandler();

  final context = <String, dynamic>{
    'farmers': [
      {
        'id': 'farmer-1',
        'farm_name': 'Green Farm',
        'address': '12 Orchard Road',
        'market_name': 'Central Market',
        'status': 'approved',
      },
      {
        'id': 'farmer-2',
        'farm_name': 'Blue Farm',
        'address': '8 River Street',
        'status': 'approved',
      },
      {
        'id': 'farmer-3',
        'farm_name': 'Red Farm',
        'status': 'approved',
      },
    ],
    'products': [
      {
        'farmer_id': 'farmer-1',
        'name': 'Tomatoes',
        'category_id': 'vegetables',
        'price': 25000,
        'unit': 'kg',
        'stock': 4,
        'is_active': true,
      },
      {
        'farmer_id': 'farmer-1',
        'name': 'Cà chua',
        'name_en': 'Tomato',
        'category_id': 'vegetables',
        'price': 25000,
        'unit': 'kg',
        'stock': 4,
        'is_active': true,
      },
      {
        'farmer_id': 'farmer-2',
        'name': 'Cà chua',
        'name_en': 'Tomato',
        'category_id': 'vegetables',
        'price': 27000,
        'unit': 'kg',
        'stock': 2,
        'is_active': true,
      },
      {
        'farmer_id': 'farmer-3',
        'name': 'Cà chua',
        'name_en': 'Tomato',
        'category_id': 'vegetables',
        'price': 22000,
        'unit': 'kg',
        'stock': 0,
        'is_active': true,
      },
      {
        'farmer_id': 'farmer-1',
        'name': 'Out of stock cucumbers',
        'category_id': 'vegetables',
        'price': 18000,
        'unit': 'kg',
        'stock': 0,
        'is_active': true,
      },
      {
        'farmer_id': 'farmer-1',
        'name': 'Inactive lettuce',
        'category_id': 'vegetables',
        'price': 12000,
        'unit': 'bunch',
        'stock': 3,
        'is_active': false,
      },
      {
        'farmer_id': 'farmer-2',
        'name': 'Blueberries',
        'category_id': 'fruits',
        'price': 50000,
        'unit': 'box',
        'stock': 6,
        'is_active': true,
      },
      {
        'farmer_id': 'farmer-1',
        'name': 'Mangoes',
        'category_id': 'fruits',
        'price': 35000,
        'unit': 'kg',
        'stock': 7,
        'is_active': true,
      },
      {
        'farmer_id': 'farmer-1',
        'name': 'Bananas',
        'category_id': 'fruits',
        'price': 20000,
        'unit': 'kg',
        'stock': 5,
        'is_active': true,
      },
    ],
    'categories': [
      {'id': 'fruits', 'name': 'Trái cây', 'name_en': 'Fruits'},
      {'id': 'vegetables', 'name': 'Rau củ', 'name_en': 'Vegetables'},
    ],
    'markets': [],
  };

  test(
      'specific farmer details include location and available products with prices',
      () {
    final answer = handler.answer(
      'Tell me about Green Farm',
      context,
      useVietnamese: false,
    );

    expect(answer, contains('12 Orchard Road'));
    expect(answer, contains('Tomatoes'));
    expect(answer, contains('\$25,000/kg'));
    expect(answer, isNot(contains('Out of stock cucumbers')));
    expect(answer, isNot(contains('Inactive lettuce')));
    expect(answer, isNot(contains('Blueberries')));
  });

  test('farmer product question lists only that farmer’s in-stock products',
      () {
    final answer = handler.answer(
      'What products does Green Farm have?',
      context,
      useVietnamese: false,
    );

    expect(answer, contains('Tomatoes'));
    expect(answer, contains('\$25,000/kg'));
    expect(answer, isNot(contains('Out of stock cucumbers')));
    expect(answer, isNot(contains('Inactive lettuce')));
    expect(answer, isNot(contains('Blueberries')));
  });

  test('Vietnamese farmer product question is scoped to that farmer', () {
    final answer = handler.answer(
      'Trang trại Green Farm có những sản phẩm nào?',
      context,
      useVietnamese: true,
    );

    expect(answer, contains('Tomatoes'));
    expect(answer, contains('\$25,000/kg'));
    expect(answer, isNot(contains('Blueberries')));
  });

  test('farmer fruit question lists only in-stock fruit from that farmer', () {
    final answer = handler.answer(
      'Green Farm có loại trái cây gì?',
      context,
      useVietnamese: true,
    );

    expect(answer, contains('Mangoes'));
    expect(answer, contains('Bananas'));
    expect(answer, isNot(contains('Tomatoes')));
    expect(answer, isNot(contains('Blueberries')));
  });

  test('specific farmer product question returns only the named product', () {
    final answer = handler.answer(
      'What Mangoes does Green Farm have?',
      context,
      useVietnamese: false,
    );

    expect(answer, contains('Mangoes'));
    expect(answer, isNot(contains('Bananas')));
    expect(answer, isNot(contains('Tomatoes')));
  });

  test('Vietnamese tomato availability question lists farms and only tomatoes',
      () {
    final answer = handler.answer(
      'Những nông trại nào còn cà chua?',
      context,
      useVietnamese: true,
    );

    expect(answer, contains('Green Farm'));
    expect(answer, contains('Blue Farm'));
    expect(answer, contains('Cà chua'));
    expect(answer, isNot(contains('Red Farm')));
    expect(answer, isNot(contains('Blueberries')));
    expect(answer, isNot(contains('Mangoes')));
  });

  test('English tomato availability question lists farms, not product catalog',
      () {
    final answer = handler.answer(
      'which farms have tomato in stock',
      context,
      useVietnamese: false,
    );

    expect(answer, contains('Green Farm'));
    expect(answer, contains('Blue Farm'));
    expect(answer, contains('Cà chua'));
    expect(answer, isNot(contains('Red Farm')));
    expect(answer, isNot(contains('Blueberries')));
    expect(answer, isNot(contains('Mangoes')));
  });

  test('singular English farm query lists farms with tomato in stock', () {
    final answer = handler.answer(
      'which farm have tomato in stock',
      context,
      useVietnamese: false,
    );

    expect(answer, contains('Farms with this product in stock'));
    expect(answer, contains('Green Farm'));
    expect(answer, contains('Blue Farm'));
    expect(answer, contains('Cà chua'));
    expect(answer, isNot(contains('Red Farm')));
    expect(answer, isNot(contains('Blueberries')));
    expect(answer, isNot(contains('Mangoes')));
  });

  test('farmer name match excludes products from partial name matches', () {
    final expandedContext = {
      ...context,
      'farmers': [
        ...(context['farmers'] as List),
        {
          'id': 'farmer-3',
          'farm_name': 'Green Valley Farm',
          'status': 'approved',
        },
      ],
      'products': [
        ...(context['products'] as List),
        {
          'farmer_id': 'farmer-3',
          'name': 'Green beans',
          'price': 30000,
          'unit': 'kg',
          'stock': 5,
          'is_active': true,
        },
      ],
    };

    final answer = handler.answer(
      'What products does Green Farm have?',
      expandedContext,
      useVietnamese: false,
    );

    expect(answer, contains('Tomatoes'));
    expect(answer, isNot(contains('Green beans')));
    expect(answer, isNot(contains('Blueberries')));
  });

  test('generic farmer list does not claim their inventories are empty', () {
    final answer = handler.answer(
      'List farmers',
      context,
      useVietnamese: false,
    );

    expect(answer, contains('Green Farm'));
    expect(answer, contains('Blue Farm'));
    expect(answer, isNot(contains('No products are currently in stock')));
  });
}
