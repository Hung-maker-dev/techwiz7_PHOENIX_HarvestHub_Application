import 'chatbot_product_handler.dart';

class ChatbotFarmerHandler {
  final ChatbotProductHandler _productHandler = ChatbotProductHandler();

  String? answer(String question, Map<String, dynamic> context,
      {bool? useVietnamese}) {
    final normalizedQuestion = _normalize(question);
    final isVietnamese = useVietnamese ?? _isVietnamese(question);

    if (normalizedQuestion.isEmpty) {
      return null;
    }

    final farmers = _mapList(context['farmers']);
    final products = _mapList(context['products']);
    final categories = _mapList(context['categories']);
    final markets = _mapList(context['markets']);

// Không có farmer thì không xử lý câu hỏi farmer.
    if (farmers.isEmpty) {
      return null;
    }

// ============================================================
// 1. XÁC ĐỊNH CÂU HỎI FARMER
// ============================================================

    final isFarmerQuestion = _isFarmerQuestion(normalizedQuestion);
    final matchedFarmers = _findMatchingFarmers(
      normalizedQuestion,
      farmers,
    );
    final isFarmerProfileQuestion = matchedFarmers.isNotEmpty &&
        _containsAny(normalizedQuestion, [
          'about',
          'information',
          'details',
          'tell me',
          'introduce',
          'thong tin',
          'chi tiet',
          'gioi thieu',
        ]);
    final isFarmerProductQuestion = matchedFarmers.isNotEmpty &&
        _isFarmerProductQuestion(normalizedQuestion);
    final isFarmerLocationQuestion = matchedFarmers.isNotEmpty &&
        _isFarmerLocationQuestion(normalizedQuestion);
    final isSellerQuestion = _isSellerQuestion(normalizedQuestion);

    if (!isFarmerQuestion &&
        !isFarmerProfileQuestion &&
        !isFarmerProductQuestion &&
        !isFarmerLocationQuestion &&
        !isSellerQuestion) {
      return null;
    }

    if (isFarmerProductQuestion) {
      return _formatFarmerProducts(
        matchedFarmers,
        products,
        categories: categories,
        question: question,
        isVietnamese: isVietnamese,
      );
    }

// ============================================================
// 2. SELLER / FARMER CỦA MỘT SẢN PHẨM
//
// Ví dụ:
// - Ai bán gạo ST25?
// - Who sells ST25 Rice?
// - Who is selling King Banana?
// ============================================================

    if (isSellerQuestion) {
      final matchingProducts = _findMatchingAvailableProducts(
        normalizedQuestion,
        products,
      );
      final sellerFarmers = _findFarmersForProducts(
        matchingProducts,
        farmers,
      );

      if (sellerFarmers.isNotEmpty) {
        return _formatFarmersWithProducts(
          sellerFarmers,
          matchingProducts,
          isVietnamese: isVietnamese,
        );
      }

      return isVietnamese
          ? 'Tôi không tìm thấy nông trại nào còn sản phẩm này.'
          : 'I could not find a farm with this product in stock.';
    }

// ============================================================
// 3. TÌM FARMER CỤ THỂ
//
// Ví dụ:
// - Tell me about Minh Phat Farm
// - Thông tin về Trang trại Minh Phát
// ============================================================

    if (matchedFarmers.isNotEmpty) {
      return _formatFarmers(
        matchedFarmers,
        markets,
        products: products,
        includeAvailableProducts: true,
        isVietnamese: isVietnamese,
      );
    }

// ============================================================
// 4. FARMER LIST
//
// Ví dụ:
// - Who are the farmers?
// - Danh sách nông dân?
// ============================================================

    if (_isGenericFarmerQuestion(normalizedQuestion)) {
      return _formatFarmers(
        farmers,
        markets,
        products: const [],
        isVietnamese: isVietnamese,
      );
    }

// ============================================================
// 5. CÓ Ý HỎI FARMER NHƯNG KHÔNG TÌM THẤY
// ============================================================

    return isVietnamese
        ? 'Tôi không tìm thấy nông dân đó trong dữ liệu HarvestHub hiện tại.'
        : 'I could not find that farmer in the current HarvestHub data.';
  }

// ============================================================
// FARMER QUESTION DETECTION
// ============================================================

