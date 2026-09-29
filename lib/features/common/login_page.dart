import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/notifications/firebase_push_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/app_button.dart';
import '../../shared_widgets/app_text_field.dart';
import '../../shared_widgets/app_toast.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    final authRepository = ref.watch(authRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.space3),
          child: AnimatedSwitcher(
            duration: AppDurations.micro,
            switchInCurve: AppCurves.easeOut,
            switchOutCurve: AppCurves.easeIn,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _showRegister
                ? RegisterForm(
                    key: const ValueKey('register'),
                    authRepository: authRepository,
                    onSwitchToLogin: () =>
                        setState(() => _showRegister = false),
                  )
                : _LoginForm(
                    key: const ValueKey('login'),
                    authRepository: authRepository,
                    onSwitchToRegister: () =>
                        setState(() => _showRegister = true),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm(
      {super.key,
      required this.authRepository,
      required this.onSwitchToRegister});
  final AuthRepository authRepository;
  final VoidCallback onSwitchToRegister;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _formError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _formError = null;
      _loading = true;
    });
    try {
      await widget.authRepository
          .loginWithEmail(_email.text.trim(), _password.text);
      await _navigateAfterSignIn();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _formError = e.i18nKey.tr());
    } catch (error, stackTrace) {
      debugPrint('Could not finish email sign-in: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _formError =
              'Đăng nhập Firebase thành công nhưng chưa xác minh được tài khoản '
                  'với máy chủ. Kiểm tra API_BASE_URL và PHP server rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _navigateAfterSignIn() async {
    final role = await widget.authRepository.fetchCurrentRole();
    if (!mounted) return;
    context.go(switch (role) {
      null => '/account-setup',
      'admin' => '/admin',
      'farmer' => '/farmer/dashboard',
      _ => '/home',
    });
    unawaited(
      ref
          .read(firebasePushServiceProvider)
          .requestPermissionAndRegister()
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint(
            'Could not request notification permission after sign-in: $error\n$stackTrace');
      }),
    );
  }

  Future<void> _submitGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final signedIn = await widget.authRepository.loginWithGoogle();
      if (signedIn) await _navigateAfterSignIn();
    } on AuthFailure catch (e) {
      Toast.error(e.i18nKey.tr());
    } catch (error, stackTrace) {
      debugPrint('Could not finish Google sign-in: $error\n$stackTrace');
      Toast.error('common.auth.errorGeneric'.tr());
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('login-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('common.auth.loginTitle'.tr(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpace.space3),
        AppTextField(
          label: 'common.auth.email'.tr(),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpace.space2),
        AppTextField(
            label: 'common.auth.password'.tr(),
            controller: _password,
            obscureText: true),
        if (_formError != null) ...[
          const SizedBox(height: AppSpace.space1),
          Text(_formError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13)),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/auth/forgot-password'),
            child: Text('common.auth.forgotPassword'.tr()),
          ),
        ),
        const SizedBox(height: AppSpace.space2),
        AppButton(
            label: 'common.auth.loginButton'.tr(),
            loading: _loading,
            onPressed: _submit),
        const SizedBox(height: AppSpace.space2),
        const Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('OR'),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: AppSpace.space2),
        AppButton(
          label: 'common.auth.continueWithGoogle'.tr(),
          variant: AppButtonVariant.secondary,
          icon: Icons.g_mobiledata,
          loading: _googleLoading,
          onPressed: _submitGoogle,
        ),
        const SizedBox(height: AppSpace.space2),
        Center(
          child: TextButton(
            onPressed: widget.onSwitchToRegister,
            child: Text(
                '${'common.auth.noAccount'.tr()} ${'common.auth.switchToRegister'.tr()}'),
          ),
        ),
      ],
    );
  }
}
