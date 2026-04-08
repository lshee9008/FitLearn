import 'package:go_router/go_router.dart';
import '../../features/onboarding/view/onboarding_page.dart';
import '../../features/lecture/view/lecture_page.dart';
import '../../features/dashboard/view/dashboard_page.dart';

final appRouter = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/lecture',
      builder: (context, state) => const LecturePage(),
    ),
    GoRoute(
      path: '/dashboard/:instructorId',
      builder: (context, state) => DashboardPage(
        instructorId: state.pathParameters['instructorId']!,
      ),
    ),
  ],
);
