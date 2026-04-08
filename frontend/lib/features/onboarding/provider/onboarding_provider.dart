import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/services/api_service.dart';

part 'onboarding_provider.g.dart';

enum LearningType { summary, detailed, example }

extension LearningTypeLabel on LearningType {
  String get label => switch (this) {
        LearningType.summary => '요약형',
        LearningType.detailed => '상세형',
        LearningType.example => '예시형',
      };

  String get emoji => switch (this) {
        LearningType.summary => '⚡',
        LearningType.detailed => '📖',
        LearningType.example => '💡',
      };
}

class DiagnosisResult {
  final LearningType type;
  final String description;

  const DiagnosisResult({required this.type, required this.description});
}

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  AsyncValue<DiagnosisResult?> build() => const AsyncData(null);

  Future<void> diagnose(String userId, List<String> answers) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ApiService().runDiagnosis(
        userId: userId,
        answers: answers,
      );
      return DiagnosisResult(
        type: _parse(result['learning_type'] as String),
        description: result['description'] as String,
      );
    });
  }

  LearningType _parse(String type) => switch (type) {
        '요약형' => LearningType.summary,
        '상세형' => LearningType.detailed,
        _ => LearningType.example,
      };
}
