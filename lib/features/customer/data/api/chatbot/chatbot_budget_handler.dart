import 'dart:math' as math;

class ChatbotBudgetHandler {
  static const int _maxProductsForSearch = 18;
  static const int _maxResults = 5;

  String? answer(
    String question,
    Map<String, dynamic> context, {
    bool isVietnamese = false,
  }) {
    final budget = _extractBudget(question);

    if (budget == null || budget <= 0) {
      return null;
    }

    if (!_isBudgetQuestion(question)) {
      return null;
    }

    final products = _extractAvailableProducts(context);

    if (products.isEmpty) {
      return isVietnamese
          ? 'Hiện chưa có sản phẩm còn hàng để gợi ý trong ngân sách của bạn.'
          : 'There are currently no in-stock products available for your budget.';
    }

// ----------------------------------------------------------
// 1. HỎI SỐ LƯỢNG CỦA MỘT SẢN PHẨM
// ----------------------------------------------------------

    final quantityAnswer = _answerQuantityQuestion(
      question,
      products,
      budget,
      isVietnamese,
    );

    if (quantityAnswer != null) {
      return quantityAnswer;
    }

// ----------------------------------------------------------
// 2. HỎI CÓ THỂ MUA NHỮNG GÌ TRONG NGÂN SÁCH
// ----------------------------------------------------------

    final results = _findBestCombinations(
      products,
      budget,
    );

    if (results.isEmpty) {
      return isVietnamese
          ? 'Hiện chưa có tổ hợp sản phẩm nào phù hợp với ngân sách ${_formatMoney(budget)}.'
          : 'There are currently no product combinations within your budget of ${_formatMoney(budget)}.';
    }

    return _formatResults(
      results,
      budget,
      isVietnamese,
    );
  }

// ============================================================
// BALANCED BASKET
//
// Mỗi danh mục cố gắng lấy 1 món.
// Sau đó dùng phần tiền còn lại để bổ sung món rẻ.
//
// Phần này dùng TOÀN BỘ products, không giới hạn 18 món.
// ============================================================

  _BudgetCombination? _balancedBasket(
    List<Map<String, dynamic>> products,
    int budget,
  ) {
    int priceOf(Map<String, dynamic> product) {
      return (_toDouble(product['price']) ?? 0).round();
    }

    final byCategory = <String, List<Map<String, dynamic>>>{};

    for (final product in products) {
      final categoryId = '${product['category_id'] ?? ''}'.trim();

      if (categoryId.isEmpty) {
        continue;
      }

      byCategory.putIfAbsent(categoryId, () => []).add(product);
    }

    if (byCategory.isEmpty) {
      return null;
    }

    final picked = <Map<String, dynamic>>[];

    var total = 0;

// Giới hạn tối đa 6 sản phẩm trong một giỏ.
    const maxBasketProducts = 6;

// Chia ngân sách tương đối đều cho các danh mục.
    final share = budget ~/ byCategory.length;

// ----------------------------------------------------------
// 1. Mỗi danh mục lấy 1 món phù hợp.
// ----------------------------------------------------------

    for (final list in byCategory.values) {
      if (picked.length >= maxBasketProducts) {
        break;
      }

      final fit = list.where(
        (product) {
          final price = priceOf(product);

          return price > 0 && price <= share && total + price <= budget;
        },
      ).toList()
        ..sort(
          (a, b) => priceOf(b).compareTo(
            priceOf(a),
          ),
        );

      if (fit.isNotEmpty) {
        picked.add(fit.first);
        total += priceOf(fit.first);
      }
    }

// ----------------------------------------------------------
// 2. Dùng phần tiền còn lại để thêm sản phẩm rẻ.
// ----------------------------------------------------------

    final rest = products
        .where(
          (product) => !picked.contains(product),
        )
        .toList()
      ..sort(
        (a, b) => priceOf(a).compareTo(
          priceOf(b),
        ),
      );

    for (final product in rest) {
      if (picked.length >= maxBasketProducts) {
        break;
      }

      final price = priceOf(product);

      if (price > 0 && total + price <= budget) {
        picked.add(product);
        total += price;
      }
    }

    if (picked.isEmpty) {
      return null;
    }

    return _BudgetCombination(
      products: picked,
      total: total,
    );
  }

// ============================================================
// BUDGET INTENT
// ============================================================

