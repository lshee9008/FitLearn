import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/api_service.dart';

part 'diagnosis_provider.g.dart';

class DiagnosisProfile {
  final String primaryStyle;
  final String secondaryStyle;
  final String socialType;
  final String cognitiveType;
  final String personalitySummary;

  const DiagnosisProfile({
    required this.primaryStyle,
    required this.secondaryStyle,
    required this.socialType,
    required this.cognitiveType,
    required this.personalitySummary,
  });
}

class DiagnosisResult {
  final DiagnosisProfile profile;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> recommendations;
  final String aiAnalysis;

  const DiagnosisResult({
    required this.profile,
    required this.strengths,
    required this.weaknesses,
    required this.recommendations,
    required this.aiAnalysis,
  });
}

@riverpod
class DiagnosisNotifier extends _$DiagnosisNotifier {
  @override
  AsyncValue<DiagnosisResult?> build() => const AsyncData(null);

  Future<void> submit(String userId, List<Map<String, dynamic>> answers) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ApiService().runDiagnosis(userId: userId, answers: answers);
      return _parse(data);
    });
  }

  Future<void> loadExisting(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ApiService().getDiagnosis(userId);
      return _parse(data);
    });
  }

  DiagnosisResult _parse(Map<String, dynamic> data) {
    final p = data['profile'] as Map<String, dynamic>;
    return DiagnosisResult(
      profile: DiagnosisProfile(
        primaryStyle: p['primary_style'] ?? '시각형',
        secondaryStyle: p['secondary_style'] ?? '읽기형',
        socialType: p['social_type'] ?? '내향형',
        cognitiveType: p['cognitive_type'] ?? '분석형',
        personalitySummary: p['personality_summary'] ?? '',
      ),
      strengths: List<String>.from(data['strengths'] ?? []),
      weaknesses: List<String>.from(data['weaknesses'] ?? []),
      recommendations: List<String>.from(data['recommendations'] ?? []),
      aiAnalysis: data['ai_analysis'] ?? '',
    );
  }
}
