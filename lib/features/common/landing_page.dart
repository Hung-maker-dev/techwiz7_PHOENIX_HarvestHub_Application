import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/app_card.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.space4),
              const _Hero(),
              const SizedBox(height: AppSpace.space4),
              _RoleCard(
                icon: Icons.shopping_basket_outlined,
                title: 'common.landing.roleBuyer'.tr(),
                description: 'common.landing.roleBuyerDesc'.tr(),
                onTap: () => context.push('/auth?role=customer'),
              ),
              const SizedBox(height: AppSpace.space2),
              _RoleCard(
                icon: Icons.storefront_outlined,
                title: 'common.landing.roleFarmer'.tr(),
                description: 'common.landing.roleFarmerDesc'.tr(),
                onTap: () => context.push('/auth?role=farmer'),
              ),
              const SizedBox(height: AppSpace.space2),
              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'common.landing.roleAdmin'.tr(),
                description: 'common.landing.roleAdminDesc'.tr(),
                onTap: () => context.push('/auth?role=admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.eco, size: 56, color: AppColors.primary),
        const SizedBox(height: AppSpace.space2),
        Text(
          'common.landing.heroTitle'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpace.space1),
        Text(
          'common.landing.heroSubtitle'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      interactive: true,
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpace.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
