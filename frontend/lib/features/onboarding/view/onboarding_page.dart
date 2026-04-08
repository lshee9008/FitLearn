import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../provider/onboarding_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final List<String> _answers = [];

  void _addAnswer(String answer) => setState(() => _answers.add(answer));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);

    ref.listen(onboardingNotifierProvider, (_, next) {
      if (next is AsyncData && next.value != null) {
        context.go('/lecture');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('FitLearn - 학습 유형 진단')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (_) => _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    // TODO: 진단 설문 UI 구현
    return Center(
      child: ElevatedButton(
        onPressed: () {
          _addAnswer('핵심만 빠르게 알고 싶어요'); // TODO: 설문 UI로 교체
          ref.read(onboardingNotifierProvider.notifier).diagnose('user_001', _answers);
        },
        child: const Text('진단 시작'),
      ),
    );
  }
}
