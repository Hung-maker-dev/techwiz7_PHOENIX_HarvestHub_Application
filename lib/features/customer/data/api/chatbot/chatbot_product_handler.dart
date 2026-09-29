class ChatbotProductHandler {
  List<Map<String, dynamic>> findRelevantProducts(
    String question,
    Map<String, dynamic> context,
  ) {
    final products = _products(context);
    final categories = _categories(context);

    final matched = findProducts(
      question,
      products,
    );

    if (matched.isNotEmpty) {
      return matched;
    }

    return findProductsByCategoryQuestion(
      question,
      products,
      categories,
    );
  }

  String? answer(
    String question,
    Map<String, dynamic> context, {
    bool? useVietnamese,
  }) {
    final products = _products(context);
    final categories = _categories(context);

    final q = _normalize(question);
    final isVietnamese = useVietnamese ?? _isVietnamese(question);

// 1. OUT OF STOCK LIST

    if (_isOutOfStockListQuestion(q)) {
      final outOfStockProducts = products.where(_isOutOfStockProduct).toList();

      if (outOfStockProducts.isEmpty) {
        return isVietnamese
            ? 'Hiện không có sản phẩm nào hết hàng.'
            : 'No products are currently out of stock.';
      }

      return _formatProductNames(
        outOfStockProducts,
        isVietnamese: isVietnamese,
      );
    }

// 2. IN STOCK LIST

    if (_isInStockListQuestion(q)) {
      final inStockProducts = products.where(_isAvailableProduct).toList();

      if (inStockProducts.isEmpty) {
        return isVietnamese
            ? 'Hiện không có sản phẩm nào còn hàng.'
            : 'No products are currently in stock.';
      }

      return _formatProductNames(
        inStockProducts,
        isVietnamese: isVietnamese,
      );
    }

// 3. GENERAL STOCK INFORMATION

    if (_isGeneralStockQuestion(q)) {
      final activeProducts = products.where(_isActiveProduct).toList();

      if (activeProducts.isEmpty) {
        return isVietnamese
            ? 'Hiện không có sản phẩm nào.'
            : 'No products are currently available.';
      }

      return _formatStocks(
        activeProducts,
        isVietnamese: isVietnamese,
      );
    }

// 4. CATEGORY LIST

    if (_isCategoryListQuestion(q)) {
      if (categories.isEmpty) {
        return isVietnamese
            ? 'Hiện chưa có danh mục nào.'
            : 'No categories are currently available.';
      }

      final names = categories
          .map(
            (category) => _categoryDisplayName(
              category,
              isVietnamese: isVietnamese,
            ),
          )
          .where((name) => name.isNotEmpty)
          .toList();

      if (names.isEmpty) {
        return isVietnamese
            ? 'Hiện chưa có danh mục nào.'
            : 'No categories are currently available.';
      }

      final title =
          isVietnamese ? 'HarvestHub hiện có:' : 'HarvestHub currently has:';

      return '$title\n'
          '${names.map((name) => '• $name').join('\n')}';
    }

// 5. GENERAL PRODUCT LIST

    if (_isAllProductsQuestion(q)) {
      final activeProducts = products.where(_isActiveProduct).toList();

      return _formatProductNames(
        activeProducts,
        isVietnamese: isVietnamese,
      );
    }

// 6. SPECIFIC PRODUCT

    final matchedProducts = findProducts(
      question,
      products,
    );

    if (matchedProducts.isNotEmpty) {
      final wantsPrice = _wantsPrice(q);
      final wantsStock = _wantsStock(q);
      final wantsDetail = _wantsDetail(q);

      if (wantsDetail) {
        return _formatFullProducts(
          matchedProducts.take(5).toList(),
          isVietnamese: isVietnamese,
        );
      }

      if (wantsPrice && wantsStock) {
        return _formatPriceAndStock(
          matchedProducts.take(5).toList(),
          isVietnamese: isVietnamese,
        );
      }

      if (wantsPrice) {
        return _formatPrices(
          matchedProducts.take(5).toList(),
          isVietnamese: isVietnamese,
        );
      }

      if (wantsStock) {
        return _formatStocks(
          matchedProducts.take(5).toList(),
          isVietnamese: isVietnamese,
        );
      }

      if (_isAvailabilityQuestion(q)) {
        final availableProducts =
            matchedProducts.where(_isAvailableProduct).take(5).toList();

        if (availableProducts.isEmpty) {
          return isVietnamese
              ? 'Sản phẩm này hiện đã hết hàng.'
              : 'This product is currently out of stock.';
        }

        return _formatProductNames(
          availableProducts,
          isVietnamese: isVietnamese,
        );
      }

      return _formatProductNames(
        matchedProducts.take(5).toList(),
        isVietnamese: isVietnamese,
      );
    }

// 7. CATEGORY-SPECIFIC PRODUCTS

    final categoryProducts = findProductsByCategoryQuestion(
      question,
      products,
      categories,
    );

    if (categoryProducts.isNotEmpty) {
      return _answerCategoryQuestion(
        q,
        categoryProducts,
        isVietnamese: isVietnamese,
      );
    }

    return null;
  }

// PRODUCT SEARCH

  List<Map<String, dynamic>> findProducts(
    String question,
    List<Map<String, dynamic>> products,
  ) {
    final q = _normalize(question);

    const stopWords = {
      'a',
      'an',
      'the',
      'is',
      'are',
      'do',
      'does',
      'did',
      'you',
      'have',
      'has',
      'what',
      'which',
      'where',
      'how',
      'much',
      'many',
      'can',
      'i',
      'me',
      'my',
      'please',
      'tell',
      'show',
      'give',
      'want',
      'need',
      'about',
      'price',
      'prices',
      'cost',
      'stock',
      'available',
      'quantity',
      'product',
      'products',
      'item',
      'items',
      'today',
      'now',
      'san',
      'pham',
      'co',
      'nhung',
      'nao',
      'gi',
      'loai',
      'hom',
      'nay',
      'gia',
      'bao',
      'nhieu',
      'tien',
      'con',
      'khong',
      'ton',
      'kho',
      'so',
      'luong',
      'mo',
      'ta',
      'thong',
      'tin',
      'chi',
      'tiet',
      've',
      'la',
      'cua',
      'cho',
      'toi',
      'minh',
      'muon',
      'hoi',
      'ban',
      'giup',
      'xin',
      'dang',
      'hien',
      'tai',
      'duoc',
      'mot',
      'nhat',
      'cac',
      'farm',
      'farmer',
      'farmers',
      'trang',
      'trai',
      'nong',
      'dan',
      'seller',
      'sellers',
      'sell',
      'sells',
      'selling',
    };

    final queryWords = q
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .where((word) => !stopWords.contains(word))
        .toList();

    if (queryWords.isEmpty) {
      return [];
    }

    final results = <_ProductMatch>[];

    for (final product in products) {
      if (!_isActiveProduct(product)) {
        continue;
      }

      final nameVi = _normalize(
        _stringValue(product['name']),
      );

      final nameEn = _normalize(
        _stringValue(product['name_en']),
      );

      final searchable = '$nameVi $nameEn'.trim();

      if (searchable.isEmpty) {
        continue;
      }

      final searchableWords = searchable
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toSet();

      var score = 0;

// Exact full product name.
      if (nameVi.isNotEmpty && q.contains(nameVi)) {
        score += 100;
      }

      if (nameEn.isNotEmpty && q.contains(nameEn)) {
        score += 100;
      }

// Word-level matching.
      for (final word in queryWords) {
        if (searchableWords.contains(word)) {
          score += 10;
          continue;
        }

        if (_pluralMatch(word, searchableWords)) {
          score += 7;
          continue;
        }

// Prefix matching for slightly incomplete typing.
        if (word.length >= 4 &&
            searchableWords.any(
              (candidate) =>
                  candidate.startsWith(word) || word.startsWith(candidate),
            )) {
          score += 4;
        }
      }

      if (score > 0) {
        results.add(
          _ProductMatch(
            product: product,
            score: score,
          ),
        );
      }
    }

    results.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    return results.map((item) => item.product).toList();
  }

  bool _pluralMatch(
    String word,
    Set<String> searchableWords,
  ) {
    if (word.length > 3 && word.endsWith('s')) {
      final singular = word.substring(
        0,
        word.length - 1,
      );

      if (searchableWords.contains(singular)) {
        return true;
      }
    }

    if (word.length > 3 && !word.endsWith('s')) {
      if (searchableWords.contains('${word}s')) {
        return true;
      }

      if (word.endsWith('o') && searchableWords.contains('${word}es')) {
        return true;
      }

      if (word.endsWith('y') &&
          searchableWords.contains(
            '${word.substring(0, word.length - 1)}ies',
          )) {
        return true;
      }
    }

    return false;
  }

// CATEGORY SEARCH

  List<Map<String, dynamic>> findProductsByCategoryQuestion(
    String question,
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> categories,
  ) {
    final q = _normalize(question);

    final category = _findMatchingCategory(
      q,
      categories,
    );

    if (category == null) {
      return [];
    }

    final categoryId = _stringValue(
      category['id'],
    );

    if (categoryId.isEmpty) {
      return [];
    }

    return products.where((product) {
      final productCategoryId = _stringValue(
        product['category_id'],
      );

      return productCategoryId == categoryId && _isAvailableProduct(product);
    }).toList();
  }

  Map<String, dynamic>? findCategoryForQuestion(
    String question,
    List<Map<String, dynamic>> categories,
  ) {
    final normalizedQuestion = _normalize(question);
    final exact = _findExactCategory(normalizedQuestion, categories);
    if (exact != null) return exact;

    final requestedType = _requestedCategoryType(normalizedQuestion);
    if (requestedType != null) {
      for (final category in categories) {
        final names = [
          _normalize(_stringValue(category['name'])),
          _normalize(_stringValue(category['name_en'])),
          _normalize(_stringValue(category['id'])),
        ];
        if (names.any((name) => _categoryTypeMatches(name, requestedType))) {
          return category;
        }
      }
    }

    return null;
  }

  bool isKnownCategoryQuestion(String question) =>
      _requestedCategoryType(_normalize(question)) != null;

  Map<String, dynamic>? _findExactCategory(
    String question,
    List<Map<String, dynamic>> categories,
  ) {
    for (final category in categories) {
      final candidates = [
        _normalize(_stringValue(category['name'])),
        _normalize(_stringValue(category['name_en'])),
        _normalize(_stringValue(category['id'])),
      ];
      if (candidates.any(
        (candidate) =>
            candidate.isNotEmpty && _containsWholePhrase(question, candidate),
      )) {
        return category;
      }
    }
    return null;
  }

  String? _requestedCategoryType(String question) {
    if (_containsAny(question, ['trai cay', 'hoa qua', 'fruit', 'fruits'])) {
      return 'fruit';
    }
    if (_containsAny(
      question,
      ['rau cu', 'rau', 'vegetable', 'vegetables', 'veggie', 'veggies'],
    )) {
      return 'vegetable';
    }
    return null;
  }

  bool _categoryTypeMatches(String categoryName, String type) {
    if (type == 'fruit') {
      return _containsAny(
        categoryName,
        ['trai cay', 'hoa qua', 'fruit', 'fruits'],
      );
    }
    return _containsAny(
      categoryName,
      ['rau cu', 'rau', 'vegetable', 'veggie'],
    );
  }

  Map<String, dynamic>? _findMatchingCategory(
    String q,
    List<Map<String, dynamic>> categories,
  ) {
    if (categories.isEmpty) {
      return null;
    }

// Exact category match.
    for (final category in categories) {
      final name = _normalize(
        _stringValue(category['name']),
      );

      final nameEn = _normalize(
        _stringValue(category['name_en']),
      );

      final id = _normalize(
        _stringValue(category['id']),
      );

      if (name.isNotEmpty && _containsWholePhrase(q, name)) {
        return category;
      }

      if (nameEn.isNotEmpty && _containsWholePhrase(q, nameEn)) {
        return category;
      }

      if (id.isNotEmpty && _containsWholePhrase(q, id)) {
        return category;
      }
    }

// Token-based category matching.
    final queryWords = q
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .where(_isMeaningfulCategoryWord)
        .toSet();

    if (queryWords.isEmpty) {
      return null;
    }

    Map<String, dynamic>? bestCategory;
    var bestScore = 0;

    for (final category in categories) {
      final candidates = <String>[
        _normalize(
          _stringValue(category['name']),
        ),
        _normalize(
          _stringValue(category['name_en']),
        ),
        _normalize(
          _stringValue(category['id']),
        ),
      ].where((value) => value.isNotEmpty);

      var categoryScore = 0;

      for (final candidate in candidates) {
        final candidateWords = candidate
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toSet();

        final score = _overlapScore(
          queryWords,
          candidateWords,
        );

        if (score > categoryScore) {
          categoryScore = score;
        }
      }

      if (categoryScore > bestScore) {
        bestScore = categoryScore;
        bestCategory = category;
      }
    }

    return bestCategory;
  }

  int _overlapScore(
    Set<String> queryWords,
    Set<String> candidateWords,
  ) {
    if (queryWords.isEmpty || candidateWords.isEmpty) {
      return 0;
    }

    var score = 0;

    for (final word in queryWords) {
      if (candidateWords.contains(word)) {
        score += 2;
        continue;
      }

      if (word.length > 3 && word.endsWith('s')) {
        final singular = word.substring(
          0,
          word.length - 1,
        );

        if (candidateWords.contains(singular)) {
          score++;
          continue;
        }
      }

      if (word.length > 3 &&
          !word.endsWith('s') &&
          candidateWords.contains('${word}s')) {
        score++;
      }
    }

    return score;
  }

  bool _isMeaningfulCategoryWord(
    String word,
  ) {
    const genericWords = {
      'what',
      'which',
      'show',
      'list',
      'products',
      'product',
      'available',
      'currently',
      'have',
      'has',
      'do',
      'you',
      'the',
      'are',
      'is',
      'in',
      'of',
      'for',
      'with',
      'all',
      'some',
      'any',
      'category',
      'categories',
      'loai',
      'san',
      'pham',
      'danh',
      'muc',
      'nhom',
      'cac',
      'nhung',
      'nao',
      'co',
      'gi',
      'hang',
      'con',
      'khong',
    };

    return !genericWords.contains(word);
  }

  bool _containsWholePhrase(
    String text,
    String phrase,
  ) {
    if (phrase.isEmpty) {
      return false;
    }

    final pattern = RegExp(
      r'(^|\s)' + RegExp.escape(phrase) + r'($|\s)',
    );

    return pattern.hasMatch(text);
  }

  String _answerCategoryQuestion(
    String q,
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    final wantsPrice = _wantsPrice(q);
    final wantsStock = _wantsStock(q);
    final wantsDetail = _wantsDetail(q);

    if (wantsDetail) {
      return _formatFullProducts(
        products,
        isVietnamese: isVietnamese,
      );
    }

    if (wantsPrice && wantsStock) {
      return _formatPriceAndStock(
        products,
        isVietnamese: isVietnamese,
      );
    }

    if (wantsPrice) {
      return _formatPrices(
        products,
        isVietnamese: isVietnamese,
      );
    }

    if (wantsStock) {
      return _formatStocks(
        products,
        isVietnamese: isVietnamese,
      );
    }

    return _formatProductNames(
      products,
      isVietnamese: isVietnamese,
    );
  }

// ============================================================
// INTENT DETECTION
// ============================================================

  bool _isInStockListQuestion(
    String q,
  ) {
// Exact/common phrases first.
    if (_containsAny(q, [
      'in stock',
      'in-stock',
      'currently in stock',
      'which are in stock',
      'what is in stock',
      'what are in stock',
      'which products are in stock',
      'products in stock',
      'san pham con hang',
      'san pham dang con hang',
      'nhung san pham con hang',
      'cac san pham con hang',
      'san pham con trong kho',
      'nhung san pham con trong kho',
      'con nhung san pham nao',
      'nhung san pham nao con hang',
      'san pham nao con hang',
    ])) {
      return true;
    }

    final productScore = _keywordScore(
      q,
      [
        'product',
        'products',
        'item',
        'items',
        'san pham',
        'hang',
      ],
    );

    final stockScore = _keywordScore(
      q,
      [
        'in stock',
        'available',
        'still available',
        'still have',
        'left',
        'con hang',
        'dang con',
        'con trong kho',
        'con lai',
        'con',
      ],
    );

    final listScore = _keywordScore(
      q,
      [
        'which',
        'what',
        'list',
        'show',
        'items',
        'products',
        'nao',
        'nhung',
        'cac',
        'gi',
        'nhung gi',
      ],
    );

    return productScore >= 2 && stockScore >= 3 && listScore >= 1;
  }

  bool _isOutOfStockListQuestion(
    String q,
  ) {
    if (_containsAny(q, [
      'out of stock',
      'out-of-stock',
      'currently out of stock',
      'which are out of stock',
      'what is out of stock',
      'what are out of stock',
      'which products are out of stock',
      'products out of stock',
      'no stock',
      'sold out',
      'san pham het hang',
      'san pham het',
      'nhung san pham het hang',
      'cac san pham het hang',
      'san pham khong con hang',
      'san pham khong con trong kho',
      'nhung san pham khong con hang',
    ])) {
      return true;
    }

    final productScore = _keywordScore(
      q,
      [
        'product',
        'products',
        'item',
        'items',
        'san pham',
        'hang',
      ],
    );

    final outScore = _keywordScore(
      q,
      [
        'out of stock',
        'sold out',
        'unavailable',
        'no stock',
        'no longer available',
        'het hang',
        'het',
        'khong con',
        'khong con hang',
        'khong con trong kho',
      ],
    );

    final listScore = _keywordScore(
      q,
      [
        'which',
        'what',
        'list',
        'show',
        'items',
        'products',
        'nao',
        'nhung',
        'cac',
        'gi',
      ],
    );

    return productScore >= 2 && outScore >= 3 && listScore >= 1;
  }

  bool _isGeneralStockQuestion(
    String q,
  ) {
    if (_containsAny(q, [
      'how much stock',
      'how much stock do you have',
      'how many products are in stock',
      'stock levels',
      'stock information',
      'stock quantity',
      'ton kho',
      'thong tin ton kho',
      'so luong ton kho',
    ])) {
      return true;
    }

    final stockScore = _keywordScore(
      q,
      [
        'stock',
        'stock level',
        'stock information',
        'stock quantity',
        'ton kho',
        'thong tin ton kho',
        'so luong ton kho',
        'inventory',
        'inventory level',
      ],
    );

    final quantityScore = _keywordScore(
      q,
      [
        'how much',
        'how many',
        'quantity',
        'levels',
        'information',
        'bao nhieu',
        'so luong',
        'thong tin',
      ],
    );

    return stockScore >= 3 && quantityScore >= 1;
  }

  bool _isAllProductsQuestion(
    String q,
  ) {
    if (_containsAny(q, [
      'what products',
      'which products',
      'available products',
      'all products',
      'product list',
      'products do you have',
      'what do you have',
      'co nhung san pham',
      'co san pham nao',
      'nhung san pham nao',
      'danh sach san pham',
      'tat ca san pham',
      'cac san pham',
      'hom nay co san pham',
      'hom nay co nhung san pham',
    ])) {
      return true;
    }

    final productScore = _keywordScore(
      q,
      [
        'product',
        'products',
        'item',
        'items',
        'san pham',
      ],
    );

    final listScore = _keywordScore(
      q,
      [
        'what',
        'which',
        'all',
        'list',
        'show',
        'have',
        'available',
        'co',
        'nhung',
        'nao',
        'cac',
        'danh sach',
      ],
    );

    final stockScore = _keywordScore(
      q,
      [
        'stock',
        'in stock',
        'out of stock',
        'con hang',
        'het hang',
        'ton kho',
      ],
    );

    return productScore >= 2 && listScore >= 2 && stockScore == 0;
  }

  bool _isCategoryListQuestion(
    String q,
  ) {
    if (_containsAny(q, [
      'what categories',
      'which categories',
      'all categories',
      'category list',
      'categories do you have',
      'danh muc',
      'co nhung danh muc',
      'nhung danh muc',
      'cac danh muc',
      'loai san pham',
      'nhom san pham',
    ])) {
      return true;
    }

    final categoryScore = _keywordScore(
      q,
      [
        'category',
        'categories',
        'danh muc',
        'loai',
        'nhom',
      ],
    );

    final listScore = _keywordScore(
      q,
      [
        'what',
        'which',
        'all',
        'list',
        'show',
        'have',
        'co',
        'nhung',
        'nao',
        'cac',
      ],
    );

    return categoryScore >= 2 && listScore >= 1;
  }

  bool _wantsPrice(
    String q,
  ) {
    return _keywordScore(
          q,
          [
            'price',
            'prices',
            'cost',
            'how much',
            'price is',
            'gia',
            'gia bao nhieu',
            'bao nhieu tien',
            'gia ban',
            'tien bao nhieu',
          ],
        ) >
        0;
  }

  bool _wantsStock(
    String q,
  ) {
    return _keywordScore(
          q,
          [
            'stock',
            'in stock',
            'available',
            'how many left',
            'how much left',
            'left',
            'quantity',
            'ton kho',
            'con bao nhieu',
            'con hang',
            'con khong',
            'so luong',
            'con lai',
            'het hang',
          ],
        ) >
        0;
  }

  bool _wantsDetail(
    String q,
  ) {
    return _keywordScore(
          q,
          [
            'details',
            'detail',
            'description',
            'information',
            'more information',
            'tell me about',
            'about this product',
            'thong tin',
            'chi tiet',
            'mo ta',
            'day du',
            'tat ca thong tin',
          ],
        ) >
        0;
  }

  bool _isAvailabilityQuestion(
    String q,
  ) {
    return _keywordScore(
          q,
          [
            'is there',
            'do you have',
            'available',
            'can i get',
            'co khong',
            'co ban',
            'co san pham',
            'tim',
            'tim kiem',
            'con khong',
          ],
        ) >
        0;
  }

// ============================================================
// SCORING ENGINE
// ============================================================

  int _keywordScore(
    String q,
    List<String> keywords,
  ) {
    var score = 0;

    for (final keyword in keywords) {
      final normalizedKeyword = _normalize(keyword);

      if (normalizedKeyword.isEmpty) {
        continue;
      }

      if (normalizedKeyword.contains(' ')) {
        if (_containsWholePhrase(
          q,
          normalizedKeyword,
        )) {
          score += 3;
        }
        continue;
      }

      final words = q.split(RegExp(r'\s+'));

      if (words.contains(normalizedKeyword)) {
        score += 1;
      }
    }

    return score;
  }

// ============================================================
// FORMATTERS
// ============================================================

  String _formatProductNames(
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    if (products.isEmpty) {
      return isVietnamese
          ? 'Không tìm thấy sản phẩm phù hợp.'
          : 'No matching products are currently available.';
    }

    final names = products
        .map(
          (product) => _productDisplayName(
            product,
            isVietnamese: isVietnamese,
          ),
        )
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return isVietnamese
          ? 'Không tìm thấy sản phẩm phù hợp.'
          : 'No matching products are currently available.';
    }

    final title =
        isVietnamese ? 'HarvestHub hiện có:' : 'HarvestHub currently has:';

    return '$title\n'
        '${names.map((name) => '• $name').join('\n')}';
  }

  String _formatPrices(
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    if (products.isEmpty) {
      return isVietnamese
          ? 'Không tìm thấy sản phẩm phù hợp.'
          : 'No matching products found.';
    }

    final lines = <String>[];

    for (final product in products) {
      final name = _productDisplayName(
        product,
        isVietnamese: isVietnamese,
      );

      final price = _numberValue(
        product['price'],
      );

      final unit = _stringValue(
        product['unit'],
      );

      if (name.isEmpty) {
        continue;
      }

      if (price == null) {
        lines.add(
          isVietnamese
              ? '• $name: Chưa có thông tin giá.'
              : '• $name: Price unavailable.',
        );
      } else {
        lines.add(
          '• $name: '
          '\$${_formatNumber(price)}'
          '${unit.isNotEmpty ? '/$unit' : ''}',
        );
      }
    }

    return lines.isEmpty
        ? isVietnamese
            ? 'Chưa có thông tin giá.'
            : 'Price information is unavailable.'
        : lines.join('\n');
  }

  String _formatStocks(
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    if (products.isEmpty) {
      return isVietnamese
          ? 'Không tìm thấy sản phẩm phù hợp.'
          : 'No matching products found.';
    }

    final lines = <String>[];

    for (final product in products) {
      final name = _productDisplayName(
        product,
        isVietnamese: isVietnamese,
      );

      final stock = _numberValue(
        product['stock'],
      );

      final unit = _stringValue(
        product['unit'],
      );

      if (name.isEmpty) {
        continue;
      }

      if (stock == null) {
        lines.add(
          isVietnamese
              ? '• $name: Chưa có thông tin tồn kho.'
              : '• $name: Stock information unavailable.',
        );
      } else if (stock <= 0) {
        lines.add(
          isVietnamese ? '• $name: Hết hàng.' : '• $name: Out of stock.',
        );
      } else {
        lines.add(
          isVietnamese
              ? '• $name: Còn '
                  '${_formatNumber(stock)}'
                  '${unit.isNotEmpty ? ' $unit' : ''}.'
              : '• $name: '
                  '${_formatNumber(stock)}'
                  '${unit.isNotEmpty ? ' $unit' : ''} available.',
        );
      }
    }

    return lines.isEmpty
        ? isVietnamese
            ? 'Chưa có thông tin tồn kho.'
            : 'Stock information is unavailable.'
        : lines.join('\n');
  }

  String _formatPriceAndStock(
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    if (products.isEmpty) {
      return isVietnamese
          ? 'Không tìm thấy sản phẩm phù hợp.'
          : 'No matching products found.';
    }

    final lines = <String>[];

    for (final product in products) {
      final name = _productDisplayName(
        product,
        isVietnamese: isVietnamese,
      );

      final price = _numberValue(
        product['price'],
      );

      final stock = _numberValue(
        product['stock'],
      );

      final unit = _stringValue(
        product['unit'],
      );

      if (name.isEmpty) {
        continue;
      }

      if (isVietnamese) {
        final priceText = price == null
            ? 'chưa có giá'
            : '\$${_formatNumber(price)}'
                '${unit.isNotEmpty ? '/$unit' : ''}';

        final stockText = stock == null
            ? 'chưa có thông tin tồn kho'
            : stock <= 0
                ? 'hết hàng'
                : 'còn ${_formatNumber(stock)}'
                    '${unit.isNotEmpty ? ' $unit' : ''}';

        lines.add(
          '• $name: $priceText — $stockText',
        );
      } else {
        final priceText = price == null
            ? 'price unavailable'
            : '\$${_formatNumber(price)}'
                '${unit.isNotEmpty ? '/$unit' : ''}';

        final stockText = stock == null
            ? 'stock unavailable'
            : stock <= 0
                ? 'out of stock'
                : '${_formatNumber(stock)}'
                    '${unit.isNotEmpty ? ' $unit' : ''} available';

        lines.add(
          '• $name: $priceText — $stockText',
        );
      }
    }

    return lines.isEmpty
        ? isVietnamese
            ? 'Chưa có thông tin sản phẩm.'
            : 'Product information is unavailable.'
        : lines.join('\n');
  }

  String _formatFullProducts(
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    if (products.isEmpty) {
      return isVietnamese
          ? 'Không tìm thấy sản phẩm phù hợp.'
          : 'No matching products found.';
    }

    final sections = <String>[];

    for (final product in products) {
      final name = _productDisplayName(
        product,
        isVietnamese: isVietnamese,
      );

      final price = _numberValue(
        product['price'],
      );

      final stock = _numberValue(
        product['stock'],
      );

      final unit = _stringValue(
        product['unit'],
      );

      final description = _productDescription(
        product,
        isVietnamese: isVietnamese,
      );

      if (name.isEmpty) {
        continue;
      }

      final buffer = StringBuffer();

      buffer.writeln('**$name**');

      if (price != null) {
        buffer.writeln(
          isVietnamese
              ? 'Giá: \$${_formatNumber(price)}'
                  '${unit.isNotEmpty ? '/$unit' : ''}'
              : 'Price: \$${_formatNumber(price)}'
                  '${unit.isNotEmpty ? '/$unit' : ''}',
        );
      }

      if (stock != null) {
        if (stock <= 0) {
          buffer.writeln(
            isVietnamese ? 'Tồn kho: Hết hàng' : 'Stock: Out of stock',
          );
        } else {
          buffer.writeln(
            isVietnamese
                ? 'Tồn kho: ${_formatNumber(stock)}'
                    '${unit.isNotEmpty ? ' $unit' : ''}'
                : 'Stock: ${_formatNumber(stock)}'
                    '${unit.isNotEmpty ? ' $unit' : ''}',
          );
        }
      }

      if (description.isNotEmpty) {
        buffer.writeln(
          isVietnamese ? 'Mô tả: $description' : 'Description: $description',
        );
      }

      sections.add(
        buffer.toString().trim(),
      );
    }

    return sections.isEmpty
        ? isVietnamese
            ? 'Chưa có thông tin sản phẩm.'
            : 'Product information is unavailable.'
        : sections.join('\n\n');
  }

