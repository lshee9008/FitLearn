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

class _WelcomePageState extends ConsumerState<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _navigate(UserProfile profile) {
    if (!mounted) return;
    if (profile.role == UserRole.student) {
      context.go('/student/home');
    } else {
      context.go('/professor/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (_, next) {
      if (next != null && mounted) _navigate(next);
    });

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
                const SizedBox(height: 40),
                _TabBar(controller: _tabCtrl),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tabCtrl.index == 0
                      ? _LoginForm(key: const ValueKey('login'), onSuccess: _navigate)
                      : _SignupForm(key: const ValueKey('signup'), onSuccess: _navigate),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 로고 ────────────────────────────────────────────────────────────────────

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

// ── 탭 바 ────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: '로그인'), Tab(text: '회원가입')],
      ),
    );
  }
}

// ── 로그인 폼 ────────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerStatefulWidget {
  final void Function(UserProfile) onSuccess;
  const _LoginForm({super.key, required this.onSuccess});

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해주세요.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithEmail(email, pw);
      final profile = ref.read(authNotifierProvider);
      if (profile != null && mounted) widget.onSuccess(profile);
    } catch (e) {
      setState(() { _error = firebaseErrorToKorean(e); _loading = false; });
    }
  }

  Future<void> _googleLogin() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier).loginWithGoogle();
      final profile = ref.read(authNotifierProvider);
      if (profile != null && mounted) widget.onSuccess(profile);
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _googleLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('이메일', style: _labelStyle),
        const SizedBox(height: 8),
        _EmailField(controller: _emailCtrl),
        const SizedBox(height: 16),
        const Text('비밀번호', style: _labelStyle),
        const SizedBox(height: 8),
        _PasswordField(
          controller: _pwCtrl,
          obscure: _obscure,
          onToggle: () => setState(() => _obscure = !_obscure),
          onSubmit: _login,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorText(_error!),
        ],
        const SizedBox(height: 20),
        GlowButton(text: '로그인', loading: _loading, onTap: _login),
        const SizedBox(height: 20),
        const _Divider(),
        const SizedBox(height: 20),
        _GoogleButton(loading: _googleLoading, onTap: _googleLogin),
      ]),
    );
  }
}

// ── 회원가입 폼 ──────────────────────────────────────────────────────────────

class _SignupForm extends ConsumerStatefulWidget {
  final void Function(UserProfile) onSuccess;
  const _SignupForm({super.key, required this.onSuccess});

  @override
  ConsumerState<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends ConsumerState<_SignupForm> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  UserRole _role = UserRole.student;
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pw2Ctrl.text;

    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해주세요.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = '이메일을 입력해주세요.');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 합니다.');
      return;
    }
    if (pw != pw2) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier).signUpWithEmail(
        name: name, email: email, password: pw, role: _role,
      );
      final profile = ref.read(authNotifierProvider);
      if (profile != null && mounted) widget.onSuccess(profile);
    } catch (e) {
      setState(() { _error = firebaseErrorToKorean(e); _loading = false; });
    }
  }

  Future<void> _googleSignup() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier).registerWithGoogle(_role);
      final profile = ref.read(authNotifierProvider);
      if (profile != null && mounted) widget.onSuccess(profile);
    } catch (e) {
      setState(() { _error = firebaseErrorToKorean(e); _googleLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('이름', style: _labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: '홍길동'),
        ),
        const SizedBox(height: 16),
        const Text('이메일', style: _labelStyle),
        const SizedBox(height: 8),
        _EmailField(controller: _emailCtrl),
        const SizedBox(height: 16),
        const Text('비밀번호', style: _labelStyle),
        const SizedBox(height: 8),
        _PasswordField(
          controller: _pwCtrl,
          obscure: _obscure,
          onToggle: () => setState(() => _obscure = !_obscure),
          hint: '6자 이상',
        ),
        const SizedBox(height: 16),
        const Text('비밀번호 확인', style: _labelStyle),
        const SizedBox(height: 8),
        _PasswordField(
          controller: _pw2Ctrl,
          obscure: _obscure2,
          onToggle: () => setState(() => _obscure2 = !_obscure2),
          onSubmit: _signup,
        ),
        const SizedBox(height: 20),
        const Text('역할 선택', style: _labelStyle),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _RoleCard(
            role: UserRole.student,
            selected: _role == UserRole.student,
            onTap: () => setState(() => _role = UserRole.student),
          )),
          const SizedBox(width: 12),
          Expanded(child: _RoleCard(
            role: UserRole.professor,
            selected: _role == UserRole.professor,
            onTap: () => setState(() => _role = UserRole.professor),
          )),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorText(_error!),
        ],
        const SizedBox(height: 20),
        GlowButton(text: '회원가입', loading: _loading, onTap: _signup),
        const SizedBox(height: 20),
        const _Divider(),
        const SizedBox(height: 20),
        _GoogleButton(loading: _googleLoading, onTap: _googleSignup),
      ]),
    );
  }
}

// ── 공통 위젯 ────────────────────────────────────────────────────────────────

const _labelStyle = TextStyle(
  color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600,
);

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  const _EmailField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: const InputDecoration(
        hintText: 'example@email.com',
        prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted, size: 18),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback? onSubmit;
  final String hint;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.onSubmit,
    this.hint = '비밀번호 입력',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textMuted, size: 18,
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: loading
            ? const Center(child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
              ))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _GoogleIcon(),
                const SizedBox(width: 10),
                const Text('Google로 계속하기', style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
                )),
              ]),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Simplified colorful G
    final paint = Paint()..style = PaintingStyle.fill;
    // Blue arc (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -0.5, 2.0, false, paint..style = PaintingStyle.stroke..strokeWidth = r * 0.55);
    // Red top
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -2.2, 1.4, false, paint..strokeWidth = r * 0.55);
    // Yellow bottom
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), 1.2, 0.9, false, paint..strokeWidth = r * 0.55);
    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), 2.1, 0.8, false, paint..strokeWidth = r * 0.55);
    // White horizontal bar
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(c.dx - 0.5, c.dy - r * 0.3, r * 1.15, r * 0.6), paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(c.dx - 0.5, c.dy - r * 0.3, r * 1.15, r * 0.6), paint..style = PaintingStyle.stroke..strokeWidth = 0);
    // Blue fill for right portion
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(c.dx - 0.5, c.dy - r * 0.3, r * 1.15, r * 0.6), paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('또는', style: TextStyle(
          color: AppColors.textMuted, fontSize: 12,
        )),
      ),
      Expanded(child: Divider(color: AppColors.border, thickness: 1)),
    ]);
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(
          color: AppColors.rose, fontSize: 13,
        ))),
      ]),
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            color: selected ? AppColors.primaryLight : AppColors.textPrimary,
            fontWeight: FontWeight.w700, fontSize: 14,
          )),
          const SizedBox(height: 4),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(
            color: AppColors.textMuted, fontSize: 11, height: 1.4,
          )),
        ]),
      ),
    );
  }
}
