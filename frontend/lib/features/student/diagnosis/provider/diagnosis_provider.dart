import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/api_service.dart';

part 'diagnosis_provider.g.dart';

class DimensionScores {
  final int visual;
  final int analytical;
  final int focusDepth;
  final int detailPref;
  final int speed;
  final int collaboration;

  const DimensionScores({
    required this.visual,
    required this.analytical,
    required this.focusDepth,
    required this.detailPref,
    required this.speed,
    required this.collaboration,
  });
}

class DiagnosisProfile {
  final String learningStyle;   // 시각형 | 청각형 | 읽기형 | 실습형
  final String cognitiveStyle;  // 분석형 | 직관형
  final String focusPattern;    // 단기집중형 | 장기몰입형
  final String preferredFormat; // 요약형 | 상세형 | 예시형
  final String pace;            // 속도형 | 숙고형
  final String interaction;     // 독립형 | 협력형
  final DimensionScores scores;
  final String analysis;

  const DiagnosisProfile({
    required this.learningStyle,
    required this.cognitiveStyle,
    required this.focusPattern,
    required this.preferredFormat,
    required this.pace,
    required this.interaction,
    required this.scores,
    required this.analysis,
  });
}

class DiagnosisResult {
  final DiagnosisProfile profile;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> strategies;

  const DiagnosisResult({
    required this.profile,
    required this.strengths,
    required this.weaknesses,
    required this.strategies,
  });
}

@riverpod
class DiagnosisNotifier extends _$DiagnosisNotifier {
  @override
  AsyncValue<DiagnosisResult?> build() => const AsyncData(null);

  Future<DiagnosisResult> submit(
      String userId, List<Map<String, dynamic>> answers) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final data =
          await ApiService().runDiagnosis(userId: userId, answers: answers);
      return _parse(data);
    });
    state = result;
    if (result.hasError) throw result.error!;
    return result.value!;
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
    final s = p['scores'] as Map<String, dynamic>? ?? {};

    return DiagnosisResult(
      profile: DiagnosisProfile(
        learningStyle: p['learning_style'] as String? ?? '읽기형',
        cognitiveStyle: p['cognitive_style'] as String? ?? '분석형',
        focusPattern: p['focus_pattern'] as String? ?? '단기집중형',
        preferredFormat: p['preferred_format'] as String? ?? '요약형',
        pace: p['pace'] as String? ?? '속도형',
        interaction: p['interaction'] as String? ?? '독립형',
        scores: DimensionScores(
          visual: (s['visual'] as num?)?.toInt() ?? 50,
          analytical: (s['analytical'] as num?)?.toInt() ?? 50,
          focusDepth: (s['focus_depth'] as num?)?.toInt() ?? 50,
          detailPref: (s['detail_pref'] as num?)?.toInt() ?? 50,
          speed: (s['speed'] as num?)?.toInt() ?? 50,
          collaboration: (s['collaboration'] as num?)?.toInt() ?? 50,
        ),
        analysis: p['analysis'] as String? ?? '',
      ),
      strengths: List<String>.from(data['strengths'] as List? ?? []),
      weaknesses: List<String>.from(data['weaknesses'] as List? ?? []),
      strategies: List<String>.from(data['strategies'] as List? ?? []),
    );
  }
}
