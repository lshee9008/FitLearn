import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/widgets/fitlearn_logo.dart';

// ── 컬러 ─────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0E0E11);
  static const surface = Color(0xFF13131A);
  static const surface2 = Color(0xFF1A1A24);
  static const border = Color(0xFF1E1E2A);
  static const lime = Color(0xFFC8F135);
  static const limeDark = Color(0xFF1A2400);
  static const lavender = Color(0xFFA78BFA);
  static const coral = Color(0xFFFB7185);
  static const textPri = Color(0xFFF0F0F4);
  static const textSec = Color(0xFF8888A0);
  static const textMute = Color(0xFF4A4A5A);
}

// ══════════════════════════════════════════════════════════════════
// AuthPage — 로그인 / 회원가입 통합 페이지
// ══════════════════════════════════════════════════════════════════
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _setError(String msg) {
    if (mounted)
      setState(() {
        _loading = false;
        _error = msg;
      });
  }

  Future<void> _routeAfterAuth(UserProfile profile) async {
    if (profile.role == UserRole.professor) {
      if (mounted) context.go('/professor/home');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingCourseId = prefs.getString('pendingCourseId');
      var enrolledPendingCourse = false;
      if (pendingCourseId != null && pendingCourseId.isNotEmpty) {
        await ApiService().enrollCourse(
          courseId: pendingCourseId,
          userId: profile.userId,
        );
        enrolledPendingCourse = true;
        await prefs.remove('pendingCourseId');
      }

      if (enrolledPendingCourse) {
        if (mounted) context.go('/student/home');
        return;
      }

      final paid = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: profile.userId)
          .where('status', isEqualTo: 'paid')
          .limit(1)
          .get();
      if (!mounted) return;
      context.go(paid.docs.isEmpty ? '/' : '/student/home');
    } catch (_) {
      if (mounted) context.go('/');
    }
  }

  // ── 로그인 ─────────────────────────────────────────────────────
  Future<void> _signIn(String email, String password) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      // Firestore에서 역할 + diagnosis 읽기
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final role =
          data['role'] == 'professor' ? UserRole.professor : UserRole.student;
      final diagnosis = data['diagnosis'] as bool? ?? false;

      final profile = UserProfile(
        userId: uid,
        name: data['name'] as String? ?? cred.user!.displayName ?? '',
        email: email.trim(),
        role: role,
        diagnosis: diagnosis,
      );
      ref.read(authNotifierProvider.notifier).setProfile(profile);

      if (!mounted) return;
      await _routeAfterAuth(profile);
    } on FirebaseAuthException catch (e) {
      _setError(firebaseErrorToKorean(e));
    } catch (e) {
      _setError('로그인 오류: $e');
    }
  }

  // ── 회원가입 ───────────────────────────────────────────────────
  Future<void> _signUp(
      String name, String email, String password, UserRole role) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name.trim());

      // Firestore users 문서 생성
      final roleStr = role == UserRole.professor ? 'professor' : 'student';
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'userId': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'role': roleStr,
        'diagnosis': false,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'last_seen_at': FieldValue.serverTimestamp(),
      });

      // 백엔드 등록 (실패해도 진행)
      try {
        await ApiService().register(
          userId: user.uid,
          name: name.trim(),
          role: roleStr,
          email: email.trim(),
        );
      } catch (_) {}

      final profile = UserProfile(
        userId: user.uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        diagnosis: false,
      );
      ref.read(authNotifierProvider.notifier).setProfile(profile);

      if (!mounted) return;
      await _routeAfterAuth(profile);
    } on FirebaseAuthException catch (e) {
      _setError(firebaseErrorToKorean(e));
    } catch (e) {
      _setError('회원가입 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 440,
            margin: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                  child: Column(children: [
                    // 로고
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const FitLearnLogo(height: 34),
                    ]),
                    const SizedBox(height: 8),
                    const Text('AI 맞춤 학습 플랫폼',
                        style: TextStyle(color: _C.textMute, fontSize: 13)),
                    const SizedBox(height: 24),
                    // 탭
                    Container(
                      decoration: BoxDecoration(
                        color: _C.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tab,
                        indicator: BoxDecoration(
                          color: _C.lime,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: _C.limeDark,
                        unselectedLabelColor: _C.textSec,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: '로그인'),
                          Tab(text: '회원가입'),
                        ],
                      ),
                    ),
                  ]),
                ),
                // 에러 메시지
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _C.coral.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: _C.coral.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!,
                          style:
                              const TextStyle(color: _C.coral, fontSize: 13)),
                    ),
                  ),
                // 탭 콘텐츠
                SizedBox(
                  height: _tab.index == 0 ? 280 : 380,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _SignInForm(
                          loading: _loading,
                          onSubmit: (email, pw) => _signIn(email, pw)),
                      _SignUpForm(
                          loading: _loading,
                          onSubmit: (name, email, pw, role) =>
                              _signUp(name, email, pw, role)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 로그인 폼 ─────────────────────────────────────────────────────
class _SignInForm extends StatefulWidget {
  final bool loading;
  final void Function(String email, String password) onSubmit;

  const _SignInForm({required this.loading, required this.onSubmit});

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
      child: Column(children: [
        _Field(ctrl: _email, hint: '이메일', icon: Icons.email_outlined),
        const SizedBox(height: 12),
        _Field(
          ctrl: _pw,
          hint: '비밀번호',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          trailing: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _C.textMute,
                size: 18),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: widget.loading
                ? null
                : () => widget.onSubmit(_email.text, _pw.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.lime,
              foregroundColor: _C.limeDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _C.limeDark))
                : const Text('로그인',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── 회원가입 폼 ───────────────────────────────────────────────────
class _SignUpForm extends StatefulWidget {
  final bool loading;
  final void Function(String name, String email, String password, UserRole role)
      onSubmit;

  const _SignUpForm({required this.loading, required this.onSubmit});

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  UserRole _role = UserRole.student;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Field(ctrl: _name, hint: '이름', icon: Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _Field(ctrl: _email, hint: '이메일', icon: Icons.email_outlined),
        const SizedBox(height: 12),
        _Field(
          ctrl: _pw,
          hint: '비밀번호 (6자 이상)',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          trailing: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _C.textMute,
                size: 18),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 16),
        const Text('역할 선택',
            style: TextStyle(
                color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _RoleChip(
            label: '학생',
            icon: Icons.school_rounded,
            selected: _role == UserRole.student,
            onTap: () => setState(() => _role = UserRole.student),
          ),
          const SizedBox(width: 10),
          _RoleChip(
            label: '강사',
            icon: Icons.cast_for_education_rounded,
            selected: _role == UserRole.professor,
            onTap: () => setState(() => _role = UserRole.professor),
          ),
        ]),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: widget.loading
                ? null
                : () =>
                    widget.onSubmit(_name.text, _email.text, _pw.text, _role),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.lime,
              foregroundColor: _C.limeDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _C.limeDark))
                : const Text('가입하기',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── 역할 칩 ──────────────────────────────────────────────────────
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _C.limeDark : _C.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _C.lime : _C.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? _C.lime : _C.textSec),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? _C.lime : _C.textSec,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── 공통 입력 필드 ────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;

  const _Field({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: _C.textPri, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
        prefixIcon: Icon(icon, color: _C.textMute, size: 18),
        suffixIcon: trailing,
        filled: true,
        fillColor: _C.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.lime, width: 1.5),
        ),
      ),
    );
  }
}
