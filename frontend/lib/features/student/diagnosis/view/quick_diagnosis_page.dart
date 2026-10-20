import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fl_ui.dart';
import '../../../auth/provider/auth_provider.dart';
import '../provider/diagnosis_provider.dart';

class _Question {
  final String id;
  final String title;
  final String hint;
  final List<(String, String, String)> options; // (key, emoji, label)
  const _Question(this.id, this.title, this.hint, this.options);
}

const _questions = [
  _Question('q1', '새로운 개념을 처음 배울 때, 가장 먼저 찾는 건?', '가장 끌리는 하나를 골라주세요', [
    ('A', '🗺️', '그림이나 도표로 전체 구조 보기'),
    ('B', '🎧', '누군가의 설명이나 강의 듣기'),
    ('C', '📖', '잘 정리된 글이나 교재 읽기'),
    ('D', '🛠️', '일단 직접 해보면서 익히기'),
  ]),
  _Question('q2', '처음 가보는 장소를 찾아갈 때 나는?', '평소 습관을 떠올려보세요', [
    ('A', '🧭', '지도 앱으로 경로를 먼저 본다'),
    ('B', '🗣️', '아는 사람에게 말로 물어본다'),
    ('C', '📝', '글로 된 길 안내를 읽는다'),
    ('D', '🚶', '일단 출발해서 걸으며 찾는다'),
  ]),
  _Question('q3', '시험 공부를 할 때 가장 효과적이었던 방법은?', '', [
    ('A', '🧠', '마인드맵·도식으로 정리'),
    ('B', '💬', '소리 내어 설명하거나 토론'),
    ('C', '✍️', '노트에 깔끔하게 요약 필기'),
    ('D', '🎯', '문제를 많이 풀면서 익히기'),
  ]),
  _Question('q4', '공부에 집중하는 나의 리듬은?', '', [
    ('A', '⏱️', '짧게 여러 번 — 25분 집중, 쉬고 반복'),
    ('B', '🌊', '한 번 앉으면 오래 — 깊게 몰입'),
  ]),
  _Question('q5', '어떤 설명이 가장 잘 맞나요?', '', [
    ('A', '⚡', '핵심만 빠르게, 짧게'),
    ('B', '🔍', '원리부터 하나하나 자세하게'),
    ('C', '📌', '예시와 사례 위주로'),
  ]),
  _Question('q6', '어려운 부분에서 막혔을 때 나는?', '', [
    ('A', '➡️', '일단 넘어가고 나중에 다시 본다'),
    ('B', '🪜', '더 쉬운 예시부터 다시 시작한다'),
    ('C', '🙋', '바로 질문하거나 도움을 구한다'),
  ]),
];

/// 6문항 빠른 학습 성향 진단 — 결과 확인 후 곧바로 맞춤 교안으로 이동
class QuickDiagnosisPage extends ConsumerStatefulWidget {
  final String? next;
  const QuickDiagnosisPage({super.key, this.next});

  @override
  ConsumerState<QuickDiagnosisPage> createState() => _QuickDiagnosisPageState();
}

class _QuickDiagnosisPageState extends ConsumerState<QuickDiagnosisPage> {
  final Map<String, String> _answers = {};
  int _index = 0;
  bool _submitting = false;
  DiagnosisResult? _result;

