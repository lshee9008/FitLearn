class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fitlearn-backend.onrender.com',
  );

  // Auth
  static const String register = '/api/v1/auth/register';
  static String profile(String uid) => '/api/v1/auth/profile/$uid';

  // Rooms
  static const String createRoom = '/api/v1/rooms';
  static String professorRooms(String uid) => '/api/v1/rooms/professor/$uid';
  static const String joinRoom = '/api/v1/rooms/join';
  static String room(String id) => '/api/v1/rooms/$id';
  static String deleteRoom(String id) => '/api/v1/rooms/$id';
  static String roomStudents(String id) => '/api/v1/rooms/$id/students';
  static String roomLectures(String id) => '/api/v1/rooms/$id/lectures';

  // Diagnosis
  static const String diagnosis = '/api/v1/diagnosis';
  static String diagnosisResult(String uid) => '/api/v1/diagnosis/$uid';

  // Lectures
  static const String uploadLecture = '/api/v1/lectures/upload';
  static String lecture(String roomId, String lectureId) =>
      '/api/v1/lectures/$roomId/$lectureId';
  static String confirmPoints(String roomId, String lectureId) =>
      '/api/v1/lectures/$roomId/$lectureId/confirm';
  static String reforgedLecture(String roomId, String lectureId) =>
      '/api/v1/lectures/$roomId/$lectureId/reforged';

  // Dashboard
  static String dashboard(String roomId) => '/api/v1/dashboard/$roomId';

  // Health
  static const String health = '/api/v1/health';
}
