import 'package:flutter/material.dart';

/// FitLearn 디자인 토큰 — 모든 화면의 색·간격·반경은 여기서 가져온다.
class FL {
  // Surfaces
  static const bg = Color(0xFF0E0E11);
  static const surface = Color(0xFF13131A);
  static const surface2 = Color(0xFF1A1A24);
  static const surface3 = Color(0xFF22222E);
  static const border = Color(0xFF23232F);
  static const borderStrong = Color(0xFF32323F);

  // Text
  static const text = Color(0xFFF0F0F4);
  static const textSec = Color(0xFF9D9DB0);
  static const textMute = Color(0xFF6E6E80);

  // Brand
  static const lime = Color(0xFFC8F135);
  static const limeDeep = Color(0xFFA8D010);
  static const limeInk = Color(0xFF151C00); // 라임 배경 위 텍스트
  static const limeDark = Color(0xFF1A2400);
  static const lavender = Color(0xFFA78BFA);
  static const lavMid = Color(0xFF1E1830);

  // Semantic
  static const coral = Color(0xFFFB7185);
  static const amber = Color(0xFFFBBF24);
  static const mint = Color(0xFF34D399);
  static const sky = Color(0xFF60A5FA);

  // Radius
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r20 = 20.0;

  static const maxContent = 1200.0;
  static const maxReading = 760.0;
}

/// 학습 스타일별 표현 정보 — 교안 스타일 스위처, 진단 결과, 대시보드 공통.
class StyleMeta {
  final String key;
  final String emoji;
  final String tagline;
  final Color color;
  const StyleMeta(this.key, this.emoji, this.tagline, this.color);

  static const all = [
    StyleMeta('시각형', '👁️', '구조와 도식으로 한눈에', FL.lavender),
    StyleMeta('청각형', '🎧', '선생님이 말로 설명하듯', FL.sky),
    StyleMeta('읽기형', '📖', '교재처럼 체계적으로', FL.mint),
    StyleMeta('실습형', '🛠️', '직접 따라 하며', FL.amber),
    StyleMeta('요약형', '⚡', '3분 만에 핵심만', FL.lime),
    StyleMeta('상세형', '🔍', '막힘없이 빠짐없이', FL.coral),
  ];

  static StyleMeta of(String style) {
    final normalized = switch (style) {
      '운동형' || '행동형' => '실습형',
      _ => style,
    };
    return all.firstWhere((m) => m.key == normalized, orElse: () => all[2]);
  }
}
