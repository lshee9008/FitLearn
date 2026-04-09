import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/api_service.dart';

part 'auth_provider.g.dart';

enum UserRole { student, professor }

class UserProfile {
  final String userId;
  final String name;
  final String email;
  final UserRole role;

  const UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  String get roleLabel => role == UserRole.student ? '학생' : '교수';
  String get roleValue => role == UserRole.student ? 'student' : 'professor';

  static UserProfile fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      userId: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] == 'professor' ? UserRole.professor : UserRole.student,
    );
  }
}

// Flutter Web: Google Sign-In Web Client ID
// Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration → Web client ID
final _googleSignIn = GoogleSignIn(
  clientId:
      '14190977451-REPLACE_WITH_WEB_CLIENT_ID.apps.googleusercontent.com',
);

String firebaseErrorToKorean(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'user-not-found':
        return '존재하지 않는 이메일입니다.';
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'too-many-requests':
        return '잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      case 'operation-not-allowed':
        return '해당 로그인 방식이 비활성화되어 있습니다.';
      default:
        return '오류가 발생했습니다. (${e.code})';
    }
  }
  return e.toString();
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  UserProfile? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    final name = prefs.getString('user_name');
    final role = prefs.getString('user_role');
    final email = prefs.getString('user_email') ?? '';

    // Firebase currentUser 일치 여부 확인
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (uid != null && name != null && role != null && firebaseUser?.uid == uid) {
      state = UserProfile(
        userId: uid,
        name: name,
        email: email,
        role: role == 'professor' ? UserRole.professor : UserRole.student,
      );
    } else if (uid != null && firebaseUser == null) {
      // Firebase 세션 만료 → 로컬 캐시 제거
      await prefs.clear();
    }
  }

  Future<void> _saveToPrefs(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', profile.userId);
    await prefs.setString('user_name', profile.name);
    await prefs.setString('user_role', profile.roleValue);
    await prefs.setString('user_email', profile.email);
  }

  // ── 이메일 로그인 ──────────────────────────────────────────────
  Future<void> signInWithEmail(String email, String password) async {
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final data = await ApiService().getProfile(uid);
    final profile = UserProfile.fromMap(uid, data);
    await _saveToPrefs(profile);
    state = profile;
  }

  // ── 이메일 회원가입 ────────────────────────────────────────────
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(name.trim());
    final uid = cred.user!.uid;
    await ApiService().register(
      userId: uid,
      name: name.trim(),
      role: role == UserRole.professor ? 'professor' : 'student',
      email: email.trim(),
    );
    final profile = UserProfile(
      userId: uid,
      name: name.trim(),
      email: email.trim(),
      role: role,
    );
    await _saveToPrefs(profile);
    state = profile;
  }

  // ── Google 로그인 (로그인 탭) ──────────────────────────────────
  // 기존 회원 전용 — 미가입 시 예외 발생
  Future<void> loginWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await FirebaseAuth.instance.signInWithCredential(credential);
    final uid = cred.user!.uid;

    try {
      final data = await ApiService().getProfile(uid);
      final profile = UserProfile.fromMap(uid, data);
      await _saveToPrefs(profile);
      state = profile;
    } catch (_) {
      // 가입 이력 없음 → Firebase 세션 해제 후 오류
      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();
      throw Exception('가입된 계정이 없습니다. 회원가입을 먼저 해주세요.');
    }
  }

  // ── Google 회원가입 (회원가입 탭) ─────────────────────────────
  // 신규: 역할 선택 후 등록 / 기존: 프로필 불러오기
  Future<void> registerWithGoogle(UserRole role) async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await FirebaseAuth.instance.signInWithCredential(credential);
    final uid = cred.user!.uid;
    final name = cred.user!.displayName ?? googleUser.displayName ?? '사용자';
    final email = cred.user!.email ?? googleUser.email;

    try {
      // 이미 가입된 경우 프로필 로드
      final data = await ApiService().getProfile(uid);
      final profile = UserProfile.fromMap(uid, data);
      await _saveToPrefs(profile);
      state = profile;
    } catch (_) {
      // 신규 사용자 등록
      await ApiService().register(
        userId: uid,
        name: name,
        role: role == UserRole.professor ? 'professor' : 'student',
        email: email,
      );
      final profile = UserProfile(
        userId: uid,
        name: name,
        email: email,
        role: role,
      );
      await _saveToPrefs(profile);
      state = profile;
    }
  }

  // ── 로그아웃 ──────────────────────────────────────────────────
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = null;
  }
}
