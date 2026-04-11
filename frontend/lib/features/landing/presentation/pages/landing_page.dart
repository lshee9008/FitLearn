import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/provider/auth_provider.dart';

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

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.instructor,
    required this.price,
    required this.roomId,
  });

  factory CourseModel.fromFirestore(String id, Map<String, dynamic> data) {
    return CourseModel(
      id: id,
      title: (data['title'] as String?) ?? (data['subject'] as String?) ?? '',
      description:
          (data['description'] as String?) ?? (data['synopsis'] as String?) ?? '',
      thumbnail: data['thumbnail'] as String? ?? '',
      instructor: (data['instructor'] as String?) ??
          (data['professor_name'] as String?) ??
          '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      roomId: data['roomId'] as String? ?? '',
    );
  }
}

// ── 더미 데이터 ───────────────────────────────────────────────────
const _kDummyCourses = [
  CourseModel(
    id: 'dummy-1',
    title: '파이썬 기초부터 실전까지',
    description: '변수·함수·자료구조부터 파일 처리, 미니 프로젝트까지. AI가 내 학습 성향에 맞게 교안을 재해석해드립니다.',
    thumbnail: '',
    instructor: '김데이터',
    price: 99000,
    roomId: '',
  ),
  CourseModel(
    id: 'dummy-2',
    title: 'React + Next.js 완성 과정',
    description: 'React 훅부터 Next.js 14 App Router, 배포까지 한 번에. 예시 중심형·요약형·상세형 중 내 스타일로 배웁니다.',
    thumbnail: '',
    instructor: '이개발',
    price: 129000,
    roomId: '',
  ),
  CourseModel(
    id: 'dummy-3',
    title: 'AI 프롬프트 엔지니어링',
    description: 'ChatGPT·Claude·Gemini를 업무에 바로 적용하는 실전 강의. 나만의 프롬프트 전략을 AI 진단으로 최적화합니다.',
    thumbnail: '',
    instructor: '박AI',
    price: 79000,
    roomId: '',
  ),
];

// ── 카테고리 탭 ───────────────────────────────────────────────────
const _kCategories = ['전체', '온라인', '오프라인'];

// ══════════════════════════════════════════════════════════════════
// LandingPage
// ══════════════════════════════════════════════════════════════════
class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  String _activeCategory = '전체';
  String _searchQuery = '';

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
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _Header(
            user: user,
            onSearch: (v) => setState(() => _searchQuery = v),
            onLogin: () async {
              if (user == null) {
                context.push('/auth');
                return;
              }
              await ref.read(authNotifierProvider.notifier).logout();
              if (mounted) context.go('/');
            },
          ),
          const Divider(color: _C.border, height: 1),
          _CategoryBar(
            categories: _kCategories,
            active: _activeCategory,
            onTap: (c) => setState(() => _activeCategory = c),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _C.lime, strokeWidth: 2),
                  );
                }
                final liveCourses = snapshot.data?.docs
                        .map((d) => CourseModel.fromFirestore(d.id, d.data()))
                        .toList() ??
                    const <CourseModel>[];
                final courses = liveCourses.isEmpty ? _kDummyCourses : liveCourses;
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
  final ValueChanged<String> onSearch;
  final VoidCallback onLogin;

  const _Header({
    required this.user,
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
          RichText(
            text: const TextSpan(
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5),
              children: [
                TextSpan(
                    text: 'Fit',
                    style: TextStyle(color: _C.textPri)),
                TextSpan(
                    text: 'Learn',
                    style: TextStyle(color: _C.lime)),
                TextSpan(
                    text: '.',
                    style: TextStyle(color: _C.lime)),
              ],
            ),
          ),
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

// ── 카테고리 바 ───────────────────────────────────────────────────
class _CategoryBar extends StatelessWidget {
  final List<String> categories;
  final String active;
  final ValueChanged<String> onTap;

  const _CategoryBar(
      {required this.categories, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: categories.map((c) {
          final selected = c == active;
          return GestureDetector(
            onTap: () => onTap(c),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? _C.lime : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: selected ? _C.lime : _C.border),
              ),
              child: Text(
                c,
                style: TextStyle(
                  color: selected ? _C.limeDark : _C.textSec,
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
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
                        Text(
                          '₩${_formatPrice(c.price)}',
                          style: const TextStyle(
                            color: _C.lime,
                            fontSize: 17,
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

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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