  bool _isFarmerQuestion(String question) {
    if (_containsAny(question, [
// English
      'farmer',
      'farmers',
      'seller',
      'sellers',
      'who sells',
      'who sell',
      'who is selling',
      'farmer information',
      'farmer details',
      'about farmer',
      'about the farmer',
      'farm information',
      'farm details',

      // Vietnamese
      'nong dan',
      'nha vuon',
      'nguoi ban',
      'nong trai',
      'ai ban',
      'ai dang ban',
      'nguoi nao ban',
      'trang trai',
      'thong tin nong dan',
      'thong tin nha vuon',
      'thong tin nguoi ban',
      'thong tin trang trai',
      've nong dan',
      've nha vuon',
      've nguoi ban',
      've trang trai',
      'nha nong',
    ])) {
      return true;
    }

    final farmerScore = _keywordScore(
      question,
      [
        'farmer',
        'farmers',
        'seller',
        'sellers',
        'nong dan',
        'nha vuon',
        'nguoi ban',
        'nong trai',
        'trang trai',
        'nha nong',
      ],
    );

    final informationScore = _keywordScore(
      question,
      [
        'information',
        'details',
        'about',
        'thong tin',
        'chi tiet',
        've',
        'gioi thieu',
      ],
    );

    final sellerScore = _keywordScore(
      question,
      [
        'who sells',
        'who sell',
        'who is selling',
        'sells',
        'selling',
        'ai ban',
        'ai dang ban',
        'nguoi nao ban',
      ],
    );

    return farmerScore >= 1 ||
        informationScore >= 2 && farmerScore >= 1 ||
        sellerScore >= 1;
  }

// ============================================================
// GENERIC FARMER QUESTION
// ============================================================

  bool _isGenericFarmerQuestion(String question) {
    if (_containsAny(question, [
      'who are the farmers',
      'who are farmers',
      'list farmers',
      'farmer list',
      'show farmers',
      'all farmers',
      'who are the sellers',
      'all sellers',
      'seller list',
      'list sellers',
      'show sellers',
      'farmers do you have',
      'sellers do you have',

      // Vietnamese
      'danh sach nong dan',
      'danh sach nha vuon',
      'danh sach nguoi ban',
      'danh sach trang trai',
      'cac nong dan',
      'cac nha vuon',
      'cac nguoi ban',
      'cac trang trai',
      'nhung nong dan',
      'nhung nha vuon',
      'nhung nguoi ban',
      'nhung trang trai',
      'co nhung nong dan nao',
      'co nhung nha vuon nao',
      'co nhung nguoi ban nao',
      'co nhung trang trai nao',
      'nong trai nao',
      'nong dan nao',
      'nha vuon nao',
      'nguoi ban nao',
      'trang trai nao',
    ])) {
      return true;
    }

    final farmerScore = _keywordScore(
      question,
      [
        'farmer',
        'farmers',
        'seller',
        'sellers',
        'nong dan',
        'nha vuon',
        'nguoi ban',
        'nong trai',
        'trang trai',
      ],
    );

    final listScore = _keywordScore(
      question,
      [
        'who',
        'which',
        'what',
        'list',
        'show',
        'all',
        'have',
        'who are',
        'danh sach',
        'cac',
        'nhung',
        'co',
        'nao',
      ],
    );

    return farmerScore >= 1 && listScore >= 1;
  }

// ============================================================
// SELLER QUESTION
// ============================================================

  bool _isSellerQuestion(String question) {
    if (_containsAny(question, [
// English
      'who sells',
      'who sell',
      'who is selling',
      'seller of',
      'sellers of',
      'which farmer sells',
      'which farmers sell',
      'which farm has',
      'which farm have',
      'which farms have',
      'which farms has',
      'which farms still have',
      'what farm has',
      'what farm have',
      'what farms have',
      'what farms has',
      'farms that have',
      'farms with',
      'farm that has',
      'farm that have',
      'farm with',
      'what farmer sells',

      // Vietnamese
      'ai ban',
      'ai dang ban',
      'nguoi nao ban',
      'nguoi ban san pham',
      'nha nao ban',
      'nong dan nao ban',
      'nong trai nao con',
      'nong trai nao co',
      'trang trai nao con',
      'trang trai nao co',
      'nong trai nao dang ban',
      'trang trai nao dang ban',
    ])) {
      return true;
    }

    final sellerScore = _keywordScore(
      question,
      [
        'seller',
        'sellers',
        'sells',
        'selling',
        'ai ban',
        'ai dang ban',
        'nguoi nao ban',
        'nong dan nao ban',
        'nong trai nao con',
        'nong trai nao co',
        'trang trai nao con',
        'trang trai nao co',
      ],
    );

    return sellerScore >= 1;
  }

