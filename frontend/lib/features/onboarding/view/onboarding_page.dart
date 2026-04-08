// Legacy redirect — 신규 진단 페이지로 이동
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
