import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class ComponentThemes {
  // AppBar 테마
  static AppBarTheme get appBarTheme => AppBarTheme(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.onSurface,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    titleTextStyle: AppTypography.titleLarge.copyWith(
      color: AppColors.onSurface,
    ),
    toolbarHeight: 64,
    shape: const Border(
      bottom: BorderSide(
        color: AppColors.outlineVariant,
        width: 0.5,
      ),
    ),
  );

  // Card 테마
  static CardTheme get cardTheme => CardTheme(
    color: AppColors.surface,
    surfaceTintColor: AppColors.primary,
    shadowColor: Colors.black.withOpacity(0.1),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
  );

  // ElevatedButton 테마
  static ElevatedButtonThemeData get elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      shadowColor: AppColors.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: AppTypography.buttonText,
      minimumSize: const Size(88, 48),
    ),
  );

  // TextButton 테마
  static TextButtonThemeData get textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTypography.buttonText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );

  // OutlinedButton 테마
  static OutlinedButtonThemeData get outlinedButtonTheme => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: AppTypography.buttonText,
      minimumSize: const Size(88, 48),
    ),
  );

  // IconButton 테마
  static IconButtonThemeData get iconButtonTheme => IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: AppColors.onSurface,
      highlightColor: AppColors.primary.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // InputDecoration 테마
  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariant.withOpacity(0.3),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
    hintStyle: AppTypography.hintText.copyWith(color: AppColors.onSurfaceVariant),
    errorStyle: AppTypography.errorText.copyWith(color: AppColors.error),
    contentPadding: const EdgeInsets.all(16),
  );

  // FloatingActionButton 테마
  static FloatingActionButtonThemeData get floatingActionButtonTheme => FloatingActionButtonThemeData(
    backgroundColor: AppColors.primaryContainer,
    foregroundColor: AppColors.onPrimaryContainer,
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  // NavigationBar 테마
  static NavigationBarThemeData get navigationBarTheme => NavigationBarThemeData(
    backgroundColor: AppColors.surface,
    elevation: 3,
    indicatorColor: AppColors.secondaryContainer,
    labelTextStyle: MaterialStateProperty.all(
      AppTypography.labelMedium.copyWith(color: AppColors.onSurface),
    ),
    iconTheme: MaterialStateProperty.all(
      const IconThemeData(color: AppColors.onSurfaceVariant),
    ),
  );

  // Dialog 테마
  static DialogTheme get dialogTheme => DialogTheme(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 24,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    titleTextStyle: AppTypography.headlineSmall.copyWith(
      color: AppColors.onSurface,
    ),
    contentTextStyle: AppTypography.bodyMedium.copyWith(
      color: AppColors.onSurfaceVariant,
    ),
  );

  // SnackBar 테마
  static SnackBarThemeData get snackBarTheme => SnackBarThemeData(
    backgroundColor: AppColors.onSurface,
    contentTextStyle: AppTypography.bodyMedium.copyWith(
      color: AppColors.surface,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    actionTextColor: AppColors.primary,
  );

  // Chip 테마
  static ChipThemeData get chipTheme => ChipThemeData(
    backgroundColor: AppColors.surfaceVariant,
    deleteIconColor: AppColors.onSurfaceVariant,
    disabledColor: AppColors.onSurface.withOpacity(0.12),
    selectedColor: AppColors.secondaryContainer,
    secondarySelectedColor: AppColors.secondaryContainer,
    shadowColor: Colors.transparent,
    elevation: 0,
    pressElevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    labelStyle: AppTypography.labelMedium.copyWith(
      color: AppColors.onSurfaceVariant,
    ),
    secondaryLabelStyle: AppTypography.labelMedium.copyWith(
      color: AppColors.onSecondaryContainer,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  // ListTile 테마
  static ListTileThemeData get listTileTheme => ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    titleTextStyle: AppTypography.bodyLarge.copyWith(
      color: AppColors.onSurface,
    ),
    subtitleTextStyle: AppTypography.bodyMedium.copyWith(
      color: AppColors.onSurfaceVariant,
    ),
    leadingAndTrailingTextStyle: AppTypography.labelMedium.copyWith(
      color: AppColors.onSurfaceVariant,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // TabBar 테마
  static TabBarTheme get tabBarTheme => TabBarTheme(
    labelColor: AppColors.primary,
    unselectedLabelColor: AppColors.onSurfaceVariant,
    labelStyle: AppTypography.titleSmall,
    unselectedLabelStyle: AppTypography.titleSmall,
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    dividerColor: AppColors.outlineVariant,
  );

  // Checkbox 테마
  static CheckboxThemeData get checkboxTheme => CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return AppColors.primary;
      }
      return Colors.transparent;
    }),
    checkColor: MaterialStateProperty.all(AppColors.onPrimary),
    side: const BorderSide(color: AppColors.outline),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
  );

  // Switch 테마
  static SwitchThemeData get switchTheme => SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return AppColors.onPrimary;
      }
      return AppColors.outline;
    }),
    trackColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return AppColors.primary;
      }
      return AppColors.surfaceVariant;
    }),
  );

  // Slider 테마
  static SliderThemeData get sliderTheme => SliderThemeData(
    activeTrackColor: AppColors.primary,
    inactiveTrackColor: AppColors.surfaceVariant,
    thumbColor: AppColors.primary,
    overlayColor: AppColors.primary.withOpacity(0.12),
    valueIndicatorColor: AppColors.primary,
    valueIndicatorTextStyle: AppTypography.bodySmall.copyWith(
      color: AppColors.onPrimary,
    ),
  );

  // ProgressIndicator 테마
  static ProgressIndicatorThemeData get progressIndicatorTheme => ProgressIndicatorThemeData(
    color: AppColors.primary,
    linearTrackColor: AppColors.surfaceVariant,
    circularTrackColor: AppColors.surfaceVariant,
  );

  // Divider 테마
  static DividerThemeData get dividerTheme => const DividerThemeData(
    color: AppColors.outlineVariant,
    thickness: 1,
    space: 1,
  );

  // Scrollbar 테마
  static ScrollbarThemeData get scrollbarTheme => ScrollbarThemeData(
    thumbColor: MaterialStateProperty.all(AppColors.outline.withOpacity(0.5)),
    trackColor: MaterialStateProperty.all(AppColors.surfaceVariant),
    radius: const Radius.circular(4),
    thickness: MaterialStateProperty.all(8),
  );
}