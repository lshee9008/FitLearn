import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../provider/diagnosis_provider.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

// ── 15문항 정의 ──────────────────────────────────────────────────

class _Q {
  final int id;
  final String category;
  final String text;
  final List<String> choices;
  const _Q(this.id, this.category, this.text, this.choices);
}

const _questions = [
  // 학습 스타일 (Q1-5)
  _Q(1, '학습 스타일', '새로운 개념을 배울 때 가장 도움이 되는 방법은?', [
    'A. 그림, 도표, 다이어그램으로 보는 것',
    'B. 강의나 설명을 들으며 이해하는 것',
    'C. 교재나 노트를 읽으며 정리하는 것',
    'D. 직접 만들거나 실습해보는 것',
  ]),
  _Q(2, '학습 스타일', '복잡한 정보를 기억할 때 어떤 방법이 가장 효과적인가요?', [
    'A. 색깔, 표, 마인드맵으로 시각화',
    'B. 소리 내어 읽거나 누군가에게 설명',
    'C. 중요한 내용을 직접 필기하고 정리',
    'D. 모형을 만들거나 직접 경험해보기',
  ]),
  _Q(3, '학습 스타일', '좋아하는 수업 형태는?', [
    'A. 슬라이드, 영상 중심의 강의',
    'B. 토론, 발표 중심의 강의',
    'C. 교재 중심의 강의',
    'D. 실습, 실험 중심의 강의',
  ]),
  _Q(4, '학습 스타일', '새로운 소프트웨어를 배울 때 선호하는 방식은?', [
    'A. UI 화면을 보며 직접 탐색',
    'B. 동영상 튜토리얼을 보며 따라하기',
    'C. 매뉴얼이나 가이드를 읽기',
    'D. 직접 눌러보며 실험',
  ]),
  _Q(5, '학습 스타일', '시험 공부를 할 때 주로 사용하는 방법은?', [
    'A. 요약 노트, 개념도, 플래시카드',
    'B. 소리 내어 읽기, 스터디 그룹 토론',
    'C. 교재나 필기를 여러 번 읽기',
    'D. 연습문제를 많이 풀고 적용해보기',
  ]),
  // 사회적 성향 (Q6-10)
  _Q(6, '사회적 성향', '오랜 시간 사람들과 어울린 후 기분이 어떤가요?', [
    'A. 더욱 활기차고 에너지가 생긴다',
    'B. 피곤하고 혼자만의 시간이 필요하다',
  ]),
  _Q(7, '사회적 성향', '가장 집중이 잘 되는 공부 환경은?', [
    'A. 조용히 혼자 공부하는 환경',
    'B. 약간의 소음이 있는 카페나 도서관',
  ]),
  _Q(8, '사회적 성향', '어려운 문제를 만났을 때 주로 어떻게 하나요?', [
    'A. 혼자 충분히 생각하고 고민한다',
    'B. 친구나 동료에게 바로 물어보거나 토론한다',
  ]),
  _Q(9, '사회적 성향', '팀 프로젝트에서 주로 어떤 역할을 맡나요?', [
    'A. 자료조사, 분석 등 개인 작업 중심 역할',
    'B. 의견 조율, 발표 등 소통 중심 역할',
  ]),
  _Q(10, '사회적 성향', '스트레스를 해소하는 방법은?', [
    'A. 독서, 산책 등 혼자 하는 활동',
    'B. 친구 만남, 모임 등 사람들과 함께하는 활동',
  ]),
  // 사고 유형 (Q11-15)
  _Q(11, '사고 유형', '중요한 결정을 내릴 때 주로 의존하는 것은?', [
    'A. 데이터, 사실, 논리적 분석',
    'B. 직감, 경험, 전체적인 느낌',
  ]),
  _Q(12, '사고 유형', '새로운 프로젝트를 시작할 때 접근 방식은?', [
    'A. 세부 계획을 먼저 꼼꼼히 세운다',
    'B. 큰 방향을 잡고 진행하면서 조율한다',
  ]),
  _Q(13, '사고 유형', '글을 읽을 때 주로 어떻게 읽나요?', [
    'A. 처음부터 끝까지 빠짐없이 정독한다',
    'B. 핵심 부분과 전체 구조를 먼저 파악한다',
  ]),
  _Q(14, '사고 유형', '업무나 과제를 처리할 때 스타일은?', [
    'A. 마감 전 꼼꼼하게 체크리스트로 완료',
    'B. 흐름에 따라 유연하게 처리',
  ]),
  _Q(15, '사고 유형', '아이디어를 생각할 때 방식은?', [
    'A. 기존 사례를 분석하고 개선점을 찾는다',
    'B. 새로운 가능성을 상상하고 창의적으로 발전',
  ]),
];

