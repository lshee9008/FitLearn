import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/view/welcome_page.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/landing/presentation/pages/course_detail_page.dart';
import '../../features/student/diagnosis/view/diagnosis_page.dart';
import '../../features/student/diagnosis/view/diagnosis_result_page.dart';
import '../../features/student/diagnosis/view/quick_diagnosis_page.dart';
import '../../features/student/diagnosis/provider/diagnosis_provider.dart';
import '../../features/student/room/view/student_home_page.dart';
import '../../features/student/room/view/subject_quiz_page.dart';
import '../../features/student/lecture/view/lecture_reader_page.dart';
import '../../features/professor/room/view/professor_home_page.dart';
import '../../features/professor/room/view/room_detail_page.dart';
import '../../features/professor/lecture/view/upload_page.dart';
import '../../features/professor/lecture/view/core_point_review_page.dart';
import '../../features/professor/dashboard/view/dashboard_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Landing / Auth ────────────────────────────────────────────
    GoRoute(
      path: '/',
      builder: (_, __) => const LandingPage(),
    ),
    GoRoute(
      path: '/auth',
      builder: (_, __) => const AuthPage(),
    ),
    GoRoute(
      path: '/course/:courseId',
      builder: (_, state) =>
          CourseDetailPage(courseId: state.pathParameters['courseId']!),
    ),
    GoRoute(
      path: '/welcome',
      builder: (_, __) => const WelcomePage(),
    ),

    // ── Student ───────────────────────────────────────────────────
    GoRoute(
      path: '/student/home',
      builder: (_, __) => const StudentHomePage(),
    ),
    GoRoute(
      path: '/student/diagnosis',
      builder: (_, __) => const DiagnosisPage(),
    ),
    GoRoute(
      path: '/student/diagnosis/quick',
      builder: (_, state) => QuickDiagnosisPage(next: state.uri.queryParameters['next']),
    ),
    GoRoute(
      path: '/student/subject_quiz/:roomId',
      builder: (_, state) =>
          SubjectQuizPage(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/student/diagnosis/result',
      builder: (_, state) =>
          DiagnosisResultPage(result: state.extra as DiagnosisResult),
    ),
    GoRoute(
      path: '/learn/:roomId/:lectureId',
      builder: (_, state) => LectureReaderPage(
        key: ValueKey(state.uri.path),
        roomId: state.pathParameters['roomId']!,
        lectureId: state.pathParameters['lectureId']!,
      ),
    ),
    GoRoute(
      // 하위호환: extra 기반 구 경로 → /learn 경로로 정규화
      path: '/student/lecture',
      redirect: (_, state) {
        final extra = state.extra;
        if (extra is Map && extra['room_id'] != null && extra['lecture_id'] != null) {
          return '/learn/${extra['room_id']}/${extra['lecture_id']}';
        }
        return '/student/home';
      },
    ),

    // ── Professor ─────────────────────────────────────────────────
    GoRoute(
      path: '/professor/home',
      builder: (_, __) => const ProfessorHomePage(),
    ),
    GoRoute(
      path: '/professor/room/new',
      builder: (_, __) => const RoomDetailPage(roomId: '', createMode: true),
    ),
    GoRoute(
      path: '/professor/room/:roomId',
      builder: (_, state) =>
          RoomDetailPage(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/professor/lecture/:roomId/upload',
      builder: (_, state) =>
          LectureUploadPage(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/professor/lecture/:roomId/:lectureId/review',
      builder: (_, state) => CorePointReviewPage(
        roomId: state.pathParameters['roomId']!,
        lectureId: state.pathParameters['lectureId']!,
        uploadData: state.extra as Map<String, dynamic>,
      ),
    ),
    GoRoute(
      path: '/professor/dashboard/:roomId',
      builder: (_, state) =>
          DashboardPage(roomId: state.pathParameters['roomId']!),
    ),
    // ── Legacy (backward compat) ───────────────────────────────────
    GoRoute(path: '/onboarding', redirect: (_, __) => '/'),
    GoRoute(path: '/lecture', redirect: (_, __) => '/student/home'),
    GoRoute(path: '/reforge-test', redirect: (_, __) => '/'),
  ],
);
