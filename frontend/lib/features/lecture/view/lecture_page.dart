import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LecturePage extends ConsumerWidget {
  const LecturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('FitLearn - 교안 재가공')),
      body: const Center(
        // TODO: 교안 업로드 + SSE 스트리밍 3버전 표시 UI
        child: Text('교안을 업로드하면 3가지 유형으로 재가공됩니다.'),
      ),
    );
  }
}
