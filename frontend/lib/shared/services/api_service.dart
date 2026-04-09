import 'package:dio/dio.dart';
import 'package:fitlearn/core/constants/api_constants.dart';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  final _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // ── Auth ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String userId,
    required String name,
    required String role,
    String email = '',
  }) async {
    final res = await _dio.post(ApiConstants.register, data: {
      'user_id': userId,
      'name': name,
      'role': role,
      'email': email,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(String userId) async {
    final res = await _dio.get(ApiConstants.profile(userId));
    return res.data as Map<String, dynamic>;
  }

  // ── Rooms ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createRoom({
    required String professorUid,
    required String subject,
    String description = '',
  }) async {
    final res = await _dio.post(ApiConstants.createRoom, data: {
      'professor_uid': professorUid,
      'subject': subject,
      'description': description,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getProfessorRooms(String uid) async {
    final res = await _dio.get(ApiConstants.professorRooms(uid));
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> joinRoom({
    required String userId,
    required String roomCode,
  }) async {
    final res = await _dio.post(ApiConstants.joinRoom, data: {
      'user_id': userId,
      'room_code': roomCode,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRoom(String roomId) async {
    final res = await _dio.get(ApiConstants.room(roomId));
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteRoom(String roomId) async {
    await _dio.delete(ApiConstants.deleteRoom(roomId));
  }

  Future<List<dynamic>> getRoomStudents(String roomId) async {
    final res = await _dio.get(ApiConstants.roomStudents(roomId));
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getRoomLectures(String roomId) async {
    final res = await _dio.get(ApiConstants.roomLectures(roomId));
    return res.data as List<dynamic>;
  }

  // ── Diagnosis ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> runDiagnosis({
    required String userId,
    required List<Map<String, dynamic>> answers,
    String? roomId,
  }) async {
    final res = await _dio.post(ApiConstants.diagnosis, data: {
      'user_id': userId,
      'answers': answers,
      if (roomId != null) 'room_id': roomId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDiagnosis(String userId) async {
    final res = await _dio.get(ApiConstants.diagnosisResult(userId));
    return res.data as Map<String, dynamic>;
  }

  // ── Lectures ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadLecture({
    required String roomId,
    required String professorUid,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'room_id': roomId,
      'professor_uid': professorUid,
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final res = await _dio.post(ApiConstants.uploadLecture, data: formData);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLecture(String roomId, String lectureId) async {
    final res = await _dio.get(ApiConstants.lecture(roomId, lectureId));
    return res.data as Map<String, dynamic>;
  }

  Future<void> confirmCorePoints({
    required String roomId,
    required String lectureId,
    required String professorUid,
    required List<Map<String, dynamic>> points,
  }) async {
    await _dio.post(ApiConstants.confirmPoints(roomId, lectureId), data: {
      'lecture_id': lectureId,
      'professor_uid': professorUid,
      'confirmed_points': points,
    });
  }

  Future<Map<String, dynamic>> getReforgedLecture({
    required String roomId,
    required String lectureId,
    required String userId,
  }) async {
    final res = await _dio.get(
      ApiConstants.reforgedLecture(roomId, lectureId),
      queryParameters: {'user_id': userId},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Dashboard ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard(String roomId) async {
    final res = await _dio.get(ApiConstants.dashboard(roomId));
    return res.data as Map<String, dynamic>;
  }
}