// ============================================================
// PRODUCT / CATEGORY DISPLAY HELPERS
// ============================================================

  String _productDisplayName(
    Map<String, dynamic> product, {
    required bool isVietnamese,
  }) {
    if (isVietnamese) {
      final nameVi = _stringValue(
        product['name'],
      );

      if (nameVi.isNotEmpty) {
        return nameVi;
      }

      return _stringValue(
        product['name_en'],
      );
    }

    final nameEn = _stringValue(
      product['name_en'],
    );

    if (nameEn.isNotEmpty) {
      return nameEn;
    }

    return _stringValue(
      product['name'],
    );
  }

  String _productDescription(
    Map<String, dynamic> product, {
    required bool isVietnamese,
  }) {
    if (isVietnamese) {
      final descriptionVi = _stringValue(
        product['description'],
      );

      if (descriptionVi.isNotEmpty) {
        return descriptionVi;
      }

      return _stringValue(
        product['description_en'],
      );
    }

    final descriptionEn = _stringValue(
      product['description_en'],
    );

    if (descriptionEn.isNotEmpty) {
      return descriptionEn;
    }

    return _stringValue(
      product['description'],
    );
  }

  String _categoryDisplayName(
    Map<String, dynamic> category, {
    required bool isVietnamese,
  }) {
    if (isVietnamese) {
      final nameVi = _stringValue(
        category['name'],
      );

      if (nameVi.isNotEmpty) {
        return nameVi;
      }

      return _stringValue(
        category['name_en'],
      );
    }

    final nameEn = _stringValue(
      category['name_en'],
    );

    if (nameEn.isNotEmpty) {
      return nameEn;
    }

    return _stringValue(
      category['name'],
    );
  }

