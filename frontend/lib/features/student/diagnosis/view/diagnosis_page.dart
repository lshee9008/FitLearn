import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../provider/diagnosis_provider.dart';

class _Q {
  final int id;
  final String part;
  final String text;
  final List<String> options;
  const _Q(this.id, this.part, this.text, this.options);
}

const _questions = [
  _Q(1, 'A', '새로운 개념을 배울 때 가장 도움이 되는 것은?',
      ['도표·그림으로 시각화', '강의 듣거나 소리 내어 이해', '교재 꼼꼼히 읽고 필기', '직접 해보며 체득']),
  _Q(2, 'A', '강의 내용을 복습할 때 주로 어떻게 하나요?',
      ['마인드맵·도식으로 정리', '혼자 설명해보거나 녹음 듣기', '노트 필기 다시 읽기', '예제·문제 직접 풀기']),
  _Q(3, 'A', '기억에 가장 오래 남는 학습 방식은?',
      ['색깔펜·하이라이트·그림 활용', '친구에게 설명하거나 토론', '꼼꼼한 반복 읽기', '실험·실습·프로젝트']),
  _Q(4, 'A', '어려운 개념 이해 시 먼저 하는 것은?',
      ['관련 이미지·영상 검색', '교수나 친구에게 설명 요청', '관련 문서·책 더 읽기', '비슷한 문제 직접 풀기']),
  _Q(5, 'A', '선호하는 수업 형태는?',
      ['슬라이드·판서 중심 시각 수업', '강의·토론·발표 중심', '자료 중심 자기 주도 학습', '실험·프로젝트·실습 기반']),
  _Q(6, 'B', '문제 해결 시 접근 방식은?',
      ['논리적으로 단계별 분석', '전체 그림 보고 직관적 파악', '상황에 따라 다름', '']),
  _Q(7, 'B', '새로운 정보를 접할 때?',
      ['세부사항부터 꼼꼼히 확인', '큰 흐름과 핵심부터 파악', '중요도에 따라 다름', '']),
  _Q(8, 'B', '계획 수립 방식은?',
      ['세부 일정까지 촘촘히 계획', '큰 방향만 정하고 유연하게', '중간 정도의 계획', '']),
  _Q(9, 'B', '판단을 내릴 때?',
      ['충분한 데이터·근거 확인 후', '경험과 직감으로 빠르게', '상황에 따라 다름', '']),
  _Q(10, 'B', '학습 중 막힐 때?',
      ['원인 파악 후 체계적으로 해결', '잠시 쉬다가 새 시각으로 접근', '둘 다 해봄', '']),
  _Q(11, 'C', '집중이 잘 되는 학습 환경은?',
      ['완전히 조용한 공간', '약간의 배경음이 있는 공간', '카페·공공장소', '환경 상관없음']),
  _Q(12, 'C', '공부가 가장 잘 되는 방식은?',
      ['짧게 여러 번 (25분 집중 후 휴식)', '한 번에 길게 몰입 (2시간+)', '불규칙하게 그때그때', '']),
  _Q(13, 'C', '새 내용을 배울 때 선호하는 방식은?',
      ['핵심만 빠르게 파악 후 넘어감', '하나씩 완벽히 이해 후 진행', '예시·사례 통해 이해', '']),
  _Q(14, 'C', '피드백 선호 방식은?',
      ['즉각적이고 짧은 피드백', '상세하고 심층적인 피드백', '동료와 함께 상호 피드백', '']),
  _Q(15, 'C', '혼자 vs 함께 공부할 때?',
      ['혼자 집중이 훨씬 효율적', '함께 공부가 더 동기부여', '상황에 따라 다름', '']),
];

const _partColors = {
  'A': AppColors.primary,
  'B': AppColors.secondary,
  'C': AppColors.accent,
};
const _partLabels = {'A': '학습 스타일', 'B': '인지 유형', 'C': '학습 환경'};

class DiagnosisPage extends ConsumerStatefulWidget {
  const DiagnosisPage({super.key});

  @override
  ConsumerState<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends ConsumerState<DiagnosisPage>
    with TickerProviderStateMixin {
  int _current = 0;
  final Map<int, String> _answers = {};
  late AnimationController _slideCtrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _buildAnim(true);
    _slideCtrl.forward();
  }

