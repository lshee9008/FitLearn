import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../provider/diagnosis_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class DiagnosisResultPage extends StatelessWidget {
  final DiagnosisResult result;

  const DiagnosisResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final p = result.profile;
    final styleInfo = _styleInfo(p.learningStyle);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── 히어로 헤더 ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    styleInfo.color.withValues(alpha: 0.25),
                    AppColors.bg,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textMuted, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Text('진단 완료',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 28),
                Text(styleInfo.emoji,
                    style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(p.learningStyle,
                    style: TextStyle(
                        color: styleInfo.color,
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('학습자', style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(height: 20),
                Wrap(spacing: 8, children: [
                  _Badge(p.cognitiveStyle, AppColors.secondary),
                  _Badge(p.focusPattern, AppColors.accent),
                  _Badge(p.preferredFormat, AppColors.primary),
                  _Badge(p.pace, const Color(0xFFEC4899)),
                  _Badge(p.interaction, const Color(0xFF10B981)),
                ]),
              ]),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── 레이더 차트 ───────────────────────────────────
                AppCard(
                  child: Column(children: [
                    const _SectionLabel('6차원 학습 성향 분석'),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 260,
                      child: RadarChart(
                        axes: [
                          RadarAxis('시각성', p.scores.visual / 100,
                              AppColors.primary),
                          RadarAxis('분석성', p.scores.analytical / 100,
                              AppColors.secondary),
                          RadarAxis('집중력', p.scores.focusDepth / 100,
                              AppColors.accent),
                          RadarAxis('상세선호', p.scores.detailPref / 100,
                              const Color(0xFFEC4899)),
                          RadarAxis('속도', p.scores.speed / 100,
                              const Color(0xFFF59E0B)),
                          RadarAxis('협력성', p.scores.collaboration / 100,
                              const Color(0xFF10B981)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RadarLegend(scores: p.scores),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── AI 분석 ───────────────────────────────────────
                if (p.analysis.isNotEmpty)
                  AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const _SectionLabel('AI 성향 분석'),
                      const SizedBox(height: 12),
                      Text(p.analysis,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.6)),
                    ]),
                  ),
                if (p.analysis.isNotEmpty) const SizedBox(height: 16),

                // ── 강점 / 약점 ───────────────────────────────────
                Row(children: [
                  Expanded(
                      child: _ListCard(
                    title: '강점',
                    emoji: '✅',
                    color: const Color(0xFF10B981),
                    items: result.strengths,
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _ListCard(
                    title: '개선점',
                    emoji: '🎯',
                    color: AppColors.rose,
                    items: result.weaknesses,
                  )),
                ]),
                const SizedBox(height: 16),

                // ── 학습 전략 ─────────────────────────────────────
                AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const _SectionLabel('맞춤 학습 전략'),
                    const SizedBox(height: 16),
                    ...List.generate(
                        result.strategies.length,
                        (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text('${i + 1}',
                                          style: const TextStyle(
                                              color: AppColors.primaryLight,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(result.strategies[i],
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textSecondary,
                                                fontSize: 14,
                                                height: 1.5))),
                                  ]),
                            )),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── CTA 버튼 ──────────────────────────────────────
                GlowButton(
                  text: '학습 시작하기',
                  onTap: () => context.go('/student/home'),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.go('/student/diagnosis'),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text('진단 다시 하기',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  _StyleInfo _styleInfo(String style) {
    switch (style) {
      case '시각형':
        return _StyleInfo('👁️', AppColors.primary);
      case '청각형':
        return _StyleInfo('👂', AppColors.secondary);
      case '실습형':
        return _StyleInfo('🔧', AppColors.accent);
      default:
        return _StyleInfo('📖', const Color(0xFF10B981));
    }
  }
}

class _StyleInfo {
  final String emoji;
  final Color color;
  const _StyleInfo(this.emoji, this.color);
}

// ── 레이더 차트 ──────────────────────────────────────────────────────────────

class RadarAxis {
  final String label;
  final double value; // 0.0 ~ 1.0
  final Color color;
  const RadarAxis(this.label, this.value, this.color);
}

class RadarChart extends StatelessWidget {
  final List<RadarAxis> axes;
  const RadarChart({super.key, required this.axes});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadarPainter(axes),
      child: const SizedBox.expand(),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<RadarAxis> axes;
  const _RadarPainter(this.axes);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy) - 32;
    final n = axes.length;
    final step = 2 * pi / n;
    // Start from top (-π/2)
    double angle(int i) => -pi / 2 + i * step;

    Offset point(int i, double frac) => Offset(
          cx + frac * r * cos(angle(i)),
          cy + frac * r * sin(angle(i)),
        );

    // Grid rings
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final frac in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final p = point(i, frac);
        if (i == 0) path.moveTo(p.dx, p.dy);
        else path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axis lines
    final axisPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 0; i < n; i++) {
      canvas.drawLine(Offset(cx, cy), point(i, 1.0), axisPaint);
    }

    // Fill polygon
    final fillPath = Path();
    for (int i = 0; i < n; i++) {
      final p = point(i, axes[i].value.clamp(0.05, 1.0));
      if (i == 0) fillPath.moveTo(p.dx, p.dy);
      else fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = AppColors.primaryLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Dots & labels
    final dotPaint = Paint()..style = PaintingStyle.fill;
    const labelStyle = TextStyle(
        color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600);

    for (int i = 0; i < n; i++) {
      final p = point(i, axes[i].value.clamp(0.05, 1.0));
      dotPaint.color = axes[i].color;
      canvas.drawCircle(p, 4.5, dotPaint);

      // Label at outer ring
      final lp = point(i, 1.18);
      final span = TextSpan(text: axes[i].label, style: labelStyle);
      final tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center)
        ..layout();
      tp.paint(canvas, Offset(lp.dx - tp.width / 2, lp.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.axes != axes;
}

class _RadarLegend extends StatelessWidget {
  final DimensionScores scores;
  const _RadarLegend({required this.scores});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('시각성', scores.visual, AppColors.primary),
      ('분석성', scores.analytical, AppColors.secondary),
      ('집중력', scores.focusDepth, AppColors.accent),
      ('상세선호', scores.detailPref, const Color(0xFFEC4899)),
      ('속도', scores.speed, const Color(0xFFF59E0B)),
      ('협력성', scores.collaboration, const Color(0xFF10B981)),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items.map((item) {
        final (label, score, color) = item;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$label $score', style: const TextStyle(
              color: AppColors.textMuted, fontSize: 11)),
        ]);
      }).toList(),
    );
  }
}

// ── 공통 위젯 ────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title, emoji;
  final Color color;
  final List<String> items;

  const _ListCard({
    required this.title,
    required this.emoji,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        ...items.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 4, height: 4,
                    margin: const EdgeInsets.fromLTRB(0, 6, 8, 0),
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle)),
                Expanded(
                    child: Text(s,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4))),
              ]),
            )),
      ]),
    );
  }
}
