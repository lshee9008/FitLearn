import 'package:flutter/material.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class DashboardPage extends StatefulWidget {
  final String roomId;
  const DashboardPage({super.key, required this.roomId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getDashboard(widget.roomId);
      setState(() { _data = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_data?['room']?['subject'] as String? ?? '대시보드'),
        backgroundColor: AppColors.bg,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : _data == null
              ? const Center(child: Text('데이터를 불러올 수 없습니다', style: TextStyle(color: AppColors.textMuted)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final total = _data!['total_students'] as int? ?? 0;
    final diagnosed = _data!['diagnosed_count'] as int? ?? 0;
    final styleDist = Map<String, int>.from(_data!['style_distribution'] as Map? ?? {});
    final socialDist = Map<String, int>.from(_data!['social_distribution'] as Map? ?? {});
    final insight = _data!['ai_insight'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 통계 카드
        Row(children: [
          Expanded(child: _MiniStat(label: '전체 학생', value: '$total', color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: _MiniStat(label: '진단 완료', value: '$diagnosed', color: AppColors.accent)),
          const SizedBox(width: 12),
          Expanded(child: _MiniStat(
            label: '진단율',
            value: total > 0 ? '${(diagnosed / total * 100).round()}%' : '-',
            color: AppColors.secondary,
          )),
        ]),
        const SizedBox(height: 24),

        // AI 인사이트
        if (insight.isNotEmpty) ...[
          AppCard(
            borderColor: AppColors.gold.withValues(alpha: 0.3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.auto_awesome, color: AppColors.gold, size: 18),
                SizedBox(width: 8),
                Text('AI 교수 인사이트', style: TextStyle(
                  color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w700,
                )),
              ]),
              const SizedBox(height: 12),
              Text(insight, style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.6,
              )),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        // 학습 스타일 분포
        if (styleDist.isNotEmpty) ...[
          const SectionTitle(title: '학습 스타일 분포'),
          const SizedBox(height: 16),
          ..._buildDistribution(styleDist, diagnosed),
          const SizedBox(height: 20),
        ],

        // 사회적 성향 분포
        if (socialDist.isNotEmpty) ...[
          const SectionTitle(title: '사회적 성향'),
          const SizedBox(height: 16),
          ..._buildDistribution(socialDist, diagnosed, useStyle: false),
          const SizedBox(height: 20),
        ],

        // 학생 목록
        const SectionTitle(title: '학생별 현황'),
        const SizedBox(height: 16),
        ..._buildStudentList(),
      ],
    );
  }

  List<Widget> _buildDistribution(Map<String, int> dist, int total, {bool useStyle = true}) {
    return dist.entries.map((e) {
      final ratio = total > 0 ? e.value / total : 0.0;
      final color = useStyle ? LearningStyleUtil.color(e.key) : AppColors.secondary;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (useStyle) Text(LearningStyleUtil.emoji(e.key), style: const TextStyle(fontSize: 16)),
            if (useStyle) const SizedBox(width: 8),
            Text(e.key, style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
            )),
            const Spacer(),
            Text('${e.value}명 (${(ratio * 100).round()}%)', style: const TextStyle(
              color: AppColors.textMuted, fontSize: 13,
            )),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.bgSurface,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
      );
    }).toList();
  }

  List<Widget> _buildStudentList() {
    final students = _data!['students'] as List<dynamic>? ?? [];
    if (students.isEmpty) {
      return [const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('아직 학생이 없습니다', style: TextStyle(color: AppColors.textMuted)),
      ))];
    }
    return students.map((s) {
      final student = s as Map<String, dynamic>;
      final style = student['primary_style'] as String?;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: style != null
                  ? LearningStyleUtil.color(style).withValues(alpha: 0.15)
                  : AppColors.bgSurface,
              child: Text(
                (student['name'] as String? ?? '?').substring(0, 1),
                style: TextStyle(
                  color: style != null ? LearningStyleUtil.color(style) : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student['name'] as String? ?? '학생', style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14,
              )),
              if (style != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${LearningStyleUtil.emoji(style)} $style · ${student['social_type'] ?? ''} · ${student['cognitive_type'] ?? ''}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ] else
                const Text('미진단', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ])),
            if (style != null)
              TypeBadge(label: style, color: LearningStyleUtil.color(style)),
          ]),
        ),
      );
    }).toList();
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text(value, style: TextStyle(
          color: color, fontSize: 28, fontWeight: FontWeight.w900,
        )),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    );
  }
}
