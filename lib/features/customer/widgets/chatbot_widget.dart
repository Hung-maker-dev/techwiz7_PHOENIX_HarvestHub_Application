import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/api/customer_api.dart';

typedef ChatLine = ({String text, bool user});

class CustomerChatState {
  const CustomerChatState({
    this.messages = const [],
    this.isOpen = false,
    this.isTyping = false,
  });

  final List<ChatLine> messages;
  final bool isOpen;
  final bool isTyping;

  CustomerChatState copyWith({
    List<ChatLine>? messages,
    bool? isOpen,
    bool? isTyping,
  }) =>
      CustomerChatState(
        messages: messages ?? this.messages,
        isOpen: isOpen ?? this.isOpen,
        isTyping: isTyping ?? this.isTyping,
      );
}

class CustomerChatController extends StateNotifier<CustomerChatState> {
  CustomerChatController(this._api) : super(const CustomerChatState());

  final CustomerApi _api;
  final String _conversationId =
      DateTime.now().microsecondsSinceEpoch.toString();

  void open() => state = state.copyWith(isOpen: true);
  void close() => state = state.copyWith(isOpen: false);

  Future<void> send(String message, String language) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || state.isTyping) return;
    state = state.copyWith(
      messages: [...state.messages, (text: trimmed, user: true)],
      isTyping: true,
    );
    try {
      final answer = await _api.sendChatMessage(
        message: trimmed,
        conversationId: _conversationId,
        language: language,
      );
      state = state.copyWith(
        messages: [...state.messages, (text: answer, user: false)],
        isTyping: false,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          (
            text: 'account.chatbot.error'.tr(args: [error.message]),
            user: false,
          ),
        ],
        isTyping: false,
      );
    } catch (error, stackTrace) {
      debugPrint('Customer chatbot request failed: $error\n$stackTrace');
      state = state.copyWith(
        messages: [
          ...state.messages,
          (
            text: 'account.chatbot.error'.tr(args: ['Unexpected error']),
            user: false,
          ),
        ],
        isTyping: false,
      );
    }
  }
}

final customerChatProvider =
    StateNotifierProvider<CustomerChatController, CustomerChatState>(
  (ref) => CustomerChatController(ref.watch(customerApiProvider)),
);

class ChatbotWidget extends ConsumerWidget {
  const ChatbotWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton(
        heroTag: 'customer_chatbot',
        tooltip: 'account.chatbot.tooltip'.tr(),
        onPressed: () {
          ref.read(customerChatProvider.notifier).open();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const _ChatPanel(),
          ).whenComplete(() {
            ref.read(customerChatProvider.notifier).close();
          });
        },
        child: const Icon(Icons.chat_outlined),
      );
}

class _ChatPanel extends ConsumerStatefulWidget {
  const _ChatPanel();

  @override
  ConsumerState<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<_ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _input.text.trim();
    if (message.isEmpty || ref.read(customerChatProvider).isTyping) return;
    _input.clear();
    await ref.read(customerChatProvider.notifier).send(
          message,
          context.locale.languageCode,
        );
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: _buildPanel(context),
        ),
      );

  Widget _buildPanel(BuildContext context) {
    final state = ref.watch(customerChatProvider);
    return Column(
      children: [
        const SizedBox(height: 12),
        Text('account.chatbot.title'.tr(),
            style: Theme.of(context).textTheme.titleMedium),
        const Divider(),
        Expanded(
          child: state.messages.isEmpty
              ? Center(
                  child: Text(
                    'account.chatbot.empty'.tr(),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length) {
                      return const _TypingDots();
                    }
                    final message = state.messages[index];
                    return Align(
                      alignment: message.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.user
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.text,
                          style: message.user
                              ? const TextStyle(color: Colors.white)
                              : null,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 180.ms)
                          .slideY(begin: 0.04, end: 0, duration: 180.ms),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'account.chatbot.hint'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: state.isTyping ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (index) => const Padding(
              padding: EdgeInsets.all(3),
              child: CircleAvatar(radius: 4),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .fadeIn(delay: (index * 120).ms)
                .then()
                .fadeOut(),
          ),
        ),
      );
}