  bool _isFarmerProductQuestion(String question) {
    return _containsAny(question, [
      'product',
      'products',
      'item',
      'items',
      'produce',
      'fruit',
      'fruits',
      'vegetable',
      'vegetables',
      'veggie',
      'veggies',
      'what does',
      'what do',
      'what can i buy',
      'sell',
      'selling',
      'have',
      'offer',
      'san pham',
      'nong san',
      'trai cay',
      'hoa qua',
      'rau cu',
      'loai',
      'ban nhung gi',
      'co nhung gi',
      'co loai',
      'co san pham gi',
      'co gi',
      'mua gi',
    ]);
  }

  bool _isFarmerLocationQuestion(String question) {
    return _containsAny(question, [
      'location',
      'where',
      'address',
      'located',
      'dia chi',
      'o dau',
      'vi tri',
    ]);
  }

// ============================================================
// FIND FARMERS
// ============================================================

  List<Map<String, dynamic>> _findMatchingFarmers(
    String question,
    List<Map<String, dynamic>> farmers,
  ) {
    final matches = <_FarmerMatch>[];

    for (final farmer in farmers) {
      if (!_isActiveFarmerForSearch(farmer)) {
        continue;
      }

      final score = _farmerMatchScore(
        question,
        farmer,
      );

      if (score > 0) {
        matches.add(
          _FarmerMatch(
            farmer: farmer,
            score: score,
          ),
        );
      }
    }

    matches.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    if (matches.isEmpty) {
      return [];
    }

    final bestScore = matches.first.score;
    return matches
        .where((match) => match.score == bestScore)
        .map((match) => match.farmer)
        .toList();
  }

// ============================================================
// FARMER MATCH SCORE
//
// Ưu tiên:
// 1. Exact full name
// 2. Full phrase
// 3. Tất cả từ có nghĩa
// 4. Từng từ
// 5. Prefix cơ bản
// ============================================================

  int _farmerMatchScore(
    String question,
    Map<String, dynamic> farmer,
  ) {
    final names = <String>[
      _stringValue(farmer['farm_name']),
      _stringValue(farmer['name']),
      _stringValue(farmer['name_en']),
      _stringValue(farmer['farm_name_en']),
      _stringValue(farmer['english_name']),
    ]
        .where((name) => name.isNotEmpty)
        .map(_normalize)
        .where((name) => name.isNotEmpty)
        .toSet();

    var bestScore = 0;

    for (final name in names) {
      // Exact toàn bộ tên.
      if (question == name) {
        bestScore = _max(bestScore, 100);
        continue;
      }

      // Câu có chứa nguyên tên farmer.
      if (_containsWholePhrase(question, name)) {
        bestScore = _max(bestScore, 80);
      }

      final meaningfulWords = _meaningfulWords(name);

      if (meaningfulWords.isEmpty) {
        continue;
      }

      // Tất cả từ có nghĩa đều xuất hiện.
      final allWordsMatched = meaningfulWords.every(
        question.contains,
      );

      if (allWordsMatched) {
        bestScore = _max(bestScore, 60);
        continue;
      }

      var wordScore = 0;

      for (final nameWord in meaningfulWords) {
        if (question.contains(nameWord)) {
          wordScore += 10;
          continue;
        }

        // Prefix cho typo nhẹ.
        if (nameWord.length >= 4 && _hasPrefixMatch(question, nameWord)) {
          wordScore += 5;
        }
      }

      bestScore = _max(bestScore, wordScore);
    }

    return bestScore;
  }

// ============================================================
// FIND FARMER BY PRODUCT
//
// products[].farmer_id
//        ↓
// farmers[].id
//
// Hoàn toàn dynamic từ database.
// ============================================================

