import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'chatbot/chatbot_budget_handler.dart';
import 'chatbot/chatbot_farmer_handler.dart';
import 'chatbot/chatbot_market_handler.dart';
import 'chatbot/chatbot_meal_handler.dart';
import 'chatbot/chatbot_product_handler.dart';

String get kChatbotApiBaseUrl {
  final fromEnv = dotenv.env['CHATBOT_API_BASE_URL']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return 'https://harvesthub.infinityfree.io/api';
}

class ChatbotApi {
  ChatbotApi(this._dio, this._apiKey)
      : _chatbotDio = Dio(
          BaseOptions(
            baseUrl: kChatbotApiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ),
        _mealHandler = ChatbotMealHandler(apiKey: _apiKey);

  // ignore: unused_field
  final Dio _dio;

  // ignore: unused_field
  final String _apiKey;

  /// Dio riêng gọi /chatbot/context.php
  final Dio _chatbotDio;

  // Handlers
  final ChatbotProductHandler _productHandler = ChatbotProductHandler();
  final ChatbotFarmerHandler _farmerHandler = ChatbotFarmerHandler();
  final ChatbotMarketHandler _marketHandler = ChatbotMarketHandler();
  final ChatbotBudgetHandler _budgetHandler = ChatbotBudgetHandler();
  final ChatbotMealHandler _mealHandler;

  static const String _contextPath = '/chatbot/context.php';
  static const Duration _contextCacheDuration = Duration(seconds: 30);

  Map<String, dynamic>? _cachedContext;
  DateTime? _contextCachedAt;

  // ===========================  =================================
  // MAIN CHAT FUNCTION
  // ============================================================

  Future<String> sendMessage({
    required String message,
    required String conversationId,
    bool? isVietnamese,
  }) async {
    final question = message.trim();
    if (question.isEmpty) return '';

    debugPrint('CHATBOT API: message = $question');

    final replyInVietnamese = isVietnamese ?? _isVietnamese(question);

    // 1. Lấy dữ liệu từ PHP + MySQL
    final context = await _getContext();

    if (context == null) {
      debugPrint('CHATBOT API: context unavailable');

      final commonReply =
          _answerCommonQuestion(question, isVietnamese: replyInVietnamese);
      if (commonReply != null) return commonReply;

      return replyInVietnamese
          ? 'Xin lỗi, tôi không thể tải dữ liệu HarvestHub lúc này. '
              'Vui lòng thử lại sau.'
          : 'Sorry, I could not load the current HarvestHub data. '
              'Please try again later.';
    }

    debugPrint('CHATBOT API: context loaded successfully');

    // 2. Các handler trả lời từ dữ liệu
    final dataReply = await _answerFromHarvestHubData(
      question,
      context,
      isVietnamese: replyInVietnamese,
    );
    if (dataReply != null && dataReply.trim().isNotEmpty) {
      debugPrint('CHATBOT API: handler returned answer');
      return dataReply;
    }

    // 3. Câu hỏi thông thường (chào hỏi, cách đặt hàng...)
    final commonReply =
        _answerCommonQuestion(question, isVietnamese: replyInVietnamese);
    if (commonReply != null) return commonReply;

    // 4. Không hiểu câu hỏi
    debugPrint('CHATBOT API: no handler matched');
    return replyInVietnamese
        ? 'Mình chưa hiểu câu hỏi này. Bạn thử hỏi về sản phẩm, giá, '
            'nông dân, chợ hoặc ngân sách nhé. Ví dụ: '
            '"Bạn có sản phẩm gì?" hoặc "Giá gạo ST25 bao nhiêu?"'
        : 'I did not understand that. Try asking about products, prices, '
            'farmers, markets or budget. For example: '
            '"What products do you have?"';
  }

  // ============================================================
  // GET CONTEXT FROM PHP API
  // ============================================================

  Future<Map<String, dynamic>?> _getContext() async {
    final now = DateTime.now();

    if (_cachedContext != null &&
        _contextCachedAt != null &&
        now.difference(_contextCachedAt!) < _contextCacheDuration) {
      debugPrint('CHATBOT: using cached context');
      return _cachedContext;
    }

    debugPrint('CHATBOT: loading context...');
    debugPrint('CHATBOT URL: $kChatbotApiBaseUrl$_contextPath');

    try {
      final response = await _chatbotDio.get<String>(
        _contextPath,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'application/json'},
        ),
      );

      final raw = response.data ?? '';
      debugPrint('CHATBOT CONTEXT STATUS: ${response.statusCode}');

      dynamic body;
      try {
        body = jsonDecode(raw);
      } catch (e) {
        debugPrint('CHATBOT CONTEXT JSON DECODE ERROR: $e');
        return null;
      }

      if (body is! Map) {
        debugPrint('CHATBOT CONTEXT ERROR: response is not Map');
        return null;
      }

      if (body['success'] != true) {
        debugPrint('CHATBOT CONTEXT ERROR: ${body['message']}');
        return null;
      }

      final rawContext = body['data'];
      if (rawContext is! Map) {
        debugPrint('CHATBOT CONTEXT ERROR: data is not Map');
        return null;
      }

      final categories = rawContext['categories'];
      final products = rawContext['products'];

      if (categories is! List || products is! List) {
        debugPrint('CHATBOT CONTEXT ERROR: categories/products invalid');
        return null;
      }

      final context = <String, dynamic>{
        'categories': categories,
        'products': products,
        'farmers':
            rawContext['farmers'] is List ? rawContext['farmers'] : <dynamic>[],
        'markets':
            rawContext['markets'] is List ? rawContext['markets'] : <dynamic>[],
      };

      _cachedContext = context;
      _contextCachedAt = DateTime.now();

      debugPrint(
        'CHATBOT: categories=${categories.length}, '
        'products=${products.length}, '
        'farmers=${(context['farmers'] as List).length}, '
        'markets=${(context['markets'] as List).length}',
      );

      return context;
    } on DioException catch (error) {
      debugPrint('CHATBOT CONTEXT DIO ERROR: ${error.type}');
      debugPrint('CHATBOT CONTEXT DIO MESSAGE: ${error.message}');
      return null;
    } catch (error) {
      debugPrint('CHATBOT CONTEXT ERROR: $error');
      return null;
    }
  }

  // ============================================================
  // HANDLER ORCHESTRATOR
  // Thứ tự: Budget → Meal → Farmer → Market → Product
  // ============================================================

  Future<String?> _answerFromHarvestHubData(
      String question, Map<String, dynamic> context,
      {required bool isVietnamese}) async {
    final budgetAnswer = _budgetHandler.answer(
      question,
      context,
      isVietnamese: isVietnamese,
    );
    if (budgetAnswer != null) {
      debugPrint('CHATBOT HANDLER: BudgetHandler');
      return budgetAnswer;
    }

    final mealAnswer = await _mealHandler.answer(
      question,
      context,
      isVietnamese: isVietnamese,
    );
    if (mealAnswer != null) {
      debugPrint('CHATBOT HANDLER: MealHandler');
      return mealAnswer;
    }

    final farmerReply = _farmerHandler.answer(
      question,
      context,
      useVietnamese: isVietnamese,
    );
    if (farmerReply != null) {
      debugPrint('CHATBOT HANDLER: FarmerHandler');
      return farmerReply;
    }

    final marketReply = _marketHandler.answer(
      question,
      context,
      useVietnamese: isVietnamese,
    );
    if (marketReply != null) {
      debugPrint('CHATBOT HANDLER: MarketHandler');
      return marketReply;
    }

    final productReply = _productHandler.answer(
      question,
      context,
      useVietnamese: isVietnamese,
    );
    if (productReply != null) {
      debugPrint('CHATBOT HANDLER: ProductHandler');
    }

    return productReply;
  }

  // ============================================================
  // COMMON QUESTIONS
  // ============================================================

  String? _answerCommonQuestion(
    String question, {
    required bool isVietnamese,
  }) {
    final q = _normalize(question);

    if (_isPureGreeting(q)) {
      return isVietnamese
          ? 'Xin chào! 👋\n'
              'Tôi là trợ lý HarvestHub. Tôi có thể giúp bạn tìm sản phẩm, '
              'giá, tồn kho và danh mục.'
          : 'Hello! 👋\n'
              'I am the HarvestHub assistant. I can help you find products, '
              'prices, stock and categories.';
    }

    if (_containsAny(q, [
      'how to order',
      'how do i order',
      'how to buy',
      'how can i buy',
      'place an order',
      'dat hang',
      'mua hang',
      'mua san pham',
      'cach mua',
      'cach dat hang',
    ])) {
      return isVietnamese
          ? 'Bạn có thể chọn sản phẩm trên HarvestHub, thêm vào giỏ hàng '
              'và sau đó đặt hàng.'
          : 'You can choose a product on HarvestHub, add it to your cart '
              'and then place your order.';
    }

    if (_containsAny(q, [
      'what is harvesthub',
      'tell me about harvesthub',
      'about harvesthub',
      'harvesthub la gi',
      'gioi thieu harvesthub',
      'ung dung la gi',
      'app la gi',
    ])) {
      return isVietnamese
          ? 'HarvestHub là nền tảng kết nối người dùng với các sản phẩm '
              'nông sản địa phương.'
          : 'HarvestHub is a marketplace that connects users with local '
              'farm products.';
    }

    if (_containsAny(q, ['thank you', 'thanks', 'cam on'])) {
      return isVietnamese
          ? 'Không có gì! 😊 Tôi luôn sẵn sàng hỗ trợ bạn.'
          : 'You are welcome! 😊 I am always happy to help.';
    }

    return null;
  }

  bool _isPureGreeting(String text) {
    if (text.isEmpty) return false;

    const greetings = [
      'hello',
      'hi',
      'hey',
      'good morning',
      'good afternoon',
      'good evening',
      'xin chao',
      'chao ban',
      'chao',
    ];

    if (!_containsAny(text, greetings)) return false;

    return !_containsAny(text, [
      'price',
      'product',
      'products',
      'vegetable',
      'vegetables',
      'fruit',
      'fruits',
      'rice',
      'stock',
      'category',
      'order',
      'gia',
      'san pham',
      'rau',
      'trai cay',
      'gao',
      'ton kho',
      'danh muc',
      'tim',
    ]);
  }

  // ============================================================
  // VIETNAMESE DETECTION
  // ============================================================

  bool _isVietnamese(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return false;

    // Có dấu tiếng Việt
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

    // Tiếng Việt không dấu
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
    ];

    return _containsAny(normalized, vietnameseWords);
  }

  String _normalize(String text) {
    var result = text.toLowerCase().trim();

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
        result = result.replaceAll(ch, base);
      }
    });

    return result
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsAny(String text, List<String> values) {
    return values.any(text.contains);
  }

  void clearConversation(String conversationId) {}

  void clearAllConversations() {}

  void clearContextCache() {
    _cachedContext = null;
    _contextCachedAt = null;
  }
}
