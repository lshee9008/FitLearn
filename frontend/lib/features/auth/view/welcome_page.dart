import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _Logo(),
                const SizedBox(height: 56),
                const Text(
                  '역할을 선택해주세요',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: _RoleCard(
                      emoji: '📚',
                      label: '학생',
                      desc: '성향 진단\n맞춤 학습',
                      onTap: () => context.go('/student/home'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _RoleCard(
                      emoji: '🎓',
                      label: '교수',
                      desc: '교안 관리\n학생 분석',
                      onTap: () => context.go('/professor/home'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Center(
          child: Text('FL', style: TextStyle(
            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900,
            letterSpacing: -1,
          )),
        ),
      ),
      const SizedBox(height: 18),
      const Text('FitLearn', style: TextStyle(
        color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
      )),
      const SizedBox(height: 6),
      const Text('나의 학습 성향에 맞춘 AI 교안 학습', style: TextStyle(
        color: AppColors.textMuted, fontSize: 14,
      )),
    ]);
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String desc;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.label,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          )),
          const SizedBox(height: 6),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(
            color: AppColors.textMuted, fontSize: 12, height: 1.5,
          )),
        ]),
      ),
    );
  }
}
