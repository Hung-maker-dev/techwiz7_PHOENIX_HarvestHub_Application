import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/accordion_group.dart';
import '../../shared_widgets/app_button.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/app_text_field.dart';

class FaqPage extends ConsumerStatefulWidget {
  const FaqPage({super.key});

  @override
  ConsumerState<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends ConsumerState<FaqPage> {
  final _question = TextEditingController();
  bool _loading = false;
  String? _answer;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _askAi(BuildContext context) async {
    final question = _question.text.trim();
    if (question.isEmpty) {
      setState(() => _answer = 'common.faq.aiEmpty'.tr());
      return;
    }

    setState(() {
      _loading = true;
      _answer = null;
    });
    try {
      final response = await ref.read(dioProvider).post(
        '/api/faq/ask',
        data: {
          'question': question,
          'language': context.locale.languageCode,
        },
      );
      if (mounted) {
        setState(() => _answer = response.data['answer'] as String?);
      }
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _answer = error.response?.statusCode == 503
            ? 'common.faq.aiUnavailable'.tr()
            : 'common.faq.aiError'.tr();
      });
    } catch (_) {
      if (mounted) setState(() => _answer = 'common.faq.aiError'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static List<_FaqGroup> _groups(BuildContext context) => [
        _FaqGroup(
          topic: 'common.faq.purchaseTopic'.tr(),
          items: [
            AccordionItemData(
              title: 'common.faq.orderHow'.tr(),
              body: 'common.faq.orderHowAnswer'.tr(),
            ),
            AccordionItemData(
              title: 'common.faq.cancelOrder'.tr(),
              body: 'common.faq.cancelOrderAnswer'.tr(),
            ),
          ],
        ),
        _FaqGroup(
          topic: 'common.faq.farmerTopic'.tr(),
          items: [
            AccordionItemData(
              title: 'common.faq.farmerSignup'.tr(),
              body: 'common.faq.farmerSignupAnswer'.tr(),
            ),
          ],
        ),
        _FaqGroup(
          topic: 'common.faq.accountTopic'.tr(),
          items: [
            AccordionItemData(
              title: 'common.faq.forgotPassword'.tr(),
              body: 'common.faq.forgotPasswordAnswer'.tr(),
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final groups = _groups(context);
    return Scaffold(
      appBar: AppBar(title: Text('common.faq.title'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.space3),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'common.faq.aiTitle'.tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: AppSpace.space2),
                  AppTextField(
                    label: 'common.faq.aiHint'.tr(),
                    controller: _question,
                    onSubmitted: (_) => _askAi(context),
                  ),
                  const SizedBox(height: AppSpace.space2),
                  AppButton(
                    label: 'common.faq.aiButton'.tr(),
                    loading: _loading,
                    icon: Icons.auto_awesome,
                    onPressed: () => _askAi(context),
                  ),
                  if (_answer != null) ...[
                    const SizedBox(height: AppSpace.space2),
                    Text(_answer!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.space3),
            ...groups.expand(
              (group) => [
                Text(
                  group.topic,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpace.space1),
                AccordionGroup(items: group.items),
                const SizedBox(height: AppSpace.space3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqGroup {
  const _FaqGroup({required this.topic, required this.items});
  final String topic;
  final List<AccordionItemData> items;
}