// PRODUCT STATE

  bool _isActiveProduct(
    Map<String, dynamic> product,
  ) {
    final rawActive = product['is_active'];

    return rawActive == true ||
        rawActive == 1 ||
        rawActive == '1' ||
        rawActive == 'true';
  }

  bool _isAvailableProduct(
    Map<String, dynamic> product,
  ) {
    final stock = _numberValue(
      product['stock'],
    );

    if (!_isActiveProduct(product)) {
      return false;
    }

    return stock != null && stock > 0;
  }

  bool _isOutOfStockProduct(
    Map<String, dynamic> product,
  ) {
    final stock = _numberValue(
      product['stock'],
    );

    if (!_isActiveProduct(product)) {
      return false;
    }

    return stock != null && stock <= 0;
  }

// LANGUAGE

  bool _isVietnamese(
    String text,
  ) {
    final normalized = _normalize(text);

    if (normalized.isEmpty) {
      return false;
    }

    if (RegExp(
      r'[àáạảãăằắặẳẵâầấậẩẫ'
      r'èéẹẻẽêềếệểễ'
      r'ìíịỉĩ'
      r'òóọỏõôồốộổỗơờớợởỡ'
      r'ùúụủũưừứựửữ'
      r'ỳýỵỷỹđ]',
      caseSensitive: false,
    ).hasMatch(text)) {
      return true;
    }

    const vietnameseWords = [
      'xin chao',
      'chao ban',
      'chao',
      'san pham',
      'con hang',
      'het hang',
      'ton kho',
      'gia bao nhieu',
      'bao nhieu',
      'danh muc',
      'nong dan',
      'nha nong',
      'cho nong san',
      'mua hang',
      'dat hang',
      'cach mua',
      'cam on',
      'gioi thieu',
      'la gi',
      'o dau',
      'ban o dau',
      'con bao nhieu',
      'co nhung',
      'cho toi',
      'giup toi',
      'toi muon',
      'dang ban',
      'ban san pham',
      'tim san pham',
      'tim cho',
      'gia cua',
      'gia san pham',
      'san pham nao',
      'loai nao',
      'nhung gi',
      'con nhung',
      'hien con',
      'hien tai',
    ];

    return _containsAny(
      normalized,
      vietnameseWords,
    );
  }

