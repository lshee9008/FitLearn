import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/widgets/fitlearn_logo.dart';

// ── 컬러 ─────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFF0E0E11);
  static const surface  = Color(0xFF13131A);
  static const surface2 = Color(0xFF1A1A24);
  static const border   = Color(0xFF1E1E2A);
  static const lime     = Color(0xFFC8F135);
  static const limeDark = Color(0xFF1A2400);
  static const lavender = Color(0xFFA78BFA);
  static const lavMid   = Color(0xFF1E1830);
  static const coral    = Color(0xFFFB7185);
  static const amber    = Color(0xFFFBBF24);
  static const textPri  = Color(0xFFF0F0F4);
  static const textSec  = Color(0xFF8888A0);
  static const textMute = Color(0xFF4A4A5A);
}

// ── 강의 모델 ─────────────────────────────────────────────────────
class CourseModel {
  final String id;
  final String title;
  final String description;
  final String thumbnail;
  final String instructor;
  final int price;
  final String roomId;
  final bool enrolled;

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.instructor,
    required this.price,
    required this.roomId,
    this.enrolled = false,
  });

  factory CourseModel.fromJson(Map<String, dynamic> data) {
    return CourseModel(
      id: data['id'] as String? ?? data['roomId'] as String? ?? '',
      title: (data['title'] as String?) ?? (data['subject'] as String?) ?? '',
      description:
          (data['description'] as String?) ?? (data['synopsis'] as String?) ?? '',
      thumbnail: data['thumbnail'] as String? ?? '',
      instructor: (data['instructor'] as String?) ??
          (data['professor_name'] as String?) ??
          '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      roomId: data['roomId'] as String? ?? data['room_id'] as String? ?? '',
    );
  }

  CourseModel copyWith({bool? enrolled}) {
    return CourseModel(
      id: id,
      title: title,
      description: description,
      thumbnail: thumbnail,
      instructor: instructor,
      price: price,
      roomId: roomId,
      enrolled: enrolled ?? this.enrolled,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// LandingPage
// ══════════════════════════════════════════════════════════════════
class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  String _searchQuery = '';
  late Future<List<CourseModel>> _coursesFuture;
  String? _loadedForUserId;

  @override
  void initState() {
    super.initState();
    _loadedForUserId = ref.read(authNotifierProvider)?.userId;
    _coursesFuture = _loadCourses(_loadedForUserId);
  }

  Future<List<CourseModel>> _loadCourses(String? userId) async {
    final items = await ApiService().getCourses();
    final courses = items
        .cast<Map<String, dynamic>>()
        .map(CourseModel.fromJson)
        .where((course) => course.id.isNotEmpty)
        .toList();
    if (userId == null || userId.isEmpty) return courses;
    try {
      final hub = await ApiService().getStudentServiceHub(userId);
      final enrolledRooms = (hub['enrolled_rooms'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final enrolledRoomIds = enrolledRooms
          .map((room) => room['room_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      return courses
          .map((course) => course.copyWith(
                enrolled: enrolledRoomIds.contains(course.roomId) ||
                    enrolledRoomIds.contains(course.id),
              ))
          .toList();
    } catch (_) {
      return courses;
    }
  }

  List<CourseModel> _filterCourses(List<CourseModel> courses) {
    final q = _searchQuery.toLowerCase();
    return courses.where((c) {
      final matchQuery = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.instructor.toLowerCase().contains(q);
      return matchQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);
    if (_loadedForUserId != user?.userId) {
      _loadedForUserId = user?.userId;
      _coursesFuture = _loadCourses(_loadedForUserId);
    }
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _Header(
            user: user,
            hasEnrolledCourseFuture: user == null
                ? null
                : _coursesFuture.then(
                    (courses) => courses.any((course) => course.enrolled),
                  ),
            onSearch: (v) => setState(() => _searchQuery = v),
            onLogin: () async {
              if (user == null) {
                context.push('/auth');
                return;
              }
              await ref.read(authNotifierProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/');
            },
          ),
          const Divider(color: _C.border, height: 1),
          Expanded(
            child: FutureBuilder<List<CourseModel>>(
              future: _coursesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _C.lime, strokeWidth: 2),
                  );
                }
                if (snapshot.hasError) {
                  return _LandingError(
                    onRetry: () => setState(
                      () => _coursesFuture = _loadCourses(_loadedForUserId),
                    ),
                  );
                }
                final courses = snapshot.data ?? const <CourseModel>[];
                return _CourseGrid(
                  courses: _filterCourses(courses),
                  onTap: (course) =>
                      context.push('/course/${course.id}', extra: course),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 헤더 ─────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final UserProfile? user;
  final Future<bool>? hasEnrolledCourseFuture;
  final ValueChanged<String> onSearch;
  final VoidCallback onLogin;

  const _Header({
    required this.user,
    required this.hasEnrolledCourseFuture,
    required this.onSearch,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      color: _C.surface,
      child: Row(
        children: [
          // 로고
          const FitLearnLogo(height: 28),
          const SizedBox(width: 32),
          // 검색바
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: TextField(
                onChanged: onSearch,
                style: const TextStyle(color: _C.textPri, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '강의명, 강사명으로 검색...',
                  hintStyle:
                      const TextStyle(color: _C.textMute, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _C.textMute, size: 18),
                  filled: true,
                  fillColor: _C.surface2,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.lime),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (user != null && hasEnrolledCourseFuture != null)
            FutureBuilder<bool>(
              future: hasEnrolledCourseFuture,
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => context.go('/student/home'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _C.limeDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _C.lime.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        '내 강의함 바로가기',
                        style: TextStyle(
                          color: _C.lime,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // 로그인 버튼
          GestureDetector(
            onTap: onLogin,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: _C.lime,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                user == null ? '로그인' : '로그아웃',
                style: TextStyle(
                    color: _C.limeDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 강의 그리드 ───────────────────────────────────────────────────
class _CourseGrid extends StatelessWidget {
  final List<CourseModel> courses;
  final ValueChanged<CourseModel> onTap;

  const _CourseGrid({required this.courses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Center(
        child: Text('강의가 없습니다.',
            style: TextStyle(color: _C.textSec, fontSize: 14)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.75,
      ),
      itemCount: courses.length,
      itemBuilder: (_, i) => _CourseCard(
        course: courses[i],
        onTap: () => onTap(courses[i]),
      ),
    );
  }
}

class _LandingError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LandingError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _C.coral, size: 34),
            const SizedBox(height: 14),
            const Text(
              '강의 목록을 불러오지 못했습니다',
              style: TextStyle(
                color: _C.textPri,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '서버 연결을 다시 확인한 뒤 재시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textSec, height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.lime,
                foregroundColor: _C.limeDark,
              ),
              child: const Text('다시 불러오기'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 강의 카드 ─────────────────────────────────────────────────────
class _CourseCard extends StatefulWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _hovered = false;

  // 강의별 그라데이션 플레이스홀더 색상
  static const _gradients = [
    [Color(0xFF1A2400), Color(0xFF2A3800)],
    [Color(0xFF1E1830), Color(0xFF2D1B69)],
    [Color(0xFF3D0A14), Color(0xFF5A1020)],
  ];

  List<Color> _gradientColors(String id) {
    final idx = id.hashCode.abs() % _gradients.length;
    return _gradients[idx];
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final grad = _gradientColors(c.id);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered
                  ? _C.lime.withValues(alpha: 0.4)
                  : _C.border,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: _C.lime.withValues(alpha: 0.06),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: c.thumbnail.isNotEmpty
                    ? Image.network(
                        c.thumbnail,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _ThumbnailPlaceholder(colors: grad, id: c.id),
                      )
                    : _ThumbnailPlaceholder(colors: grad, id: c.id),
              ),
              // 정보
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI 맞춤 배지
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _C.lavMid,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  _C.lavender.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'AI 맞춤 교안',
                          style: TextStyle(
                              color: _C.lavender,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (c.enrolled) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _C.limeDark,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _C.lime.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            '수강중',
                            style: TextStyle(
                              color: _C.lime,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // 제목
                      Text(
                        c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.textPri,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 강사
                      Row(children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 12, color: _C.textMute),
                        const SizedBox(width: 4),
                        Text(c.instructor,
                            style: const TextStyle(
                                color: _C.textMute, fontSize: 12)),
                      ]),
                      const Spacer(),
                      // 가격 + 화살표
                      Row(children: [
                        if (c.enrolled)
                          const Text(
                            '학습 이어가기',
                            style: TextStyle(
                              color: _C.lime,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          const Text(
                            '강의 자세히 보기',
                            style: TextStyle(
                              color: _C.lime,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 13, color: _C.textMute),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ── 썸네일 플레이스홀더 ───────────────────────────────────────────
class _ThumbnailPlaceholder extends StatelessWidget {
  final List<Color> colors;
  final String id;

  const _ThumbnailPlaceholder({required this.colors, required this.id});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: _C.lime.withValues(alpha: 0.6),
          size: 48,
        ),
      ),
    );
  }
}
