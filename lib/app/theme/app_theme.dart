import 'package:avdibook/app/theme/app_colors.dart';
import 'package:avdibook/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// AvdiBook Material 3 theme system.
///
/// Soft, premium audiobook aesthetic:
/// - Warm off-white surfaces (light)
/// - Deep slate background (dark)
/// - Expressive rounded shapes
/// - Generous elevation and spacing
class AppTheme {
  AppTheme._();

  // Seed color — calm deep blue used for generative Material 3 color roles
  static const Color _seedColor = AppColors.primary;

  // ─── Light theme ──────────────────────────────────────────────────────────

  static ThemeData light([ColorScheme? dynamicScheme]) {
    final cs =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.onSurfaceLight,
        );

    return _build(cs, Brightness.light);
  }

  // ─── Dark theme ────────────────────────────────────────────────────────────

  static ThemeData dark([ColorScheme? dynamicScheme]) {
    final cs =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onSurfaceDark,
        );

    return _build(cs, Brightness.dark);
  }

  // ─── Shared builder ────────────────────────────────────────────────────────

  static ThemeData _build(ColorScheme cs, Brightness brightness) {
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: 'Inter',
      textTheme: AppTypography.textTheme(cs),

      // Scaffold
      scaffoldBackgroundColor: cs.surface,

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.textTheme(cs).titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: cs.surfaceContainerLow,
      ),

      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainer,
        elevation: 0,
        indicatorColor: cs.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontFamily: 'Inter',
          );
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surfaceContainerLow,
        indicatorColor: cs.secondaryContainer,
        elevation: 0,
        selectedIconTheme: IconThemeData(color: cs.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        unselectedLabelTextStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      ),

      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: cs.onSurfaceVariant),
        ),
      ),

      // Sliders (chapter progress, volume)
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),

      // Pills / icon buttons
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      // Floating action button (mini player promote)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // Bottom sheets (chapter list, sleep timer)
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        modalBackgroundColor: cs.surfaceContainerHigh,
        dragHandleColor: cs.onSurfaceVariant.withValues(alpha: 0.45),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 1,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: cs.surfaceContainerHigh,
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: cs.outline.withValues(alpha: 0.15),
        thickness: 0.5,
        space: 0,
      ),

      // Snack bars
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isLight ? AppColors.surfaceDark : AppColors.cardLight,
        contentTextStyle: TextStyle(
          color: isLight ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
