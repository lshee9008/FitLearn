import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../provider/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final _nameCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.student;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해주세요.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier).register(name, _selectedRole);
      if (mounted) {
        if (_selectedRole == UserRole.student) {
          context.go('/student/home');
        } else {
          context.go('/professor/home');
        }
      }
    } catch (e) {
      setState(() { _error = '등록 중 오류가 발생했습니다.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이미 로그인된 경우 자동 이동
    ref.listen(authNotifierProvider, (_, next) {
      if (next != null && mounted) {
        final dest = next.role == UserRole.student ? '/student/home' : '/professor/home';
        context.go(dest);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 48),
                _buildForm(),
                const SizedBox(height: 24),
                GlowButton(
                  text: '시작하기',
                  loading: _loading,
                  onTap: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Center(
            child: Text('FL', style: TextStyle(
              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900,
            )),
          ),
        ),
        const SizedBox(height: 20),
        const Text('FitLearn', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w900,
          letterSpacing: -1,
        )),
        const SizedBox(height: 8),
        const Text(
          '나의 학습 성향에 맞춘 AI 교안 학습',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이름', style: TextStyle(
            color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: '이름을 입력하세요'),
          ),
          const SizedBox(height: 24),
          const Text('역할 선택', style: TextStyle(
            color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _RoleCard(
                role: UserRole.student,
                selected: _selectedRole == UserRole.student,
                onTap: () => setState(() => _selectedRole = UserRole.student),
              )),
              const SizedBox(width: 12),
              Expanded(child: _RoleCard(
                role: UserRole.professor,
                selected: _selectedRole == UserRole.professor,
                onTap: () => setState(() => _selectedRole = UserRole.professor),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isProfessor = role == UserRole.professor;
    final label = isProfessor ? '교수' : '학생';
    final emoji = isProfessor ? '🎓' : '📚';
    final desc = isProfessor ? '교안 관리\n학생 분석' : '성향 진단\n맞춤 학습';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              color: selected ? AppColors.primaryLight : AppColors.textPrimary,
              fontWeight: FontWeight.w700, fontSize: 15,
            )),
            const SizedBox(height: 4),
            Text(desc, textAlign: TextAlign.center, style: const TextStyle(
              color: AppColors.textMuted, fontSize: 11, height: 1.4,
            )),
          ],
        ),
      ),
    );
  }
}
