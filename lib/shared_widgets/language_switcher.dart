import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../core/theme/app_colors.dart';

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVi = context.locale.languageCode == 'vi';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LangChip(
            label: 'VI',
            selected: isVi,
            onTap: () => _setLocale(ref, context, const Locale('vi'))),
        const SizedBox(width: 4),
        _LangChip(
            label: 'EN',
            selected: !isVi,
            onTap: () => _setLocale(ref, context, const Locale('en'))),
      ],
    );
  }

  Future<void> _setLocale(
      WidgetRef ref, BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);

    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await ref.read(dioProvider).patch(
          '/api/users/me',
          data: {'preferred_language': locale.languageCode},
        );
      } catch (_) {
        // Giữ trải nghiệm đổi ngôn ngữ khi backend tạm thời không có mạng.
      }
    }
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
