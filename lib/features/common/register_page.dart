import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/app_button.dart';
import '../../shared_widgets/app_text_field.dart';
import '../../shared_widgets/app_toast.dart';

/// Nội dung form đăng ký — được `login_page.dart` chuyển vào bằng
/// AnimatedSwitcher crossfade 150ms, không phải route riêng
/// (route /auth dùng chung cho cả đăng nhập và đăng ký, theo mục 1.2).
class RegisterForm extends StatefulWidget {
  const RegisterForm({
    super.key,
    required this.authRepository,
    required this.onSwitchToLogin,
  });

  final AuthRepository authRepository;
  final VoidCallback onSwitchToLogin;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });

    if (_password.text != _confirmPassword.text) {
      setState(() => _confirmError = 'common.auth.errorPasswordMismatch'.tr());
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.authRepository.registerWithEmail(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
      );
    } on AuthFailure catch (e) {
      setState(() {
        if (e.i18nKey == 'common.auth.errorEmailInUse') {
          _emailError = e.i18nKey.tr();
        } else if (e.i18nKey == 'common.auth.errorWeakPassword') {
          _passwordError = e.i18nKey.tr();
        } else {
          Toast.error(e.i18nKey.tr());
        }
      });
    } catch (_) {
      Toast.error('common.auth.errorGeneric'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('register-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('common.auth.registerTitle'.tr(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpace.space3),
        AppTextField(label: 'common.auth.fullName'.tr(), controller: _fullName),
        const SizedBox(height: AppSpace.space2),
        AppTextField(
          label: 'common.auth.email'.tr(),
          controller: _email,
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpace.space2),
        AppTextField(
          label: 'common.auth.password'.tr(),
          controller: _password,
          errorText: _passwordError,
          obscureText: true,
        ),
        const SizedBox(height: AppSpace.space2),
        AppTextField(
          label: 'common.auth.confirmPassword'.tr(),
          controller: _confirmPassword,
          errorText: _confirmError,
          obscureText: true,
        ),
        const SizedBox(height: AppSpace.space3),
        const SizedBox(height: AppSpace.space3),
        AppButton(
          label: 'common.auth.registerButton'.tr(),
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpace.space2),
        Center(
          child: TextButton(
            onPressed: widget.onSwitchToLogin,
            child: Text(
              '${'common.auth.haveAccount'.tr()} ${'common.auth.switchToLogin'.tr()}',
            ),
          ),
        ),
      ],
    );
  }
}
