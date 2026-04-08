import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardPage extends ConsumerWidget {
  final String instructorId;

  const DashboardPage({super.key, required this.instructorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('FitLearn - 강의자 대시보드')),
      body: const Center(
        // TODO: 질문 패턴 AI 분석 결과 시각화
        child: Text('질문 패턴 분석 결과가 표시됩니다.'),
      ),
    );
  }
}
