import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/services/api_service.dart';

part 'onboarding_provider.g.dart';

enum LearningType { summary, detailed, example }

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  AsyncValue<LearningType?> build() => const AsyncData(null);

  Future<void> diagnose(String userId, List<String> answers) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ApiService().runDiagnosis(
        userId: userId,
        answers: answers,
      );
      return _parse(result['learning_type'] as String);
    });
  }

  LearningType _parse(String type) => switch (type) {
        '요약형' => LearningType.summary,
        '상세형' => LearningType.detailed,
        _ => LearningType.example,
      };
}
