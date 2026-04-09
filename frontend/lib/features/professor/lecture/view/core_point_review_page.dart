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
  ConsumerState<CorePointReviewPage> createState() =>
      _CorePointReviewPageState();
}

class _CorePointReviewPageState extends ConsumerState<CorePointReviewPage> {
  late List<Map<String, dynamic>> _points;
  bool _confirming = false;
  final _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final raw = widget.uploadData['core_points'] as List<dynamic>? ?? [];
    _points = raw
        .map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['confirmed'] = m['confirmed'] ?? true;
          m['priority'] = (m['priority'] as num?)?.toInt() ?? 3;
          m['topic'] = m['topic'] as String? ?? '';
          m['difficulty'] = m['difficulty'] as String? ?? '중';
          m['review_question'] = m['review_question'] as String? ?? '';
          return m;
        })
        .toList();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _toggle(int i) => setState(
      () => _points[i]['confirmed'] = !(_points[i]['confirmed'] as bool));

  void _setPriority(int i, int v) =>
      setState(() => _points[i]['priority'] = v);

  void _delete(int i) => setState(() => _points.removeAt(i));

  void _addPoint() {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _points.add({
        'id': _points.length + 1,
        'content': text,
        'priority': 3,
        'confirmed': true,
      });
      _addCtrl.clear();
    });
  }

  void _updateContent(int i, String text) =>
      setState(() => _points[i]['content'] = text);

  Future<void> _confirm() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _confirming = true);
    try {
      final confirmed =
          _points.where((p) => p['confirmed'] as bool).toList();
      if (confirmed.isEmpty) {
        messenger.showSnackBar(const SnackBar(
            content: Text('최소 1개 이상의 포인트를 포함해주세요.')));
        setState(() => _confirming = false);
        return;
      }
      await ApiService().confirmCorePoints(
        roomId: widget.roomId,
        lectureId: widget.lectureId,
        professorUid: user.userId,
        points: confirmed,
      );
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: const Text('확정 완료! 학생들이 맞춤 교안을 학습할 수 있습니다.'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.pop();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('오류: $e')));
      setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.uploadData['title'] as String? ?? '교안';
    final activeCount = _points.where((p) => p['confirmed'] as bool).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // ── 헤더 ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('핵심 포인트 검토',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  Text('교수 확정 후 학생 맞춤 교안이 생성됩니다',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$activeCount개 선택',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── 교안 요약 카드 ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PipelineResultCard(uploadData: widget.uploadData, title: title),
          ),
          const SizedBox(height: 16),

          // ── 포인트 리스트 ─────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                ..._points.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PointCard(
                        index: e.key,
                        point: e.value,
                        onToggle: () => _toggle(e.key),
                        onPriorityChanged: (v) => _setPriority(e.key, v),
                        onDelete: () => _delete(e.key),
                        onContentChanged: (t) => _updateContent(e.key, t),
                      ),
                    )),

                // ── 포인트 추가 ───────────────────────────────────
                AppCard(
                  borderColor: AppColors.border,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('포인트 추가',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _addCtrl,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: '추가할 핵심 포인트를 입력하세요',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addPoint(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _addPoint,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── 확정 버튼 ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: GlowButton(
              text: '확정하기 — 학생 교안 활성화',
              loading: _confirming,
              onTap: _confirming ? null : _confirm,
              color: AppColors.accent,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 파이프라인 결과 카드 ──────────────────────────────────────────────────────

class _PipelineResultCard extends StatelessWidget {
  final Map<String, dynamic> uploadData;
  final String title;
  const _PipelineResultCard({required this.uploadData, required this.title});

  @override
  Widget build(BuildContext context) {
    final summary = uploadData['lecture_summary'] as String? ?? '';
    final topics = (uploadData['topics'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final objectives = (uploadData['learning_objectives'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final difficulty = uploadData['estimated_difficulty'] as String? ?? '중';
    final diffColor = difficulty == '상'
        ? AppColors.rose
        : difficulty == '중'
            ? AppColors.gold
            : AppColors.accent;

    return AppCard(
      borderColor: AppColors.gold.withValues(alpha: 0.3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📄', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: diffColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('난이도 $difficulty',
                style: TextStyle(
                    color: diffColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(summary,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.5)),
        ],
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: topics
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.secondary
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(t,
                          style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ],
        if (objectives.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('학습 목표',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...objectives.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ',
                      style: TextStyle(
                          color: AppColors.primaryLight, fontSize: 11)),
                  Expanded(
                      child: Text(o,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              height: 1.4))),
                ]),
              )),
        ],
      ]),
    );
  }
}

// ── 포인트 카드 ──────────────────────────────────────────────────────────────

class _PointCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> point;
  final VoidCallback onToggle;
  final ValueChanged<int> onPriorityChanged;
  final VoidCallback onDelete;
  final ValueChanged<String> onContentChanged;

  const _PointCard({
    required this.index,
    required this.point,
    required this.onToggle,
    required this.onPriorityChanged,
    required this.onDelete,
    required this.onContentChanged,
  });

  @override
  State<_PointCard> createState() => _PointCardState();
}

class _PointCardState extends State<_PointCard> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        TextEditingController(text: widget.point['content'] as String? ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = widget.point['confirmed'] as bool;
    final priority = (widget.point['priority'] as num?)?.toInt() ?? 3;
    final topic = widget.point['topic'] as String? ?? '';
    final difficulty = widget.point['difficulty'] as String? ?? '중';
    final reviewQ = widget.point['review_question'] as String? ?? '';
    final diffColor = difficulty == '상'
        ? AppColors.rose
        : difficulty == '중'
            ? AppColors.gold
            : AppColors.accent;

    return AnimatedOpacity(
      opacity: confirmed ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: AppCard(
        borderColor: confirmed
            ? AppColors.accent.withValues(alpha: 0.35)
            : AppColors.border,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 상단 행: 체크박스 + 번호 + 내용 + 삭제
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 24, height: 24, margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: confirmed ? AppColors.accent : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: confirmed ? AppColors.accent : AppColors.borderLight,
                  ),
                ),
                child: confirmed
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22, height: 22, margin: const EdgeInsets.only(top: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${widget.index + 1}',
                  style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                onChanged: widget.onContentChanged,
                enabled: confirmed,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                maxLines: null,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: '핵심 포인트 내용',
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded,
                    color: AppColors.textMuted.withValues(alpha: 0.6), size: 18),
              ),
            ),
          ]),

          // 주제·난이도 배지
          if (topic.isNotEmpty || difficulty.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (topic.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(topic,
                      style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('난이도 $difficulty',
                    style: TextStyle(
                        color: diffColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ],

          // AI 검토 질문
          if (confirmed && reviewQ.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('💡', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(reviewQ,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4))),
              ]),
            ),
          ],

          // 중요도 슬라이더
          if (confirmed) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Text('중요도',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: AppColors.gold,
                    inactiveTrackColor: AppColors.bgSurface,
                    thumbColor: AppColors.gold,
                    overlayColor: AppColors.gold.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: priority.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (v) =>
                        widget.onPriorityChanged(v.round()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < priority
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.gold,
                    size: 14,
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
