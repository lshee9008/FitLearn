import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../provider/diagnosis_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class DiagnosisResultPage extends StatefulWidget {
  final DiagnosisResult result;

  const DiagnosisResultPage({super.key, required this.result});

  @override
  State<DiagnosisResultPage> createState() => _DiagnosisResultPageState();
}

class _DiagnosisResultPageState extends State<DiagnosisResultPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.result.profile;
    final styleInfo = _styleInfo(p.learningStyle);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── 히어로 헤더 ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
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
                const SizedBox(height: 24),
                Text(styleInfo.emoji,
                    style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                Text(p.learningStyle,
                    style: TextStyle(
                        color: styleInfo.color,
                        fontSize: 26,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('학습자',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _Badge(p.cognitiveStyle, AppColors.secondary),
                  _Badge(p.focusPattern, AppColors.accent),
                  _Badge(p.preferredFormat, AppColors.primary),
                  _Badge(p.pace, const Color(0xFFEC4899)),
                  _Badge(p.interaction, const Color(0xFF10B981)),
                  if (p.kolbType.isNotEmpty)
                    _Badge(p.kolbType, const Color(0xFFF59E0B)),
                ]),
                const SizedBox(height: 20),
                // Confidence bar
                _ConfidenceBar(score: p.confidenceScore),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          // ── TabBar ─────────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBar(
              TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primaryLight,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '개요'),
                  Tab(text: 'VARK'),
                  Tab(text: 'Felder'),
                  Tab(text: '인지부하'),
                  Tab(text: '전략'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _OverviewTab(result: widget.result),
            _VarkTab(vark: widget.result.profile.vark),
            _FelderTab(felder: widget.result.profile.felder),
            _CogLoadTab(
                cogLoad: widget.result.profile.cognitiveLoad,
                kolbType: widget.result.profile.kolbType),
            _StrategyTab(result: widget.result),
          ],
        ),
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

// ── 탭: 개요 ──────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final DiagnosisResult result;
  const _OverviewTab({required this.result});

  @override
  Widget build(BuildContext context) {
    final p = result.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        // 8D 레이더 차트
        AppCard(
          child: Column(children: [
            const _SectionLabel('8차원 학습 성향 레이더'),
            const SizedBox(height: 6),
            const Text('VARK · Felder · CLT · Kolb 통합',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
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
                  RadarAxis('메타인지', p.scores.metacognition / 100,
                      const Color(0xFF8B5CF6)),
                  RadarAxis('일관성', p.scores.consistency / 100,
                      const Color(0xFF06B6D4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _RadarLegend(scores: p.scores),
          ]),
        ),
        const SizedBox(height: 16),

        // 신뢰도 게이지
        AppCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const _SectionLabel('응답 신뢰도'),
            const SizedBox(height: 4),
            Text(p.reliability.message,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            _ReliabilityGauge(reliability: p.reliability),
          ]),
        ),
        const SizedBox(height: 16),

        // AI 분석
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

        // 글쓰기 인사이트
        if (p.writingInsight.isNotEmpty)
          AppCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const _SectionLabel('✍️ 글쓰기 패턴 분석'),
              const SizedBox(height: 12),
              Text(p.writingInsight,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.6)),
            ]),
          ),
        if (p.writingInsight.isNotEmpty) const SizedBox(height: 16),

        // 강점 / 약점
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

        // CTA
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
      ],
    );
  }
}

// ── 탭: VARK ──────────────────────────────────────────────────────────────────