  List<Map<String, dynamic>> _findMatchingAvailableProducts(
    String question,
    List<Map<String, dynamic>> products,
  ) {
    final matchedProducts = <_ProductMatch>[];

    for (final product in products) {
      if (!_isAvailableProduct(product)) {
        continue;
      }

      final score = _productMatchScore(
        question,
        product,
      );

      if (score > 0) {
        matchedProducts.add(
          _ProductMatch(
            product: product,
            score: score,
          ),
        );
      }
    }

    if (matchedProducts.isEmpty) {
      return [];
    }

    matchedProducts.sort(
      (a, b) => b.score.compareTo(a.score),
    );

// Chỉ lấy các product match mạnh nhất.
    final bestScore = matchedProducts.first.score;

    final bestProducts = matchedProducts
        .where(
          (item) => item.score >= bestScore,
        )
        .map((item) => item.product)
        .toList();

    return bestProducts;
  }

  List<Map<String, dynamic>> _findFarmersForProducts(
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> farmers,
  ) {
    final farmerIds = products
        .map(
          (product) => _stringValue(product['farmer_id']),
        )
        .where((id) => id.isNotEmpty)
        .toSet();

    if (farmerIds.isEmpty) {
      return [];
    }

    return farmers.where((farmer) {
      if (!_isActiveFarmerForSearch(farmer)) {
        return false;
      }

      final farmerId = _stringValue(
        farmer['id'],
      );

      return farmerId.isNotEmpty && farmerIds.contains(farmerId);
    }).toList();
  }

  String _formatFarmersWithProducts(
    List<Map<String, dynamic>> farmers,
    List<Map<String, dynamic>> matchedProducts, {
    required bool isVietnamese,
  }) {
    final lines = <String>[];

    for (final farmer in farmers) {
      final farmerId = _stringValue(farmer['id']);
      final name = _farmerDisplayName(
        farmer,
        isVietnamese: isVietnamese,
      );
      final farmerProducts = matchedProducts
          .where((product) => _stringValue(product['farmer_id']) == farmerId)
          .toList();

      if (name.isEmpty || farmerProducts.isEmpty) {
        continue;
      }

      lines.add(
        '• $name\n${_formatAvailableProducts(
          farmerProducts,
          isVietnamese: isVietnamese,
        )}',
      );
    }

    if (lines.isEmpty) {
      return isVietnamese
          ? 'Hiện chưa có thông tin nông trại.'
          : 'No farm information is currently available.';
    }

    final heading = isVietnamese
        ? 'Các nông trại còn sản phẩm này:'
        : 'Farms with this product in stock:';
    return '$heading\n${lines.join('\n')}';
  }

// ============================================================
// PRODUCT MATCH SCORE
// ============================================================

  int _productMatchScore(
    String question,
    Map<String, dynamic> product,
  ) {
    final names = <String>[
      _stringValue(product['name']),
      _stringValue(product['name_lower']),
      _stringValue(product['name_en']),
    ]
        .where((name) => name.isNotEmpty)
        .map(_normalize)
        .where((name) => name.isNotEmpty)
        .toSet();

    var bestScore = 0;

    for (final name in names) {
      if (question == name) {
        bestScore = _max(bestScore, 100);
        continue;
      }

      if (_containsWholePhrase(question, name)) {
        bestScore = _max(bestScore, 90);
      }

      final meaningfulWords = _meaningfulProductWords(name);

      if (meaningfulWords.isEmpty) {
        continue;
      }

      final allWordsMatched = meaningfulWords.every(
        question.contains,
      );

      if (allWordsMatched) {
        bestScore = _max(bestScore, 70);
        continue;
      }

      var wordScore = 0;

      for (final word in meaningfulWords) {
        if (question.contains(word)) {
          wordScore += 10;
          continue;
        }

        if (word.length >= 4 && _hasPrefixMatch(question, word)) {
          wordScore += 5;
        }
      }

      bestScore = _max(bestScore, wordScore);
    }

    return bestScore;
  }

