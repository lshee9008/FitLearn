// Legacy provider — 신규 구조에서는 student/lecture 및 professor/lecture 사용
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lecture_provider.g.dart';

@riverpod
class LectureNotifier extends _$LectureNotifier {
  @override
  AsyncValue<String?> build() => const AsyncData(null);
}
