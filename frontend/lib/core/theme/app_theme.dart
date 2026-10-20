import 'package:flutter/material.dart';
import 'tokens.dart';

export 'tokens.dart';

/// 레거시 화면 호환용 팔레트 — 실제 값은 [FL] 디자인 토큰을 따른다.
class AppColors {
  static const Color bg = FL.bg;
  static const Color bgCard = FL.surface2;
  static const Color bgSurface = FL.surface;

  static const Color primary = FL.lime;
  static const Color primaryLight = FL.lime;
  static const Color primaryGlow = FL.limeDeep;
  static const Color secondary = FL.lavender;
  static const Color accent = FL.mint;
  static const Color gold = FL.amber;
  static const Color rose = FL.coral;

  static const Color textPrimary = FL.text;
  static const Color textSecondary = FL.textSec;
  static const Color textMuted = FL.textMute;

  static const Color border = FL.border;
  static const Color borderLight = FL.borderStrong;

  static const Color visual = FL.lavender;
  static const Color auditory = FL.sky;
  static const Color reading = FL.mint;
  static const Color kinesthetic = FL.amber;
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: FL.surface3,
      contentTextStyle: const TextStyle(color: FL.text, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: FL.surface3, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: FL.text, fontSize: 12),
    ),
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.bgCard,
      onPrimary: FL.limeInk,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      error: AppColors.rose,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textSecondary),
      bodySmall: TextStyle(color: AppColors.textMuted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: FL.limeInk,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgSurface,
      selectedColor: AppColors.primary,
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ── 학습 유형별 색상/아이콘 유틸 ─────────────────────────────────

class LearningStyleUtil {
  static Color color(String style) => switch (style) {
        '시각형' => AppColors.visual,
        '청각형' => AppColors.auditory,
        '읽기형' => AppColors.reading,
        '운동형' => AppColors.kinesthetic,
        _ => AppColors.primary,
      };

  static String emoji(String style) => switch (style) {
        '시각형' => '👁️',
        '청각형' => '👂',
        '읽기형' => '📖',
        '운동형' => '⚡',
        _ => '🎯',
      };

  static String description(String style) => switch (style) {
        '시각형' => '도식과 시각 자료로 빠르게 이해',
        '청각형' => '스토리와 설명으로 깊이 습득',
        '읽기형' => '체계적 글쓰기로 완벽히 정리',
        '운동형' => '실습과 예제로 직접 체험',
        _ => '맞춤 학습으로 효과 극대화',
      };
}
