import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/widgets/fl_markdown.dart';
import '../../../../shared/widgets/fl_ui.dart';

/// 교수용 학습 분석 대시보드 — 수강생 성향 분포 + AI 수업 인사이트
class DashboardPage extends StatefulWidget {
  final String roomId;
  const DashboardPage({super.key, required this.roomId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async =>
      Map<String, dynamic>.from(await ApiService().getDashboard(widget.roomId));

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 32.0;
    return Scaffold(
      backgroundColor: FL.bg,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            final data = snap.data;
            return Column(children: [
              _Header(
                title: (data?['room'] as Map?)?['subject'] as String? ?? '학습 분석',
                onBack: () => context.canPop() ? context.pop() : context.go('/professor/home'),
                onRefresh: () => setState(() {
                  _future = _load();
                }),
              ),
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const _Loading()
                    : snap.hasError || data == null
                        ? Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Text('대시보드를 불러오지 못했어요', style: TextStyle(color: FL.textSec)),
                              const SizedBox(height: 14),
                              FLButton('다시 시도', kind: FLButtonKind.secondary, onPressed: () => setState(() {
                                    _future = _load();
                                  })),
                            ]),
                          )
                        : SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(pad, 28, pad, 64),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1080),
                                child: _Body(data: data, roomId: widget.roomId),
                              ),
                            ),
                          ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  const _Header({required this.title, required this.onBack, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: FL.border))),
      child: Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: FL.textSec)),
        const SizedBox(width: 4),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('학습 분석 대시보드', style: TextStyle(color: FL.textMute, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: FL.text, fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
        ),
        IconButton(
          tooltip: '새로고침',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, color: FL.textSec),
        ),
      ]),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: FL.lime, strokeWidth: 3)),
        SizedBox(height: 16),
        Text('수강생 성향을 분석하고 있어요', style: TextStyle(color: FL.text, fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text('AI가 수업 설계 인사이트를 함께 만들고 있어요 (약 5초)', style: TextStyle(color: FL.textMute, fontSize: 13)),
      ]),
    );
  }
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;
  final String roomId;
  const _Body({required this.data, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final total = (data['total_students'] as num?)?.toInt() ?? 0;
    final diagnosed = (data['diagnosed_count'] as num?)?.toInt() ?? 0;
    final style = Map<String, num>.from(data['style_distribution'] as Map? ?? {});
    final social = Map<String, num>.from(data['social_distribution'] as Map? ?? {});
    final cognitive = Map<String, num>.from(data['cognitive_distribution'] as Map? ?? {});
    final students = (data['students'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final insight = (data['ai_insight'] as String? ?? '').trim();
    final completion = ((data['room'] as Map?)?['completion_rate'] as num?)?.toInt() ?? 0;
    final top = style.entries.isEmpty ? null : (style.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final stats = [
      _Stat('수강생', '$total명', FL.lime, Icons.people_rounded),
      _Stat('성향 진단 완료', total == 0 ? '-' : '${(diagnosed / total * 100).round()}%', FL.mint, Icons.psychology_rounded),
      _Stat('평균 진도', '$completion%', FL.sky, Icons.trending_up_rounded),
      _Stat('가장 많은 유형', top == null ? '-' : top.key, top == null ? FL.textSec : StyleMeta.of(top.key).color,
          Icons.auto_awesome_rounded),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 800 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final s in stats) SizedBox(width: w, child: _StatTile(stat: s)),
        ]);
      }),
      const SizedBox(height: 20),
      if (insight.isNotEmpty)
        FLCard(
          color: FL.lavender.withValues(alpha: 0.05),
          borderColor: FL.lavender.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 17, color: FL.lavender),
              SizedBox(width: 8),
              Text('AI 수업 설계 인사이트', style: TextStyle(color: FL.text, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            FLMarkdown(insight, scale: 0.92, accent: FL.lavender),
          ]),
        ),
      const SizedBox(height: 20),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: _DistributionCard(title: '학습 스타일 분포', data: style, total: diagnosed, styled: true)),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(children: [
              _DistributionCard(title: '인지 유형', data: cognitive, total: diagnosed),
              const SizedBox(height: 16),
              _DistributionCard(title: '학습 상호작용', data: social, total: diagnosed),
            ]),
          ),
        ])
      else ...[
        _DistributionCard(title: '학습 스타일 분포', data: style, total: diagnosed, styled: true),
        const SizedBox(height: 16),
        _DistributionCard(title: '인지 유형', data: cognitive, total: diagnosed),
        const SizedBox(height: 16),
        _DistributionCard(title: '학습 상호작용', data: social, total: diagnosed),
      ],
      const SizedBox(height: 20),
      FLCard(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('수강생', style: TextStyle(color: FL.text, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('${students.length}', style: const TextStyle(color: FL.textMute, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          const Text('같은 교안이 학생마다 이 성향에 맞춰 다르게 재구성되고 있어요',
              style: TextStyle(color: FL.textMute, fontSize: 12.5)),
          const SizedBox(height: 12),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('아직 수강생이 없어요.', style: TextStyle(color: FL.textSec)),
            ),
          for (final s in students) _StudentRow(student: s),
        ]),
      ),
    ]);
  }
}

