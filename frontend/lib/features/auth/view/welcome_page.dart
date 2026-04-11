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
  bool _isSignUp = false;
  UserRole _role = UserRole.student;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _submitAuth() async {
    setState(() => _loading = true);
    try {
      final notifier = ref.read(authNotifierProvider.notifier);
      if (_isSignUp) {
        await notifier.signUpWithEmail(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: _role,
        );
      } else {
        await notifier.signInWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firebaseErrorToKorean(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleAuth() async {
    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        await ref.read(authNotifierProvider.notifier).registerWithGoogle(_role);
      } else {
        await ref.read(authNotifierProvider.notifier).loginWithGoogle();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firebaseErrorToKorean(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 28),
                      const Text(
                        'AI 기반 맞춤형 강의실',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '교수는 강의자료와 핵심 포인트를 관리하고, 학생은 성향과 과목 수준에 맞춘 교안을 학습합니다.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.7),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 36),
                Expanded(child: _buildAuthPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthPanel() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AuthToggle(
                label: '로그인',
                active: !_isSignUp,
                onTap: () => setState(() => _isSignUp = false),
              ),
              const SizedBox(width: 8),
              _AuthToggle(
                label: '회원가입',
                active: _isSignUp,
                onTap: () => setState(() => _isSignUp = true),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (_isSignUp) ...[
            _RoleSwitcher(
              role: _role,
              onChanged: (role) => setState(() => _role = role),
            ),
            const SizedBox(height: 14),
            _AuthField(controller: _nameCtrl, label: '이름', icon: Icons.person_outline),
            const SizedBox(height: 12),
          ],
          _AuthField(controller: _emailCtrl, label: '이메일', icon: Icons.mail_outline),
          const SizedBox(height: 12),
          _AuthField(controller: _passwordCtrl, label: '비밀번호', icon: Icons.lock_outline, obscure: true),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _submitAuth,
              child: Text(_isSignUp ? '계정 만들기' : '로그인'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _googleAuth,
              icon: const Icon(Icons.g_mobiledata_rounded),
              label: Text(_isSignUp ? 'Google로 회원가입' : 'Google로 로그인'),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 14),
          const Text('빠른 시연', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _RoleButton(
            emoji: '📚',
            label: '학생 데모 입장',
            description: '성향 진단 · 맞춤 교안 학습',
            color: AppColors.primary,
            loading: _loading,
            onTap: () => _enter(UserRole.student),
          ),
          const SizedBox(height: 10),
          _RoleButton(
            emoji: '🎓',
            label: '교수 데모 입장',
            description: '강의 방 관리 · 교안 업로드',
            color: AppColors.secondary,
            loading: _loading,
            onTap: () => _enter(UserRole.professor),
          ),
        ],
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

class _AuthToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _AuthToggle({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : AppColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSwitcher extends StatelessWidget {
  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  const _RoleSwitcher({
    required this.role,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleMiniButton(
            label: '학생',
            active: role == UserRole.student,
            onTap: () => onChanged(UserRole.student),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RoleMiniButton(
            label: '교수',
            active: role == UserRole.professor,
            onTap: () => onChanged(UserRole.professor),
          ),
        ),
      ],
    );
  }
}

class _RoleMiniButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RoleMiniButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppColors.secondary.withValues(alpha: 0.14) : null,
        side: BorderSide(color: active ? AppColors.secondary : AppColors.border),
      ),
      child: Text(label),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
