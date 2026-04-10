import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/providers/room_data_providers.dart';

// ─── 컬러 ───────────────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFF111111);
  static const surface    = Color(0xFF1A1A1A);
  static const surface2   = Color(0xFF222222);
  static const border     = Color(0xFF2A2A2A);
  static const lime       = Color(0xFFC8F135);
  static const limeDeep   = Color(0xFFA8D010);
  static const limeDark   = Color(0xFF1A2E00);
  static const salmon     = Color(0xFFFF6B5B);
  static const salmonDark = Color(0xFF3D0A04);
  static const lavender   = Color(0xFFC5B8F8);
  static const lavDark    = Color(0xFF26215C);
  static const yellow     = Color(0xFFFFE566);
  static const yellowDark = Color(0xFF412402);
  static const textPri    = Color(0xFFFFFFFF);
  static const textSec    = Color(0xFF888888);
  static const textMute   = Color(0xFF555555);
}

// ─── 데이터 모델 ─────────────────────────────────────────────────
class _CourseData {
  final String title, price, hours, students;
  final double rating;
  final Color bg, accent, textColor;
  const _CourseData({
    required this.title, required this.price,
    required this.hours, required this.students,
    required this.rating,
    required this.bg, required this.accent, required this.textColor,
  });
}

class _EnrolledCourse {
  final String title, part;
  final double progress;
  final Color bg, accent, textColor;
  const _EnrolledCourse({
    required this.title, required this.part, required this.progress,
    required this.bg, required this.accent, required this.textColor,
  });
}

const _kTags = ['전체', 'UX/UI', '영상편집', '마케팅', '코딩', 'Java'];

const _kEnrolled = [
  _EnrolledCourse(
    title: '영상편집 마스터클래스', part: '파트 3 / 8', progress: 0.37,
    bg: _C.lime, accent: _C.limeDeep, textColor: _C.limeDark,
  ),
  _EnrolledCourse(
    title: '포토샵 & 일러스트', part: '파트 1 / 6', progress: 0.16,
    bg: _C.salmon, accent: Color(0xFFE04030), textColor: _C.salmonDark,
  ),
  _EnrolledCourse(
    title: 'Figma 컴포넌트 완전정복', part: '파트 6 / 8', progress: 0.75,
    bg: _C.lavender, accent: Color(0xFFA090E0), textColor: _C.lavDark,
  ),
];

const _kRecommended = [
  _CourseData(
    title: 'After Effects 마스터', price: '220,000원', rating: 4.8,
    hours: '98시간', students: '6k명',
    bg: _C.yellow, accent: Color(0xFFE0C030), textColor: _C.yellowDark,
  ),
  _CourseData(
    title: '프리미어 프로 완성', price: '150,000원', rating: 4.6,
    hours: '62시간', students: '4k명',
    bg: _C.lavender, accent: Color(0xFFA090E0), textColor: _C.lavDark,
  ),
];

// ════════════════════════════════════════════════════════════════
// 메인 페이지
// ════════════════════════════════════════════════════════════════
class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<StudentHomePage> {
  String _activeTag = '전체';
  final Map<int, bool> _liked = {};

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  void _goToDiagnosis() => context.push('/student/diagnosis');

  void _goToEnrolledLecture(_EnrolledCourse course) {
    final user = ref.read(authNotifierProvider);
    context.push('/student/lecture', extra: {
      'room_id': 'mock_room',
      'lecture_id': 'mock_lecture',
      'user_id': user?.userId ?? '',
      'title': course.title,
    });
  }

  Future<void> _goToLecture(
    Map<String, dynamic> lecture,
    String userId, {
    required String roomId,
    required String? subjectLevel,
  }) async {
    if (userId.isEmpty) return;

    try {
      final quiz = await ApiService().getRoomQuiz(roomId);
      final questions = quiz['questions'] as List<dynamic>? ?? [];
      final needsQuiz = questions.isNotEmpty && (subjectLevel == null || subjectLevel.isEmpty);

      if (needsQuiz && mounted) {
        final completed = await context.push<bool>('/student/subject_quiz/$roomId');
        if (completed != true || !mounted) return;
        ref.invalidate(studentHomeSummaryProvider(userId));
      }
    } catch (_) {
      // 퀴즈 조회에 실패해도 교안 입장은 막지 않는다.
    }

    if (!mounted) return;
    context.push('/student/lecture', extra: {
      'room_id': roomId,
      'lecture_id': lecture['lecture_id'],
      'user_id': userId,
      'title': lecture['title'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);
    final summaryAsync = ref.watch(currentStudentHomeSummaryProvider);
    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        children: [
          _Sidebar(onLogout: _logout, onDiagnosis: _goToDiagnosis),
          Expanded(child: _buildMain(user, summaryAsync)),
          _RightPanel(onDiagnosis: _goToDiagnosis),
        ],
      ),
    );
  }