class _Stat {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _Stat(this.label, this.value, this.color, this.icon);
}

class _StatTile extends StatelessWidget {
  final _Stat stat;
  const _StatTile({required this.stat});

  @override
  Widget build(BuildContext context) {
    return FLCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(stat.icon, size: 16, color: stat.color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(stat.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: FL.textMute, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(stat.value,
            style: TextStyle(color: stat.color, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
      ]),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final String title;
  final Map<String, num> data;
  final int total;
  final bool styled;
  const _DistributionCard({required this.title, required this.data, required this.total, this.styled = false});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sum = entries.fold<num>(0, (a, e) => a + e.value);
    const palette = [FL.sky, FL.amber, FL.coral, FL.mint, FL.lavender];
    return FLCard(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: FL.text, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Text('진단을 완료한 수강생이 없어요.', style: TextStyle(color: FL.textMute, fontSize: 13)),
        for (var i = 0; i < entries.length; i++) ...[
          _Bar(
            label: styled ? '${StyleMeta.of(entries[i].key).emoji} ${entries[i].key}' : entries[i].key,
            value: entries[i].value,
            ratio: sum == 0 ? 0 : entries[i].value / sum,
            color: styled ? StyleMeta.of(entries[i].key).color : palette[i % palette.length],
          ),
          if (i < entries.length - 1) const SizedBox(height: 14),
        ],
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final num value;
  final double ratio;
  final Color color;
  const _Bar({required this.label, required this.value, required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: FL.text, fontSize: 13.5, fontWeight: FontWeight.w600))),
        Text('${value.toInt()}명 · ${(ratio * 100).round()}%',
            style: const TextStyle(color: FL.textSec, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 8,
            color: color,
            backgroundColor: FL.surface3,
          ),
        ),
      ),
    ]);
  }
}

class _StudentRow extends StatelessWidget {
  final Map<String, dynamic> student;
  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final name = student['name'] as String? ?? '학생';
    final style = student['primary_style'] as String?;
    final meta = style == null ? null : StyleMeta.of(style);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: FL.border))),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: (meta?.color ?? FL.textMute).withValues(alpha: 0.15),
          child: Text(name.characters.first,
              style: TextStyle(color: meta?.color ?? FL.textSec, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: const TextStyle(color: FL.text, fontSize: 14, fontWeight: FontWeight.w600))),
        if (meta != null)
          FLTag('${meta.emoji} ${meta.key}', color: meta.color)
        else
          const FLTag('진단 전', color: FL.textMute),
        if (student['cognitive_type'] != null) ...[
          const SizedBox(width: 6),
          FLTag(student['cognitive_type'] as String, color: FL.textSec),
        ],
      ]),
    );
  }
}