  bool _isBudgetQuestion(String question) {
    final q = _normalize(question);

    const vietnamesePatterns = [
      'toi co',
      'minh co',
      'co',
      'ngan sach',
      'ngan sach cua toi',
      'voi',
      'mua duoc gi',
      'mua gi',
      'mua duoc nhung gi',
      'mua duoc nhung san pham gi',
      'co the mua gi',
      'nen mua gi',
      'mua gi voi',
      'mua duoc gi voi',
      'mua duoc bao nhieu',
      'mua duoc may',
      'co the mua bao nhieu',
      'co the mua may',
    ];

    const englishPatterns = [
      'what can i buy',
      'what can i get',
      'what should i buy',
      'what products can i buy',
      'what can i buy with',
      'what can i get with',
      'under my budget',
      'within my budget',
      'budget',
      'with my budget',
      'how much can i buy',
      'how much can i get',
      'how many can i buy',
      'how many can i get',
      'how much can i purchase',
      'how many can i purchase',
      'how much of this can i buy',
      'how many of this can i buy',
      'what quantity can i buy',
      'what quantity can i get',
    ];

    final hasVietnamese = vietnamesePatterns.any(q.contains);

    final hasEnglish = englishPatterns.any(q.contains);

// ----------------------------------------------------------
// English quantity/budget question with product name.
//
// Ví dụ:
// How much ST25 Rice can I buy with $100,000?
// How many Organic Cherry Tomatoes can I buy with $200,000?
// ----------------------------------------------------------

    final hasHowMuch = q.contains('how much');

    final hasHowMany = q.contains('how many');

    final hasCanIBuy = q.contains('can i buy') ||
        q.contains('can i get') ||
        q.contains('can i purchase');

    final hasQuantityIntent = (hasHowMuch || hasHowMany) && hasCanIBuy;
    final hasDollarPurchaseIntent = question.contains(r'$') &&
        _containsAny(q, [
          'buy',
          'get',
          'purchase',
          'mua',
          'san pham',
          'what',
          'gi',
        ]);

// ----------------------------------------------------------
// Money
// ----------------------------------------------------------

    final hasMoney = RegExp(r'\d').hasMatch(q) &&
        (question.contains(r'$') ||
            RegExp(r'\d+(?:[.,]\d+)?\s*k\b').hasMatch(q) ||
            q.contains('000') ||
            q.contains('d') ||
            q.contains('dong') ||
            q.contains('vnd') ||
            q.contains('budget'));

    return (hasVietnamese ||
            hasEnglish ||
            hasQuantityIntent ||
            hasDollarPurchaseIntent) &&
        hasMoney;
  }

  bool _containsAny(String text, List<String> phrases) {
    return phrases.any(text.contains);
  }

// ============================================================
// EXTRACT BUDGET
// ============================================================

  int? _extractBudget(String question) {
    final q = _normalize(question);

// ----------------------------------------------------------
// Currency amount using app shorthand, e.g. $100 / 100$ or $100,000.
// ----------------------------------------------------------

    final dollarMatch = RegExp(
      r'(?:\$\s*(\d[\d,]*(?:\.\d+)?)|(\d[\d,]*(?:\.\d+)?)\s*\$)',
    ).firstMatch(question.toLowerCase());

    if (dollarMatch != null) {
      final amount = double.tryParse(
        (dollarMatch.group(1) ?? dollarMatch.group(2)!).replaceAll(',', ''),
      );
      if (amount != null) {
        // Budget inputs and product prices use the same VND-thousands
        // shorthand as "100k" throughout the chatbot.
        return (amount < 1000 ? amount * 1000 : amount).round();
      }
    }

// ----------------------------------------------------------
// Ví dụ:
// $100,000 / $100 / 100$
// $50,500 / $50.5
// Backward compatible: 100k, 50.5k, 100,5k
// ----------------------------------------------------------

    final kMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*k\b',
      caseSensitive: false,
    ).firstMatch(q);

