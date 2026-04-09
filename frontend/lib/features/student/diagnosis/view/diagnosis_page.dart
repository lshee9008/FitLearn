import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../provider/diagnosis_provider.dart';

// ── 질문 모델 ──────────────────────────────────────────────────────────────────

enum _QType { choice, scenario }

class _Q {
  final int id;
  final String part;
  final String framework;
  final String text;
  final List<String> options;
  final _QType type;
  final String emoji;

  const _Q({
    required this.id,
    required this.part,
    required this.framework,
    required this.text,
    required this.options,
    this.type = _QType.choice,
    this.emoji = '',
  });
}

// ── 25문항 (VARK 7 + Felder 6 + CLT 6 + Kolb 6) ──────────────────────────────

const _questions = <_Q>[
  // ── 파트A: VARK 학습 스타일 (Q1-7) ──────────────────────────────────────────
  _Q(id: 1, part: 'A', framework: 'VARK', text: '새로운 개념을 배울 때 가장 도움이 되는 것은?',
      options: ['도표·그림으로 시각화', '강의 듣거나 소리 내어 이해', '교재 꼼꼼히 읽고 필기', '직접 해보며 체득']),
  _Q(id: 2, part: 'A', framework: 'VARK', text: '강의 내용을 복습할 때 주로 어떻게 하나요?',
      options: ['마인드맵·도식으로 정리', '혼자 설명해보거나 녹음 듣기', '노트 필기 다시 읽기', '예제·문제 직접 풀기']),
  _Q(id: 3, part: 'A', framework: 'VARK', text: '기억에 가장 오래 남는 학습 방식은?',
      options: ['색깔펜·하이라이트·그림 활용', '친구에게 설명하거나 토론', '꼼꼼한 반복 읽기', '실험·실습·프로젝트']),
  _Q(id: 4, part: 'A', framework: 'VARK', text: '어려운 개념 이해 시 먼저 하는 것은?',
      options: ['관련 이미지·영상 검색', '교수나 친구에게 설명 요청', '관련 문서·책 더 읽기', '비슷한 문제 직접 풀기']),
  _Q(id: 5, part: 'A', framework: 'VARK',
      text: '복잡한 통계 그래프가 담긴 자료를 받았습니다. 어떻게 접근하나요?',
      options: ['색깔·축 레이블 등 시각 요소 먼저 파악', '아는 사람에게 구두로 설명 요청', '설명 텍스트와 주석 꼼꼼히 정독', '직접 유사 데이터 만들어 조작해봄'],
      type: _QType.scenario, emoji: '📊'),
  _Q(id: 6, part: 'A', framework: 'VARK', text: '선호하는 수업 형태는?',
      options: ['슬라이드·판서 중심 시각 수업', '강의·토론·발표 중심', '자료 중심 자기 주도 학습', '실험·프로젝트·실습 기반']),
  _Q(id: 7, part: 'A', framework: 'VARK', text: '시험 준비 시 가장 효과적인 방법은?',
      options: ['정리 노트·다이어그램 제작', '핵심 내용 소리 내어 반복', '기출·요약본 반복 독해', '실전 문제 대량 풀이']),

  // ── 파트B: Felder-Silverman 인지 유형 (Q8-13) ────────────────────────────────
  _Q(id: 8, part: 'B', framework: 'Felder', text: '문제 해결 시 접근 방식은?',
      options: ['논리적으로 단계별 분석', '전체 그림 보고 직관적 파악', '상황에 따라 다름', '']),
  _Q(id: 9, part: 'B', framework: 'Felder',
      text: '처음 보는 복잡한 기계 장치를 이해해야 합니다. 어떻게 하나요?',
      options: ['부품 하나하나 순서대로 파악', '전체 작동 원리부터 큰 그림 파악', '비슷한 것과 비교하며 파악', ''],
      type: _QType.scenario, emoji: '🧩'),
  _Q(id: 10, part: 'B', framework: 'Felder', text: '새로운 정보를 접할 때?',
      options: ['세부사항부터 꼼꼼히 확인', '큰 흐름과 핵심부터 파악', '중요도에 따라 다름', '']),
  _Q(id: 11, part: 'B', framework: 'Felder', text: '학습 내용을 체화하는 방식은?',
      options: ['순차적으로 단계별 연습', '핵심 패턴 파악 후 적용', '중간 방식으로 균형 있게', '']),
  _Q(id: 12, part: 'B', framework: 'Felder', text: '팀 프로젝트에서 선호하는 역할은?',
      options: ['혼자 맡은 부분 집중 완성', '토론·협력으로 함께 결정', '상황에 따라 유연하게', '']),
  _Q(id: 13, part: 'B', framework: 'Felder', text: '판단을 내릴 때?',
      options: ['충분한 데이터·근거 확인 후', '경험과 직감으로 빠르게', '상황에 따라 다름', '']),

  // ── 파트C: 인지부하 이론 CLT (Q14-19) ─────────────────────────────────────────
  _Q(id: 14, part: 'C', framework: 'CLT', text: '집중이 가장 잘 되는 학습 환경은?',
      options: ['완전히 조용한 공간', '약간의 배경음이 있는 공간', '카페·공공장소', '환경 상관없음']),
  _Q(id: 15, part: 'C', framework: 'CLT',
      text: '시험까지 48시간이 남았고 방대한 내용을 공부해야 합니다. 어떻게 하나요?',
      options: ['핵심만 빠르게 정리해 우선순위 집중', '처음부터 순서대로 꼼꼼히 정독', '예상 문제 풀면서 약점 파악', ''],
      type: _QType.scenario, emoji: '⏱️'),
  _Q(id: 16, part: 'C', framework: 'CLT', text: '공부가 가장 잘 되는 시간 패턴은?',
      options: ['짧게 여러 번 (25분 집중 후 휴식)', '한 번에 길게 몰입 (2시간+)', '불규칙하게 그때그때', '']),
  _Q(id: 17, part: 'C', framework: 'CLT', text: '새 내용을 배울 때 선호하는 방식은?',
      options: ['핵심만 빠르게 파악 후 넘어감', '하나씩 완벽히 이해 후 진행', '예시·사례 통해 이해', '']),
  _Q(id: 18, part: 'C', framework: 'CLT', text: '학습 자료의 시각 요소(그림·도표) 역할은?',
      options: ['필수 — 시각 없으면 이해 어려움', '보조적 — 있으면 좋지만 없어도 됨', '텍스트가 더 명확해서 선호', '']),
  _Q(id: 19, part: 'C', framework: 'CLT', text: '피드백 선호 방식은?',
      options: ['즉각적이고 짧은 피드백', '상세하고 심층적인 피드백', '동료와 함께 상호 피드백', '']),

  // ── 파트D: Kolb 경험학습 (Q20-25) ────────────────────────────────────────────
  _Q(id: 20, part: 'D', framework: 'Kolb',
      text: '새 스포츠를 배웁니다. 어떻게 시작하나요?',
      options: ['유튜브·책으로 이론 충분히 공부 먼저', '일단 해보면서 느낌으로 파악', '코치 지도 받으며 체계적으로', ''],
      type: _QType.scenario, emoji: '🌱'),
  _Q(id: 21, part: 'D', framework: 'Kolb', text: '실수했을 때 반응은?',
      options: ['원인을 분석하고 개선책 연구', '일단 다시 도전하며 감으로 수정', '다른 사람 사례 참고해 해결법 찾기', '']),
  _Q(id: 22, part: 'D', framework: 'Kolb', text: '학습한 내용을 실생활에 적용하는 방식은?',
      options: ['체계적으로 계획 세우고 실행', '즉흥적으로 바로 적용해봄', '조금씩 실험해보며 조정', '']),
  _Q(id: 23, part: 'D', framework: 'Kolb',
      text: '복잡한 프로젝트를 혼자 처음부터 설계해야 합니다. 첫 번째 행동은?',
      options: ['마인드맵이나 구조도로 전체 설계 먼저', '핵심 기능부터 바로 만들어봄', '비슷한 프로젝트 레퍼런스 수집', ''],
      type: _QType.scenario, emoji: '🌙'),
  _Q(id: 24, part: 'D', framework: 'Kolb', text: '학습 후 지식 정착 방식은?',
      options: ['순서에 맞게 체계적으로 복습', '큰 그림으로 연결해 이해 강화', '다양한 방식 혼합해 반복', '']),
  _Q(id: 25, part: 'D', framework: 'Kolb', text: '가장 동기부여가 되는 학습 환경은?',
      options: ['혼자 집중할 수 있는 환경', '함께 배우는 커뮤니티 환경', '경쟁이 있는 도전적 환경', '']),
];

