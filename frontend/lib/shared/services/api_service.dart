import 'package:dio/dio.dart';
import 'package:fitlearn/core/constants/api_constants.dart';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  final _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 60), // 15초 -> 60초로 대폭 연장
    receiveTimeout: const Duration(minutes: 5), // AI 파이프라인 대기를 위해 5분 유지
    sendTimeout: const Duration(minutes: 5), // 큰 파일 업로드를 위해 추가
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

  Future<void> markActive(String userId) async {
    await _dio.post('/api/v1/auth/active/$userId');
  }

  // ── Rooms ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createRoom({
    required String professorUid,
    required String subject,
    String description = '',
    String roomType = 'offline',
    String synopsis = '',
    List<String> coreConcepts = const [],
    String youtubeUrl = '',
    int price = 0,
  }) async {
    final res = await _dio.post(ApiConstants.createRoom, data: {
      'professor_uid': professorUid,
      'subject': subject,
      'description': description,
      'room_type': roomType,
      'synopsis': synopsis,
      'core_concepts': coreConcepts,
      'youtube_url': youtubeUrl,
      'price': price,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getStudentRooms(String uid) async {
    final res = await _dio.get(ApiConstants.studentRooms(uid));
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStudentRoomSummary(String uid) async {
    final res = await _dio.get('/api/v1/rooms/student/$uid/summary');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudentServiceHub(String uid) async {
    final res = await _dio.get('/api/v1/rooms/student/$uid/hub');
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

  Future<Map<String, dynamic>> applyToRoom({
    required String roomId,
    required String userId,
    String note = '',
  }) async {
    final res = await _dio.post('/api/v1/rooms/$roomId/apply', data: {
      'user_id': userId,
      'note': note,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> enrollRoom({
    required String roomId,
    required String userId,
  }) async {
    await _dio.post('/api/v1/rooms/$roomId/enroll', data: {
      'user_id': userId,
    });
  }

  Future<List<dynamic>> getStudentApplications(String userId) async {
    final res = await _dio.get('/api/v1/rooms/student/$userId/applications');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getRoomApplications(String roomId) async {
    final res = await _dio.get('/api/v1/rooms/$roomId/applications');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> reviewRoomApplication({
    required String roomId,
    required String userId,
    required String status,
    String note = '',
  }) async {
    final res = await _dio
        .post('/api/v1/rooms/$roomId/applications/$userId/review', data: {
      'status': status,
      'note': note,
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

  Future<void> updateRoom({
    required String roomId,
    required String subject,
    String description = '',
    String synopsis = '',
    String coreConcepts = '',
  }) async {
    await _dio.put(
      '/api/v1/rooms/$roomId',
      data: {
        'subject': subject,
        'description': description,
        'synopsis': synopsis,
        'core_concepts': coreConcepts,
      },
    );
  }

  Future<List<dynamic>> getRoomStudents(String roomId) async {
    final res = await _dio.get(ApiConstants.roomStudents(roomId));
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getRoomLectures(String roomId) async {
    final res = await _dio.get(ApiConstants.roomLectures(roomId));
    return res.data as List<dynamic>;
  }

  Future<void> markLectureProgress({
    required String roomId,
    required String lectureId,
    required String userId,
  }) async {
    await _dio.post(
      '/api/v1/rooms/$roomId/lectures/$lectureId/progress',
      data: {'user_id': userId},
    );
  }

  // ── Diagnosis ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> runDiagnosis({
    required String userId,
    required List<Map<String, dynamic>> answers,
    String? roomId,
    String writingResponse = '',
    Map<String, dynamic> learningHistory = const {},
  }) async {
    final res = await _dio.post(ApiConstants.diagnosis, data: {
      'user_id': userId,
      'answers': answers,
      'writing_response': writingResponse,
      'learning_history': learningHistory,
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
    int weekNumber = 0,
    String lectureTitle = '',
    String lectureId = '',
    int orderIndex = 0,
    String videoUrl = '',
    String videoTranscriptText = '',
    String materialUrl = '',
    List<int>? videoFileBytes,
    String? videoFileName,
  }) async {
    final formData = FormData.fromMap({
      'room_id': roomId,
      'professor_uid': professorUid,
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'week_number': weekNumber,
      'lecture_title': lectureTitle,
      'lecture_id': lectureId,
      'order_index': orderIndex,
      'video_url': videoUrl,
      'video_transcript_text': videoTranscriptText,
      'material_url': materialUrl,
      if (videoFileBytes != null)
        'video_file': MultipartFile.fromBytes(
          videoFileBytes,
          filename: videoFileName ?? 'video.mp4',
        ),
    });
    final res = await _dio.post(ApiConstants.uploadLecture, data: formData);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLecture(
      String roomId, String lectureId) async {
    final res = await _dio.get(ApiConstants.lecture(roomId, lectureId));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> askVideoSegment({
    required String roomId,
    required String lectureId,
    required String userId,
    required int startMinute,
    required int endMinute,
    required String question,
  }) async {
    final res = await _dio
        .post('/api/v1/lectures/$roomId/$lectureId/video/assist', data: {
      'user_id': userId,
      'start_minute': startMinute,
      'end_minute': endMinute,
      'question': question,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLectureShells(
    String roomId,
    List<Map<String, dynamic>> lectures,
  ) async {
    final res = await _dio.post(
      '/api/v1/rooms/$roomId/lectures/shells',
      data: {'lectures': lectures},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLectureMeta(
    String roomId,
    String lectureId,
    Map<String, dynamic> data,
  ) async {
    final res = await _dio.patch('/api/v1/rooms/$roomId/lectures/$lectureId',
        data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reorderLectures(
    String roomId,
    List<Map<String, dynamic>> items,
  ) async {
    final res =
        await _dio.post('/api/v1/rooms/$roomId/lectures/reorder', data: {
      'items': items,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteLecture(String roomId, String lectureId) async {
    await _dio.delete('/api/v1/rooms/$roomId/lectures/$lectureId');
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
    String? testStyle,
  }) async {
    // 데모 모드: Firebase 없이 내장 샘플로 테스트
    if (roomId == 'demo' || lectureId == 'demo') {
      final res = await _dio.get(
        '/api/v1/lectures/demo/reforged',
        queryParameters: {'test_style': testStyle ?? '읽기형'},
      );
      return res.data as Map<String, dynamic>;
    }
    final params = <String, String>{'user_id': userId};
    if (testStyle != null && testStyle.isNotEmpty)
      params['test_style'] = testStyle;
    final res = await _dio.get(
      ApiConstants.reforgedLecture(roomId, lectureId),
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Quiz & Level ──────────────────────────────────────────────

  Future<Map<String, dynamic>> updateRoomMeta(
      String roomId, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/v1/rooms/$roomId/meta', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRoomQuiz(String roomId) async {
    final res = await _dio.get('/api/v1/rooms/$roomId/quiz');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitQuiz(
      String roomId, String userId, List<int> answers) async {
    final res = await _dio.post('/api/v1/rooms/$roomId/quiz/submit', data: {
      'user_id': userId,
      'answers': answers,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getQuizResult(
      String roomId, String userId) async {
    final res = await _dio.get('/api/v1/rooms/$roomId/quiz/result/$userId');
    return res.data as Map<String, dynamic>;
  }

  // ── Notices ───────────────────────────────────────────────────

  Future<List<dynamic>> getNotices(String roomId) async {
    final res = await _dio.get('/api/v1/rooms/$roomId/notices');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createNotice(
      String roomId, String professorUid, String content,
      {String title = ''}) async {
    final res = await _dio.post('/api/v1/rooms/$roomId/notices', data: {
      'professor_uid': professorUid,
      'content': content,
      'title': title,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteNotice(String roomId, String noticeId) async {
    await _dio.delete('/api/v1/rooms/$roomId/notices/$noticeId');
  }

  // ── Original File ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getOriginalLectureUrl(
      String roomId, String lectureId) async {
    final res = await _dio.get('/api/v1/lectures/$roomId/$lectureId/original');
    return res.data as Map<String, dynamic>;
  }

  // ── Dashboard ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard(String roomId) async {
    final res = await _dio.get(ApiConstants.dashboard(roomId));
    return res.data as Map<String, dynamic>;
  }
}