// CONTEXT

  List<Map<String, dynamic>> _products(
    Map<String, dynamic> context,
  ) {
    final raw = context['products'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  List<Map<String, dynamic>> _categories(
    Map<String, dynamic> context,
  ) {
    final raw = context['categories'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

// VALUES

  String _stringValue(
    dynamic value,
  ) {
    return value?.toString().trim() ?? '';
  }

  double? _numberValue(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  String _formatNumber(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString().replaceAllMapped(
            RegExp(
              r'\B(?=(\d{3})+(?!\d))',
            ),
            (match) => ',',
          );
    }

    return value.toString();
  }

// NORMALIZATION

  String _normalize(
    String text,
  ) {
    var result = text.toLowerCase().trim();

    const replacements = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'đ': 'd',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
    };

    replacements.forEach(
      (from, to) {
        result = result.replaceAll(
          from,
          to,
        );
      },
    );

    return result
        .replaceAll(
          RegExp(r'[^a-z0-9]+'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  bool _containsAny(
    String text,
    List<String> values,
  ) {
    return values.any(
      (value) => text.contains(
        _normalize(value),
      ),
    );
  }
}

// PRODUCT MATCH MODEL

class _ProductMatch {
  const _ProductMatch({
    required this.product,
    required this.score,
  });

  final Map<String, dynamic> product;
  final int score;
}
