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

class ProfessorRoomDetailSummary {
  final Map<String, dynamic> room;
  final List<dynamic> lectures;
  final List<dynamic> students;
  final List<dynamic> notices;

  const ProfessorRoomDetailSummary({
    required this.room,
    required this.lectures,
    required this.students,
    required this.notices,
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

final professorRoomDetailProvider =
    FutureProvider.autoDispose.family<ProfessorRoomDetailSummary, String>((ref, roomId) async {
  final results = await Future.wait([
    ApiService().getRoom(roomId),
    ApiService().getRoomLectures(roomId),
    ApiService().getRoomStudents(roomId),
    ApiService().getNotices(roomId),
  ]);

  return ProfessorRoomDetailSummary(
    room: results[0] as Map<String, dynamic>,
    lectures: results[1] as List<dynamic>,
    students: results[2] as List<dynamic>,
    notices: results[3] as List<dynamic>,
  );
});

final currentStudentHomeSummaryProvider =
    FutureProvider.autoDispose<StudentHomeSummary?>((ref) async {
  final user = ref.watch(authNotifierProvider);
  if (user == null) return null;
  return ref.watch(studentHomeSummaryProvider(user.userId).future);
});