// ============================================================
// FORMAT FARMERS
// ============================================================

  String _formatFarmers(
    List<Map<String, dynamic>> farmers,
    List<Map<String, dynamic>> markets, {
    required List<Map<String, dynamic>> products,
    bool includeAvailableProducts = false,
    required bool isVietnamese,
  }) {
    if (farmers.isEmpty) {
      return isVietnamese
          ? 'Hiện chưa có thông tin nông dân.'
          : 'No farmer information is currently available.';
    }

    final lines = <String>[];

    for (final farmer in farmers.take(10)) {
      final name = _farmerDisplayName(
        farmer,
        isVietnamese: isVietnamese,
      );

      final status = _stringValue(
        farmer['status'],
      );

      final rating = _numberValue(
        farmer['rating'],
      );

      final description = _farmerDescription(
        farmer,
        isVietnamese: isVietnamese,
      );

      // Ưu tiên market_name có sẵn.
      var marketName = _marketDisplayName(
        farmer,
        isVietnamese: isVietnamese,
      );

      // Nếu chưa có market_name thì lookup bằng market_id.
      if (marketName.isEmpty) {
        final marketId = _stringValue(
          farmer['market_id'],
        );

        for (final market in markets) {
          if (_stringValue(market['id']) == marketId) {
            marketName = _marketName(
              market,
              isVietnamese: isVietnamese,
            );
            break;
          }
        }
      }

      final details = <String>[];
      final location = _farmerLocation(farmer);

      if (location.isNotEmpty) {
        details.add(
          isVietnamese ? 'Địa chỉ: $location' : 'Address: $location',
        );
      }

      if (status.isNotEmpty) {
        details.add(
          isVietnamese
              ? 'Trạng thái: ${_formatStatus(
                  status,
                  isVietnamese: true,
                )}'
              : 'Status: ${_formatStatus(
                  status,
                  isVietnamese: false,
                )}',
        );
      }

      if (marketName.isNotEmpty) {
        details.add(
          isVietnamese ? 'Chợ: $marketName' : 'Market: $marketName',
        );
      }

      if (rating != null && rating > 0) {
        details.add(
          isVietnamese
              ? 'Đánh giá: ${rating.toStringAsFixed(1)}'
              : 'Rating: ${rating.toStringAsFixed(1)}',
        );
      }

      if (description.isNotEmpty) {
        details.add(description);
      }

      if (includeAvailableProducts) {
        final farmerProducts = _availableProductsForFarmer(
          farmer,
          products,
        );
        if (farmerProducts.isNotEmpty) {
          details.add(
            isVietnamese
                ? 'Sản phẩm đang bán:\n${_formatAvailableProducts(
                    farmerProducts,
                    isVietnamese: true,
                  )}'
                : 'Currently available products:\n${_formatAvailableProducts(
                    farmerProducts,
                    isVietnamese: false,
                  )}',
          );
        } else {
          details.add(
            isVietnamese
                ? 'Hiện chưa có sản phẩm còn hàng.'
                : 'No products are currently in stock.',
          );
        }
      }

      if (name.isEmpty) {
        if (details.isNotEmpty) {
          lines.add(
            '• ${details.join('; ')}',
          );
        }

        continue;
      }

      if (details.isEmpty) {
        lines.add('• $name');
      } else {
        lines.add(
          '• $name — ${details.join('; ')}',
        );
      }
    }

    if (lines.isEmpty) {
      return isVietnamese
          ? 'Hiện chưa có thông tin nông dân.'
          : 'No farmer information is currently available.';
    }

    return lines.join('\n');
  }

  String _formatFarmerProducts(
    List<Map<String, dynamic>> farmers,
    List<Map<String, dynamic>> products, {
    required List<Map<String, dynamic>> categories,
    required String question,
    required bool isVietnamese,
  }) {
    return farmers.map((farmer) {
      final name = _farmerDisplayName(
        farmer,
        isVietnamese: isVietnamese,
      );
      final availableProducts = _availableProductsForFarmer(
        farmer,
        products,
      );
      final category = _productHandler.findCategoryForQuestion(
        question,
        categories,
      );
      final categoryQuestion =
          _productHandler.isKnownCategoryQuestion(question);
      final farmerName = _normalize(_farmerDisplayName(
        farmer,
        isVietnamese: isVietnamese,
      ));
      final productQuestion = _removePhrase(_normalize(question), farmerName);
      final matchingProducts = category != null
          ? availableProducts
              .where((product) =>
                  _stringValue(product['category_id']) ==
                  _stringValue(category['id']))
              .toList()
          : categoryQuestion
              ? const <Map<String, dynamic>>[]
              : _productHandler.findProducts(
                  productQuestion,
                  availableProducts,
                );
      final productsToShow = category != null || categoryQuestion
          ? matchingProducts
          : matchingProducts.isNotEmpty
              ? matchingProducts
              : availableProducts;
      final heading = isVietnamese
          ? 'Sản phẩm còn hàng của $name:'
          : 'Currently available products from $name:';

      if (productsToShow.isEmpty) {
        return isVietnamese
            ? '$heading\n${categoryQuestion ? 'Nông trại hiện không có sản phẩm còn hàng thuộc loại này.' : 'Hiện chưa có sản phẩm còn hàng.'}'
            : '$heading\n${categoryQuestion ? 'This farm has no in-stock products in that category.' : 'No products are currently in stock.'}';
      }

      return '$heading\n${_formatAvailableProducts(
        productsToShow,
        isVietnamese: isVietnamese,
      )}';
    }).join('\n\n');
  }

  String _removePhrase(String text, String phrase) {
    if (phrase.isEmpty) return text;
    return text.replaceAll(phrase, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<Map<String, dynamic>> _availableProductsForFarmer(
    Map<String, dynamic> farmer,
    List<Map<String, dynamic>> products,
  ) {
    final farmerId = _stringValue(farmer['id']);
    if (farmerId.isEmpty) {
      return const [];
    }

    return products.where((product) {
      return _stringValue(product['farmer_id']) == farmerId &&
          _isAvailableProduct(product);
    }).toList();
  }

  String _formatAvailableProducts(
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    return products.map((product) {
      final name = _productDisplayName(
        product,
        isVietnamese: isVietnamese,
      );
      final price = _numberValue(product['price']);
      final unit = _stringValue(product['unit']);
      final priceText = price == null
          ? (isVietnamese ? 'Chưa có thông tin giá' : 'Price unavailable')
          : '\$${_formatNumber(price)}${unit.isNotEmpty ? '/$unit' : ''}';
      final stock = _numberValue(product['stock']);
      final stockText = isVietnamese
          ? 'Còn ${_formatNumber(stock ?? 0)}${unit.isNotEmpty ? ' $unit' : ''}'
          : '${_formatNumber(stock ?? 0)}${unit.isNotEmpty ? ' $unit' : ''} in stock';

      return '• $name — $priceText — $stockText';
    }).join('\n');
  }

  String _productDisplayName(
    Map<String, dynamic> product, {
    required bool isVietnamese,
  }) {
    final name = _stringValue(product['name']);
    if (name.isNotEmpty) {
      return name;
    }

    return _stringValue(product['name_en']);
  }

  String _farmerLocation(Map<String, dynamic> farmer) {
    final address = _stringValue(farmer['address']);
    if (address.isNotEmpty) {
      return address;
    }

    final marketName = _stringValue(farmer['market_name']);
    if (marketName.isNotEmpty) {
      return marketName;
    }

    final latitude = _numberValue(farmer['latitude']);
    final longitude = _numberValue(farmer['longitude']);
    if (latitude != null && longitude != null) {
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    }

    return '';
  }

// ============================================================
// FARMER DISPLAY NAME
// ============================================================

  String _farmerDisplayName(
    Map<String, dynamic> farmer, {
    required bool isVietnamese,
  }) {
    if (isVietnamese) {
      final nameVi = _stringValue(
        farmer['farm_name'],
      );

      if (nameVi.isNotEmpty) {
        return nameVi;
      }

      final fallbackVi = _stringValue(
        farmer['name'],
      );

      if (fallbackVi.isNotEmpty) {
        return fallbackVi;
      }

      final nameEn = _stringValue(
        farmer['farm_name_en'],
      );

      if (nameEn.isNotEmpty) {
        return nameEn;
      }

      return _stringValue(
        farmer['name_en'],
      );
    }

    final nameEn = _stringValue(
      farmer['farm_name_en'],
    );

    if (nameEn.isNotEmpty) {
      return nameEn;
    }

    final englishName = _stringValue(
      farmer['english_name'],
    );

    if (englishName.isNotEmpty) {
      return englishName;
    }

    final name = _stringValue(
      farmer['name_en'],
    );

    if (name.isNotEmpty) {
      return name;
    }

    return _stringValue(
      farmer['farm_name'],
    );
  }

// ============================================================
// FARMER DESCRIPTION
// ============================================================

  String _farmerDescription(
    Map<String, dynamic> farmer, {
    required bool isVietnamese,
  }) {
    if (isVietnamese) {
      final descriptionVi = _stringValue(
        farmer['description'],
      );

      if (descriptionVi.isNotEmpty) {
        return descriptionVi;
      }

      return _stringValue(
        farmer['description_en'],
      );
    }

    final descriptionEn = _stringValue(
      farmer['description_en'],
    );

    if (descriptionEn.isNotEmpty) {
      return descriptionEn;
    }

    return _stringValue(
      farmer['description'],
    );
  }

// ============================================================
// MARKET DISPLAY NAME
// ============================================================

  String _marketDisplayName(
    Map<String, dynamic> farmer, {
    required bool isVietnamese,
  }) {
    final marketNameVi = _stringValue(
      farmer['market_name'],
    );

    final marketNameEn = _stringValue(
      farmer['market_name_en'],
    );

    if (isVietnamese) {
      if (marketNameVi.isNotEmpty) {
        return marketNameVi;
      }

      return marketNameEn;
    }

    if (marketNameEn.isNotEmpty) {
      return marketNameEn;
    }

    return marketNameVi;
  }

  String _marketName(
    Map<String, dynamic> market, {
    required bool isVietnamese,
  }) {
    final nameVi = _stringValue(
      market['name'],
    );

    final nameEn = _stringValue(
      market['name_en'],
    );

    if (isVietnamese) {
      if (nameVi.isNotEmpty) {
        return nameVi;
      }

      return nameEn;
    }

    if (nameEn.isNotEmpty) {
      return nameEn;
    }

    return nameVi;
  }

// ============================================================
// STATUS
// ============================================================

  String _formatStatus(
    String status, {
    required bool isVietnamese,
  }) {
    switch (_normalize(status)) {
      case 'approved':
        return isVietnamese ? 'Đã duyệt' : 'Approved';

      case 'pending':
        return isVietnamese ? 'Đang chờ duyệt' : 'Pending';

      case 'rejected':
        return isVietnamese ? 'Bị từ chối' : 'Rejected';

      case 'inactive':
        return isVietnamese ? 'Không hoạt động' : 'Inactive';

      default:
        return status;
    }
  }

// ============================================================
// MEANINGFUL FARMER WORDS
// ============================================================

  List<String> _meaningfulWords(String value) {
    const genericWords = {
// Vietnamese
      'trang',
      'trai',
      'nong',
      'nong trai',
      'vuon',
      'rau',
      'nha',
      'dan',
      'nguoi',
      'ban',
      'co',
      'chu',
      'ong',
      'ba',

      // English
      'farm',
      'farmer',
      'farmers',
      'seller',
      'sellers',
      'the',
      'garden',
    };

    return value
        .split(RegExp(r'\s+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .where(
          (word) => !genericWords.contains(word),
        )
        .where(
          (word) => word.length >= 2,
        )
        .toList();
  }

// ============================================================
// MEANINGFUL PRODUCT WORDS
// ============================================================

  List<String> _meaningfulProductWords(String value) {
    const genericWords = {
// English
      'organic',
      'fresh',
      'high',
      'quality',
      'product',
      'products',

      // Vietnamese
      'huu',
      'co',
      'tuoi',
      'ngon',
      'chat',
      'luong',
      'cao',
      'san',
      'pham',
    };

    return value
        .split(RegExp(r'\s+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .where(
          (word) => !genericWords.contains(word),
        )
        .where(
          (word) => word.length >= 2,
        )
        .toList();
  }

// ============================================================
// PREFIX MATCH
// ============================================================

  bool _hasPrefixMatch(
    String question,
    String targetWord,
  ) {
    final words = question.split(
      RegExp(r'\s+'),
    );

    for (final word in words) {
      if (word.length >= 4 &&
          (word.startsWith(targetWord) || targetWord.startsWith(word))) {
        return true;
      }
    }

    return false;
  }

// ============================================================
// KEYWORD SCORE
// ============================================================

  int _keywordScore(
    String question,
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
          question,
          normalizedKeyword,
        )) {
          score += 3;
        }

        continue;
      }

      final words = question.split(
        RegExp(r'\s+'),
      );

      if (words.contains(normalizedKeyword)) {
        score += 1;
      }
    }

    return score;
  }