// ── 페이지 ───────────────────────────────────────────────────────

class DiagnosisPage extends ConsumerStatefulWidget {
  const DiagnosisPage({super.key});

  @override
  ConsumerState<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends ConsumerState<DiagnosisPage>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  final Map<int, String> _answers = {};
  late final AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _select(String choice) => setState(() => _answers[_questions[_idx].id] = choice);

  void _next() async {
    if (_idx < _questions.length - 1) {
      await _anim.reverse();
      setState(() => _idx++);
      _anim.forward();
    } else {
      _submit();
    }
  }

  void _prev() async {
    if (_idx > 0) {
      await _anim.reverse();
      setState(() => _idx--);
      _anim.forward();
    }
  }

  void _submit() {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    final answers = _answers.entries
        .map((e) => {'question_id': e.key, 'answer': e.value.substring(0, 1)})
        .toList();
    ref.read(diagnosisNotifierProvider.notifier).submit(user.userId, answers);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(diagnosisNotifierProvider, (_, next) {
      if (next is AsyncData && next.value != null) {
        context.go('/student/diagnosis/result', extra: next.value);
      }
    });

    final state = ref.watch(diagnosisNotifierProvider);
    if (state is AsyncLoading) return const _AnalyzingScreen();
    if (state is AsyncError) return _ErrorScreen(onRetry: _submit);

    final q = _questions[_idx];
    final selected = _answers[q.id];
    final progress = (_idx + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(progress),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryChip(q.category),
                    const SizedBox(height: 16),
                    Text(q.text, style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: FadeTransition(
                  opacity: _fade,
                  child: ListView.separated(
                    itemCount: q.choices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ChoiceCard(
                      label: q.choices[i].substring(0, 1),
                      text: q.choices[i].substring(3),
                      isSelected: selected == q.choices[i].substring(0, 1),
                      onTap: () => _select(q.choices[i].substring(0, 1)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildNav(selected != null, _idx == _questions.length - 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('FitLearn 학습 성향 진단', style: TextStyle(
              color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w600,
            )),
            Text('${_idx + 1} / ${_questions.length}', style: const TextStyle(
              color: AppColors.textMuted, fontSize: 13,
            )),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.bgSurface,
            valueColor: AlwaysStoppedAnimation(AppColors.primaryLight),
          ),
        ),
      ],
    );
  }

  Widget _buildNav(bool canNext, bool isLast) {
    return Row(
      children: [
        if (_idx > 0) ...[
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _prev,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('이전'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: GlowButton(
            text: isLast ? '진단 완료' : '다음',
            onTap: canNext ? _next : null,
          ),
        ),
      ],
    );
  }
}

// ── 하위 위젯 ────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: const TextStyle(
        color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600,
      )),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label, style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              )),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              height: 1.3,
            ))),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingScreen extends StatelessWidget {
  const _AnalyzingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
          ),
          const SizedBox(height: 28),
          const Text('AI가 학습 성향을 분석 중입니다', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 8),
          const Text('잠시만 기다려 주세요...', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ]),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: AppColors.rose, size: 64),
          const SizedBox(height: 16),
          const Text('분석 중 오류가 발생했습니다', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 24),
          GlowButton(text: '다시 시도', onTap: onRetry, fullWidth: false),
        ]),
      ),
    );
  }
}