    if (kMatch != null) {
      final raw = kMatch.group(1)!;

      final number = double.tryParse(
        raw.replaceAll(',', '.'),
      );

      if (number != null) {
        return (number * 1000).round();
      }
    }

// ----------------------------------------------------------
// Ví dụ:
// 100000
// 100.000
// 100,000
// 100000đ
// 100.000đ
// 100000 VND
// ----------------------------------------------------------

    final vndMatch = RegExp(
      r'(\d[\d.,]*)\s*(?:d|dong|vnd)?',
      caseSensitive: false,
    ).firstMatch(q);

    if (vndMatch != null) {
      var raw = vndMatch.group(1)!;

      raw = raw.replaceAll('.', '').replaceAll(',', '');

      final value = int.tryParse(raw);

      if (value != null && value >= 1000) {
        return value;
      }
    }

    return null;
  }

// ============================================================
// EXTRACT AVAILABLE PRODUCTS
// ============================================================

  List<Map<String, dynamic>> _extractAvailableProducts(
    Map<String, dynamic> context,
  ) {
    final rawProducts = context['products'];

    if (rawProducts is! List) {
      return [];
    }

    final products = <Map<String, dynamic>>[];

    for (final item in rawProducts) {
      if (item is! Map) {
        continue;
      }

      final product = Map<String, dynamic>.from(item);

      final isActive = product['is_active'];

      if (isActive == false || isActive == 0 || isActive == '0') {
        continue;
      }

      final stock = _toDouble(product['stock']);

      final price = _toDouble(product['price']);

      if (stock == null || stock <= 0 || price == null || price <= 0) {
        continue;
      }

      products.add(product);
    }

// Giá thấp trước.
    products.sort(
      (a, b) {
        final priceA = _toDouble(a['price']) ?? double.infinity;

        final priceB = _toDouble(b['price']) ?? double.infinity;

        return priceA.compareTo(priceB);
      },
    );

    return products;
  }

