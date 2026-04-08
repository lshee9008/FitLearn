import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../provider/onboarding_provider.dart';

// ── 설문 데이터 ──────────────────────────────────────────────────

class _Question {
  final String category;
  final String text;
  final List<String> choices;

  const _Question({
    required this.category,
    required this.text,
    required this.choices,
  });
}

const _questions = [
  // 학습 스타일 3문항
  _Question(
    category: '학습 스타일',
    text: '새로운 개념을 배울 때 선호하는 방식은?',
    choices: [
      '핵심만 간결하게 정리된 요약본',
      '단계별로 상세히 설명된 내용',
      '실제 사례와 예시 중심',
    ],
  ),
  _Question(
    category: '학습 스타일',
    text: '공부할 때 가장 효과적인 방법은?',
    choices: [
      '핵심 키워드와 정의를 빠르게 정리',
      '개념 간의 논리적 연결을 깊이 이해',
      '직접 해보거나 예시로 확인',
    ],
  ),
  _Question(
    category: '학습 스타일',
    text: '모르는 내용이 있을 때 어떻게 하나요?',
    choices: [
      '핵심 요약 자료를 찾아본다',
      '자세한 설명이 담긴 교재를 찾는다',
      '관련 예제나 사례를 먼저 본다',
    ],
  ),
  // 수준 진단 4문항
  _Question(
    category: '수준 진단',
    text: '현재 학습 분야의 경력/경험은?',
    choices: [
      '완전 처음 (0~3개월)',
      '초급 (3개월~1년)',
      '중급 (1~3년)',
      '고급 (3년 이상)',
    ],
  ),
  _Question(
    category: '수준 진단',
    text: '관련 자격증이나 학위가 있나요?',
    choices: [
      '없음',
      '관련 전공 학위',
      '관련 자격증 보유',
      '학위와 자격증 모두',
    ],
  ),
  _Question(
    category: '수준 진단',
    text: '이번 학습의 주된 목적은?',
    choices: [
      '기초 개념 이해',
      '업무 실무 적용',
      '심화 학습 및 전문성 강화',
      '자격증/시험 준비',
    ],
  ),
  _Question(
    category: '수준 진단',
    text: '하루 평균 학습 가능 시간은?',
    choices: [
      '30분 미만',
      '30분~1시간',
      '1~2시간',
      '2시간 이상',
    ],
  ),
];

// ── 페이지 ───────────────────────────────────────────────────────

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _currentIndex = 0;
  final List<String> _answers = [];

  void _select(String choice) {
    setState(() {
      if (_answers.length > _currentIndex) {
        _answers[_currentIndex] = choice;
      } else {
        _answers.add(choice);
      }
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submit();
    }
  }

  void _prev() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _submit() {
    ref.read(onboardingNotifierProvider.notifier).diagnose('user_001', _answers);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingNotifierProvider, (_, next) {
      if (next is AsyncData && next.value != null) {
        context.go('/result', extra: next.value);
      }
    });

    final diagState = ref.watch(onboardingNotifierProvider);

    if (diagState is AsyncLoading) {
      return const _LoadingScreen();
    }

    if (diagState is AsyncError) {
      return _ErrorScreen(message: diagState.error.toString(), onRetry: _submit);
    }

    final q = _questions[_currentIndex];
    final selected = _answers.length > _currentIndex ? _answers[_currentIndex] : null;
    final progress = (_currentIndex + 1) / _questions.length;
    final isLast = _currentIndex == _questions.length - 1;
    final canProceed = selected != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(progress),
              const SizedBox(height: 32),
              _buildCategoryChip(q.category),
              const SizedBox(height: 16),
              _buildQuestion(q.text),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: q.choices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ChoiceCard(
                    index: i,
                    text: q.choices[i],
                    isSelected: selected == q.choices[i],
                    onTap: () => _select(q.choices[i]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildNavButtons(canProceed, isLast),
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
            const Text(
              'FitLearn',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4F46E5),
              ),
            ),
            Text(
              '${_currentIndex + 1} / ${_questions.length}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE0DEFF),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }

  Widget _buildQuestion(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E),
        height: 1.4,
      ),
    );
  }

  Widget _buildNavButtons(bool canProceed, bool isLast) {
    return Row(
      children: [
        if (_currentIndex > 0)
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _prev,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF4F46E5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('이전', style: TextStyle(color: Color(0xFF4F46E5))),
            ),
          ),
        if (_currentIndex > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: canProceed ? _next : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              disabledBackgroundColor: const Color(0xFFD1D0F0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isLast ? '진단 완료' : '다음',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 선택지 카드 ──────────────────────────────────────────────────

class _ChoiceCard extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE5E5E5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha:0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha:0.2)
                    : const Color(0xFFEEEDFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _labels[index],
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isSelected ? Colors.white : const Color(0xFF4F46E5),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1.3,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── 로딩 / 에러 화면 ─────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F7FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
            SizedBox(height: 24),
            Text(
              'AI가 학습 유형을 분석하고 있어요...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
      backgroundColor: const Color(0xFFF8F7FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                '진단 중 오류가 발생했어요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('다시 시도', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
