import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fitlearn/core/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  Future<Map<String, dynamic>> runDiagnosis({
    required String userId,
    required List<String> answers,
  }) async {
    final res = await _dio.post(
      ApiConstants.diagnosis,
      data: {'user_id': userId, 'answers': answers},
    );
    return res.data as Map<String, dynamic>;
  }

  /// SSE 스트리밍 수신 - 3버전 재가공 결과를 Stream으로 반환
  Stream<Map<String, dynamic>> reforgeStream({
    required String userId,
    required String lectureId,
    required String lectureContent,
  }) async* {
    final controller = StreamController<Map<String, dynamic>>();

    _dio.post<ResponseBody>(
      ApiConstants.reforge,
      data: {
        'user_id': userId,
        'lecture_id': lectureId,
        'lecture_content': lectureContent,
      },
      options: Options(responseType: ResponseType.stream),
    ).then((res) {
      res.data!.stream.listen(
        (chunk) {
          final lines = String.fromCharCodes(chunk).split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ') && !line.contains('[DONE]')) {
              // TODO: JSON 파싱 후 controller에 추가
            }
          }
        },
        onDone: controller.close,
        onError: controller.addError,
      );
    });

    yield* controller.stream;
  }
}