// ============================================================
// QUANTITY QUESTION
// ============================================================

  String? _answerQuantityQuestion(
    String question,
    List<Map<String, dynamic>> products,
    int budget,
    bool isVietnamese,
  ) {
    if (!_isQuantityQuestion(question)) {
      return null;
    }

    final normalizedQuestion = _normalize(question);

    final product = _findMentionedProduct(
      normalizedQuestion,
      products,
    );

    if (product == null) {
      return null;
    }

    final price = _toDouble(product['price']);

    if (price == null || price <= 0) {
      return null;
    }

    final stock = _toDouble(product['stock']) ?? 0;

    if (stock <= 0) {
      final name = _productName(
        product,
        isVietnamese,
      );

      return isVietnamese
          ? '$name hiện đã hết hàng.'
          : '$name is currently out of stock.';
    }

    final quantityByBudget = (budget / price).floor();

    final quantityByStock = stock.floor();

    final quantity = math.min(
      quantityByBudget,
      quantityByStock,
    );

    final name = _productName(
      product,
      isVietnamese,
    );

    final unit = _stringValue(
      product['unit'],
    );

    final priceInt = price.round();

    if (quantity <= 0) {
      return isVietnamese
          ? 'Với ngân sách ${_formatMoney(budget)}, bạn chưa đủ để mua 1 $unit $name. Giá hiện tại là ${_formatMoney(priceInt)}/${unit.isNotEmpty ? unit : 'đơn vị'}.'
          : 'With a budget of ${_formatMoney(budget)}, you cannot afford 1 $unit of $name. The current price is ${_formatMoney(priceInt)}/${unit.isNotEmpty ? unit : 'unit'}.';
    }

    final total = (quantity * price).round();

    final remaining = budget - total;

    if (isVietnamese) {
      final buffer = StringBuffer();

      buffer.writeln(
        'Với ngân sách ${_formatMoney(budget)}, '
        'bạn có thể mua tối đa $quantity '
        '${unit.isNotEmpty ? unit : 'đơn vị'} $name.',
      );

      buffer.writeln();

      buffer.writeln(
        '• Giá: ${_formatMoney(priceInt)}'
        '${unit.isNotEmpty ? '/$unit' : ''}',
      );

      buffer.writeln(
        '• Số lượng: $quantity'
        '${unit.isNotEmpty ? ' $unit' : ''}',
      );

      buffer.writeln(
        '• Tổng tiền: ${_formatMoney(total)}',
      );

      buffer.writeln(
        '• Còn lại: ${_formatMoney(remaining)}',
      );

      if (quantityByBudget > quantity) {
        buffer.writeln();

        buffer.write(
          'Số lượng được giới hạn bởi tồn kho hiện tại '
          '(${stock.floor()} ${unit.isNotEmpty ? unit : 'đơn vị'}).',
        );
      }

      return buffer.toString().trim();
    }

    final buffer = StringBuffer();

    buffer.writeln(
      'With a budget of ${_formatMoney(budget)}, '
      'you can buy up to $quantity '
      '${unit.isNotEmpty ? unit : 'unit'} of $name.',
    );

    buffer.writeln();

    buffer.writeln(
      '• Price: ${_formatMoney(priceInt)}'
      '${unit.isNotEmpty ? '/$unit' : ''}',
    );

    buffer.writeln(
      '• Quantity: $quantity'
      '${unit.isNotEmpty ? ' $unit' : ''}',
    );

    buffer.writeln(
      '• Total: ${_formatMoney(total)}',
    );

    buffer.writeln(
      '• Remaining: ${_formatMoney(remaining)}',
    );

    if (quantityByBudget > quantity) {
      buffer.writeln();

      buffer.write(
        'The quantity is limited by the current stock '
        '(${stock.floor()} ${unit.isNotEmpty ? unit : 'units'}).',
      );
    }

    return buffer.toString().trim();
  }

// ============================================================
// QUANTITY INTENT
// ============================================================

  bool _isQuantityQuestion(String question) {
    final q = _normalize(question);

    const vietnamesePatterns = [
      'mua duoc bao nhieu',
      'mua duoc may',
      'co the mua bao nhieu',
      'co the mua may',
      'mua duoc bao nhieu voi',
      'mua duoc may voi',
      'mua duoc bao nhieu kg',
      'mua duoc may kg',
      'mua duoc bao nhieu gam',
      'mua duoc bao nhieu bo',
      'mua duoc may bo',
      'mua duoc bao nhieu nai',
      'mua duoc may nai',
      'mua duoc bao nhieu san pham',
      'mua duoc bao nhieu don vi',
    ];

    const englishPatterns = [
      'how much can i buy',
      'how much can i get',
      'how many can i buy',
      'how many can i get',
      'how much can i purchase',
      'how many can i purchase',
      'how much of this can i buy',
      'how many of this can i buy',
      'what quantity can i buy',
      'what quantity can i get',
    ];

    if (vietnamesePatterns.any(q.contains)) {
      return true;
    }

    if (englishPatterns.any(q.contains)) {
      return true;
    }

    final hasHowMuch = q.contains('how much');

    final hasHowMany = q.contains('how many');

    final hasCanIBuy = q.contains('can i buy') ||
        q.contains('can i get') ||
        q.contains('can i purchase');

    if ((hasHowMuch || hasHowMany) && hasCanIBuy) {
      return true;
    }

    return false;
  }

