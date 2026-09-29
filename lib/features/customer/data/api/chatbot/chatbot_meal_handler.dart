import 'package:flutter/foundation.dart';

class ChatbotMealHandler {
  ChatbotMealHandler({
    // ignore: avoid_unused_constructor_parameters
    String apiKey = '',
  });

  Future<String?> answer(
    String question,
    Map<String, dynamic> context, {
    required bool isVietnamese,
  }) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) return null;

    final isMeal = _isMealQuestion(cleanQuestion);

    debugPrint('🍽️ MEAL QUESTION: $cleanQuestion');
    debugPrint('🍽️ IS MEAL QUESTION: $isMeal');

    if (!isMeal) return null;

    final products = _getAvailableProducts(context);
    debugPrint('🍽️ AVAILABLE PRODUCTS: ${products.length}');

    if (products.isEmpty) {
      return isVietnamese
          ? 'Hiện tại chưa có đủ sản phẩm đang có sẵn trong HarvestHub '
              'để gợi ý món ăn.'
          : 'There are not enough available products in HarvestHub to '
              'suggest a meal right now.';
    }

    final relevantProducts = _findRelevantProducts(cleanQuestion, products);
    debugPrint('🍽️ RELEVANT PRODUCTS: ${relevantProducts.length}');

    final mealProducts = relevantProducts.isNotEmpty
        ? relevantProducts
        : products.take(20).toList();

    return _buildAnswer(
      products: mealProducts,
      isVietnamese: isVietnamese,
      hasSpecificProducts: relevantProducts.isNotEmpty,
    );
  }

  bool _isMealQuestion(String question) {
    final text = _normalize(question);

    const vietnameseKeywords = [
      'hom nay an gi',
      'an gi hom nay',
      'goi y mon an',
      'goi y mon',
      'mon an hom nay',
      'mon gi hom nay',
      'nen an gi',
      'toi nay an gi',
      'trua nay an gi',
      'bua toi an gi',
      'bua trua an gi',
      'bua sang an gi',
      'co the nau mon gi',
      'nau mon gi',
      'lam mon gi',
      'nau gi',
      'lam gi an',
      'che bien mon gi',
      'che bien gi',
      'co the lam mon gi',
      'mon nao',
      'goi y nau an',
      'goi y bua an',
      'goi y bua toi',
      'goi y bua trua',
      'goi y bua sang',
      'cho toi mon an',
      'cho toi goi y mon an',
      'toi nen an gi',
      'toi nen nau gi',
      'co mon gi',
    ];

    const englishKeywords = [
      'what should i eat',
      'what can i eat',
      'what to eat',
      'what should we eat',
      'what can we eat',
      'what to cook',
      'what should i cook',
      'what can i cook',
      'what should we cook',
      'what can we cook',
      'meal suggestion',
      'meal suggestions',
      'food suggestion',
      'food suggestions',
      'suggest a meal',
      'suggest meals',
      'suggest a dish',
      'suggest dishes',
      'dinner ideas',
      'lunch ideas',
      'breakfast ideas',
      'dinner suggestion',
      'lunch suggestion',
      'breakfast suggestion',
      'cooking idea',
      'cooking ideas',
      'recipe idea',
      'recipe ideas',
      'what can i make',
      'what should i make',
      'what can we make',
      'what should we make',
      'make for dinner',
      'make for lunch',
      'make for breakfast',
      'cook for dinner',
      'cook for lunch',
      'cook for breakfast',
      'give me a meal idea',
      'give me meal ideas',
      'give me a meal suggestion',
      'give me meal suggestions',
      'give me a food idea',
      'give me food ideas',
      'give me a dish idea',
      'give me dish ideas',
      'give me a recipe idea',
      'give me recipe ideas',
      'meal idea',
      'meal ideas',
      'food idea',
      'food ideas',
      'dish idea',
      'dish ideas',
      'suggest something to eat',
      'suggest something to cook',
      'suggest something for dinner',
      'suggest something for lunch',
      'suggest something for breakfast',
      'what can i cook with',
      'what should i cook with',
      'what can i make with',
      'what should i make with',
      'what can we cook with',
      'what can we make with',
    ];

    for (final keyword in [...vietnameseKeywords, ...englishKeywords]) {
      if (text.contains(keyword)) return true;
    }

    final hasVietnameseCookingWord = [
      'nau',
      'mon an',
      'bua an',
      'che bien',
      'xao',
      'luoc',
      'canh',
      'mon',
      'an gi',
      'goi y',
    ].any(text.contains);

    final hasEnglishCookingWord = [
      'cook',
      'cooking',
      'meal',
      'dish',
      'recipe',
      'dinner',
      'lunch',
      'breakfast',
      'eat',
      'make',
      'suggest',
    ].any(text.contains);

    final hasQuestionForm = text.contains('?') ||
        text.startsWith('what ') ||
        text.startsWith('how ') ||
        text.startsWith('give me ') ||
        text.startsWith('suggest ') ||
        text.startsWith('can i ') ||
        text.startsWith('should i ');

    return hasQuestionForm &&
        (hasVietnameseCookingWord || hasEnglishCookingWord);
  }

  List<Map<String, dynamic>> _getAvailableProducts(
    Map<String, dynamic> context,
  ) {
    final rawProducts = context['products'];
    if (rawProducts is! List) return [];

    return rawProducts
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .where(_isAvailable)
        .toList();
  }

  bool _isAvailable(Map<String, dynamic> product) {
    final isActive = product['is_active'];
    if (isActive == false || isActive == 0) return false;
    return _toDouble(product['stock']) > 0;
  }

  List<Map<String, dynamic>> _findRelevantProducts(
    String question,
    List<Map<String, dynamic>> products,
  ) {
    final normalizedQuestion = _normalize(question);
    final matches = <Map<String, dynamic>>[];

    for (final product in products) {
      final name = _normalize(product['name']?.toString() ?? '');
      final nameEn = _normalize(product['name_en']?.toString() ?? '');

      if (name.isNotEmpty && normalizedQuestion.contains(name)) {
        matches.add(product);
        continue;
      }
      if (nameEn.isNotEmpty && normalizedQuestion.contains(nameEn)) {
        matches.add(product);
      }
    }

    return matches;
  }

  String _buildAnswer({
    required List<Map<String, dynamic>> products,
    required bool isVietnamese,
    required bool hasSpecificProducts,
  }) {
    final vegetables = _findByCategories(products, ['vegetables']);
    final fruits = _findByCategories(products, ['fruits']);
    final grains = _findByCategories(products, ['grains']);
    final herbs = _findByCategories(products, ['herbs']);

    final buffer = StringBuffer();

    // Câu hỏi nhắc tới sản phẩm cụ thể: liệt kê + cách chế biến gợi ý
    if (hasSpecificProducts) {
      buffer.writeln(
        isVietnamese
            ? '🍽️ Với sản phẩm bạn nhắc tới:'
            : '🍽️ With the products you mentioned:',
      );
      buffer.writeln();

      for (final p in products.take(4)) {
        final hint = _cookingHint(p, isVietnamese);
        buffer.write('• ${_productName(p)} (${_priceText(p)})');
        if (hint != null) buffer.write(': $hint');
        buffer.writeln();
      }
    }

    // Các combo gợi ý
    final suggestions = <String>[];

    if (grains.isNotEmpty && vegetables.isNotEmpty) {
      suggestions.add(
        '🍚 ${_productName(grains.first)} + ${_productName(vegetables.first)}',
      );
    }
    if (vegetables.length >= 2) {
      suggestions.add(
        '🥗 ${_productName(vegetables[0])} + ${_productName(vegetables[1])}',
      );
    }
    if (vegetables.isNotEmpty && herbs.isNotEmpty) {
      suggestions.add(
        '🌿 ${_productName(vegetables.first)} + ${_productName(herbs.first)}',
      );
    }
    if (fruits.length >= 2) {
      suggestions.add(
        '🍎 ${_productName(fruits[0])} + ${_productName(fruits[1])}',
      );
    }

    if (suggestions.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(
        isVietnamese
            ? (hasSpecificProducts
                ? '👉 Có thể kết hợp:'
                : '🍽️ Một số gợi ý cho hôm nay:')
            : (hasSpecificProducts
                ? '👉 You can combine:'
                : '🍽️ Some ideas for today:'),
      );
      if (!hasSpecificProducts) buffer.writeln();
      buffer.write(suggestions.take(4).join('\n'));
    }

    final result = buffer.toString().trim();
    if (result.isNotEmpty) return result;

    // Không ghép được combo nào
    final product = products.first;
    return isVietnamese
        ? '🍽️ Bạn có thể thử ${_productName(product)} hôm nay '
            '(${_priceText(product)}). Sản phẩm này hiện đang có sẵn.'
        : '🍽️ You could try ${_productName(product)} today '
            '(${_priceText(product)}). This product is currently available.';
  }

  String? _cookingHint(Map<String, dynamic> product, bool isVietnamese) {
    final category = product['category_id']?.toString().toLowerCase().trim();

    switch (category) {
      case 'vegetables':
        return isVietnamese
            ? 'xào tỏi, luộc hoặc nấu canh'
            : 'stir-fry with garlic, boil or make soup';
      case 'grains':
        return isVietnamese ? 'nấu cơm hoặc cháo' : 'cook as rice or porridge';
      case 'fruits':
        return isVietnamese
            ? 'ăn tráng miệng hoặc ép nước'
            : 'eat fresh or make juice';
      case 'herbs':
        return isVietnamese
            ? 'dùng làm gia vị hoặc ăn kèm'
            : 'use as seasoning or garnish';
      case 'legumes':
        return isVietnamese
            ? 'nấu chè, hầm hoặc nấu canh'
            : 'stew or make soup';
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> _findByCategories(
    List<Map<String, dynamic>> products,
    List<String> categoryIds,
  ) {
    return products.where((product) {
      final categoryId =
          product['category_id']?.toString().toLowerCase().trim();
      return categoryId != null && categoryIds.contains(categoryId);
    }).toList();
  }

  String _productName(Map<String, dynamic> product) {
    final name = product['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;

    final englishName = product['name_en']?.toString().trim();
    if (englishName != null && englishName.isNotEmpty) return englishName;

    return 'product';
  }

  String _priceText(Map<String, dynamic> product) {
    final price = _toDouble(product['price']);
    final unit = product['unit']?.toString().trim() ?? '';
    final formatted = price
        .toInt()
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return unit.isNotEmpty ? '\$$formatted/$unit' : '\$$formatted';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _normalize(String value) {
    var text = value.toLowerCase().trim();

    const groups = {
      'a': 'àáạảãăằắặẳẵâầấậẩẫ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };

    groups.forEach((base, chars) {
      for (final ch in chars.split('')) {
        text = text.replaceAll(ch, base);
      }
    });

    return text
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
