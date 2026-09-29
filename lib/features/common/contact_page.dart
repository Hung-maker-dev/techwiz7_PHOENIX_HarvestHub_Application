import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/app_button.dart';
import '../../shared_widgets/app_text_area.dart';
import '../../shared_widgets/app_text_field.dart';
import '../../shared_widgets/app_toast.dart';

class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/contact-messages', data: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'message': _message.text.trim(),
      });
      if (mounted) {
        Toast.success('common.contact.successToast'.tr());
        _name.clear();
        _email.clear();
        _message.clear();
      }
    } catch (_) {
      if (mounted) Toast.error('common.auth.errorGeneric'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('common.contact.title'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                  label: 'common.contact.name'.tr(), controller: _name),
              const SizedBox(height: AppSpace.space2),
              AppTextField(
                label: 'common.contact.email'.tr(),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpace.space2),
              AppTextArea(
                  label: 'common.contact.message'.tr(), controller: _message),
              const SizedBox(height: AppSpace.space3),
              AppButton(
                label: 'common.contact.submit'.tr(),
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
