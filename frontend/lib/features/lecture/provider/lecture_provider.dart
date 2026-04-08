import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/services/api_service.dart';

part 'lecture_provider.g.dart';

class ReforgedContent {
  final String summaryType;
  final String detailedType;
  final String exampleType;

  const ReforgedContent({
    required this.summaryType,
    required this.detailedType,
    required this.exampleType,
  });
}

@riverpod
class LectureNotifier extends _$LectureNotifier {
  @override
  AsyncValue<ReforgedContent?> build() => const AsyncData(null);

  Future<void> reforge({
    required String userId,
    required String lectureId,
    required String content,
  }) async {
    state = const AsyncLoading();

    final results = <String, String>{};

    await for (final chunk in ApiService().reforgeStream(
      userId: userId,
      lectureId: lectureId,
      lectureContent: content,
    )) {
      results[chunk['type'] as String] = chunk['content'] as String;
    }

    state = AsyncData(ReforgedContent(
      summaryType: results['요약형'] ?? '',
      detailedType: results['상세형'] ?? '',
      exampleType: results['예시형'] ?? '',
    ));
  }
}