// ── 파트 설정 ──────────────────────────────────────────────────────────────────

const _partColors = <String, Color>{
  'A': AppColors.primary,
  'B': AppColors.secondary,
  'C': AppColors.accent,
  'D': Color(0xFFF59E0B),
};

const _partLabels = <String, String>{
  'A': 'VARK 학습 스타일',
  'B': 'Felder 인지 유형',
  'C': 'CLT 인지부하',
  'D': 'Kolb 경험학습',
};

const _scenarioGradients = <String, List<Color>>{
  '📊': [AppColors.primary, AppColors.secondary],
  '🧩': [AppColors.secondary, AppColors.accent],
  '⏱️': [Color(0xFFF59E0B), Color(0xFFF43F5E)],
  '🌱': [AppColors.accent, AppColors.primary],
  '🌙': [Color(0xFF1E1B4B), AppColors.primary],
};

// ── Phase 상태 ─────────────────────────────────────────────────────────────────

enum _Phase { writing, questions, history, analyzing }

// ── 메인 페이지 ────────────────────────────────────────────────────────────────

class DiagnosisPage extends ConsumerStatefulWidget {
  const DiagnosisPage({super.key});

  @override
  ConsumerState<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends ConsumerState<DiagnosisPage>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.writing;

  // Writing
  final _writingCtrl = TextEditingController();

