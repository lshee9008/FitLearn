// Legacy redirect — 신규 진단 결과 페이지로 이동
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, dynamic result});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/student/home'));
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