class _VarkTab extends StatelessWidget {
  final Map<String, dynamic> vark;
  const _VarkTab({required this.vark});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Visual 시각형', vark['visual'] as num? ?? 0, AppColors.primary, '👁️'),
      ('Aural 청각형', vark['aural'] as num? ?? 0, AppColors.secondary, '👂'),
      ('Read/Write 읽기형', vark['read_write'] as num? ?? 0,
          const Color(0xFF10B981), '📖'),
      ('Kinesthetic 실습형', vark['kinesthetic'] as num? ?? 0,
          const Color(0xFFF59E0B), '🔧'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionLabel('VARK 학습 스타일'),
            const SizedBox(height: 4),
            const Text('Fleming(1992) — 선호 감각 채널 분석',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 20),
            ...items.map((item) {
              final (label, score, color, emoji) = item;
              final pct = score.toDouble().clamp(0, 100) / 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${score.toInt()}',
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.bgSurface,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 10,
                    ),
                  ),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'VARK란?',
          content:
              'Fleming & Mills(1992)이 제안한 학습 스타일 모델입니다. '
              '시각(Visual), 청각(Aural), 읽기/쓰기(Read/Write), '
              '운동감각(Kinesthetic) 4가지 선호 채널을 분석합니다.',
        ),
      ],
    );
  }
}

// ── 탭: Felder ────────────────────────────────────────────────────────────────

class _FelderTab extends StatelessWidget {
  final Map<String, dynamic> felder;
  const _FelderTab({required this.felder});

  @override
  Widget build(BuildContext context) {
    final si = (felder['sensing_intuitive'] as num?)?.toDouble() ?? 0;
    final sg = (felder['sequential_global'] as num?)?.toDouble() ?? 0;
    final ar = (felder['active_reflective'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionLabel('Felder-Silverman 인지 차원'),
            const SizedBox(height: 4),
            const Text('Felder & Silverman(1988) — 정보 처리 방식 분석',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 24),
            _FelderDimension(
              leftLabel: '감각형', rightLabel: '직관형',
              value: si, color: AppColors.primary,
            ),
            const SizedBox(height: 20),
            _FelderDimension(
              leftLabel: '순차형', rightLabel: '전체형',
              value: sg, color: AppColors.secondary,
            ),
            const SizedBox(height: 20),
            _FelderDimension(
              leftLabel: '능동형', rightLabel: '숙고형',
              value: ar, color: AppColors.accent,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Felder 차원 읽는 법',
          content:
              '각 차원은 -100~+100 범위입니다. '
              '양수(+)는 왼쪽 성향, 음수(-)는 오른쪽 성향이 강함을 의미합니다. '
              '±20 이내는 중간 성향으로 두 유형 모두 활용합니다.',
        ),
      ],
    );
  }
}

class _FelderDimension extends StatelessWidget {
  final String leftLabel, rightLabel;
  final double value; // -100 ~ +100
  final Color color;

  const _FelderDimension({
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = (value.clamp(-100, 100) + 100) / 200; // 0~1
    final isLeft = value >= 0;
    final absVal = value.abs().toInt();

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(leftLabel,
            style: TextStyle(
                color: isLeft ? color : AppColors.textMuted,
                fontSize: 12,
                fontWeight: isLeft ? FontWeight.w700 : FontWeight.w400)),
        Text('${isLeft ? '+' : '-'}$absVal',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        Text(rightLabel,
            style: TextStyle(
                color: !isLeft ? color : AppColors.textMuted,
                fontSize: 12,
                fontWeight: !isLeft ? FontWeight.w700 : FontWeight.w400)),
      ]),
      const SizedBox(height: 8),
      Stack(children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(5)),
        ),
        FractionallySizedBox(
          widthFactor: 1,
          child: CustomPaint(
            size: const Size(double.infinity, 10),
            painter: _FelderBarPainter(
                normalized: normalized, color: color),
          ),
        ),
      ]),
    ]);
  }
}

class _FelderBarPainter extends CustomPainter {
  final double normalized;
  final Color color;
  const _FelderBarPainter({required this.normalized, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    final barX = normalized * size.width;
    final paint = Paint()..color = color;
    final rr = const Radius.circular(5);
    if (barX < mid) {
      canvas.drawRRect(
          RRect.fromLTRBR(barX, 0, mid, size.height, rr), paint);
    } else {
      canvas.drawRRect(
          RRect.fromLTRBR(mid, 0, barX, size.height, rr), paint);
    }
    // Center line
    canvas.drawRect(
        Rect.fromLTWH(mid - 1, 0, 2, size.height),
        Paint()..color = AppColors.border);
  }

  @override
  bool shouldRepaint(_FelderBarPainter old) =>
      old.normalized != normalized;
}

// ── 탭: 인지부하 ───────────────────────────────────────────────────────────────

class _CogLoadTab extends StatelessWidget {
  final Map<String, dynamic> cogLoad;
  final String kolbType;
  const _CogLoadTab({required this.cogLoad, required this.kolbType});

