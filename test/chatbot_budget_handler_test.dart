import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_mobile/features/customer/data/api/chatbot/chatbot_budget_handler.dart';

void main() {
  final handler = ChatbotBudgetHandler();
  final context = <String, dynamic>{
    'products': [
      {
        'id': 'tomato',
        'name': 'Tomato',
        'price': 25000,
        'unit': 'kg',
        'stock': 10,
        'is_active': true,
        'category_id': 'vegetables',
      },
      {
        'id': 'rice',
        'name': 'ST25 Rice',
        'price': 50000,
        'unit': 'kg',
        'stock': 10,
        'is_active': true,
        'category_id': 'grains',
      },
    ],
  };

  test('parses dollar-formatted budget questions', () {
    final answer = handler.answer(
      'What can I buy with \$100,000?',
      context,
      isVietnamese: false,
    );

    expect(answer, isNotNull);
    expect(answer, contains('Tomato'));
    expect(answer, contains('ST25 Rice'));
  });

  test('continues to support k-formatted budget questions', () {
    final answer = handler.answer(
      'What can I buy with 100k?',
      context,
      isVietnamese: false,
    );

    expect(answer, isNotNull);
    expect(answer, contains('Tomato'));
    expect(answer, contains('ST25 Rice'));
  });

  test('treats a trailing dollar amount as the existing k budget shorthand',
      () {
    final dollarAnswer = handler.answer(
      'how many products can i buy with 100\$',
      context,
      isVietnamese: false,
    );
    final shorthandAnswer = handler.answer(
      'how many products can i buy with 100k',
      context,
      isVietnamese: false,
    );

    expect(dollarAnswer, isNotNull);
    expect(dollarAnswer, contains('Tomato'));
    expect(dollarAnswer, contains('ST25 Rice'));
    expect(dollarAnswer, shorthandAnswer);
  });

  test('answers Vietnamese what-can-I-buy wording with a dollar budget', () {
    final answer = handler.answer(
      'Với 100\$ có thể mua gì?',
      context,
      isVietnamese: true,
    );

    expect(answer, isNotNull);
    expect(answer, contains('100,000'));
    expect(answer, contains('Tomato'));
    expect(answer, contains('ST25 Rice'));
  });

  test('answers reverse-order English what-can-I-buy dollar question', () {
    final answer = handler.answer(
      'With 100\$ what can I buy?',
      context,
      isVietnamese: false,
    );

    expect(answer, isNotNull);
    expect(answer, contains('Tomato'));
    expect(answer, contains('ST25 Rice'));
  });
}
