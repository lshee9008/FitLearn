import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class CorePointReviewPage extends ConsumerStatefulWidget {
  final String roomId;
  final String lectureId;
  final Map<String, dynamic> uploadData;

  const CorePointReviewPage({
    super.key,
    required this.roomId,
    required this.lectureId,
    required this.uploadData,
  });

  @override
  ConsumerState<CorePointReviewPage> createState() => _CorePointReviewPageState();
}

class _CorePointReviewPageState extends ConsumerState<CorePointReviewPage> {
  late List<Map<String, dynamic>> _points;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.uploadData['core_points'] as List<dynamic>? ?? [];
    _points = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _toggleConfirm(int i) => setState(() =>
      _points[i]['confirmed'] = !(_points[i]['confirmed'] as bool? ?? true));

  void _updatePriority(int i, int val) => setState(() => _points[i]['priority'] = val);

  Future<void> _confirm() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    setState(() => _confirming = true);
    try {
      final confirmed = _points.where((p) => p['confirmed'] as bool? ?? true).toList();
      await ApiService().confirmCorePoints(
        roomId: widget.roomId,
        lectureId: widget.lectureId,
        professorUid: user.userId,
        points: confirmed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('핵심 포인트가 확정되었습니다. 학생들이 맞춤 교안을 학습할 수 있습니다.'),
            backgroundColor: AppColors.accent,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.uploadData['title'] as String? ?? '교안';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('핵심 포인트 검토'),
        backgroundColor: AppColors.bg,
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                borderColor: AppColors.gold.withValues(alpha: 0.3),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700,
                    )),
                    const SizedBox(height: 2),
                    const Text('AI가 추출한 핵심 포인트를 검토해주세요', style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12,
                    )),
                  ])),
                ]),
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: '핵심 포인트',
                subtitle: '체크 해제 시 제외됩니다',
              ),
              const SizedBox(height: 16),
              ..._points.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PointCard(
                  index: e.key,
                  point: e.value,
                  onToggle: () => _toggleConfirm(e.key),
                  onPriorityChanged: (v) => _updatePriority(e.key, v),
                ),
              )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: GlowButton(
            text: '확정 — 학생 교안 활성화',
            loading: _confirming,
            onTap: !_confirming ? _confirm : null,
            color: AppColors.accent,
          ),
        ),
      ]),
    );
  }
}

class _PointCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> point;
  final VoidCallback onToggle;
  final ValueChanged<int> onPriorityChanged;

  const _PointCard({
    required this.index,
    required this.point,
    required this.onToggle,
    required this.onPriorityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final confirmed = point['confirmed'] as bool? ?? true;
    final priority = point['priority'] as int? ?? 1;

    return AnimatedOpacity(
      opacity: confirmed ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: AppCard(
        borderColor: confirmed ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: confirmed ? AppColors.accent : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: confirmed ? AppColors.accent : AppColors.borderLight,
                  ),
                ),
                child: confirmed
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(point['content'] as String? ?? '', style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14, height: 1.5,
            ))),
          ]),
          if (confirmed) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Text('우선순위: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ...List.generate(5, (i) => GestureDetector(
                onTap: () => onPriorityChanged(i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < priority ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
              )),
            ]),
          ],
        ]),
      ),
    );
  }
}
