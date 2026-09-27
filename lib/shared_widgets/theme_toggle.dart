import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';

class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;

    return IconButton(
      icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
      tooltip: context.locale.languageCode == 'vi'
          ? (isDark ? 'Chế độ tối' : 'Chế độ sáng')
          : (isDark ? 'Dark mode' : 'Light mode'),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