// ============================================================
// FIND MENTIONED PRODUCT
//
// Ưu tiên:
// 1. Full product name
// 2. Tất cả từ quan trọng
// 3. Token đặc trưng
// 4. Tên cụ thể hơn
//
// Hỗ trợ tiếng Việt có dấu/không dấu và English.
// ============================================================

  Map<String, dynamic>? _findMentionedProduct(
    String normalizedQuestion,
    List<Map<String, dynamic>> products,
  ) {
    Map<String, dynamic>? bestProduct;

    var bestScore = 0;

    const ignoredWords = {
      'rau',
      'qua',
      'trai',
      'cay',
      'gao',
      'hat',
      'san',
      'pham',
    };

    for (final product in products) {
      final nameVi = _normalize(
        _stringValue(product['name']),
      );

      final nameEn = _normalize(
        _stringValue(product['name_en']),
      );

      if (nameVi.isEmpty && nameEn.isEmpty) {
        continue;
      }

      var score = 0;

// --------------------------------------------------------
// 1. FULL PRODUCT NAME
// --------------------------------------------------------

      if (nameVi.isNotEmpty && normalizedQuestion.contains(nameVi)) {
        score = math.max(score, 1000);
      }

      if (nameEn.isNotEmpty && normalizedQuestion.contains(nameEn)) {
        score = math.max(score, 1000);
      }

      if (score >= 1000) {
        if (score > bestScore) {
          bestScore = score;
          bestProduct = product;
        }

        continue;
      }

// --------------------------------------------------------
// 2. MATCH TỪ QUAN TRỌNG
// --------------------------------------------------------

      final allWords = <String>{
        ...nameVi.split(' '),
        ...nameEn.split(' '),
      };

      final words = allWords
          .map(_normalize)
          .where(
            (word) => word.length >= 2 && !ignoredWords.contains(word),
          )
          .toSet();

      if (words.isEmpty) {
        continue;
      }

      var matchedWords = 0;

      for (final word in words) {
        if (normalizedQuestion.contains(word)) {
          matchedWords++;
        }
      }

      if (matchedWords == 0) {
        continue;
      }

// Mỗi từ khớp.
      score += matchedWords * 100;

// Khớp toàn bộ từ quan trọng.
      if (matchedWords == words.length) {
        score += 300;
      }

// --------------------------------------------------------
// 3. TOKEN ĐẶC TRƯNG
// --------------------------------------------------------

      final questionWords = normalizedQuestion.split(' ');

      for (final word in words) {
        if (questionWords.contains(word)) {
          score += 30;
        }
      }

// --------------------------------------------------------
// 4. ƯU TIÊN TÊN CỤ THỂ HƠN
// --------------------------------------------------------

      final longestName = nameVi.length >= nameEn.length ? nameVi : nameEn;

      if (longestName.isNotEmpty) {
        final nameWordCount = longestName.split(' ').length;

        score += math.min(
          nameWordCount * 10,
          50,
        );
      }

// --------------------------------------------------------
// 5. CHỌN BEST MATCH
// --------------------------------------------------------

      if (score > bestScore) {
        bestScore = score;
        bestProduct = product;
      }
    }

    return bestProduct;
  }