  Future<void> _pick(String key) async {
    final q = _questions[_index];
    setState(() => _answers[q.id] = key);
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    if (_index < _questions.length - 1) {
      setState(() => _index++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final user = await ref.read(authNotifierProvider.notifier).ready();
    if (!mounted) return;
    if (user == null) {
      context.go('/');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(diagnosisNotifierProvider.notifier)
          .submitQuick(userId: user.userId, answers: _answers);
      await ref.read(authNotifierProvider.notifier).updateDiagnosis();
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진단 결과를 저장하지 못했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FL.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _result != null
                    ? _ResultView(
                        key: const ValueKey('result'),
                        result: _result!,
                        onContinue: () => context.go(widget.next ?? '/student/home'),
                        onFull: () => context.go('/student/diagnosis'),
                      )
                    : _submitting
                        ? const _Analyzing(key: ValueKey('analyzing'))
                        : _buildQuestion(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_index];
    return Column(
      key: ValueKey(q.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(
            tooltip: '이전',
            onPressed: _index == 0
                ? () => context.canPop() ? context.pop() : context.go('/student/home')
                : () => setState(() => _index--),
            icon: const Icon(Icons.arrow_back_rounded, color: FL.textSec),
          ),
          const SizedBox(width: 4),
          const FLTag('1분 학습 성향 진단', icon: Icons.bolt_rounded),
          const Spacer(),
          Text('${_index + 1} / ${_questions.length}',
              style: const TextStyle(color: FL.textMute, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (_index + 1) / _questions.length,
            minHeight: 4,
            color: FL.lime,
            backgroundColor: FL.surface2,
          ),
        ),
        const SizedBox(height: 36),
        Text(q.title,
            style: const TextStyle(
                color: FL.text, fontSize: 26, fontWeight: FontWeight.w800, height: 1.35, letterSpacing: -0.6)),
        if (q.hint.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(q.hint, style: const TextStyle(color: FL.textMute, fontSize: 14)),
        ],
        const SizedBox(height: 28),
        for (final (key, emoji, label) in q.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionTile(
              emoji: emoji,
              label: label,
              selected: _answers[q.id] == key,
              onTap: () => _pick(key),
            ),
          ),
      ],
    );
  }
}

class _OptionTile extends StatefulWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.emoji, required this.label, required this.selected, required this.onTap});

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: widget.selected ? FL.lime.withValues(alpha: 0.1) : (active ? FL.surface2 : FL.surface),
            borderRadius: BorderRadius.circular(FL.r16),
            border: Border.all(
              color: widget.selected ? FL.lime : (active ? FL.borderStrong : FL.border),
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(
                    color: widget.selected ? FL.text : FL.textSec,
                    fontSize: 16,
                    fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                  )),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: widget.selected ? 1 : 0,
              child: const Icon(Icons.check_circle_rounded, color: FL.lime, size: 20),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(children: [
        SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: FL.lime, strokeWidth: 3)),
        SizedBox(height: 22),
        Text('학습 성향을 분석하고 있어요',
            style: TextStyle(color: FL.text, fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ResultView extends StatelessWidget {
  final DiagnosisResult result;
  final VoidCallback onContinue;
  final VoidCallback onFull;
  const _ResultView({super.key, required this.result, required this.onContinue, required this.onFull});

  @override
  Widget build(BuildContext context) {
    final p = result.profile;
    final meta = StyleMeta.of(p.learningStyle);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Center(child: FLTag('진단 완료', icon: Icons.check_rounded)),
      const SizedBox(height: 20),
      Center(child: Text(meta.emoji, style: const TextStyle(fontSize: 56))),
      const SizedBox(height: 12),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: '당신은 '),
          TextSpan(text: meta.key, style: TextStyle(color: meta.color)),
          const TextSpan(text: ' 학습자예요'),
        ]),
        textAlign: TextAlign.center,
        style: const TextStyle(color: FL.text, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8),
      ),
      const SizedBox(height: 12),
      Text(p.analysis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: FL.textSec, fontSize: 15, height: 1.6)),
      const SizedBox(height: 24),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        FLTag(p.focusPattern, color: FL.sky),
        FLTag('${p.preferredFormat} 선호', color: FL.lavender),
        FLTag(p.pace, color: FL.amber),
      ]),
      const SizedBox(height: 28),
      FLCard(
        color: meta.color.withValues(alpha: 0.06),
        borderColor: meta.color.withValues(alpha: 0.3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('그래서 FitLearn은 교안을 이렇게 바꿔드려요',
              style: TextStyle(color: meta.color, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final s in result.strategies)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.arrow_right_rounded, color: meta.color, size: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(s, style: const TextStyle(color: FL.text, fontSize: 14.5, height: 1.5)),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 28),
      FLButton('내 맞춤 교안 보러 가기', trailingIcon: Icons.arrow_forward_rounded, large: true, expand: true,
          onPressed: onContinue),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: onFull,
          child: const Text('더 정밀한 22문항 진단 받기',
              style: TextStyle(color: FL.textMute, fontSize: 13, decoration: TextDecoration.underline)),
        ),
      ),
    ]);
  }
}
