import 'package:flutter/material.dart';

class AppColors {
  // Premium Color Palette
  // Primary: Deep Navy (Trust, Professionalism)
  static const Color primary = Color(0xFF1A237E); 
  static const Color primaryContainer = Color(0xFFE8EAF6);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF0D1240);

  // Secondary: Vibrant Teal (Modern, Tech)
  static const Color secondary = Color(0xFF00BCD4);
  static const Color secondaryContainer = Color(0xFFE0F7FA);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF006064);

  // Tertiary: Amber/Gold (Opportunity, Wealth)
  static const Color tertiary = Color(0xFFFFC107);
  static const Color tertiaryContainer = Color(0xFFFFF8E1);
  static const Color onTertiary = Color(0xFF000000);
  static const Color onTertiaryContainer = Color(0xFF3E2723);

  // Neutral Colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F7FA); // Light Blue-Grey for cards
  static const Color onSurface = Color(0xFF1A1C1E);
  static const Color onSurfaceVariant = Color(0xFF455A64);

  static const Color background = Color(0xFFF5F7FA); // Very light cool grey
  static const Color onBackground = Color(0xFF1A1C1E);

  static const Color outline = Color(0xFF78909C);
  static const Color outlineVariant = Color(0xFFCFD8DC);

  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color successContainer = Color(0xFFE8F5E9);
  static const Color onSuccess = Color(0xFFFFFFFF);

  static const Color warning = Color(0xFFFF9800);
  static const Color warningContainer = Color(0xFFFFF3E0);
  static const Color onWarning = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFD32F2F);
  static const Color errorContainer = Color(0xFFFFEBEE);
  static const Color onError = Color(0xFFFFFFFF);

  static const Color info = Color(0xFF2196F3);
  static const Color infoContainer = Color(0xFFE3F2FD);
  static const Color onInfo = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color deadline = Color(0xFFE53935);
  static const Color deadlineContainer = Color(0xFFFFEBEE);
  
  static const Color processing = Color(0xFF1976D2);
  static const Color processingContainer = Color(0xFFE3F2FD);
  
  static const Color completed = Color(0xFF388E3C);
  static const Color completedContainer = Color(0xFFE8F5E8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Colors.white, Colors.white54],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Opacity Variants
  static Color primaryWithOpacity(double opacity) => primary.withOpacity(opacity);
  static Color surfaceWithOpacity(double opacity) => surface.withOpacity(opacity);
  static Color outlineWithOpacity(double opacity) => outline.withOpacity(opacity);

  // Dark Mode (Future Proofing)
  static const Color darkPrimary = Color(0xFF536DFE);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkOnSurface = Color(0xFFE0E0E0);
}

// 컬러 시멘틱 확장
extension AppColorsExtension on ColorScheme {
  Color get success => AppColors.success;
  Color get successContainer => AppColors.successContainer;
  Color get onSuccess => AppColors.onSuccess;

  Color get warning => AppColors.warning;
  Color get warningContainer => AppColors.warningContainer;
  Color get onWarning => AppColors.onWarning;

  Color get info => AppColors.info;
  Color get infoContainer => AppColors.infoContainer;
  Color get onInfo => AppColors.onInfo;

  Color get deadline => AppColors.deadline;
  Color get processing => AppColors.processing;
  Color get completed => AppColors.completed;
}