import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../provider/onboarding_provider.dart';

class ResultPage extends StatelessWidget {
  final DiagnosisResult result;

  const ResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              _buildBadge(),
              const SizedBox(height: 32),
              _buildTitle(),
              const SizedBox(height: 16),
              _buildDescription(),
              const SizedBox(height: 40),
              _buildTips(),
              const Spacer(flex: 2),
              _buildButton(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha:0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              result.type.emoji,
              style: const TextStyle(fontSize: 44),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEDFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '진단 완료',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Text(
          '나의 학습 유형은',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          result.type.label,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F46E5),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        result.description,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF444466),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildTips() {
    final tips = _tipsFor(result.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '맞춤 학습 방식',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✓ ', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF555577), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.go('/lecture'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: const Text(
          '맞춤 교안 학습 시작',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  List<String> _tipsFor(LearningType type) => switch (type) {
        LearningType.summary => [
            'Bullet point로 핵심 개념만 정리한 요약본 제공',
            '불필요한 설명 없이 키워드 중심으로 학습',
            '빠른 복습을 위한 1페이지 요약 시트 활용',
          ],
        LearningType.detailed => [
            '개념 간 연결 관계를 단계별로 설명',
            '왜(Why)와 어떻게(How)를 충분히 다룬 심화 자료 제공',
            '논리적 흐름에 따라 순서대로 학습',
          ],
        LearningType.example => [
            '각 개념마다 실생활 사례와 코드 예제 제공',
            '이론보다 적용 사례 중심으로 학습',
            '직접 따라해보며 체험으로 이해',
          ],
      };
}
