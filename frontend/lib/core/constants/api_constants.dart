class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fitlearn-backend.onrender.com',
  );

  static const String diagnosis = '/api/v1/diagnosis';
  static const String reforge = '/api/v1/reforge';
  static const String questions = '/api/v1/questions';
  static String dashboard(String id) => '/api/v1/dashboard/$id';
  static const String health = '/api/v1/health';
}