// ============================================================
// ACTIVE FARMER
// ============================================================

  bool _isActiveFarmerForSearch(
    Map<String, dynamic> farmer,
  ) {
    final status = _normalize(
      _stringValue(farmer['status']),
    );

// Nếu không có status thì vẫn cho phép tìm.
    if (status.isEmpty) {
      return true;
    }

// Farmer rejected/inactive không nên xuất hiện.
    if (status == 'rejected' || status == 'inactive') {
      return false;
    }

    return true;
  }

// ============================================================
// ACTIVE PRODUCT
// ============================================================

  bool _isActiveProduct(
    Map<String, dynamic> product,
  ) {
    final rawActive = product['is_active'];

    return rawActive == true ||
        rawActive == 1 ||
        rawActive == '1' ||
        rawActive == 'true';
  }

  bool _isAvailableProduct(Map<String, dynamic> product) {
    final stock = _numberValue(product['stock']);
    return _isActiveProduct(product) && stock != null && stock > 0;
  }

  String _formatNumber(double value) {
    final fixed = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(
              RegExp(r'\.$'),
              '',
            );
    final parts = fixed.split('.');
    final whole = parts.first;
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.length == 1 ? grouped : '$grouped.${parts[1]}';
  }

// ============================================================
// WHOLE PHRASE
// ============================================================

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

