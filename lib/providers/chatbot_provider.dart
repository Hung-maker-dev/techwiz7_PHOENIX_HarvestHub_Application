import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../features/customer/data/api/chatbot_api.dart';
import '../models/chat_message.dart';

// STATE

class ChatbotState {
  final List<ChatMessage> messages;
  final bool isOpen;
  final bool isTyping;

  const ChatbotState({
    this.messages = const [],
    this.isOpen = false,
    this.isTyping = false,
  });

  ChatbotState copyWith({
    List<ChatMessage>? messages,
    bool? isOpen,
    bool? isTyping,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      isOpen: isOpen ?? this.isOpen,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

// CONTROLLER

class ChatbotController extends StateNotifier<ChatbotState> {
  ChatbotController(this._api) : super(const ChatbotState());

  final ChatbotApi _api;

  final String conversationId =
      DateTime.now().millisecondsSinceEpoch.toString();

  static const Duration _minimumTypingDuration = Duration(milliseconds: 3500);

  static const String _emptyReplyText =
      'Sorry, I do not have a suitable answer right now.';

  static const String _errorReplyText =
      'Sorry, the assistant is currently unavailable. Please try again later.';

  void open() {
    state = state.copyWith(isOpen: true);
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }

  Future<void> send(String text, {bool isVietnamese = false}) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty || state.isTyping) return;

    // 1. Hiện tin nhắn của người dùng và bật trạng thái "đang nhập"
    _addMessage(
      ChatMessage(id: _newId(), text: trimmed, isUser: true),
      isTyping: true,
    );

    final startedAt = DateTime.now();

    // 2. Lấy câu trả lời (lỗi thì dùng câu báo lỗi)
    String reply;
    try {
      reply = (await _api.sendMessage(
        message: trimmed,
        conversationId: conversationId,
        isVietnamese: isVietnamese,
      ))
          .trim();

      if (reply.isEmpty) reply = _emptyReplyText;
    } catch (e) {
      debugPrint('CHATBOT CONTROLLER ERROR: $e');
      reply = _errorReplyText;
    }

    // 3. Đợi cho đủ thời gian "đang nhập" tối thiểu
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _minimumTypingDuration) {
      await Future.delayed(_minimumTypingDuration - elapsed);
    }

    if (!mounted) return;

    _addMessage(
      ChatMessage(id: _newId(), text: reply, isUser: false),
      isTyping: false,
    );
  }

  void clearChat() {
    _api.clearConversation(conversationId);
    state = const ChatbotState();
  }

  void _addMessage(ChatMessage message, {required bool isTyping}) {
    state = state.copyWith(
      messages: [...state.messages, message],
      isTyping: isTyping,
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

final chatbotApiProvider = Provider<ChatbotApi>((ref) {
  final dio = ref.watch(dioProvider);

  return ChatbotApi(dio, '');
});

final chatbotProvider =
    StateNotifierProvider<ChatbotController, ChatbotState>((ref) {
  return ChatbotController(ref.watch(chatbotApiProvider));
});
