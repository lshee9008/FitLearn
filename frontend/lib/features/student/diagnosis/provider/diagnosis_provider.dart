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
  final int metacognition;
  final int consistency;

  const DimensionScores({
    required this.visual,
    required this.analytical,
    required this.focusDepth,
    required this.detailPref,
    required this.speed,
    required this.collaboration,
    this.metacognition = 50,
    this.consistency = 50,
  });
}

class ReliabilityInfo {
  final double pairQ3Q18;
  final double pairQ7Q22;
  final double pairQ11Q24;
  final double overall;

  const ReliabilityInfo({
    this.pairQ3Q18 = 0.75,
    this.pairQ7Q22 = 0.75,
    this.pairQ11Q24 = 0.75,
    this.overall = 0.75,
  });

  int get overallPct => (overall * 100).round();

  String get message {
    if (overall >= 0.8) return '높은 일관성 — 안정적인 성향입니다';
    if (overall >= 0.6) return '중간 일관성 — 상황에 따라 유연한 성향입니다';
    return '변동성 있음 — 성향이 맥락에 따라 달라집니다';
  }
}

class DiagnosisProfile {
  final String learningStyle;
  final String cognitiveStyle;
  final String focusPattern;
  final String preferredFormat;
  final String pace;
  final String interaction;
  final DimensionScores scores;
  final String analysis;
  final String writingInsight;
  final ReliabilityInfo reliability;
  final Map<String, dynamic> vark;
  final Map<String, dynamic> felder;
  final Map<String, dynamic> cognitiveLoad;
  final String kolbType;
  final int confidenceScore;
  final List<String> paperCitations;

  const DiagnosisProfile({
    required this.learningStyle,
    required this.cognitiveStyle,
    required this.focusPattern,
    required this.preferredFormat,
    required this.pace,
    required this.interaction,
    required this.scores,
    required this.analysis,
    this.writingInsight = '',
    this.reliability = const ReliabilityInfo(),
    this.vark = const {},
    this.felder = const {},
    this.cognitiveLoad = const {},
    this.kolbType = '',
    this.confidenceScore = 70,
    this.paperCitations = const [],
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

  Future<DiagnosisResult> submit({
    required String userId,
    required List<Map<String, dynamic>> answers,
    required String writingResponse,
    required Map<String, dynamic> learningHistory,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final data = await ApiService().runDiagnosis(
        userId: userId,
        answers: answers,
        writingResponse: writingResponse,
        learningHistory: learningHistory,
      );
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
    final rel = p['reliability'] as Map<String, dynamic>? ?? {};
    final vark = Map<String, dynamic>.from(p['vark'] as Map? ?? {});
    final felder = Map<String, dynamic>.from(p['felder'] as Map? ?? {});
    final cogLoad = Map<String, dynamic>.from(p['cognitive_load'] as Map? ?? {});

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
          metacognition: (s['metacognition'] as num?)?.toInt() ?? 50,
          consistency: (s['consistency'] as num?)?.toInt() ?? 50,
        ),
        analysis: p['analysis'] as String? ?? '',
        writingInsight: p['writing_insight'] as String? ?? '',
        reliability: ReliabilityInfo(
          pairQ3Q18: (rel['pair_q3_q18'] as num?)?.toDouble() ?? 0.75,
          pairQ7Q22: (rel['pair_q7_q22'] as num?)?.toDouble() ?? 0.75,
          pairQ11Q24: (rel['pair_q11_q24'] as num?)?.toDouble() ?? 0.75,
          overall: (rel['overall'] as num?)?.toDouble() ?? 0.75,
        ),
        vark: vark,
        felder: felder,
        cognitiveLoad: cogLoad,
        kolbType: p['kolb_type'] as String? ?? '',
        confidenceScore: (p['confidence_score'] as num?)?.toInt() ?? 70,
        paperCitations: List<String>.from(p['paper_citations'] as List? ?? []),
      ),
      strengths: List<String>.from(data['strengths'] as List? ?? []),
      weaknesses: List<String>.from(data['weaknesses'] as List? ?? []),
      strategies: List<String>.from(data['strategies'] as List? ?? []),
    );
  }
}
