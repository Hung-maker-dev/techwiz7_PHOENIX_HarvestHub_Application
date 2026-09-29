class ChatbotMarketHandler {
  // ============================================================
  // PUBLIC API
  // ============================================================

  String? answer(
    String question,
    Map<String, dynamic> context, {
    bool? useVietnamese,
  }) {
    final normalizedQuestion = _normalize(question);
    final isVietnamese = useVietnamese ?? _isVietnamese(question);

    if (normalizedQuestion.isEmpty) {
      return null;
    }

    final markets = _mapList(context['markets']);
    final farmers = _mapList(context['farmers']);
    final products = _mapList(context['products']);

    if (markets.isEmpty) {
      return null;
    }

    // ============================================================
    // 1. KIỂM TRA CÂU HỎI MARKET
    // ============================================================

    if (!_isMarketQuestion(normalizedQuestion)) {
      return null;
    }

    // ============================================================
    // 2. TÌM MARKET CỤ THỂ
    // ============================================================

    final matchedMarkets = _findMatchingMarkets(
      normalizedQuestion,
      markets,
    );

    // ============================================================
    // 3. MARKET THÔNG QUA FARMER
    //
    // Ví dụ:
    // - Where is Minh Phat Farm?
    // - Trang trại Minh Phát ở chợ nào?
    // ============================================================

    if (_isFarmerMarketQuestion(normalizedQuestion)) {
      final farmerMarkets = _findMarketsByFarmer(
        normalizedQuestion,
        farmers,
        markets,
      );

      if (farmerMarkets.isNotEmpty) {
        return _formatMarkets(
          farmerMarkets,
          farmers,
          products,
          isVietnamese: isVietnamese,
        );
      }

      return isVietnamese
          ? 'Tôi không tìm thấy chợ của nông dân này trong dữ liệu hiện tại.'
          : 'I could not find the market for this farmer.';
    }

    // ============================================================
    // 4. MARKET THÔNG QUA PRODUCT
    //
    // Ví dụ:
    // - Where can I find Gạo ST25?
    // - Gạo ST25 bán ở đâu?
    // - Which market sells King Banana?
    // ============================================================

    if (_isProductMarketQuestion(normalizedQuestion)) {
      final productMarkets = _findMarketsByProduct(
        normalizedQuestion,
        products,
        markets,
      );

      if (productMarkets.isNotEmpty) {
        return _formatMarkets(
          productMarkets,
          farmers,
          products,
          isVietnamese: isVietnamese,
        );
      }

      return isVietnamese
          ? 'Tôi không tìm thấy chợ bán sản phẩm này.'
          : 'I could not find a market selling that product.';
    }

    // ============================================================
    // 5. CÂU HỎI VỀ FARMER TRONG MARKET
    //
    // Ví dụ:
    // - Which farmers are at Thu Duc Market?
    // - Chợ Thủ Đức có những nông dân nào?
    // ============================================================

    if (_isMarketFarmerQuestion(normalizedQuestion)) {
      if (matchedMarkets.isNotEmpty) {
        return _formatMarketFarmers(
          matchedMarkets,
          farmers,
          isVietnamese: isVietnamese,
        );
      }

      return isVietnamese
          ? 'Tôi không tìm thấy chợ này trong dữ liệu hiện tại.'
          : 'I could not find that market in the current data.';
    }

    // ============================================================
    // 6. CÂU HỎI VỀ PRODUCT TRONG MARKET
    //
    // Ví dụ:
    // - What products are sold at Thu Duc Market?
    // - Chợ Thủ Đức bán những sản phẩm gì?
    // ============================================================

    if (_isMarketProductQuestion(normalizedQuestion)) {
      if (matchedMarkets.isNotEmpty) {
        return _formatMarketProducts(
          matchedMarkets,
          products,
          isVietnamese: isVietnamese,
        );
      }

      return isVietnamese
          ? 'Tôi không tìm thấy chợ này trong dữ liệu hiện tại.'
          : 'I could not find that market in the current data.';
    }

    // ============================================================
    // 7. CÂU HỎI ĐỊA CHỈ MARKET
    //
    // Ví dụ:
    // - Chợ Thủ Đức ở đâu?
    // - Where is Thu Duc Market?
    // - What is the address of Thu Duc Market?
    // ============================================================

    if (_isMarketAddressQuestion(normalizedQuestion)) {
      if (matchedMarkets.isNotEmpty) {
        return _formatMarketAddress(
          matchedMarkets,
          isVietnamese: isVietnamese,
        );
      }

      return isVietnamese
          ? 'Tôi không tìm thấy chợ này trong dữ liệu hiện tại.'
          : 'I could not find that market in the current data.';
    }

    // ============================================================
    // 8. CÂU HỎI GIỜ MỞ CỬA MARKET
    //
    // Ví dụ:
    // - Chợ Thủ Đức mở cửa lúc mấy giờ?
    // - What time does Thu Duc Market open?
    // - What are the opening hours of Thu Duc Market?
    // ============================================================

    if (_isMarketOpeningHoursQuestion(normalizedQuestion)) {
      if (matchedMarkets.isNotEmpty) {
        return _formatMarketOpeningHours(
          matchedMarkets,
          isVietnamese: isVietnamese,
        );
      }

      return isVietnamese
          ? 'Tôi không tìm thấy chợ này trong dữ liệu hiện tại.'
          : 'I could not find that market in the current data.';
    }

    // ============================================================
    // 9. MATCH MARKET CỤ THỂ
    // ============================================================

    if (matchedMarkets.isNotEmpty) {
      return _formatMarkets(
        matchedMarkets,
        farmers,
        products,
        isVietnamese: isVietnamese,
      );
    }

    // ============================================================
    // 10. DANH SÁCH MARKET
    //
    // Ví dụ:
    // - What markets are available?
    // - Which markets do you have?
    // - Có những chợ nào?
    // ============================================================

    if (_isGenericMarketQuestion(normalizedQuestion)) {
      return _formatMarkets(
        markets,
        farmers,
        products,
        isVietnamese: isVietnamese,
      );
    }

    // ============================================================
    // 11. MARKET QUESTION NHƯNG KHÔNG MATCH ĐƯỢC
    // ============================================================

    return isVietnamese
        ? 'Tôi không tìm thấy chợ phù hợp trong dữ liệu HarvestHub hiện tại.'
        : 'I could not find a matching market in the current HarvestHub data.';
  }

  // ============================================================
  // MARKET QUESTION DETECTION
  // ============================================================

  bool _isMarketQuestion(String question) {
    if (_containsAny(question, [
      // English
      'market',
      'markets',
      'address',
      'location',
      'where is the market',
      'where are the markets',
      'opening hours',
      'open hours',
      'what time does the market open',
      'what time is the market open',
      'market information',
      'market details',
      'about the market',
      'market location',
      'market address',

      // Vietnamese
      'cho',
      'cho nong san',
      'dia chi',
      'vi tri',
      'o dau',
      'gio mo cua',
      'gio dong cua',
      'gio hoat dong',
      'thoi gian mo cua',
      'thong tin cho',
      'chi tiet cho',
      'cho nao',
      'nhung cho nao',
    ])) {
      return true;
    }

    final marketScore = _keywordScore(
      question,
      [
        'market',
        'markets',
        'cho',
        'cho nong san',
      ],
    );

    final locationScore = _keywordScore(
      question,
      [
        'address',
        'location',
        'where',
        'dia chi',
        'vi tri',
        'o dau',
      ],
    );

    final timeScore = _keywordScore(
      question,
      [
        'opening hours',
        'open hours',
        'open',
        'close',
        'hours',
        'gio mo cua',
        'gio dong cua',
        'thoi gian',
      ],
    );

    return marketScore >= 1 ||
        (locationScore >= 1 && marketScore >= 1) ||
        (timeScore >= 1 && marketScore >= 1);
  }

  // ============================================================
  // GENERIC MARKET QUESTION
  // ============================================================

  bool _isGenericMarketQuestion(String question) {
    if (_containsAny(question, [
      // English
      'what markets',
      'which markets',
      'all markets',
      'market list',
      'list markets',
      'show markets',
      'markets do you have',
      'what markets are available',
      'which markets are available',

      // Vietnamese
      'co nhung cho nao',
      'co nhung cho nong san nao',
      'nhung cho nao',
      'cac cho',
      'cac cho nong san',
      'danh sach cho',
      'danh sach cho nong san',
      'cho nao dang hoat dong',
      'nhung cho nao dang hoat dong',
    ])) {
      return true;
    }

    final marketScore = _keywordScore(
      question,
      [
        'market',
        'markets',
        'cho',
        'cho nong san',
      ],
    );

    final listScore = _keywordScore(
      question,
      [
        'what',
        'which',
        'all',
        'list',
        'show',
        'have',
        'available',
        'who',
        'co',
        'nhung',
        'cac',
        'nao',
        'danh sach',
      ],
    );

    return marketScore >= 1 && listScore >= 1;
  }

  // ============================================================
  // MARKET ADDRESS QUESTION
  // ============================================================

  bool _isMarketAddressQuestion(String question) {
    if (_containsAny(question, [
      // English
      'where is',
      'where are',
      'where can i find the market',
      'where can i find this market',
      'market address',
      'address of the market',
      'what is the address',
      'what is the market address',
      'market location',
      'location of the market',

      // Vietnamese
      'cho o dau',
      'cho nao o dau',
      'cho nay o dau',
      'cho do o dau',
      'dia chi cho',
      'dia chi cua cho',
      'dia chi chợ',
      'vi tri cho',
      'vi tri cua cho',
      'cho nam o dau',
      'cho nam dau',
    ])) {
      return true;
    }

    final marketScore = _keywordScore(
      question,
      [
        'market',
        'markets',
        'cho',
      ],
    );

    final locationScore = _keywordScore(
      question,
      [
        'where',
        'address',
        'location',
        'dia chi',
        'vi tri',
        'o dau',
        'nam dau',
      ],
    );

    return marketScore >= 1 && locationScore >= 1;
  }

  // ============================================================
  // MARKET OPENING HOURS QUESTION
  // ============================================================

  bool _isMarketOpeningHoursQuestion(String question) {
    if (_containsAny(question, [
      // English
      'opening hours',
      'open hours',
      'market hours',
      'opening time',
      'closing time',
      'what time does the market open',
      'what time does the market close',
      'what time is the market open',
      'what time is the market closed',
      'when does the market open',
      'when does the market close',
      'when is the market open',
      'when is the market closed',

      // Vietnamese
      'gio mo cua',
      'gio dong cua',
      'gio hoat dong',
      'thoi gian mo cua',
      'thoi gian dong cua',
      'cho mo cua luc may gio',
      'cho dong cua luc may gio',
      'cho mo luc may gio',
      'cho dong luc may gio',
      'cho mo cua khi nao',
      'cho dong cua khi nao',
    ])) {
      return true;
    }

    final marketScore = _keywordScore(
      question,
      [
        'market',
        'markets',
        'cho',
      ],
    );

    final timeScore = _keywordScore(
      question,
      [
        'opening',
        'open',
        'hours',
        'hour',
        'close',
        'closing',
        'when',
        'time',
        'gio',
        'thoi gian',
      ],
    );

    return marketScore >= 1 && timeScore >= 1;
  }

  // ============================================================
  // FARMER -> MARKET QUESTION
  // ============================================================

  bool _isFarmerMarketQuestion(String question) {
    if (_containsAny(question, [
      // English
      'where is',
      'where can i find',
      'which market is',
      'which market does',
      'what market is',
      'what market does',
      'farmer market',
      'farm market',

      // Vietnamese
      'o cho nao',
      'o thi truong nao',
      'cho nao cua',
      'farmer o dau',
      'nong dan o dau',
      'trang trai o dau',
      'nha vuon o dau',
    ])) {
      final farmerScore = _keywordScore(
        question,
        [
          'farmer',
          'farm',
          'nong dan',
          'trang trai',
          'nha vuon',
        ],
      );

      return farmerScore >= 1;
    }

    final farmerScore = _keywordScore(
      question,
      [
        'farmer',
        'farm',
        'nong dan',
        'trang trai',
        'nha vuon',
      ],
    );

    final locationScore = _keywordScore(
      question,
      [
        'where',
        'location',
        'market',
        'o dau',
        'cho',
        'vi tri',
      ],
    );

    return farmerScore >= 1 && locationScore >= 2;
  }

  // ============================================================
  // PRODUCT -> MARKET QUESTION
  // ============================================================

  bool _isProductMarketQuestion(String question) {
    if (_containsAny(question, [
      // English
      'where can i find',
      'where can i buy',
      'which market sells',
      'what market sells',
      'where is this product sold',
      'where is the product sold',
      'which market has',

      // Vietnamese
      'ban o dau',
      'mua o dau',
      'tim o dau',
      'tim cho nao',
      'san pham ban o',
      'san pham o cho nao',
      'cho nao ban',
      'cho nao co',
    ])) {
      return true;
    }

    final productScore = _keywordScore(
      question,
      [
        'product',
        'products',
        'san pham',
      ],
    );

    final locationScore = _keywordScore(
      question,
      [
        'where',
        'market',
        'cho',
        'o dau',
        'ban',
        'mua',
        'tim',
      ],
    );

    return productScore >= 1 && locationScore >= 2;
  }

  // ============================================================
  // MARKET -> FARMER QUESTION
  // ============================================================

  bool _isMarketFarmerQuestion(String question) {
    if (_containsAny(question, [
      // English
      'which farmers',
      'what farmers',
      'farmers at',
      'farmers in',
      'sellers at',
      'sellers in',
      'who sells at',
      'who is selling at',

      // Vietnamese
      'nong dan nao o',
      'nhung nong dan o',
      'cac nong dan o',
      'nguoi ban o',
      'ai ban o',
      'ai dang ban o',
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
        'nguoi ban',
      ],
    );

    final locationScore = _keywordScore(
      question,
      [
        'market',
        'markets',
        'at',
        'in',
        'o',
        'tai',
        'cho',
      ],
    );

    return farmerScore >= 1 && locationScore >= 1;
  }

  // ============================================================
  // MARKET -> PRODUCT QUESTION
  // ============================================================

  bool _isMarketProductQuestion(String question) {
    if (_containsAny(question, [
      // English
      'what products are sold',
      'which products are sold',
      'what products does the market have',
      'which products does the market have',
      'products at',
      'products in',
      'what is sold at',
      'what can i buy at',

      // Vietnamese
      'cho nay ban gi',
      'cho nay co gi',
      'cho nay ban nhung gi',
      'cho nay co nhung san pham gi',
      'san pham o cho',
      'san pham tai cho',
      'cho ban san pham gi',
    ])) {
      return true;
    }

    final productScore = _keywordScore(
      question,
      [
        'product',
        'products',
        'san pham',
      ],
    );

    final marketScore = _keywordScore(
      question,
      [
        'market',
        'markets',
        'cho',
      ],
    );

    final listScore = _keywordScore(
      question,
      [
        'what',
        'which',
        'sold',
        'have',
        'buy',
        'gi',
        'nhung gi',
      ],
    );

    return productScore >= 1 && marketScore >= 1 && listScore >= 1;
  }

  // ============================================================
  // FIND MARKET
  // ============================================================

  List<Map<String, dynamic>> _findMatchingMarkets(
    String question,
    List<Map<String, dynamic>> markets,
  ) {
    final matches = <_MarketMatch>[];

    for (final market in markets) {
      if (!_isActiveMarket(market)) {
        continue;
      }

      final score = _marketMatchScore(
        question,
        market,
      );

      if (score > 0) {
        matches.add(
          _MarketMatch(
            market: market,
            score: score,
          ),
        );
      }
    }

    matches.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    if (matches.isNotEmpty && matches.first.score >= 60) {
      return [
        matches.first.market,
      ];
    }

    return matches.take(5).map((item) => item.market).toList();
  }

  // ============================================================
  // MARKET MATCH SCORE
  // ============================================================

  int _marketMatchScore(
    String question,
    Map<String, dynamic> market,
  ) {
    final names = <String>[
      _stringValue(market['name']),
      _stringValue(market['name_en']),
      _stringValue(market['id']),
    ]
        .where((name) => name.isNotEmpty)
        .map(_normalize)
        .where((name) => name.isNotEmpty)
        .toSet();

    var bestScore = 0;

    for (final name in names) {
      if (question == name) {
        bestScore = _max(
          bestScore,
          100,
        );
        continue;
      }

      if (_containsWholePhrase(
        question,
        name,
      )) {
        bestScore = _max(
          bestScore,
          80,
        );
      }

      final meaningfulWords = _meaningfulMarketWords(name);

      if (meaningfulWords.isEmpty) {
        continue;
      }

      final allWordsMatched = meaningfulWords.every(
        question.contains,
      );

      if (allWordsMatched) {
        bestScore = _max(
          bestScore,
          70,
        );
        continue;
      }

      var wordScore = 0;

      for (final word in meaningfulWords) {
        if (question.contains(word)) {
          wordScore += 10;
          continue;
        }

        if (word.length >= 4 &&
            _hasPrefixMatch(
              question,
              word,
            )) {
          wordScore += 5;
        }
      }

      bestScore = _max(
        bestScore,
        wordScore,
      );
    }

    return bestScore;
  }

  // ============================================================
  // FIND MARKET BY FARMER
  //
  // farmers[].market_id
  //        ↓
  // markets[].id
  // ============================================================

  List<Map<String, dynamic>> _findMarketsByFarmer(
    String question,
    List<Map<String, dynamic>> farmers,
    List<Map<String, dynamic>> markets,
  ) {
    final matchedFarmers = <_FarmerMatch>[];

    for (final farmer in farmers) {
      if (!_isActiveFarmer(farmer)) {
        continue;
      }

      final score = _farmerMatchScore(
        question,
        farmer,
      );

      if (score > 0) {
        matchedFarmers.add(
          _FarmerMatch(
            farmer: farmer,
            score: score,
          ),
        );
      }
    }

    if (matchedFarmers.isEmpty) {
      return [];
    }

    matchedFarmers.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    final bestScore = matchedFarmers.first.score;

    final bestFarmers = matchedFarmers
        .where(
          (item) => item.score >= bestScore,
        )
        .toList();

    final marketIds = bestFarmers
        .map(
          (item) => _stringValue(
            item.farmer['market_id'],
          ),
        )
        .where(
          (id) => id.isNotEmpty,
        )
        .toSet();

    if (marketIds.isEmpty) {
      return [];
    }

    return markets.where((market) {
      final id = _stringValue(
        market['id'],
      );

      return marketIds.contains(id) && _isActiveMarket(market);
    }).toList();
  }

  // ============================================================
  // FIND MARKET BY PRODUCT
  //
  // products[].market_id
  //        ↓
  // markets[].id
  // ============================================================

  List<Map<String, dynamic>> _findMarketsByProduct(
    String question,
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> markets,
  ) {
    final matchedProducts = <_ProductMatch>[];

    for (final product in products) {
      if (!_isActiveProduct(product)) {
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

    final bestScore = matchedProducts.first.score;

    final bestProducts = matchedProducts
        .where(
          (item) => item.score >= bestScore,
        )
        .toList();

    final marketIds = bestProducts
        .map(
          (item) => _stringValue(
            item.product['market_id'],
          ),
        )
        .where(
          (id) => id.isNotEmpty,
        )
        .toSet();

    if (marketIds.isEmpty) {
      return [];
    }

    return markets.where((market) {
      final id = _stringValue(
        market['id'],
      );

      return marketIds.contains(id) && _isActiveMarket(market);
    }).toList();
  }

  // ============================================================
  // FORMAT MARKETS
  // ============================================================

  String _formatMarkets(
    List<Map<String, dynamic>> markets,
    List<Map<String, dynamic>> farmers,
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    if (markets.isEmpty) {
      return isVietnamese
          ? 'Hiện chưa có thông tin chợ.'
          : 'No market information is currently available.';
    }

    final lines = <String>[];

    for (final market in markets.take(10)) {
      final name = _marketDisplayName(
        market,
        isVietnamese: isVietnamese,
      );

      final address = _stringValue(
        market['address'],
      );

      final openHours = _stringValue(
        market['open_hours'],
      );

      final marketId = _stringValue(
        market['id'],
      );

      final farmerCount = farmers
          .where(
            (farmer) =>
                _stringValue(
                  farmer['market_id'],
                ) ==
                marketId,
          )
          .length;

      final productCount = products
          .where(
            (product) =>
                _stringValue(
                      product['market_id'],
                    ) ==
                    marketId &&
                _isActiveProduct(product),
          )
          .length;

      final details = <String>[];

      if (address.isNotEmpty) {
        details.add(
          isVietnamese ? 'Địa chỉ: $address' : 'Address: $address',
        );
      }

      if (openHours.isNotEmpty) {
        details.add(
          isVietnamese ? 'Giờ mở cửa: $openHours' : 'Open: $openHours',
        );
      }

      if (farmerCount > 0) {
        details.add(
          isVietnamese ? '$farmerCount nông dân' : '$farmerCount farmers',
        );
      }

      if (productCount > 0) {
        details.add(
          isVietnamese ? '$productCount sản phẩm' : '$productCount products',
        );
      }

      if (name.isEmpty) {
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
          ? 'Hiện chưa có thông tin chợ.'
          : 'No market information is currently available.';
    }

    final title = isVietnamese
        ? 'HarvestHub hiện có các chợ:'
        : 'HarvestHub currently has these markets:';

    return '$title\n${lines.join('\n')}';
  }

  // ============================================================
  // FORMAT MARKET ADDRESS
  // ============================================================

  String _formatMarketAddress(
    List<Map<String, dynamic>> markets, {
    required bool isVietnamese,
  }) {
    if (markets.isEmpty) {
      return isVietnamese ? 'Không tìm thấy chợ.' : 'Market not found.';
    }

    final lines = <String>[];

    for (final market in markets.take(5)) {
      final name = _marketDisplayName(
        market,
        isVietnamese: isVietnamese,
      );

      final address = _stringValue(
        market['address'],
      );

      if (name.isEmpty) {
        continue;
      }

      if (address.isEmpty) {
        lines.add(
          isVietnamese
              ? '• $name — Chưa có thông tin địa chỉ.'
              : '• $name — Address information is not available.',
        );
      } else {
        lines.add(
          isVietnamese
              ? '• $name — Địa chỉ: $address'
              : '• $name — Address: $address',
        );
      }
    }

    if (lines.isEmpty) {
      return isVietnamese
          ? 'Chưa có thông tin địa chỉ của chợ.'
          : 'No market address information is currently available.';
    }

    return lines.join('\n');
  }

  // ============================================================
  // FORMAT MARKET OPENING HOURS
  // ============================================================

  String _formatMarketOpeningHours(
    List<Map<String, dynamic>> markets, {
    required bool isVietnamese,
  }) {
    if (markets.isEmpty) {
      return isVietnamese ? 'Không tìm thấy chợ.' : 'Market not found.';
    }

    final lines = <String>[];

    for (final market in markets.take(5)) {
      final name = _marketDisplayName(
        market,
        isVietnamese: isVietnamese,
      );

      final openHours = _stringValue(
        market['open_hours'],
      );

      if (name.isEmpty) {
        continue;
      }

      if (openHours.isEmpty) {
        lines.add(
          isVietnamese
              ? '• $name — Chưa có thông tin giờ mở cửa.'
              : '• $name — Opening hours are not available.',
        );
      } else {
        lines.add(
          isVietnamese
              ? '• $name — Giờ mở cửa: $openHours'
              : '• $name — Open: $openHours',
        );
      }
    }

    if (lines.isEmpty) {
      return isVietnamese
          ? 'Chưa có thông tin giờ mở cửa của chợ.'
          : 'No market opening hours are currently available.';
    }

    return lines.join('\n');
  }

  // ============================================================
  // FORMAT MARKET FARMERS
  // ============================================================

  String _formatMarketFarmers(
    List<Map<String, dynamic>> markets,
    List<Map<String, dynamic>> farmers, {
    required bool isVietnamese,
  }) {
    if (markets.isEmpty) {
      return isVietnamese ? 'Không tìm thấy chợ.' : 'Market not found.';
    }

    final marketIds = markets
        .map(
          (market) => _stringValue(
            market['id'],
          ),
        )
        .where(
          (id) => id.isNotEmpty,
        )
        .toSet();

    final matchedFarmers = farmers.where(
      (farmer) {
        final marketId = _stringValue(
          farmer['market_id'],
        );

        return marketIds.contains(marketId) && _isActiveFarmer(farmer);
      },
    ).toList();

    if (matchedFarmers.isEmpty) {
      return isVietnamese
          ? 'Chưa có nông dân nào được ghi nhận tại chợ này.'
          : 'No farmers are currently recorded at this market.';
    }

    final marketNames = markets
        .map(
          (market) => _marketDisplayName(
            market,
            isVietnamese: isVietnamese,
          ),
        )
        .where(
          (name) => name.isNotEmpty,
        )
        .toList();

    final title = isVietnamese
        ? 'Nông dân tại ${marketNames.join(', ')}:'
        : 'Farmers at ${marketNames.join(', ')}:';

    final lines = matchedFarmers
        .take(10)
        .map(
          (farmer) {
            final name = _farmerDisplayName(
              farmer,
              isVietnamese: isVietnamese,
            );

            return name.isEmpty ? null : '• $name';
          },
        )
        .whereType<String>()
        .toList();

    return '$title\n${lines.join('\n')}';
  }

  // ============================================================
  // FORMAT MARKET PRODUCTS
  // ============================================================

  String _formatMarketProducts(
    List<Map<String, dynamic>> markets,
    List<Map<String, dynamic>> products, {
    required bool isVietnamese,
  }) {
    if (markets.isEmpty) {
      return isVietnamese ? 'Không tìm thấy chợ.' : 'Market not found.';
    }

    final marketIds = markets
        .map(
          (market) => _stringValue(
            market['id'],
          ),
        )
        .where(
          (id) => id.isNotEmpty,
        )
        .toSet();

    final matchedProducts = products.where(
      (product) {
        final marketId = _stringValue(
          product['market_id'],
        );

        return marketIds.contains(marketId) && _isActiveProduct(product);
      },
    ).toList();

    if (matchedProducts.isEmpty) {
      return isVietnamese
          ? 'Chưa có sản phẩm nào được ghi nhận tại chợ này.'
          : 'No active products are currently recorded at this market.';
    }

    final marketNames = markets
        .map(
          (market) => _marketDisplayName(
            market,
            isVietnamese: isVietnamese,
          ),
        )
        .where(
          (name) => name.isNotEmpty,
        )
        .toList();

    final title = isVietnamese
        ? 'Sản phẩm tại ${marketNames.join(', ')}:'
        : 'Products at ${marketNames.join(', ')}:';

    final lines = <String>[];

    for (final product in matchedProducts.take(15)) {
      final name = _productDisplayName(
        product,
        isVietnamese: isVietnamese,
      );

      if (name.isEmpty) {
        continue;
      }

      final price = _numberValue(
        product['price'],
      );

      final stock = _numberValue(
        product['stock'],
      );

      final unit = _stringValue(
        product['unit'],
      );

      final details = <String>[];

      if (price != null) {
        details.add(
          '\$${_formatNumber(price)}'
          '${unit.isNotEmpty ? '/$unit' : ''}',
        );
      }

      if (stock != null) {
        if (stock <= 0) {
          details.add(
            isVietnamese ? 'Hết hàng' : 'Out of stock',
          );
        } else {
          details.add(
            isVietnamese
                ? 'Còn ${_formatNumber(stock)}'
                    '${unit.isNotEmpty ? ' $unit' : ''}'
                : '${_formatNumber(stock)}'
                    '${unit.isNotEmpty ? ' $unit' : ''} available',
          );
        }
      }

      lines.add(
        details.isEmpty ? '• $name' : '• $name — ${details.join('; ')}',
      );
    }

    return '$title\n${lines.join('\n')}';
  }

  // ============================================================
  // MARKET DISPLAY NAME
  // ============================================================

  String _marketDisplayName(
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
  // FARMER DISPLAY NAME
  // ============================================================

  String _farmerDisplayName(
    Map<String, dynamic> farmer, {
    required bool isVietnamese,
  }) {
    final nameVi = _stringValue(
      farmer['farm_name'],
    );

    final nameEn = _stringValue(
      farmer['farm_name_en'],
    );

    final genericNameEn = _stringValue(
      farmer['name_en'],
    );

    final englishName = _stringValue(
      farmer['english_name'],
    );

    if (isVietnamese) {
      if (nameVi.isNotEmpty) {
        return nameVi;
      }

      final genericName = _stringValue(
        farmer['name'],
      );

      if (genericName.isNotEmpty) {
        return genericName;
      }

      if (nameEn.isNotEmpty) {
        return nameEn;
      }

      return genericNameEn;
    }

    if (nameEn.isNotEmpty) {
      return nameEn;
    }

    if (englishName.isNotEmpty) {
      return englishName;
    }

    if (genericNameEn.isNotEmpty) {
      return genericNameEn;
    }

    return nameVi;
  }

  // ============================================================
  // PRODUCT DISPLAY NAME
  // ============================================================

  String _productDisplayName(
    Map<String, dynamic> product, {
    required bool isVietnamese,
  }) {
    final nameVi = _stringValue(
      product['name'],
    );

    final nameEn = _stringValue(
      product['name_en'],
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
  // FIND FARMER MATCH
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
        .where(
          (name) => name.isNotEmpty,
        )
        .map(_normalize)
        .where(
          (name) => name.isNotEmpty,
        )
        .toSet();

    var bestScore = 0;

    for (final name in names) {
      if (question == name) {
        bestScore = _max(
          bestScore,
          100,
        );
        continue;
      }

      if (_containsWholePhrase(
        question,
        name,
      )) {
        bestScore = _max(
          bestScore,
          80,
        );
      }

      final words = _meaningfulWords(name);

      if (words.isEmpty) {
        continue;
      }

      if (words.every(question.contains)) {
        bestScore = _max(
          bestScore,
          70,
        );
        continue;
      }

      var score = 0;

      for (final word in words) {
        if (question.contains(word)) {
          score += 10;
        } else if (word.length >= 4 &&
            _hasPrefixMatch(
              question,
              word,
            )) {
          score += 5;
        }
      }

      bestScore = _max(
        bestScore,
        score,
      );
    }

    return bestScore;
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
        .where(
          (name) => name.isNotEmpty,
        )
        .map(_normalize)
        .where(
          (name) => name.isNotEmpty,
        )
        .toSet();

    var bestScore = 0;

    for (final name in names) {
      if (question == name) {
        bestScore = _max(
          bestScore,
          100,
        );
        continue;
      }

      if (_containsWholePhrase(
        question,
        name,
      )) {
        bestScore = _max(
          bestScore,
          90,
        );
      }

      final words = _meaningfulProductWords(
        name,
      );

      if (words.isEmpty) {
        continue;
      }

      if (words.every(question.contains)) {
        bestScore = _max(
          bestScore,
          70,
        );
        continue;
      }

      var score = 0;

      for (final word in words) {
        if (question.contains(word)) {
          score += 10;
        } else if (word.length >= 4 &&
            _hasPrefixMatch(
              question,
              word,
            )) {
          score += 5;
        }
      }

      bestScore = _max(
        bestScore,
        score,
      );
    }

    return bestScore;
  }

  // ============================================================
  // ACTIVE MARKET
  // ============================================================

  bool _isActiveMarket(
    Map<String, dynamic> market,
  ) {
    final rawActive = market['is_active'];

    if (rawActive == null) {
      return true;
    }

    return rawActive == true ||
        rawActive == 1 ||
        rawActive == '1' ||
        rawActive == 'true';
  }

  // ============================================================
  // ACTIVE FARMER
  // ============================================================

  bool _isActiveFarmer(
    Map<String, dynamic> farmer,
  ) {
    final status = _normalize(
      _stringValue(farmer['status']),
    );

    if (status.isEmpty) {
      return true;
    }

    return status != 'rejected' && status != 'inactive';
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

  // ============================================================
  // MEANINGFUL MARKET WORDS
  // ============================================================

  List<String> _meaningfulMarketWords(
    String value,
  ) {
    const genericWords = {
      'market',
      'markets',
      'cho',
      'nong',
      'san',
      'nong san',
      'the',
      'of',
    };

    return value
        .split(RegExp(r'\s+'))
        .map((word) => word.trim())
        .where(
          (word) => word.isNotEmpty,
        )
        .where(
          (word) => !genericWords.contains(word),
        )
        .where(
          (word) => word.length >= 2,
        )
        .toList();
  }

  // ============================================================
  // MEANINGFUL FARMER WORDS
  // ============================================================

  List<String> _meaningfulWords(
    String value,
  ) {
    const genericWords = {
      'trang',
      'trai',
      'nong',
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
        .where(
          (word) => word.isNotEmpty,
        )
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

  List<String> _meaningfulProductWords(
    String value,
  ) {
    const genericWords = {
      'organic',
      'fresh',
      'high',
      'quality',
      'product',
      'products',
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
        .where(
          (word) => word.isNotEmpty,
        )
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

    final words = question.split(
      RegExp(r'\s+'),
    );

    for (final keyword in keywords) {
      final normalizedKeyword = _normalize(
        keyword,
      );

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

      if (words.contains(normalizedKeyword)) {
        score += 1;
      }
    }

    return score;
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
      'dia chi',
      'vi tri',
      'gio mo cua',
      'gio dong cua',
      'cho',
      'cho nao',
      'cho nong san',
      'o dau',
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
  // FORMAT NUMBER
  // ============================================================

  String _formatNumber(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (match) => ',',
          );
    }

    return value.toString();
  }

  // ============================================================
  // NORMALIZE
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
        final normalizedValue = _normalize(
          value,
        );

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
// MARKET MATCH
// ============================================================

class _MarketMatch {
  const _MarketMatch({
    required this.market,
    required this.score,
  });

  final Map<String, dynamic> market;
  final int score;
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
