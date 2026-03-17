import 'package:avdibook/app/router/app_router.dart';
import 'package:avdibook/app/theme/app_theme.dart';
import 'package:avdibook/shared/providers/app_state_provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AvdiBookApp extends ConsumerWidget {
  const AvdiBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = AppRouter.router;
    final themeModeIndex = ref.watch(themeModeProvider);
    final themeMode = switch (themeModeIndex) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = lightDynamic?.harmonized();
        final darkScheme = darkDynamic?.harmonized();

        return MaterialApp.router(
          title: 'AvdiBook',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.light(lightScheme),
          darkTheme: AppTheme.dark(darkScheme),
          routerConfig: router,
        );
      },
    );
  }
}