  Widget _buildMain(UserProfile? user, AsyncValue<StudentHomeSummary?> summaryAsync) {
    final summary = summaryAsync.valueOrNull;
    final room = summary?.room;
    final lectures = summary?.lectures ?? const [];
    final subjectLevel = summary?.subjectLevel;
    final subjectScore = summary?.subjectScore;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(user: user, onLogout: _logout),
                const SizedBox(height: 20),
                _WelcomeBanner(name: user?.name ?? ''),
                const SizedBox(height: 16),
                _TagFilter(
                  tags: _kTags, active: _activeTag,
                  onTap: (t) => setState(() => _activeTag = t),
                ),
                const SizedBox(height: 20),
                // 수강 중인 강의 (가로 스크롤 카드)
                const _SectionTitle(title: '수강 중인 강의'),
                const SizedBox(height: 12),
                _EnrolledCoursesSection(
                  courses: _kEnrolled,
                  onResume: _goToEnrolledLecture,
                ),
                const SizedBox(height: 24),
                if (room != null) ...[
                  _SubjectLevelBanner(
                    roomName: room['name'] as String? ?? '강의실',
                    subjectLevel: subjectLevel,
                    score: subjectScore,
                    onAction: () async {
                      final roomId = room['room_id'] as String;
                      final completed = await context.push<bool>('/student/subject_quiz/$roomId');
                      if (completed == true && user != null) {
                        ref.invalidate(studentHomeSummaryProvider(user.userId));
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                // 추천강의
                const _SectionTitle(title: '추천강의'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        _courseGrid(_kRecommended, 0),
        if (room != null && lectures.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(title: '교안 목록', sub: '${lectures.length}개'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LectureCard(
                    lecture: lectures[i] as Map<String, dynamic>,
                    onTap: () => _goToLecture(
                      lectures[i] as Map<String, dynamic>,
                      user?.userId ?? '',
                      roomId: room['room_id'] as String,
                      subjectLevel: subjectLevel,
                    ),
                  ),
                ),
                childCount: lectures.length,
              ),
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  SliverPadding _courseGrid(List<_CourseData> items, int keyOffset) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _CourseCard(
            data: items[i],
            liked: _liked[keyOffset + i] ?? false,
            onLike: () => setState(
              () => _liked[keyOffset + i] = !(_liked[keyOffset + i] ?? false),
            ),
          ),
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.65,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 수강 중인 강의 — 가로 스크롤 카드 + 하단 액션바
// ════════════════════════════════════════════════════════════════
class _EnrolledCoursesSection extends StatefulWidget {
  final List<_EnrolledCourse> courses;
  final void Function(_EnrolledCourse) onResume;
  const _EnrolledCoursesSection({required this.courses, required this.onResume});

  @override
  State<_EnrolledCoursesSection> createState() => _EnrolledCoursesSectionState();
}

class _EnrolledCoursesSectionState extends State<_EnrolledCoursesSection> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final course = widget.courses[_selected];
    return Column(children: [
      // ── 가로 스크롤 카드 리스트 ──
      SizedBox(
        height: 155,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: widget.courses.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _EnrolledCourseCard(
            course: widget.courses[i],
            selected: _selected == i,
            onTap: () => setState(() => _selected = i),
          ),
        ),
      ),
      const SizedBox(height: 8),
      // ── 하단 액션바 ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _C.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Row(children: [
          _HoverButton(
            label: '이어보기',
            icon: Icons.play_arrow_rounded,
            color: _C.lime,
            onTap: () => widget.onResume(course),
          ),
          const SizedBox(width: 10),
          _HoverButton(
            label: '질문 남기기',
            icon: Icons.chat_bubble_outline_rounded,
            color: _C.lavender,
            onTap: () {},
          ),
          const Spacer(),
          Text(course.part,
              style: const TextStyle(color: _C.textMute, fontSize: 12)),
          const SizedBox(width: 8),
          Text('${(course.progress * 100).toInt()}%',
              style: const TextStyle(
                  color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

class _EnrolledCourseCard extends StatefulWidget {
  final _EnrolledCourse course;
  final bool selected;
  final VoidCallback onTap;
  const _EnrolledCourseCard({
    required this.course, required this.selected, required this.onTap,
  });

  @override
  State<_EnrolledCourseCard> createState() => _EnrolledCourseCardState();
}

class _EnrolledCourseCardState extends State<_EnrolledCourseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final active = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 180,
          transform: Matrix4.translationValues(0, _hovered && !active ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: active || _hovered
                ? [BoxShadow(
                    color: c.bg.withValues(alpha: 0.45),
                    blurRadius: 20, offset: const Offset(0, 8),
                  )]
                : [],
          ),
          child: Stack(children: [
            // 배경 원형 액센트
            Positioned(right: -16, bottom: -16,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              )),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 선택 뱃지
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('현재 선택', style: TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700,
                    )),
                  ),
                Text(c.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textColor, fontSize: 13,
                    fontWeight: FontWeight.w700, height: 1.3,
                  )),
                const Spacer(),
                Text('${(c.progress * 100).toInt()}% 완료',
                  style: TextStyle(
                    color: c.textColor, fontSize: 12, fontWeight: FontWeight.w600,
                  )),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: c.progress, minHeight: 5,
                    backgroundColor: Colors.black.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation(c.accent),
                  ),
                ),
              ]),
            ),
            // 선택 체크마크
            if (active)
              Positioned(top: 10, right: 10,
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                )),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 호버 버튼
// ════════════════════════════════════════════════════════════════
class _HoverButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _HoverButton({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hovered ? widget.color : _C.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, color: widget.color, size: 14),
            const SizedBox(width: 6),
            Text(widget.label, style: TextStyle(
              color: widget.color, fontSize: 12, fontWeight: FontWeight.w600,
            )),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 사이드바
// ════════════════════════════════════════════════════════════════
class _Sidebar extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onDiagnosis;
  const _Sidebar({required this.onLogout, required this.onDiagnosis});

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  int _idx = 0;
  static const _items = [
    ('홈',      Icons.grid_view_rounded),
    ('강의 탐색', Icons.search_rounded),
    ('내 강의실', Icons.play_circle_outline_rounded),
    ('학습 성향', Icons.person_outline_rounded),
    ('Q&A',    Icons.chat_bubble_outline_rounded),
    ('설정',    Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(right: BorderSide(color: _C.border)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: _C.lime, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.grid_view, color: _C.bg, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FitLearn', style: TextStyle(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('수강생 포털', style: TextStyle(color: _C.textMute, fontSize: 10)),
            ]),
          ]),
        ),
        const Divider(color: _C.border, height: 1),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final active = _idx == i;
              return GestureDetector(
                onTap: () { setState(() => _idx = i); if (i == 3) widget.onDiagnosis(); },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? _C.limeDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(
                      color: active ? _C.lime : Colors.transparent, width: 3,
                    )),
                  ),
                  child: Row(children: [
                    Icon(_items[i].$2, size: 16, color: active ? _C.lime : _C.textSec),
                    const SizedBox(width: 10),
                    Text(_items[i].$1, style: TextStyle(
                      fontSize: 13,
                      color: active ? _C.lime : _C.textSec,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    )),
                    if (i == 4) ...[
                      const Spacer(),
                      Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(color: _C.salmon, shape: BoxShape.circle),
                        child: const Center(child: Text('2',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                      ),
                    ],
                  ]),
                ),
              );
            },
          ),
        ),
        const Divider(color: _C.border, height: 1),
        GestureDetector(
          onTap: widget.onLogout,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.logout_rounded, size: 16, color: _C.salmon),
              SizedBox(width: 8),
              Text('로그아웃', style: TextStyle(fontSize: 13, color: _C.salmon)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 상단바
// ════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final UserProfile? user;
  final VoidCallback onLogout;
  const _TopBar({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border),
          ),
          child: const Row(children: [
            SizedBox(width: 12),
            Icon(Icons.search, color: _C.textMute, size: 16),
            SizedBox(width: 8),
            Text('강의, 단과, 강사 검색...', style: TextStyle(color: _C.textMute, fontSize: 13)),
          ]),
        ),
      ),
      const SizedBox(width: 14),
      Stack(children: [
        const Icon(Icons.notifications_outlined, color: _C.textSec, size: 22),
        Positioned(right: 0, top: 0,
          child: Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: _C.lime, shape: BoxShape.circle))),
      ]),
      const SizedBox(width: 12),
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: _C.limeDark,
          border: Border.all(color: _C.lime, width: 1.5),
        ),
        child: Center(child: Text(
          (user?.name ?? '').isNotEmpty ? user!.name.substring(0, 1) : '?',
          style: const TextStyle(color: _C.lime, fontSize: 12, fontWeight: FontWeight.w700),
        )),
      ),
      const SizedBox(width: 8),
      Text(user?.name ?? '',
          style: const TextStyle(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// 웰컴 배너
// ════════════════════════════════════════════════════════════════
class _WelcomeBanner extends StatelessWidget {
  final String name;
  const _WelcomeBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(color: _C.lime, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('안녕하세요, $name님 👋',
              style: const TextStyle(color: _C.limeDark, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text.rich(TextSpan(
            style: TextStyle(color: Color(0xFF3A4A00), fontSize: 12),
            children: [
              TextSpan(text: '이번 주 학습 목표의 '),
              TextSpan(text: '70%', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: '를 달성했어요! 조금만 더 힘내세요.'),
            ],
          )),
          const SizedBox(height: 4),
          const Text('AI 분석: 예시 중심형 · 집중 30분 · 초급',
              style: TextStyle(color: Color(0xFF3A4A00), fontSize: 11)),
        ])),
        Container(
          width: 60, height: 60,
          decoration: const BoxDecoration(color: _C.limeDeep, shape: BoxShape.circle),
          child: const Icon(Icons.person, color: _C.bg, size: 30),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 태그 필터
// ════════════════════════════════════════════════════════════════
class _TagFilter extends StatelessWidget {
  final List<String> tags;
  final String active;
  final void Function(String) onTap;
  const _TagFilter({required this.tags, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isActive = active == tags[i];
          return GestureDetector(
            onTap: () => onTap(tags[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? _C.lime : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? _C.lime : _C.border),
              ),
              child: Text(tags[i], style: TextStyle(
                color: isActive ? _C.limeDark : _C.textSec,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              )),
            ),
          );
        },
      ),
    );
  }
}

class _SubjectLevelBanner extends StatelessWidget {
  final String roomName;
  final String? subjectLevel;
  final int? score;
  final VoidCallback onAction;

  const _SubjectLevelBanner({
    required this.roomName,
    required this.subjectLevel,
    required this.score,
    required this.onAction,
  });

  String get _label {
    switch (subjectLevel) {
      case 'advanced':
        return '고급';
      case 'intermediate':
        return '중급';
      case 'beginner':
        return '입문';
      default:
        return '미진단';
    }
  }

  Color get _accent {
    switch (subjectLevel) {
      case 'advanced':
        return _C.lime;
      case 'intermediate':
        return _C.yellow;
      case 'beginner':
        return _C.salmon;
      default:
        return _C.lavender;
    }
  }

  String get _message {
    switch (subjectLevel) {
      case 'advanced':
        return '심화 설명과 최적화 관점까지 반영된 교안을 우선 제공합니다.';
      case 'intermediate':
        return '핵심 개념과 응용 예시 중심으로 교안이 재해석됩니다.';
      case 'beginner':
        return '쉬운 용어, 단계별 설명, 따라하기 흐름 중심으로 교안이 재해석됩니다.';
      default:
        return '과목 수준 진단을 완료하면 이 강의에 맞는 난이도로 교안이 재해석됩니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagnosed = subjectLevel != null && subjectLevel!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              diagnosed ? Icons.auto_awesome_rounded : Icons.rule_folder_rounded,
              color: _accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$roomName 맞춤 교안 설정',
                        style: const TextStyle(
                          color: _C.textPri,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        diagnosed
                            ? '과목 수준 $_label${score != null ? ' · $score점' : ''}'
                            : '과목 수준 진단 필요',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _message,
                  style: const TextStyle(
                    color: _C.textSec,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HoverButton(
            label: diagnosed ? '다시 진단' : '퀴즈 시작',
            icon: diagnosed ? Icons.refresh_rounded : Icons.play_arrow_rounded,
            color: _accent,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 섹션 타이틀
// ════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? sub;
  const _SectionTitle({required this.title, this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
      if (sub != null) ...[
        const SizedBox(width: 8),
        Text(sub!, style: const TextStyle(color: _C.textSec, fontSize: 12)),
      ],
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: _C.border)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// 강의 카드 (추천강의용)
// ════════════════════════════════════════════════════════════════
class _CourseCard extends StatefulWidget {
  final _CourseData data;
  final bool liked;
  final VoidCallback onLike;
  const _CourseCard({required this.data, required this.liked, required this.onLike});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(color: widget.data.bg, borderRadius: BorderRadius.circular(14)),
          child: Stack(children: [
            Positioned(right: -16, bottom: -16,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(color: widget.data.accent, shape: BoxShape.circle),
              )),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(widget.data.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: widget.data.textColor, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3))),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onLike,
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(color: Color(0xFF111111), shape: BoxShape.circle),
                      child: Icon(widget.liked ? Icons.favorite : Icons.favorite_border,
                          color: widget.liked ? _C.salmon : Colors.white, size: 14),
                    ),
                  ),
                ]),
                const Spacer(),
                Text(widget.data.price,
                    style: TextStyle(color: widget.data.textColor, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  _Badge('★ ${widget.data.rating}'),
                  const SizedBox(width: 4),
                  _Badge(widget.data.hours),
                  const SizedBox(width: 4),
                  _Badge(widget.data.students),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 교안 카드 (방 입장 후)
// ════════════════════════════════════════════════════════════════
class _LectureCard extends StatelessWidget {
  final Map<String, dynamic> lecture;
  final VoidCallback onTap;
  const _LectureCard({required this.lecture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final confirmed = lecture['confirmed'] as bool? ?? false;
    return GestureDetector(
      onTap: confirmed ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: confirmed ? _C.limeDark : _C.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              confirmed ? Icons.menu_book_rounded : Icons.lock_outline_rounded,
              color: confirmed ? _C.lime : _C.textMute, size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lecture['title'] as String? ?? '교안',
                style: const TextStyle(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(confirmed ? '맞춤 교안 학습 가능' : '교수 검토 중',
                style: TextStyle(color: confirmed ? _C.lime : _C.textMute, fontSize: 12)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded,
              color: confirmed ? _C.textSec : _C.border, size: 14),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 오른쪽 패널
// ════════════════════════════════════════════════════════════════
class _RightPanel extends StatefulWidget {
  final VoidCallback onDiagnosis;
  const _RightPanel({required this.onDiagnosis});

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  static const _myLectures = [
    ('영상편집 마스터클래스', '파트 3 / 8', 0.37, _C.lime,     _C.limeDark,   '영상'),
    ('Figma 컴포넌트',       '파트 6 / 8', 0.75, _C.lavender, _C.lavDark,    'Fig'),
    ('포토샵 & 일러스트',    '파트 1 / 6', 0.16, _C.salmon,   _C.salmonDark, '포샵'),
  ];

  final List<(bool, String)> _todos = [
    (true,  '파트3 영상 보기'),
    (false, '파트3 질문지 제출'),
    (false, 'Figma 실습 30분'),
  ];

  void _toggle(int i) {
    setState(() => _todos[i] = (!_todos[i].$1, _todos[i].$2));
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _todos.where((t) => t.$1).length;
    final totalCount = _todos.length;

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(left: BorderSide(color: _C.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _AiDiagCard(onDiagnosis: widget.onDiagnosis),
          const SizedBox(height: 16),
          const Text('수강 중인 강의',
              style: TextStyle(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ..._myLectures.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MyLectureRow(
              title: e.$1, sub: e.$2, progress: e.$3,
              color: e.$4, colorBg: e.$5, label: e.$6,
            ),
          )),
          const Divider(color: _C.border, height: 24),
          // ── 오늘 할 일 헤더 ──
          Row(children: [
            const Text('오늘 할 일',
                style: TextStyle(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _C.limeDark, borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$doneCount / $totalCount', style: const TextStyle(
                color: _C.lime, fontSize: 10, fontWeight: FontWeight.w700,
              )),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: doneCount / totalCount,
              minHeight: 3,
              backgroundColor: _C.surface2,
              valueColor: const AlwaysStoppedAnimation(_C.lime),
            ),
          ),
          const SizedBox(height: 10),
          // ── 할 일 목록 ──
          ...List.generate(_todos.length, (i) {
            final done = _todos[i].$1;
            final label = _todos[i].$2;
            return Padding(
              padding: EdgeInsets.only(bottom: i < _todos.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => _toggle(i),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: done ? Colors.transparent : _C.salmon.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: done ? _C.lime.withValues(alpha: 0.35) : _C.salmon,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: done ? _C.lime : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: done ? _C.lime : _C.salmon,
                            width: 1.5,
                          ),
                        ),
                        child: done
                            ? const Icon(Icons.check_rounded, color: _C.bg, size: 11)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label, style: TextStyle(
                          color: done ? _C.textMute : _C.textPri,
                          fontSize: 11,
                          fontWeight: done ? FontWeight.w400 : FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: _C.textMute,
                          decorationThickness: 1.5,
                        )),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }),
          const Divider(color: _C.border, height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI 학습 코치',
                  style: TextStyle(color: _C.lime, fontSize: 11, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('파트 3 색보정 구간에서 막힌 것 같아요. 예시 중심형 보충 자료를 확인해보세요.',
                  style: TextStyle(color: _C.textSec, fontSize: 11, height: 1.6)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AI 진단 카드
// ════════════════════════════════════════════════════════════════
class _AiDiagCard extends StatelessWidget {
  final VoidCallback onDiagnosis;
  const _AiDiagCard({required this.onDiagnosis});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A6A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: _C.lime, borderRadius: BorderRadius.circular(20)),
          child: const Text('AI 분석 완료',
              style: TextStyle(color: _C.limeDark, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        const Text('나의 학습 성향',
            style: TextStyle(color: _C.lavender, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _row('스타일', pill: '예시 중심형'),
        _row('집중', val: '30분 단위'),
        _row('수준', val: '초급'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(8)),
          child: const Text.rich(TextSpan(
            style: TextStyle(color: _C.textSec, fontSize: 11, height: 1.6),
            children: [
              TextSpan(text: '평균 대비 '),
              TextSpan(text: '28% 빠른', style: TextStyle(color: _C.lime, fontWeight: FontWeight.w700)),
              TextSpan(text: ' 실력 향상 예상'),
            ],
          )),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onDiagnosis,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _C.lavender.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('진단 다시 하기',
                style: TextStyle(color: _C.lavender, fontSize: 11, fontWeight: FontWeight.w600))),
          ),
        ),
      ]),
    );
  }

  Widget _row(String label, {String? pill, String? val}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 44, child: Text(label, style: const TextStyle(color: _C.textSec, fontSize: 11))),
        if (pill != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _C.lavender, borderRadius: BorderRadius.circular(20)),
            child: Text(pill, style: const TextStyle(color: _C.lavDark, fontSize: 10, fontWeight: FontWeight.w600)),
          )
        else
          Text(val ?? '', style: const TextStyle(color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 수강 중 강의 행 (우측 패널)
// ════════════════════════════════════════════════════════════════
class _MyLectureRow extends StatelessWidget {
  final String title, sub, label;
  final double progress;
  final Color color, colorBg;
  const _MyLectureRow({
    required this.title, required this.sub, required this.label,
    required this.progress, required this.color, required this.colorBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: colorBg, borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(label,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: _C.textSec, fontSize: 10)),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress, minHeight: 3,
              backgroundColor: _C.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ])),
      ]),
    );
  }
}