  // Questions
  int _current = 0;
  final Map<int, String> _answers = {};
  final Map<int, int> _responseTimes = {};
  DateTime? _questionStartTime;

  // History
  final _historySubjectCtrl = TextEditingController();
  String? _historyReason;
  String? _historyDifficulty;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slide;

  // Total steps: 1 writing + 25 questions + 3 history = 29
  static const int _totalSteps = 29;

  int get _currentStep {
    switch (_phase) {
      case _Phase.writing:
        return 0;
      case _Phase.questions:
        return _current < 12 ? 1 + _current : 16 + (_current - 12);
      case _Phase.history:
        return 13;
      case _Phase.analyzing:
        return _totalSteps;
    }
  }

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _buildAnim(true);
    _slideCtrl.forward();
    _questionStartTime = DateTime.now();
    _writingCtrl.addListener(() => setState(() {}));
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
    _writingCtrl.dispose();
    _historySubjectCtrl.dispose();
    super.dispose();
  }

  void _recordTime(int qId) {
    if (_questionStartTime != null) {
      _responseTimes[qId] =
          DateTime.now().difference(_questionStartTime!).inMilliseconds;
    }
  }

  void _select(String label) {
    final q = _questions[_current];
    _recordTime(q.id);
    setState(() => _answers[q.id] = label);
  }

  void _animNext() {
    _buildAnim(true);
    _slideCtrl.reset();
    _slideCtrl.forward();
  }

  void _animPrev() {
    _buildAnim(false);
    _slideCtrl.reset();
    _slideCtrl.forward();
  }

  Future<void> _onNext() async {
    switch (_phase) {
      case _Phase.writing:
        if (_writingCtrl.text.trim().length < 20) return;
        _animNext();
        setState(() {
          _phase = _Phase.questions;
          _current = 0;
          _questionStartTime = DateTime.now();
        });
      case _Phase.questions:
        final q = _questions[_current];
        if (_answers[q.id] == null) return;
        if (_current == 11) {
          // After Q12, go to history
          _animNext();
          setState(() => _phase = _Phase.history);
          return;
        }
        if (_current < _questions.length - 1) {
          _animNext();
          setState(() {
            _current++;
            _questionStartTime = DateTime.now();
          });
        } else {
          await _submit();
        }
      case _Phase.history:
        if (_historySubjectCtrl.text.trim().isEmpty) return;
        _animNext();
        setState(() {
          _phase = _Phase.questions;
          _current = 12;
          _questionStartTime = DateTime.now();
        });
      case _Phase.analyzing:
        break;
    }
  }

  void _onBack() {
    switch (_phase) {
      case _Phase.writing:
        Navigator.of(context).maybePop();
      case _Phase.questions:
        if (_current == 12) {
          _animPrev();
          setState(() => _phase = _Phase.history);
        } else if (_current == 0) {
          _animPrev();
          setState(() => _phase = _Phase.writing);
        } else {
          _animPrev();
          setState(() {
            _current--;
            _questionStartTime = DateTime.now();
          });
        }
      case _Phase.history:
        _animPrev();
        setState(() {
          _phase = _Phase.questions;
          _current = 11;
          _questionStartTime = DateTime.now();
        });
      case _Phase.analyzing:
        break;
    }
  }

  Future<void> _submit() async {
    setState(() => _phase = _Phase.analyzing);
    final user = ref.read(authNotifierProvider);
    if (user == null) return;

    final answers = _answers.entries.map((e) => {
      'question_id': e.key,
      'answer': e.value,
      'response_time_ms': _responseTimes[e.key] ?? 0,
    }).toList();

    try {
      final result = await ref
          .read(diagnosisNotifierProvider.notifier)
          .submit(
            userId: user.userId,
            answers: answers,
            writingResponse: _writingCtrl.text.trim(),
            learningHistory: {
              'subject': _historySubjectCtrl.text.trim(),
              'reason': _historyReason ?? '',
              'difficulty': _historyDifficulty ?? '',
            },
          );
      if (mounted) context.push('/student/diagnosis/result', extra: result);
    } catch (e) {
      if (mounted) {
        setState(() => _phase = _Phase.questions);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('분석 실패: $e'),
          backgroundColor: AppColors.rose,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.analyzing) return const _AnalyzingScreen();

    bool canProceed = false;
    String btnText = '다음 →';

    switch (_phase) {
      case _Phase.writing:
        canProceed = _writingCtrl.text.trim().length >= 20;
        btnText = '진단 시작 →';
      case _Phase.questions:
        canProceed = _answers[_questions[_current].id] != null;
        btnText = _current == _questions.length - 1 ? '결과 분석하기 →' : '다음 문항 →';
      case _Phase.history:
        canProceed = _historySubjectCtrl.text.trim().isNotEmpty;
        btnText = '계속하기 →';
      case _Phase.analyzing:
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: SlideTransition(
              position: _slide,
              child: _buildBody(),
            ),
          ),
          _buildNavBtn(canProceed, btnText),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final progress = (_currentStep + 1) / _totalSteps;
    Color barColor = AppColors.primary;
    String label = '글쓰기 준비';

    if (_phase == _Phase.questions) {
      final q = _questions[_current];
      barColor = _partColors[q.part]!;
      label = '${q.part}파트 · ${_partLabels[q.part]}';
    } else if (_phase == _Phase.history) {
      barColor = AppColors.accent;
      label = '학습 이력';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: _onBack,
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text('${_currentStep + 1} / $_totalSteps',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgSurface,
            valueColor: AlwaysStoppedAnimation(barColor),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildBody() {
    if (_phase == _Phase.writing) {
      return _WritingCard(
        key: const ValueKey('writing'),
        controller: _writingCtrl,
      );
    }
    if (_phase == _Phase.history) {
      return _HistoryCard(
        key: const ValueKey('history'),
        subjectCtrl: _historySubjectCtrl,
        reason: _historyReason,
        difficulty: _historyDifficulty,
        onReasonChanged: (v) => setState(() => _historyReason = v),
        onDifficultyChanged: (v) => setState(() => _historyDifficulty = v),
      );
    }
    final q = _questions[_current];
    return _QuestionCard(
      key: ValueKey(_current),
      question: q,
      partColor: _partColors[q.part]!,
      answered: _answers[q.id],
      onSelect: _select,
    );
  }

  Widget _buildNavBtn(bool canProceed, String btnText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: GestureDetector(
        onTap: canProceed ? _onNext : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            color:
                canProceed ? AppColors.primary : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: canProceed
                ? [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6))]
                : null,
          ),
          child: Center(
            child: Text(
              btnText,
              style: TextStyle(
                color: canProceed ? Colors.white : AppColors.textMuted,
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

// ── 글쓰기 카드 ────────────────────────────────────────────────────────────────

class _WritingCard extends StatelessWidget {
  final TextEditingController controller;
  const _WritingCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final len = controller.text.trim().length;
    final minReached = len >= 20;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.primary.withValues(alpha: 0.2),
              AppColors.secondary.withValues(alpha: 0.1),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Text('✍️', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('자유 서술',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('AI가 글쓰기 패턴으로 학습 성향을 분석합니다',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        const Text(
          '가장 잘 이해됐던 수업 또는 학습 경험을 떠올려보세요.\n어떤 점이 도움이 됐나요?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: minReached ? AppColors.accent : AppColors.border,
              width: minReached ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: 6,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 15, height: 1.5),
            decoration: const InputDecoration(
              hintText: '예) 교수님이 도표로 설명해주셔서 개념이 한눈에 들어왔어요. 특히...',
              hintStyle:
                  TextStyle(color: AppColors.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('$len자',
              style: TextStyle(
                  color: minReached
                      ? AppColors.accent
                      : AppColors.textMuted,
                  fontSize: 12)),
          if (!minReached) ...[
            const SizedBox(width: 4),
            const Text('(최소 20자)',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ]),
      ]),
    );
  }
}

// ── 질문 카드 ──────────────────────────────────────────────────────────────────

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
    final isScenario = question.type == _QType.scenario;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isScenario) ...[
          _ScenarioBanner(emoji: question.emoji),
          const SizedBox(height: 16),
        ],
        Text(question.text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.4,
            )),
        const SizedBox(height: 24),
        ...List.generate(
          opts.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChoiceCard(
              label: _labels[i],
              text: opts[i],
              selected: answered == _labels[i],
              partColor: partColor,
              onTap: () => onSelect(_labels[i]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── 시나리오 배너 ──────────────────────────────────────────────────────────────

class _ScenarioBanner extends StatelessWidget {
  final String emoji;
  const _ScenarioBanner({required this.emoji});

  @override
  Widget build(BuildContext context) {
    final colors = _scenarioGradients[emoji] ??
        [AppColors.primary, AppColors.secondary];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors
                .map((c) => c.withValues(alpha: 0.25))
                .toList()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colors.first.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        const Text('시나리오 문항',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.first.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('상황 기반',
              style: TextStyle(
                  color: colors.first,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── 선택지 카드 ────────────────────────────────────────────────────────────────

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
                  color: selected ? Colors.white : AppColors.textMuted,
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
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ))),
          if (selected)
            Icon(Icons.check_circle_rounded,
                color: partColor, size: 20),
        ]),
      ),
    );
  }
}

// ── 학습 이력 카드 ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatefulWidget {
  final TextEditingController subjectCtrl;
  final String? reason;
  final String? difficulty;
  final ValueChanged<String?> onReasonChanged;
  final ValueChanged<String?> onDifficultyChanged;

  const _HistoryCard({
    super.key,
    required this.subjectCtrl,
    required this.reason,
    required this.difficulty,
    required this.onReasonChanged,
    required this.onDifficultyChanged,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  static const _reasons = [
    '선생님·교수님 설명이 명확해서',
    '시각 자료·도표가 많아서',
    '충분히 반복 연습할 수 있어서',
    '직접 해볼 기회가 있어서',
  ];

  static const _difficulties = [
    '일방적 강의만 있고 상호작용 없음',
    '시각 자료 없이 텍스트만 있음',
    '이론만 있고 실습이 없음',
    '너무 빠른 속도로 진행',
  ];

  @override
  void initState() {
    super.initState();
    widget.subjectCtrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final hasSubject = widget.subjectCtrl.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.accent.withValues(alpha: 0.2),
              AppColors.secondary.withValues(alpha: 0.1),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Text('📚', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('학습 이력',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('과거 경험으로 학습 패턴을 더 정확히 분석합니다',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 28),

        // LH1: 잘한 과목
        const Text('LH1. 가장 잘 이해됐던 과목이나 분야는?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.4)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasSubject ? AppColors.accent : AppColors.border,
              width: hasSubject ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: widget.subjectCtrl,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: '예) 수학, 생물, 프로그래밍...',
              hintStyle:
                  TextStyle(color: AppColors.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // LH2: 잘한 이유
        const Text('LH2. 잘 이해됐던 이유는?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...List.generate(_reasons.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ChoiceCard(
            label: String.fromCharCode(65 + i),
            text: _reasons[i],
            selected: widget.reason == _reasons[i],
            partColor: AppColors.accent,
            onTap: () => widget.onReasonChanged(_reasons[i]),
          ),
        )),
        const SizedBox(height: 24),

        // LH3: 힘든 방식
        const Text('LH3. 가장 힘들었던 학습 방식은?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...List.generate(_difficulties.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ChoiceCard(
            label: String.fromCharCode(65 + i),
            text: _difficulties[i],
            selected: widget.difficulty == _difficulties[i],
            partColor: AppColors.accent,
            onTap: () =>
                widget.onDifficultyChanged(_difficulties[i]),
          ),
        )),
      ]),
    );
  }
}

// ── 분석 중 화면 ────────────────────────────────────────────────────────────────

class _AnalyzingScreen extends StatefulWidget {
  const _AnalyzingScreen();

  @override
  State<_AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<_AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _msgIdx = 0;

  static const _msgs = [
    'AI가 글쓰기 패턴을 분석하고 있어요',
    '25문항 응답 데이터를 처리하고 있어요',
    '8차원 학습 성향을 도출하는 중이에요',
    'VARK · Felder · Kolb 모델 적용 중',
    '신뢰도 검증을 수행하고 있어요',
    '맞춤 학습 전략을 수립하고 있어요',
    '논문 근거를 검색하고 있어요',
    '거의 다 됐어요 ✨',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child:
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.secondary.withValues(alpha: 0.2),
                ]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                  child: Text('🧠', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 28),
            const Text('8차원 학습 성향 분석 중',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('RAG · Gemini · 심리학 논문 기반',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(_msgs[_msgIdx],
                  key: ValueKey(_msgIdx),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.primaryLight, fontSize: 14)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.bgSurface,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primaryLight),
              ),
            ),
            const SizedBox(height: 16),
            const Text('최대 30초 소요될 수 있어요',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
