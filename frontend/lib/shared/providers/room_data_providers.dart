import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../services/api_service.dart';

class StudentHomeSummary {
  final Map<String, dynamic>? room;
  final List<dynamic> lectures;
  final String? subjectLevel;
  final int? subjectScore;

  const StudentHomeSummary({
    required this.room,
    required this.lectures,
    required this.subjectLevel,
    required this.subjectScore,
  });

  bool get hasRoom => room != null;
}

class StudentServiceHub {
  final List<dynamic> enrolledRooms;
  final List<dynamic> discoverRooms;
  final List<dynamic> applications;
  final Map<String, dynamic>? activeRoom;
  final List<dynamic> activeRoomLectures;
  final String? activeSubjectLevel;
  final int? activeSubjectScore;

  const StudentServiceHub({
    required this.enrolledRooms,
    required this.discoverRooms,
    required this.applications,
    required this.activeRoom,
    required this.activeRoomLectures,
    required this.activeSubjectLevel,
    required this.activeSubjectScore,
  });
}

class ProfessorRoomDetailSummary {
  final Map<String, dynamic> room;
  final List<dynamic> lectures;
  final List<dynamic> students;
  final List<dynamic> notices;
  final List<dynamic> applications;

  const ProfessorRoomDetailSummary({
    required this.room,
    required this.lectures,
    required this.students,
    required this.notices,
    required this.applications,
  });
}

final professorRoomsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, userId) async {
  return ApiService().getProfessorRooms(userId);
});

final studentHomeSummaryProvider =
    FutureProvider.autoDispose.family<StudentHomeSummary, String>((ref, userId) async {
  final data = await ApiService().getStudentRoomSummary(userId);
  final room = data['room'] as Map<String, dynamic>?;
  if (room == null) {
    return const StudentHomeSummary(
      room: null,
      lectures: [],
      subjectLevel: null,
      subjectScore: null,
    );
  }

  return StudentHomeSummary(
    room: room,
    lectures: data['lectures'] as List<dynamic>? ?? const [],
    subjectLevel: data['subject_level'] as String?,
    subjectScore: data['score'] as int?,
  );
});

final currentProfessorRoomsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final user = ref.watch(authNotifierProvider);
  if (user == null) return [];
  return ref.watch(professorRoomsProvider(user.userId).future);
});

final studentServiceHubProvider =
    FutureProvider.autoDispose.family<StudentServiceHub, String>((ref, userId) async {
  final data = await ApiService().getStudentServiceHub(userId);
  return StudentServiceHub(
    enrolledRooms: data['enrolled_rooms'] as List<dynamic>? ?? const [],
    discoverRooms: data['discover_rooms'] as List<dynamic>? ?? const [],
    applications: data['applications'] as List<dynamic>? ?? const [],
    activeRoom: data['active_room'] as Map<String, dynamic>?,
    activeRoomLectures: data['active_room_lectures'] as List<dynamic>? ?? const [],
    activeSubjectLevel: data['active_subject_level'] as String?,
    activeSubjectScore: data['active_subject_score'] as int?,
  );
});

final professorRoomDetailProvider =
    FutureProvider.autoDispose.family<ProfessorRoomDetailSummary, String>((ref, roomId) async {
  final results = await Future.wait([
    ApiService().getRoom(roomId),
    ApiService().getRoomLectures(roomId),
    ApiService().getRoomStudents(roomId),
    ApiService().getNotices(roomId),
    ApiService().getRoomApplications(roomId),
  ]);

  return ProfessorRoomDetailSummary(
    room: results[0] as Map<String, dynamic>,
    lectures: results[1] as List<dynamic>,
    students: results[2] as List<dynamic>,
    notices: results[3] as List<dynamic>,
    applications: results[4] as List<dynamic>,
  );
});

final currentStudentHomeSummaryProvider =
    FutureProvider.autoDispose<StudentHomeSummary?>((ref) async {
  final user = ref.watch(authNotifierProvider);
  if (user == null) return null;
  return ref.watch(studentHomeSummaryProvider(user.userId).future);
});

final currentStudentServiceHubProvider =
    FutureProvider.autoDispose<StudentServiceHub?>((ref) async {
  final user = ref.watch(authNotifierProvider);
  if (user == null) return null;
  return ref.watch(studentServiceHubProvider(user.userId).future);
});