// ============================================================
// FIND BEST COMBINATIONS
//
// Đệ quy chỉ chạy trên 18 sản phẩm rẻ nhất.
//
// Balanced basket KHÔNG nằm trong pool này.
// ============================================================

  List<_BudgetCombination> _findBestCombinations(
    List<Map<String, dynamic>> products,
    int budget,
  ) {
// ----------------------------------------------------------
// Chỉ lấy 18 sản phẩm rẻ nhất để tránh recursion quá lớn.
//
// products đã được sort theo giá tăng dần trong
// _extractAvailableProducts().
// ----------------------------------------------------------

    final pool = products.take(_maxProductsForSearch).toList();

    final results = <_BudgetCombination>[];

    void search(
      int index,
      List<Map<String, dynamic>> selected,
      int total,
    ) {
      if (selected.isNotEmpty && total <= budget) {
        results.add(
          _BudgetCombination(
            products: List<Map<String, dynamic>>.from(
              selected,
            ),
            total: total,
          ),
        );
      }

// Không tạo tổ hợp quá 6 sản phẩm.
      if (selected.length >= 6) {
        return;
      }

      for (var i = index; i < pool.length; i++) {
        final price = (_toDouble(pool[i]['price']) ?? 0).round();

        if (price <= 0) {
          continue;
        }

        if (total + price > budget) {
          continue;
        }

        selected.add(pool[i]);

        search(
          i + 1,
          selected,
          total + price,
        );

        selected.removeLast();
      }
    }

    search(
      0,
      [],
      0,
    );

// ----------------------------------------------------------
// Loại duplicate.
// ----------------------------------------------------------

    final unique = <String, _BudgetCombination>{};

    for (final result in results) {
      unique[_comboKey(result)] = result;
    }

// ----------------------------------------------------------
// Sort theo score cũ.
// ----------------------------------------------------------

    final sorted = unique.values.toList()
      ..sort(
        (a, b) => _scoreCombination(
          b,
          budget,
        ).compareTo(
          _scoreCombination(
            a,
            budget,
          ),
        ),
      );

// ----------------------------------------------------------
// Balanced basket dùng TOÀN BỘ products.
// Luôn đứng đầu nếu tạo được.
// ----------------------------------------------------------

    final basket = _balancedBasket(
      products,
      budget,
    );

    if (basket == null) {
      return sorted.take(_maxResults).toList();
    }

    final basketKey = _comboKey(basket);

    return [
      basket,
      ...sorted
          .where(
            (combination) => _comboKey(combination) != basketKey,
          )
          .take(
            math.max(
              0,
              _maxResults - 1,
            ),
          ),
    ];
  }

// ============================================================
// COMBINATION KEY
// ============================================================

  String _comboKey(
    _BudgetCombination combination,
  ) {
    final ids = combination.products
        .map(
          (product) => '${product['id']}',
        )
        .toList()
      ..sort();

    return ids.join('|');
  }

// ============================================================
// SCORE COMBINATION
// ============================================================

  double _scoreCombination(
    _BudgetCombination combination,
    int budget,
  ) {
    final utilization = combination.total / budget;

    final productCount = combination.products.length;

    final categoryIds = combination.products
        .map(
          (product) => '${product['category_id']}',
        )
        .where(
          (id) => id.isNotEmpty,
        )
        .toSet();

    final categoryBonus = categoryIds.length * 0.04;

    final countBonus = math.min(
          productCount,
          5,
        ) *
        0.03;

    final budgetScore = utilization.clamp(0.0, 1.0);

    return budgetScore + categoryBonus + countBonus;
  }

// ============================================================
// FORMAT COMBINATION RESULTS
// ============================================================

  String _formatResults(
    List<_BudgetCombination> results,
    int budget,
    bool isVietnamese,
  ) {
    final buffer = StringBuffer();

    if (isVietnamese) {
      buffer.writeln(
        'Với ngân sách ${_formatMoney(budget)}, '
        'bạn có thể tham khảo:',
      );

      buffer.writeln();

      for (var i = 0; i < results.length; i++) {
        final result = results[i];

// ------------------------------------------------------
// Giỏ cân đối
// ------------------------------------------------------

        if (i == 0) {
          buffer.writeln(
            '🧺 Giỏ cân đối',
          );

          buffer.writeln(
            '   Gợi ý gồm nhiều nhóm sản phẩm khác nhau.',
          );
        } else {
          buffer.writeln(
            '${i + 1}. Tổng ${_formatMoney(result.total)}',
          );
        }

// Nếu là giỏ cân đối thì vẫn hiển thị tổng tiền.
        if (i == 0) {
          buffer.writeln(
            '   Tổng ${_formatMoney(result.total)}',
          );
        }

        for (final product in result.products) {
          final name = _productName(
            product,
            isVietnamese,
          );

          final price = (_toDouble(
                    product['price'],
                  ) ??
                  0)
              .round();

          final unit = _stringValue(
            product['unit'],
          );

          buffer.writeln(
            '   • $name — '
            '${_formatMoney(price)}'
            '${unit.isNotEmpty ? '/$unit' : ''}',
          );
        }

        buffer.writeln(
          '   Còn lại: '
          '${_formatMoney(
            budget - result.total,
          )}',
        );

        if (i != results.length - 1) {
          buffer.writeln();
        }
      }
    } else {
      buffer.writeln(
        'With a budget of '
        '${_formatMoney(budget)}, '
        'you can consider:',
      );

      buffer.writeln();

      for (var i = 0; i < results.length; i++) {
        final result = results[i];

// ------------------------------------------------------
// Balanced basket
// ------------------------------------------------------

        if (i == 0) {
          buffer.writeln(
            '🧺 Balanced basket',
          );

          buffer.writeln(
            '   A suggestion with products from different categories.',
          );
        } else {
          buffer.writeln(
            '${i + 1}. Total '
            '${_formatMoney(result.total)}',
          );
        }

        if (i == 0) {
          buffer.writeln(
            '   Total '
            '${_formatMoney(result.total)}',
          );
        }

        for (final product in result.products) {
          final name = _productName(
            product,
            isVietnamese,
          );

          final price = (_toDouble(
                    product['price'],
                  ) ??
                  0)
              .round();

          final unit = _stringValue(
            product['unit'],
          );

          buffer.writeln(
            '   • $name — '
            '${_formatMoney(price)}'
            '${unit.isNotEmpty ? '/$unit' : ''}',
          );
        }

        buffer.writeln(
          '   Remaining: '
          '${_formatMoney(
            budget - result.total,
          )}',
        );

        if (i != results.length - 1) {
          buffer.writeln();
        }
      }
    }

    return buffer.toString().trim();
  }