  @override
  Widget build(BuildContext context) {
    final intrinsic = (cogLoad['intrinsic'] as num?)?.toInt() ?? 0;
    final extraneous = (cogLoad['extraneous'] as num?)?.toInt() ?? 0;
    final germane = (cogLoad['germane'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionLabel('인지부하 이론 (CLT)'),
            const SizedBox(height: 4),
            const Text('Sweller(1988) — 작업 기억 부하 분석',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 20),
            _CogLoadItem(
              label: '내재적 부하 (Intrinsic)',
              desc: '학습 내용의 본질적 복잡도',
              value: intrinsic,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            _CogLoadItem(
              label: '외재적 부하 (Extraneous)',
              desc: '불필요한 정보로 인한 부하',
              value: extraneous,
              color: AppColors.rose,
            ),
            const SizedBox(height: 16),
            _CogLoadItem(
              label: '생성적 부하 (Germane)',
              desc: '스키마 형성을 위한 유용한 부하',
              value: germane,
              color: AppColors.accent,
            ),
          ]),
        ),
        const SizedBox(height: 16),

        if (kolbType.isNotEmpty)
          AppCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionLabel('Kolb 경험학습 유형'),
              const SizedBox(height: 4),
              const Text('Kolb(1984) — 경험 처리 방식',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFF59E0B)
                          .withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Text('🔄', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(kolbType,
                        style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(_kolbDesc(kolbType),
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12)),
                  ]),
                ]),
              ),
            ]),
          ),
        if (kolbType.isNotEmpty) const SizedBox(height: 16),

        _InfoCard(
          title: '인지부하 최적화 팁',
          content:
              '외재적 부하가 높으면 불필요한 정보를 제거하고 핵심에 집중하세요. '
              '생성적 부하가 높을수록 스키마가 잘 형성되어 장기 기억에 유리합니다.',
        ),
      ],
    );
  }

  String _kolbDesc(String type) {
    switch (type) {
      case '확산형': return '구체적 경험 + 반성적 관찰 — 아이디어 풍부';
      case '동화형': return '추상적 개념화 + 반성적 관찰 — 이론 정립 강점';
      case '수렴형': return '추상적 개념화 + 능동적 실험 — 문제해결 강점';
      case '적응형': return '구체적 경험 + 능동적 실험 — 실행력 강점';
      default: return '';
    }
  }
}

class _CogLoadItem extends StatelessWidget {
  final String label, desc;
  final int value;
  final Color color;

  const _CogLoadItem({
    required this.label,
    required this.desc,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            Text(desc,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        Text('$value',
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: value / 100,
          backgroundColor: AppColors.bgSurface,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 10,
        ),
      ),
    ]);
  }
}

// ── 탭: 전략 ──────────────────────────────────────────────────────────────────

class _StrategyTab extends StatelessWidget {
  final DiagnosisResult result;
  const _StrategyTab({required this.result});

  @override
  Widget build(BuildContext context) {
    final p = result.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        AppCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionLabel('맞춤 학습 전략'),
            const SizedBox(height: 16),
            ...List.generate(
              result.strategies.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
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
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.5))),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // 논문 인용
        if (p.paperCitations.isNotEmpty)
          AppCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionLabel('📄 논문 근거'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.paperCitations
                    .map((c) => _CitationBadge(citation: c))
                    .toList(),
              ),
            ]),
          ),
        if (p.paperCitations.isNotEmpty) const SizedBox(height: 16),

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
      ],
    );
  }
}

// ── 신뢰도 게이지 ──────────────────────────────────────────────────────────────

