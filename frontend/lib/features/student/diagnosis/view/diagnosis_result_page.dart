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
    final color = LearningStyleUtil.color(p.primaryStyle);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.bg,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHero(p, color),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
              onPressed: () => context.go('/student/home'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildBadges(p),
                const SizedBox(height: 24),
                _buildSummaryCard(p),
                const SizedBox(height: 20),
                _buildAiAnalysis(),
                const SizedBox(height: 20),
                _buildStrengths(),
                const SizedBox(height: 20),
                _buildRecommendations(),
                const SizedBox(height: 32),
                GlowButton(
                  text: '학습 시작하기',
                  onTap: () => context.go('/student/home'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(DiagnosisProfile p, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.2), AppColors.bg],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            Text(LearningStyleUtil.emoji(p.primaryStyle), style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('나의 학습 유형', style: TextStyle(
              color: AppColors.textMuted, fontSize: 13,
            )),
            const SizedBox(height: 4),
            Text(p.primaryStyle, style: TextStyle(
              color: color, fontSize: 36, fontWeight: FontWeight.w900,
            )),
            const SizedBox(height: 6),
            Text(LearningStyleUtil.description(p.primaryStyle), style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges(DiagnosisProfile p) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TypeBadge(
          label: '부 스타일: ${p.secondaryStyle}',
          color: LearningStyleUtil.color(p.secondaryStyle),
        ),
        TypeBadge(label: p.socialType, color: AppColors.secondary),
        TypeBadge(label: p.cognitiveType, color: AppColors.accent),
      ],
    );
  }

  Widget _buildSummaryCard(DiagnosisProfile p) {
    return AppCard(
      borderColor: AppColors.primaryLight.withValues(alpha: 0.3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.psychology_outlined, color: AppColors.primaryLight, size: 18),
          SizedBox(width: 8),
          Text('성향 요약', style: TextStyle(
            color: AppColors.primaryLight, fontSize: 14, fontWeight: FontWeight.w700,
          )),
        ]),
        const SizedBox(height: 12),
        Text(p.personalitySummary, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 14, height: 1.6,
        )),
      ]),
    );
  }

  Widget _buildAiAnalysis() {
    if (result.aiAnalysis.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome, color: AppColors.gold, size: 18),
          SizedBox(width: 8),
          Text('AI 심층 분석', style: TextStyle(
            color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w700,
          )),
        ]),
        const SizedBox(height: 12),
        Text(result.aiAnalysis, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 14, height: 1.6,
        )),
      ]),
    );
  }

  Widget _buildStrengths() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle(title: '강점', subtitle: '이 성향의 학습 강점'),
      const SizedBox(height: 12),
      ...result.strengths.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('✓ ', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          Expanded(child: Text(s, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 14, height: 1.4,
          ))),
        ]),
      )),
      if (result.weaknesses.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionTitle(title: '개선 포인트'),
        const SizedBox(height: 12),
        ...result.weaknesses.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('→ ', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
            Expanded(child: Text(w, style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14, height: 1.4,
            ))),
          ]),
        )),
      ],
    ]);
  }

  Widget _buildRecommendations() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle(title: '맞춤 학습법'),
      const SizedBox(height: 12),
      ...result.recommendations.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${e.key + 1}', style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13,
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(e.value, style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14,
            ))),
          ]),
        ),
      )),
    ]);
  }
}