  void _buildAnim(bool fwd) {
    _slide = Tween<Offset>(
      begin: Offset(fwd ? 1.0 : -1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _select(String label) =>
      setState(() => _answers[_questions[_current].id] = label);

  Future<void> _next() async {
    if (_answers[_questions[_current].id] == null) return;
    if (_current < _questions.length - 1) {
      _buildAnim(true);
      _slideCtrl.reset();
      setState(() => _current++);
      _slideCtrl.forward();
    } else {
      await _submit();
    }
  }

  void _prev() {
    if (_current == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    _buildAnim(false);
    _slideCtrl.reset();
    setState(() => _current--);
    _slideCtrl.forward();
  }

  Future<void> _submit() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    final answers = _answers.entries
        .map((e) => {'question_id': e.key, 'answer': e.value})
        .toList();
    try {
      final result = await ref
          .read(diagnosisNotifierProvider.notifier)
          .submit(user.userId, answers);
      if (mounted) context.push('/student/diagnosis/result', extra: result);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final diagState = ref.watch(diagnosisNotifierProvider);
    final q = _questions[_current];
    final partColor = _partColors[q.part]!;

    if (diagState is AsyncLoading) return _LoadingScreen();
    if (diagState is AsyncError) {
      return _ErrorScreen(
          message: diagState.error.toString(), onRetry: _submit);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(q, partColor),
          Expanded(
            child: SlideTransition(
              position: _slide,
              child: _QuestionCard(
                key: ValueKey(_current),
                question: q,
                partColor: partColor,
                answered: _answers[q.id],
                onSelect: _select,
              ),
            ),
          ),
          _buildNavBtn(),
        ]),
      ),
    );
  }

  Widget _buildHeader(_Q q, Color partColor) {
    final progress = (_current + 1) / _questions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: _prev,
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: partColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('파트 ${q.part} · ${_partLabels[q.part]}',
                style: TextStyle(
                    color: partColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text('${_current + 1} / ${_questions.length}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgSurface,
            valueColor: AlwaysStoppedAnimation(partColor),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildNavBtn() {
    final answered = _answers[_questions[_current].id];
    final isLast = _current == _questions.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: GestureDetector(
        onTap: answered != null ? _next : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            color: answered != null ? AppColors.primary : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: answered != null
                ? [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6))]
                : null,
          ),
          child: Center(
            child: Text(
              isLast ? '결과 분석하기 →' : '다음 문항 →',
              style: TextStyle(
                color:
                    answered != null ? Colors.white : AppColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final _Q question;
  final Color partColor;
  final String? answered;
  final void Function(String) onSelect;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.partColor,
    required this.answered,
    required this.onSelect,
  });

  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final opts = question.options.where((o) => o.isNotEmpty).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(question.text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.4,
            )),
        const SizedBox(height: 28),
        ...List.generate(opts.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChoiceCard(
                label: _labels[i],
                text: opts[i],
                selected: answered == _labels[i],
                partColor: partColor,
                onTap: () => onSelect(_labels[i]),
              ),
            )),
      ]),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label, text;
  final bool selected;
  final Color partColor;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.label,
    required this.text,
    required this.selected,
    required this.partColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? partColor.withValues(alpha: 0.1)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? partColor : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? partColor : AppColors.bgSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label,
                style: TextStyle(
                  color:
                      selected ? Colors.white : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ))),
          if (selected)
            Icon(Icons.check_circle_rounded,
                color: partColor, size: 20),
        ]),
      ),
    );
  }
}

class _LoadingScreen extends StatefulWidget {
  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _msgIdx = 0;
  static const _msgs = [
    'AI가 학습 패턴을 분석하고 있어요',
    '6차원 성향을 도출하는 중이에요',
    '맞춤 학습 전략을 수립하고 있어요',
    '거의 다 됐어요',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800))
      ..repeat();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return false;
      setState(() => _msgIdx = (_msgIdx + 1) % _msgs.length);
      return true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                  child: Text('🧠',
                      style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 24),
            const Text('AI 분석 중',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(_msgs[_msgIdx],
                  key: ValueKey(_msgIdx),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14)),
            ),
            const SizedBox(height: 32),
            SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.bgSurface,
                  valueColor: const AlwaysStoppedAnimation(
                      AppColors.primaryLight),
                )),
          ])),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text('분석 실패',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('다시 시도',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      )),
    );
  }
}