class _ReliabilityGauge extends StatelessWidget {
  final ReliabilityInfo reliability;
  const _ReliabilityGauge({required this.reliability});

  @override
  Widget build(BuildContext context) {
    final pct = reliability.overallPct;
    final color = pct >= 80
        ? AppColors.accent
        : pct >= 60
            ? const Color(0xFFF59E0B)
            : AppColors.rose;

    return Column(children: [
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: reliability.overall.clamp(0.0, 1.0),
              backgroundColor: AppColors.bgSurface,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('$pct%',
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        _RelPair(label: 'Q3↔Q18 시각',
            value: reliability.pairQ3Q18),
        const SizedBox(width: 12),
        _RelPair(label: 'Q7↔Q22 실습',
            value: reliability.pairQ7Q22),
        const SizedBox(width: 12),
        _RelPair(label: 'Q11↔Q24 순차',
            value: reliability.pairQ11Q24),
      ]),
    ]);
  }
}

class _RelPair extends StatelessWidget {
  final String label;
  final double value;
  const _RelPair({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    final color = pct >= 80
        ? AppColors.accent
        : pct >= 50
            ? const Color(0xFFF59E0B)
            : AppColors.rose;
    return Expanded(
      child: Column(children: [
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 4),
        Text('$pct%',
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── 신뢰도 바 ─────────────────────────────────────────────────────────────────

class _ConfidenceBar extends StatelessWidget {
  final int score;
  const _ConfidenceBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppColors.accent
        : score >= 60
            ? const Color(0xFFF59E0B)
            : AppColors.rose;
    return Row(children: [
      const Text('AI 신뢰도 ',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: AppColors.bgSurface,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('$score%',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── 논문 인용 배지 ─────────────────────────────────────────────────────────────

class _CitationBadge extends StatelessWidget {
  final String citation;
  const _CitationBadge({required this.citation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('📄', style: TextStyle(fontSize: 11)),
        const SizedBox(width: 5),
        Text(citation,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── 정보 카드 ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title, content;
  const _InfoCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('💡 $title',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(content,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12, height: 1.5)),
      ]),
    );
  }
}

// ── 레이더 차트 ───────────────────────────────────────────────────────────────

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
    final r = min(cx, cy) - 36;
    final n = axes.length;
    final step = 2 * pi / n;
    double angle(int i) => -pi / 2 + i * step;

    Offset pt(int i, double frac) => Offset(
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
        final p = pt(i, frac);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axis lines
    final axisPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 0; i < n; i++) {
      canvas.drawLine(Offset(cx, cy), pt(i, 1.0), axisPaint);
    }

    // Fill polygon
    final fillPath = Path();
    for (int i = 0; i < n; i++) {
      final p = pt(i, axes[i].value.clamp(0.05, 1.0));
      i == 0 ? fillPath.moveTo(p.dx, p.dy) : fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.close();

    canvas.drawPath(fillPath,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill);
    canvas.drawPath(fillPath,
        Paint()
          ..color = AppColors.primaryLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Dots & labels
    final dotPaint = Paint()..style = PaintingStyle.fill;
    const labelStyle = TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w600);

    for (int i = 0; i < n; i++) {
      final p = pt(i, axes[i].value.clamp(0.05, 1.0));
      dotPaint.color = axes[i].color;
      canvas.drawCircle(p, 4, dotPaint);

      final lp = pt(i, 1.22);
      final span = TextSpan(text: axes[i].label, style: labelStyle);
      final tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center)
        ..layout();
      tp.paint(
          canvas, Offset(lp.dx - tp.width / 2, lp.dy - tp.height / 2));
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
      ('메타인지', scores.metacognition, const Color(0xFF8B5CF6)),
      ('일관성', scores.consistency, const Color(0xFF06B6D4)),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items.map((item) {
        final (label, score, color) = item;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$label $score',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ]);
      }).toList(),
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────────────────────────

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
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
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
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                    width: 4,
                    height: 4,
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

// ── Sticky TabBar delegate ─────────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBar(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.bg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBar old) => false;
}
