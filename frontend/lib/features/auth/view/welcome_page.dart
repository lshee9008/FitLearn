import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../provider/auth_provider.dart';

// ── 데모 모드 우회 화면 ───────────────────────────────────────────────────────
// TODO: 인증 시스템 재활성화 시 아래 클래스를 _AuthWelcomePage로 교체
// TODO: kDemoMode = false 설정 후 실제 로그인/회원가입 UI 복원

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _loading = false;

  Future<void> _enter(UserRole role) async {
    setState(() => _loading = true);
    await ref.read(authNotifierProvider.notifier).demoLogin(role);
    if (!mounted) return;
    if (role == UserRole.student) {
      context.go('/student/home');
    } else {
      context.go('/professor/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이미 세션 있으면 자동 이동
    ref.listen(authNotifierProvider, (_, next) {
      if (next != null && mounted) {
        final dest = next.role == UserRole.student ? '/student/home' : '/professor/home';
        context.go(dest);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '데모 모드',
                    style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 56),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '역할을 선택하세요',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '인증 없이 핵심 기능을 바로 체험합니다',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),
                _RoleButton(
                  emoji: '📚',
                  label: '학생으로 시작',
                  description: '성향 진단 · 맞춤 교안 학습',
                  color: AppColors.primary,
                  loading: _loading,
                  onTap: () => _enter(UserRole.student),
                ),
                const SizedBox(height: 16),
                _RoleButton(
                  emoji: '🎓',
                  label: '교수로 시작',
                  description: '강의 방 관리 · 교안 업로드 · 학생 분석',
                  color: AppColors.secondary,
                  loading: _loading,
                  onTap: () => _enter(UserRole.professor),
                ),
                const SizedBox(height: 24),
                const Divider(color: AppColors.border),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.push('/reforge-test'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      const Text('🧪', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('재가공 시스템 테스트',
                            style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w800)),
                        const Text('로그인 없이 AI 교안 재해석 바로 체험',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ])),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: 14),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
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

class _RoleButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _RoleButton({
    required this.emoji,
    required this.label,
    required this.description,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                color: color, fontSize: 17, fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(
                color: AppColors.textMuted, fontSize: 13,
              )),
            ],
          )),
          if (loading)
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 15),
        ]),
      ),
    );
  }
}
