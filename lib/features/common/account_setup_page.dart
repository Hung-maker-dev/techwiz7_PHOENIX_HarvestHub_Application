import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/app_button.dart';

class AccountSetupPage extends ConsumerStatefulWidget {
  const AccountSetupPage({super.key});

  @override
  ConsumerState<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends ConsumerState<AccountSetupPage> {
  bool _applyAsFarmer = false;
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .completeAccountSetup(applyAsFarmer: _applyAsFarmer);
      if (!mounted) return;
      context.go(switch (result) {
        'admin' => '/admin',
        'farmer_application' => '/farmer-application',
        _ => '/home',
      });
    } on AuthFailure catch (error) {
      _showError(error.i18nKey.tr());
    } catch (error, stackTrace) {
      debugPrint('Account setup failed: $error\n$stackTrace');
      _showError('common.accountSetup.failed'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('common.accountSetup.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'common.home.logout'.tr(),
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.space3),
          children: [
            Text(
              'common.accountSetup.subtitle'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.space2),
            Text('common.accountSetup.existingAccountNote'.tr()),
            const SizedBox(height: AppSpace.space3),
            RadioGroup<bool>(
              groupValue: _applyAsFarmer,
              onChanged: (value) {
                if (!_saving && value != null) {
                  setState(() => _applyAsFarmer = value);
                }
              },
              child: Column(
                children: [
                  Card(
                    child: RadioListTile<bool>(
                      value: false,
                      title: Text('common.accountSetup.customer'.tr()),
                      subtitle:
                          Text('common.accountSetup.customerDescription'.tr()),
                    ),
                  ),
                  Card(
                    child: RadioListTile<bool>(
                      value: true,
                      title: Text('common.accountSetup.farmer'.tr()),
                      subtitle:
                          Text('common.accountSetup.farmerDescription'.tr()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.space3),
            AppButton(
              label: 'common.accountSetup.continue'.tr(),
              loading: _saving,
              onPressed: _continue,
            ),
          ],
        ),
      ),
    );
  }
}