// ============================================================
// PRODUCT NAME
// ============================================================

  String _productName(
    Map<String, dynamic> product,
    bool isVietnamese,
  ) {
    final vi = _stringValue(
      product['name'],
    );

    final en = _stringValue(
      product['name_en'],
    );

    if (isVietnamese) {
      return vi.isNotEmpty ? vi : en;
    }

    return en.isNotEmpty ? en : vi;
  }

// ============================================================
// MONEY FORMAT
// ============================================================

  String _formatMoney(int value) {
    final text = value.toString();

    final formatted = text.replaceAllMapped(
      RegExp(
        r'(\d)(?=(\d{3})+(?!\d))',
      ),
      (match) => '${match.group(1)},',
    );

    return '\$$formatted';
  }

// ============================================================
// PARSE DOUBLE
// ============================================================

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

// ============================================================
// STRING
// ============================================================

  String _stringValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

// ============================================================
// NORMALIZE VIETNAMESE / ENGLISH
// ============================================================

  String _normalize(
    String value,
  ) {
    var result = value.toLowerCase().trim();

    const replacements = {
      'á': 'a',
      'à': 'a',
      'ả': 'a',
      'ã': 'a',
      'ạ': 'a',
      'ă': 'a',
      'ắ': 'a',
      'ằ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'ặ': 'a',
      'â': 'a',
      'ấ': 'a',
      'ầ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ậ': 'a',
      'đ': 'd',
      'é': 'e',
      'è': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ẹ': 'e',
      'ê': 'e',
      'ế': 'e',
      'ề': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ệ': 'e',
      'í': 'i',
      'ì': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ị': 'i',
      'ó': 'o',
      'ò': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ọ': 'o',
      'ô': 'o',
      'ố': 'o',
      'ồ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ộ': 'o',
      'ơ': 'o',
      'ớ': 'o',
      'ờ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ợ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ụ': 'u',
      'ư': 'u',
      'ứ': 'u',
      'ừ': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ự': 'u',
      'ý': 'y',
      'ỳ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'ỵ': 'y',
    };

    replacements.forEach(
      (key, replacement) {
        result = result.replaceAll(
          key,
          replacement,
        );
      },
    );

    return result
        .replaceAll(
          RegExp(r'[^\w\s.]'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }
}

// ============================================================
// BUDGET COMBINATION MODEL
// ============================================================

class _BudgetCombination {
  const _BudgetCombination({
    required this.products,
    required this.total,
  });

  final List<Map<String, dynamic>> products;
  final int total;
}