// ============================================================
// LANGUAGE
// ============================================================

  bool _isVietnamese(String text) {
    if (text.trim().isEmpty) {
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

    final normalized = _normalize(text);

    const vietnameseWords = [
      'xin chao',
      'chao ban',
      'san pham',
      'con hang',
      'het hang',
      'ton kho',
      'gia bao nhieu',
      'bao nhieu',
      'danh muc',
      'nong dan',
      'nha vuon',
      'nguoi ban',
      'trang trai',
      'nha nong',
      'ai ban',
      'ai dang ban',
      'thong tin',
      'chi tiet',
      've',
      'gioi thieu',
      'co nhung',
      'nhung',
      'cac',
      'toi',
      'minh',
      'cho toi',
      'giup toi',
      'muon',
      'dang ban',
      'ban san pham',
      'tim san pham',
      'san pham nao',
      'nong dan nao',
      'nha vuon nao',
      'nguoi ban nao',
      'trang trai nao',
    ];

    return _containsAny(
      normalized,
      vietnameseWords,
    );
  }

// ============================================================
// MAP LIST
// ============================================================

  List<Map<String, dynamic>> _mapList(
    dynamic raw,
  ) {
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

// ============================================================
// STRING
// ============================================================

  String _stringValue(
    dynamic value,
  ) {
    return value?.toString().trim() ?? '';
  }

// ============================================================
// NUMBER
// ============================================================

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

// ============================================================
// NORMALIZATION
// ============================================================

  String _normalize(
    String text,
  ) {
    var normalized = text.toLowerCase().trim();

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
        normalized = normalized.replaceAll(
          from,
          to,
        );
      },
    );

    return normalized
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

// ============================================================
// CONTAINS ANY
// ============================================================

  bool _containsAny(
    String text,
    List<String> values,
  ) {
    return values.any(
      (value) {
        final normalizedValue = _normalize(value);

        if (normalizedValue.isEmpty) {
          return false;
        }

        if (normalizedValue.contains(' ')) {
          return _containsWholePhrase(
            text,
            normalizedValue,
          );
        }

        return text.split(RegExp(r'\s+')).contains(normalizedValue);
      },
    );
  }

// ============================================================
// MAX
// ============================================================

  int _max(
    int a,
    int b,
  ) {
    return a > b ? a : b;
  }
}

// ============================================================
// FARMER MATCH
// ============================================================

class _FarmerMatch {
  const _FarmerMatch({
    required this.farmer,
    required this.score,
  });

  final Map<String, dynamic> farmer;
  final int score;
}

// ============================================================
// PRODUCT MATCH
// ============================================================

class _ProductMatch {
  const _ProductMatch({
    required this.product,
    required this.score,
  });

  final Map<String, dynamic> product;
  final int score;
}
