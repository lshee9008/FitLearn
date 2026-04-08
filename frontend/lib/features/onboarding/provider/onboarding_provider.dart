// Legacy provider — 신규 구조에서는 student/diagnosis/provider 사용
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.g.dart';

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  AsyncValue<String?> build() => const AsyncData(null);
}
