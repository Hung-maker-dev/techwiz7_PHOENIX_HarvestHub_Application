import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/app_button.dart';
import '../../shared_widgets/app_text_field.dart';
import '../../shared_widgets/app_toast.dart';
import '../../shared_widgets/empty_state.dart';

/// 1.3 Quên mật khẩu — route `/auth/forgot-password`.
/// Sau khi gửi: form chuyển thành thông báo dạng empty_state, luôn hiện
/// cùng một thông điệp bất kể email có tồn tại hay không (chống dò email).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) Toast.error('common.auth.errorGeneric'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('common.forgotPassword.title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.space3),
          child: AnimatedSwitcher(
            duration: AppDurations.standard,
            switchInCurve: AppCurves.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: _sent ? _buildSent(context) : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'common.forgotPassword.instruction'.tr(),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.space3),
        AppTextField(
          label: 'common.auth.email'.tr(),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpace.space3),
        AppButton(
          label: 'common.forgotPassword.submit'.tr(),
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildSent(BuildContext context) {
    return Center(
      key: const ValueKey('sent'),
      child: EmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'common.forgotPassword.sentMessage'.tr(),
        actionLabel: 'common.forgotPassword.backToLogin'.tr(),
        onAction: () => Navigator.of(context).pop(),
      ),
    );
  }
}
