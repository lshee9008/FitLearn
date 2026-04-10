import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds — 다크 블랙/딥그레이
  static const Color bg = Color(0xFF0A0A0F);
  static const Color bgCard = Color(0xFF1A1A2E);
  static const Color bgSurface = Color(0xFF141420);

  // Brand — 초록 포인트
  static const Color primary = Color(0xFF10B981);
  static const Color primaryLight = Color(0xFF34D399);
  static const Color primaryGlow = Color(0xFF059669);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFF34D399);
  static const Color gold = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF64748B);

  // Borders
  static const Color border = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFF334155);

  // Learning type colors
  static const Color visual = Color(0xFF7C3AED);    // 시각형
  static const Color auditory = Color(0xFF0EA5E9);   // 청각형
  static const Color reading = Color(0xFF10B981);    // 읽기형
  static const Color kinesthetic = Color(0xFFF59E0B); // 운동형
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.bgCard,
      onPrimary: Color(0xFF0A0A0F),
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
        foregroundColor: Colors.white,
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
