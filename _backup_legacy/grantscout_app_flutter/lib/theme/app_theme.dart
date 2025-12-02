import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'component_themes.dart';

class AppTheme {
  // Premium Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Premium Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimary,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondary: AppColors.onSecondary,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        
        tertiary: AppColors.tertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiary: AppColors.onTertiary,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        
        surface: AppColors.surface,
        surfaceVariant: AppColors.surfaceVariant,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        
        background: AppColors.background,
        onBackground: AppColors.onBackground,
        
        error: AppColors.error,
        errorContainer: AppColors.errorContainer,
        onError: AppColors.onError,
        
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),

      // Typography
      textTheme: AppTextTheme.lightTextTheme,

      // Component Themes
      appBarTheme: ComponentThemes.appBarTheme,
      cardTheme: ComponentThemes.cardTheme,
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme,
      textButtonTheme: ComponentThemes.textButtonTheme,
      outlinedButtonTheme: ComponentThemes.outlinedButtonTheme,
      iconButtonTheme: ComponentThemes.iconButtonTheme,
      inputDecorationTheme: ComponentThemes.inputDecorationTheme,
      floatingActionButtonTheme: ComponentThemes.floatingActionButtonTheme,
      navigationBarTheme: ComponentThemes.navigationBarTheme,
      dialogTheme: ComponentThemes.dialogTheme,
      snackBarTheme: ComponentThemes.snackBarTheme,
      chipTheme: ComponentThemes.chipTheme,
      listTileTheme: ComponentThemes.listTileTheme,
      tabBarTheme: ComponentThemes.tabBarTheme,
      checkboxTheme: ComponentThemes.checkboxTheme,
      switchTheme: ComponentThemes.switchTheme,
      sliderTheme: ComponentThemes.sliderTheme,
      progressIndicatorTheme: ComponentThemes.progressIndicatorTheme,
      dividerTheme: ComponentThemes.dividerTheme,
      scrollbarTheme: ComponentThemes.scrollbarTheme,

      // Visual Density & Platform
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      platform: TargetPlatform.android,

      // System UI Overlay
      appBarTheme: ComponentThemes.appBarTheme.copyWith(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
    );
  }

  // Premium Dark Theme (Future Proofing)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      colorScheme: ColorScheme.dark(
        primary: AppColors.darkPrimary,
        surface: AppColors.darkSurface,
        background: AppColors.darkBackground,
        onSurface: AppColors.darkOnSurface,
        secondary: AppColors.secondary, // Keep Teal for dark mode accent
      ),

      textTheme: AppTextTheme.darkTextTheme,
      
      appBarTheme: ComponentThemes.appBarTheme.copyWith(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkOnSurface,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.darkBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
    );
  }
}

// 테마 유틸리티 함수들
class ThemeUtils {
  // 현재 테마가 다크 모드인지 확인
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // 적응형 컬러 반환 (라이트/다크에 따라)
  static Color adaptiveColor(
    BuildContext context, {
    required Color lightColor,
    required Color darkColor,
  }) {
    return isDarkMode(context) ? darkColor : lightColor;
  }

  // 텍스트 컨트라스트에 따른 컬러 반환
  static Color getTextColor(Color backgroundColor) {
    // 배경색의 명도에 따라 텍스트 컬러 결정
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  // 상태에 따른 컬러 반환
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'completed':
      case 'analysis_success':
        return AppColors.success;
      case 'warning':
      case 'processing':
        return AppColors.warning;
      case 'error':
      case 'failed':
      case 'text_extracted_failed':
        return AppColors.error;
      case 'info':
      case 'uploaded':
        return AppColors.info;
      default:
        return AppColors.outline;
    }
  }

  // 마감일에 따른 컬러 반환
  static Color getDeadlineColor(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;
    
    if (difference < 0) {
      return AppColors.error; // 마감일 지남
    } else if (difference == 0) {
      return AppColors.deadline; // 오늘 마감
    } else if (difference <= 3) {
      return AppColors.warning; // 3일 이내
    } else {
      return AppColors.success; // 충분한 시간
    }
  }
}