import 'package:flutter/material.dart';

class AppTypography {
  // 폰트 패밀리
  static const String fontFamily = 'Pretendard';
  static const String fallbackFont = 'Apple SD Gothic Neo';
  
  // 기본 텍스트 스타일
  static const TextStyle _baseTextStyle = TextStyle(
    fontFamily: fontFamily,
    height: 1.4,
    letterSpacing: -0.01,
  );

  // Display 스타일 (큰 제목용)
  static final TextStyle displayLarge = _baseTextStyle.copyWith(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    height: 1.12,
    letterSpacing: -0.25,
  );

  static final TextStyle displayMedium = _baseTextStyle.copyWith(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    height: 1.16,
  );

  static final TextStyle displaySmall = _baseTextStyle.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.22,
  );

  // Headline 스타일 (섹션 제목용)
  static final TextStyle headlineLarge = _baseTextStyle.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static final TextStyle headlineMedium = _baseTextStyle.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.29,
  );

  static final TextStyle headlineSmall = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33,
  );

  // Title 스타일 (카드 제목 등)
  static final TextStyle titleLarge = _baseTextStyle.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.27,
  );

  static final TextStyle titleMedium = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.50,
    letterSpacing: 0.1,
  );

  static final TextStyle titleSmall = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.43,
    letterSpacing: 0.1,
  );

  // Label 스타일 (버튼, 탭 등)
  static final TextStyle labelLarge = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.43,
    letterSpacing: 0.1,
  );

  static final TextStyle labelMedium = _baseTextStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: 0.5,
  );

  static final TextStyle labelSmall = _baseTextStyle.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0.5,
  );

  // Body 스타일 (본문용)
  static final TextStyle bodyLarge = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.50,
    letterSpacing: 0.5,
  );

  static final TextStyle bodyMedium = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0.25,
  );

  static final TextStyle bodySmall = _baseTextStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.4,
  );

  // 커스텀 스타일 (앱 특화)
  static final TextStyle caption = _baseTextStyle.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.4,
  );

  static final TextStyle overline = _baseTextStyle.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.6,
    letterSpacing: 1.5,
  );

  // 특수 용도 스타일
  static final TextStyle buttonText = labelLarge.copyWith(
    fontWeight: FontWeight.w600,
  );

  static final TextStyle inputText = bodyLarge.copyWith(
    fontWeight: FontWeight.w400,
  );

  static final TextStyle hintText = bodyMedium.copyWith(
    fontWeight: FontWeight.w400,
  );

  static final TextStyle errorText = bodySmall.copyWith(
    fontWeight: FontWeight.w500,
  );

  // 숫자 및 코드용 (고정폭 폰트)
  static final TextStyle monospace = _baseTextStyle.copyWith(
    fontFamily: 'Courier New',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // 강조 스타일
  static final TextStyle emphasis = bodyMedium.copyWith(
    fontWeight: FontWeight.w700,
  );

  static final TextStyle link = bodyMedium.copyWith(
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.underline,
  );

  // 상태별 스타일
  static final TextStyle successText = bodyMedium.copyWith(
    fontWeight: FontWeight.w600,
  );

  static final TextStyle warningText = bodyMedium.copyWith(
    fontWeight: FontWeight.w600,
  );

  static final TextStyle deadlineText = bodySmall.copyWith(
    fontWeight: FontWeight.w700,
  );
}

// TextTheme 생성 헬퍼
class AppTextTheme {
  static TextTheme get lightTextTheme => TextTheme(
    displayLarge: AppTypography.displayLarge,
    displayMedium: AppTypography.displayMedium,
    displaySmall: AppTypography.displaySmall,
    headlineLarge: AppTypography.headlineLarge,
    headlineMedium: AppTypography.headlineMedium,
    headlineSmall: AppTypography.headlineSmall,
    titleLarge: AppTypography.titleLarge,
    titleMedium: AppTypography.titleMedium,
    titleSmall: AppTypography.titleSmall,
    labelLarge: AppTypography.labelLarge,
    labelMedium: AppTypography.labelMedium,
    labelSmall: AppTypography.labelSmall,
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
  );

  static TextTheme get darkTextTheme => lightTextTheme;
}

// Typography 확장
extension AppTypographyExtension on TextTheme {
  TextStyle get caption => AppTypography.caption;
  TextStyle get overline => AppTypography.overline;
  TextStyle get buttonText => AppTypography.buttonText;
  TextStyle get inputText => AppTypography.inputText;
  TextStyle get hintText => AppTypography.hintText;
  TextStyle get errorText => AppTypography.errorText;
  TextStyle get monospace => AppTypography.monospace;
  TextStyle get emphasis => AppTypography.emphasis;
  TextStyle get link => AppTypography.link;
  TextStyle get successText => AppTypography.successText;
  TextStyle get warningText => AppTypography.warningText;
  TextStyle get deadlineText => AppTypography.deadlineText;
}