import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/services/api_service.dart';

part 'auth_provider.g.dart';

enum UserRole { student, professor }

class UserProfile {
  final String userId;
  final String name;
  final UserRole role;

  const UserProfile({required this.userId, required this.name, required this.role});

  String get roleLabel => role == UserRole.student ? '학생' : '교수';
  String get roleValue => role == UserRole.student ? 'student' : 'professor';
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
    if (uid != null && name != null && role != null) {
      state = UserProfile(
        userId: uid,
        name: name,
        role: role == 'professor' ? UserRole.professor : UserRole.student,
      );
    }
  }

  Future<void> register(String name, UserRole role) async {
    final uid = const Uuid().v4();
    final profile = UserProfile(userId: uid, name: name, role: role);

    await ApiService().register(
      userId: uid,
      name: name,
      role: profile.roleValue,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', uid);
    await prefs.setString('user_name', name);
    await prefs.setString('user_role', profile.roleValue);

    state = profile;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = null;
  }
}
