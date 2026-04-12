import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/providers/room_data_providers.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/widgets/fitlearn_logo.dart';
import 'subject_quiz_page.dart';

class _C {
  static const bg = Color(0xFF0E0E11);
  static const surface = Color(0xFF13131A);
  static const surface2 = Color(0xFF1A1A24);
  static const border = Color(0xFF1E1E2A);
  static const lime = Color(0xFFC8F135);
  static const limeDark = Color(0xFF1A2400);
  static const mint = Color(0xFF34D399);
  static const coral = Color(0xFFFB7185);
  static const coralDark = Color(0xFF3D0A14);
  static const amber = Color(0xFFFBBF24);
  static const lavender = Color(0xFFA78BFA);
  static const lavMid = Color(0xFF1E1830);
  static const textPri = Color(0xFFF0F0F4);
  static const textSec = Color(0xFF8888A0);
  static const textMute = Color(0xFF4A4A5A);
}

class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<StudentHomePage> {
  String _searchQuery = '';
  bool _refreshingHub = false;
  DateTime? _lastHubRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(authNotifierProvider);
      if (profile != null) _refreshHub(profile.userId);
    });
    Future.delayed(const Duration(milliseconds: 600), _checkDiagnosis);
  }

  void _refreshHubSoon(String? userId) {
    if (userId == null || userId.isEmpty) return;
    final now = DateTime.now();
    if (_lastHubRefreshAt != null &&
        now.difference(_lastHubRefreshAt!) < const Duration(seconds: 2)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshHub(userId);
    });
  }

  Future<void> _checkDiagnosis() async {
    if (!mounted) return;
    final profile = ref.read(authNotifierProvider);
    if (profile == null) return;
    if (profile.diagnosis) return;

    // Firestore에서 diagnosis 상태 재확인
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.userId)
          .get();
      final diagnosed = doc.data()?['diagnosis'] as bool? ?? false;
      if (diagnosed) {
        await ref.read(authNotifierProvider.notifier).updateDiagnosis();
        return;
      }
    } catch (_) {}

    if (mounted) _showDiagnosisPopup();
  }

  void _showDiagnosisPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: _C.surface,
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.lavMid,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Color(0xFFA78BFA), size: 22),
              ),
              const SizedBox(height: 12),
              const Text('학습 유형 진단',
                  style: TextStyle(
                      color: _C.textPri,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'AI가 맞는 학습 방식을 진단하고\n교안을 맞춤형으로 재가공합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.textSec, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.textSec,
                      side: const BorderSide(color: _C.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('나중에', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _goToDiagnosis();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA78BFA),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('지금 진단하기',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  void _goToDiagnosis() => context.push('/student/diagnosis');

  void _refreshHub(String userId) {
    if (_refreshingHub) return;
    _refreshingHub = true;
    _lastHubRefreshAt = DateTime.now();
    ref.invalidate(studentServiceHubProvider(userId));
    ref.invalidate(studentHomeSummaryProvider(userId));
    ref.invalidate(currentStudentServiceHubProvider);
    ref.invalidate(currentStudentHomeSummaryProvider);
    Future<void>(() async {
      try {
        await ref.read(currentStudentServiceHubProvider.future);
      } catch (_) {
      } finally {
        _refreshingHub = false;
      }
    });
  }

  Future<void> _joinByCode(String userId) async {
    final ctrl = TextEditingController();
    final joined = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        title: const Text('초대 코드로 입장', style: TextStyle(color: _C.textPri)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: _C.textPri),
          decoration: const InputDecoration(
            hintText: '예: A1B2C3',
            filled: true,
            fillColor: _C.surface2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('입장'),
          ),
        ],
      ),
    );

    if (joined != true) return;

    try {
      await ApiService().joinRoom(userId: userId, roomCode: ctrl.text.trim());
      _refreshHub(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강의실 입장이 완료되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('입장 오류: $e')),
      );
    }
  }

  Future<void> _applyToRoom(Map<String, dynamic> room, String userId) async {
    final noteCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        title: Text(
          '${room['subject'] ?? '강의'} 수강 신청',
          style: const TextStyle(color: _C.textPri),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room['synopsis'] as String? ??
                    room['description'] as String? ??
                    '',
                style: const TextStyle(color: _C.textSec, height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                maxLines: 4,
                style: const TextStyle(color: _C.textPri),
                decoration: const InputDecoration(
                  labelText: '교수님께 남길 메모',
                  hintText: '학습 목적이나 현재 수준을 간단히 남기면 승인에 도움이 됩니다.',
                  filled: true,
                  fillColor: _C.surface2,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('신청 보내기'),
          ),
        ],
      ),
    );

    if (submitted != true) return;

    try {
      await ApiService().applyToRoom(
        roomId: room['room_id'] as String,
        userId: userId,
        note: noteCtrl.text.trim(),
      );
      _refreshHub(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수강 신청이 접수되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청 오류: $e')),
      );
    }
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
      final needsQuiz = questions.isNotEmpty &&
          (subjectLevel == null || subjectLevel.isEmpty);

      if (needsQuiz && mounted) {
        final completed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 520,
                height: 680,
                child: SubjectQuizPage(roomId: roomId),
              ),
            ),
          ),
        );
        if (completed != true || !mounted) return;
        _refreshHub(userId);
      }
    } catch (_) {
      // 퀴즈가 아직 없으면 입장을 막지 않는다.
    }

    try {
      await ApiService().markLectureProgress(
        roomId: roomId,
        lectureId: lecture['lecture_id'] as String,
        userId: userId,
      );
      _refreshHub(userId);
    } catch (_) {
      // 진행률 저장이 늦어져도 학습 화면 진입은 막지 않는다.
    }

    if (!mounted) return;
    context.push('/student/lecture', extra: {
      'room_id': roomId,
      'lecture_id': lecture['lecture_id'],
      'user_id': userId,
      'title': lecture['title'],
    });
  }

  Future<void> _enterRoom(
    Map<String, dynamic> room,
    String userId, {
    String? subjectLevel,
  }) async {
    final roomId = room['room_id'] as String;
    final lectures = (await ApiService().getRoomLectures(roomId))
        .cast<Map<String, dynamic>>()
        .where((lecture) => lecture['confirmed'] == true)
        .toList();
    if (!mounted) return;
    if (lectures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 입장 가능한 교안이 없습니다.')),
      );
      return;
    }

    final completedCount = room['completed_lecture_count'] as int? ?? 0;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _LecturePickerDialog(
        roomTitle: room['subject'] as String? ?? '강의',
        lectures: lectures,
        completedCount: completedCount,
      ),
    );
    if (selected == null) return;

    await _goToLecture(selected, userId,
        roomId: roomId, subjectLevel: subjectLevel);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);
    final hubAsync = ref.watch(currentStudentServiceHubProvider);
    _refreshHubSoon(user?.userId);

    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        children: [
          _Sidebar(onLogout: _logout, onDiagnosis: _goToDiagnosis),
          Expanded(
            child: _buildMain(
              user,
              hubAsync,
            ),
          ),
          _RightPanel(
            hub: hubAsync.valueOrNull,
            user: user,
            onDiagnosis: _goToDiagnosis,
          ),
        ],
      ),
    );
  }

  Widget _buildMain(
      UserProfile? user, AsyncValue<StudentServiceHub?> hubAsync) {
    final hub = hubAsync.valueOrNull;
    final activeRoom = hub?.activeRoom;
    final enrolledRooms = hub?.enrolledRooms ?? const <dynamic>[];
    final activeRoomLectures = hub?.activeRoomLectures ?? const <dynamic>[];
    final activeRoomNotices = hub?.activeRoomNotices ?? const <dynamic>[];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(
                  user: user,
                  onSearchChanged: (value) =>
                      setState(() => _searchQuery = value),
                  onJoinByCode: null,
                ),
                const SizedBox(height: 20),
                _WelcomeBanner(
                  name: user?.name ?? '',
                  enrolledCount: enrolledRooms.length,
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: '내 강의실',
                  sub: enrolledRooms.isEmpty
                      ? '수강 중인 강의가 없습니다'
                      : '${enrolledRooms.length}개 수강 중',
                ),
                const SizedBox(height: 12),
                if (hubAsync.isLoading)
                  const _LoadingPanel()
                else if (enrolledRooms.isEmpty)
                  _EmptyStateCard(
                    title: '아직 수강 중인 강의실이 없습니다',
                    description: '첫 화면에서 원하는 강의를 결제하면 이곳에 학습 공간이 열립니다.',
                    actionLabel: '강의 둘러보기',
                    onAction: () => context.go('/'),
                  )
                else
                  SizedBox(
                    height: 228,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: enrolledRooms.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, index) {
                        final room =
                            enrolledRooms[index] as Map<String, dynamic>;
                        return _EnrolledRoomCard(
                          room: room,
                          highlighted:
                              activeRoom?['room_id'] == room['room_id'],
                          onEnter: user == null
                              ? null
                              : () => _enterRoom(
                                    room,
                                    user.userId,
                                    subjectLevel:
                                        room['subject_level'] as String?,
                                  ),
                        );
                      },
                    ),
                  ),
                if (activeRoom != null) ...[
                  const SizedBox(height: 28),
                  _SubjectLevelBanner(
                    roomName: activeRoom['subject'] as String? ?? '강의실',
                    subjectLevel: hub?.activeSubjectLevel,
                    score: hub?.activeSubjectScore,
                    onAction: () async {
                      final completed = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: SizedBox(
                              width: 520,
                              height: 680,
                              child: SubjectQuizPage(
                                roomId: activeRoom['room_id'] as String,
                              ),
                            ),
                          ),
                        ),
                      );
                      if (completed == true && user != null) {
                        _refreshHub(user.userId);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: '강의실 공지',
                    sub: activeRoomNotices.isEmpty
                        ? '새 공지 없음'
                        : '${activeRoomNotices.length}개',
                  ),
                  const SizedBox(height: 12),
                  if (activeRoomNotices.isEmpty)
                    const _InlineHintCard(
                      title: '아직 공지가 없습니다',
                      body: '교수님이 등록한 공지와 운영 안내가 이곳에 표시됩니다.',
                    )
                  else
                    Column(
                      children: activeRoomNotices
                          .cast<Map<String, dynamic>>()
                          .take(3)
                          .map((notice) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _NoticeCard(notice: notice),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: '바로 입장 가능한 교안',
                    sub: '${activeRoomLectures.length}개',
                  ),
                  const SizedBox(height: 12),
                  if (activeRoomLectures.isEmpty)
                    const _InlineHintCard(
                      title: '아직 공개된 교안이 없습니다',
                      body: '교수 검토가 끝난 교안부터 학생 강의실에 순차적으로 열립니다.',
                    )
                  else
                    Column(
                      children: activeRoomLectures
                          .cast<Map<String, dynamic>>()
                          .map((lecture) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _LectureCard(
                                  lecture: lecture,
                                  onTap: user == null
                                      ? null
                                      : () => _goToLecture(
                                            lecture,
                                            user.userId,
                                            roomId:
                                                activeRoom['room_id'] as String,
                                            subjectLevel:
                                                hub?.activeSubjectLevel,
                                          ),
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 36)),
      ],
    );
  }
}

class _Sidebar extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onDiagnosis;

  const _Sidebar({
    required this.onLogout,
    required this.onDiagnosis,
  });

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  int _selected = 0;

  static const _items = [
    ('홈', Icons.grid_view_rounded),
    ('강의 탐색', Icons.travel_explore_rounded),
    ('학습 성향', Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 208,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(right: BorderSide(color: _C.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: const FitLearnLogo(iconOnly: true, height: 36),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FitLearnLogo(height: 21),
                    const SizedBox(height: 3),
                    const Text(
                      '학생 학습 포털',
                      style: TextStyle(color: _C.textMute, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: _C.border, height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final active = _selected == index;
                return InkWell(
                  onTap: () {
                    setState(() => _selected = index);
                    if (index == 1) context.go('/');
                    if (index == 2) widget.onDiagnosis();
                  },
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? _C.limeDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? _C.lime.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _items[index].$2,
                          size: 17,
                          color: active ? _C.lime : _C.textSec,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _items[index].$1,
                          style: TextStyle(
                            color: active ? _C.lime : _C.textSec,
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: _C.border, height: 1),
          ListTile(
            onTap: widget.onLogout,
            leading:
                const Icon(Icons.logout_rounded, color: _C.coral, size: 18),
            title: const Text('로그아웃',
                style: TextStyle(color: _C.coral, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final UserProfile? user;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onJoinByCode;

  const _TopBar({
    required this.user,
    required this.onSearchChanged,
    required this.onJoinByCode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: _C.textPri),
            decoration: InputDecoration(
              hintText: '강의명, 줄거리, 교수명으로 탐색',
              hintStyle: const TextStyle(color: _C.textMute),
              prefixIcon: const Icon(Icons.search_rounded, color: _C.textMute),
              filled: true,
              fillColor: _C.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _C.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.surface,
            border: Border.all(color: _C.border),
          ),
          child: Center(
            child: Text(
              (user?.name ?? '?').substring(0, 1),
              style: const TextStyle(
                  color: _C.textPri, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String name;
  final int enrolledCount;

  const _WelcomeBanner({
    required this.name,
    required this.enrolledCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC8F135), Color(0xFF9ED919)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name님의 학습 대시보드',
                  style: const TextStyle(
                    color: _C.limeDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '결제한 강의와 학습 진행률을 한 화면에서 이어지도록 정리했습니다.',
                  style: TextStyle(color: Color(0xFF314200), height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MetricPill(label: '수강 중', value: '$enrolledCount개'),
                  ],
                ),
              ],
            ),
          ),
          FitLearnMarkBox(
            size: 78,
            backgroundColor: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF314200), fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: _C.limeDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFilter extends StatelessWidget {
  final List<String> tags;
  final String active;
  final ValueChanged<String> onTap;

  const _TagFilter({
    required this.tags,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = tags[index] == active;
          return InkWell(
            onTap: () => onTap(tags[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _C.lime : _C.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? _C.lime : _C.border),
              ),
              child: Text(
                tags[index],
                style: TextStyle(
                  color: selected ? _C.limeDark : _C.textSec,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? sub;

  const _SectionTitle({
    required this.title,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _C.textPri,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(width: 10),
          Text(sub!, style: const TextStyle(color: _C.textMute, fontSize: 12)),
        ],
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: _C.border)),
      ],
    );
  }
}

class _LecturePickerDialog extends StatelessWidget {
  final String roomTitle;
  final List<Map<String, dynamic>> lectures;
  final int completedCount;

  const _LecturePickerDialog({
    required this.roomTitle,
    required this.lectures,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomTitle,
              style: const TextStyle(
                color: _C.textPri,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '학습할 강의를 선택하세요. 이미 본 강의는 초록색으로 표시됩니다.',
              style: TextStyle(color: _C.textSec, height: 1.5),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lectures.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final lecture = lectures[index];
                  final order = lecture['order_index'] as int? ?? index + 1;
                  final watched = order <= completedCount;
                  return InkWell(
                    onTap: () => Navigator.pop(context, lecture),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: watched ? _C.limeDark : _C.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: watched
                              ? _C.lime.withValues(alpha: 0.5)
                              : _C.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: watched ? _C.lime : _C.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '$order',
                                style: TextStyle(
                                  color: watched ? _C.bg : _C.textSec,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lecture['title'] as String? ?? '$order강',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _C.textPri,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            watched
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_ios_rounded,
                            color: watched ? _C.lime : _C.textMute,
                            size: watched ? 18 : 14,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrolledRoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final bool highlighted;
  final VoidCallback? onEnter;

  const _EnrolledRoomCard({
    required this.room,
    required this.highlighted,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final confirmedCount = room['confirmed_lecture_count'] as int? ?? 0;
    final completedCount = room['completed_lecture_count'] as int? ?? 0;
    final progress =
        confirmedCount == 0 ? 0.0 : completedCount / confirmedCount;
    const accent = _C.lime;

    return Container(
      width: 308,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlighted ? _C.surface2 : _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: highlighted ? accent.withValues(alpha: 0.4) : _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room['subject'] as String? ?? '강의실',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (room['synopsis'] as String? ??
                room['description'] as String? ??
                '강의 설명이 아직 등록되지 않았습니다.'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.textSec, height: 1.45),
          ),
          const Spacer(),
          Row(
            children: [
              _InfoText(
                  icon: Icons.groups_2_outlined,
                  text: '${room['student_count'] ?? 0}명'),
              const SizedBox(width: 12),
              _InfoText(
                  icon: Icons.menu_book_rounded,
                  text: '$completedCount / $confirmedCount'),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onEnter,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: _C.bg,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                confirmedCount > 0 ? '강의 목록 보기' : '오픈 대기',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationStatusCard extends StatelessWidget {
  final Map<String, dynamic> application;

  const _ApplicationStatusCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final status = application['status'] as String? ?? 'pending';
    final color = switch (status) {
      'approved' => _C.mint,
      'rejected' => _C.coral,
      _ => _C.amber,
    };
    final label = switch (status) {
      'approved' => '승인 완료',
      'rejected' => '반려됨',
      _ => '승인 대기',
    };
    final message = switch (status) {
      'approved' => '강의실 입장이 열렸습니다. 내 강의실 섹션에서 바로 입장할 수 있습니다.',
      'rejected' => '메모를 보완한 뒤 다시 신청할 수 있습니다.',
      _ => '교수 검토가 끝나면 자동으로 내 강의실에 연결됩니다.',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.fact_check_outlined, color: color),
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
                        application['room_subject'] as String? ?? '강의 신청',
                        style: const TextStyle(
                          color: _C.textPri,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _TinyChip(label: label, color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(color: _C.textSec, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Map<String, dynamic> notice;

  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    final title = (notice['title'] as String? ?? '').trim();
    final content = notice['content'] as String? ?? '';
    final createdAt = notice['created_at'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _C.lavender.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_outlined, color: _C.lavender),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '제목 없는 공지' : title,
                  style: const TextStyle(
                    color: _C.textPri,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.textSec, height: 1.45),
                ),
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    createdAt,
                    style: const TextStyle(color: _C.textMute, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverRoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback? onApply;

  const _DiscoverRoomCard({
    required this.room,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final roomType = room['room_type'] as String? ?? 'offline';
    final status = room['application_status'] as String?;
    final accent = roomType == 'online' ? _C.lime : _C.lavender;
    final statusLabel = switch (status) {
      'pending' => '승인 대기',
      'approved' => '입장 승인',
      'rejected' => '재신청 가능',
      _ => '신청 가능',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TinyChip(
                label: roomType == 'online' ? '온라인 강의' : '오프라인 강의',
                color: accent,
              ),
              const Spacer(),
              _TinyChip(
                label: statusLabel,
                color: status == 'pending'
                    ? _C.amber
                    : status == 'approved'
                        ? _C.mint
                        : accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            room['subject'] as String? ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (room['synopsis'] as String? ??
                room['description'] as String? ??
                '강의 소개가 곧 등록됩니다.'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.textSec, height: 1.45),
          ),
          const Spacer(),
          Row(
            children: [
              _InfoText(
                icon: Icons.person_outline_rounded,
                text: room['professor_name'] as String? ?? '교수 정보 없음',
              ),
              const SizedBox(width: 12),
              _InfoText(
                icon: Icons.groups_rounded,
                text: '${room['student_count'] ?? 0}명',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: status == 'pending' ? null : onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: _C.bg,
                disabledBackgroundColor: _C.surface2,
                disabledForegroundColor: _C.textMute,
              ),
              icon: Icon(status == 'pending'
                  ? Icons.hourglass_top_rounded
                  : Icons.send_rounded),
              label: Text(
                status == 'pending' ? '승인 대기 중' : '수강 신청',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
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

  String get label {
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

  Color get accent {
    switch (subjectLevel) {
      case 'advanced':
        return _C.mint;
      case 'intermediate':
        return _C.amber;
      case 'beginner':
        return _C.coral;
      default:
        return _C.lavender;
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
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              diagnosed ? Icons.auto_awesome_rounded : Icons.quiz_outlined,
              color: accent,
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
                        '$roomName 맞춤 교안 세팅',
                        style: const TextStyle(
                          color: _C.textPri,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _TinyChip(
                      label: diagnosed
                          ? '$label${score != null ? ' · $score점' : ''}'
                          : '과목 수준 진단 필요',
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  diagnosed
                      ? '이 결과를 바탕으로 교안 난이도, 설명 방식, 예시 밀도를 조절해 재해석합니다.'
                      : '수준 진단을 완료하면 이 과목에서 어느 정도 설명 깊이가 필요한지 반영할 수 있습니다.',
                  style: const TextStyle(color: _C.textSec, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: Icon(
                diagnosed ? Icons.refresh_rounded : Icons.play_arrow_rounded),
            label: Text(diagnosed ? '다시 진단' : '퀴즈 시작'),
          ),
        ],
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  final Map<String, dynamic> lecture;
  final VoidCallback? onTap;

  const _LectureCard({
    required this.lecture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final confirmed = lecture['confirmed'] as bool? ?? false;
    final hasVideo = (lecture['video_url'] as String? ?? '').trim().isNotEmpty;

    return InkWell(
      onTap: confirmed ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: confirmed ? _C.limeDark : _C.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                confirmed
                    ? Icons.menu_book_rounded
                    : Icons.lock_outline_rounded,
                color: confirmed ? _C.lime : _C.textMute,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecture['title'] as String? ?? '교안',
                    style: const TextStyle(
                      color: _C.textPri,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    confirmed
                        ? (hasVideo ? '교안 + 영상 학습 가능' : '맞춤 교안 학습 가능')
                        : '교수 검토 중',
                    style: TextStyle(
                      color: confirmed ? _C.lime : _C.textMute,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: confirmed ? _C.textSec : _C.textMute,
            ),
          ],
        ),
      ),
    );
  }
}

class _RightPanel extends StatefulWidget {
  final StudentServiceHub? hub;
  final UserProfile? user;
  final VoidCallback onDiagnosis;
  const _RightPanel({
    required this.hub,
    required this.user,
    required this.onDiagnosis,
  });

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  final List<(bool, String)> _todos = [
    (false, '오늘 강의 1개 이상 수강하기'),
    (false, '막힌 구간 질문 1개 남기기'),
    (false, '핵심 포인트 3줄로 복습하기'),
  ];

  void _toggle(int i) {
    setState(() => _todos[i] = (!_todos[i].$1, _todos[i].$2));
  }

  @override
  Widget build(BuildContext context) {
    final enrolledRooms =
        widget.hub?.enrolledRooms.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
    final diagnosed = widget.user?.diagnosis == true;
    final doneCount = _todos.where((todo) => todo.$1).length;
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
          _AiDiagCard(
            diagnosed: diagnosed,
            onDiagnosis: widget.onDiagnosis,
          ),
          const SizedBox(height: 16),
          const Text('수강 중인 강의',
              style: TextStyle(
                  color: _C.textPri,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (enrolledRooms.isEmpty)
            const _InlineHintCard(
              title: '수강 중인 강의 없음',
              body: '스플래시 화면에서 강의를 결제하면 이곳에 표시됩니다.',
            )
          else
            ...enrolledRooms.take(3).map((room) {
              final confirmed = room['confirmed_lecture_count'] as int? ?? 0;
              final completed = room['completed_lecture_count'] as int? ?? 0;
              final progress = confirmed == 0 ? 0.0 : completed / confirmed;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MyLectureRow(
                  title: room['subject'] as String? ?? '강의',
                  sub: '$completed / $confirmed강 수강',
                  progress: progress,
                  color: _C.lime,
                  colorBg: _C.limeDark,
                  label: '강의',
                ),
              );
            }),
          const Divider(color: _C.border, height: 24),
          Row(children: [
            const Text('오늘 할 일',
                style: TextStyle(
                    color: _C.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _C.limeDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$doneCount / $totalCount',
                  style: const TextStyle(
                    color: _C.lime,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ]),
          const SizedBox(height: 10),
          ...List.generate(_todos.length, (i) {
            final done = _todos[i].$1;
            final label = _todos[i].$2;
            return Padding(
              padding: EdgeInsets.only(bottom: i < _todos.length - 1 ? 8 : 0),
              child: InkWell(
                onTap: () => _toggle(i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: done ? _C.limeDark : _C.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: done ? _C.lime.withValues(alpha: 0.35) : _C.border,
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: done ? _C.lime : _C.textMute,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                            color: done ? _C.lime : _C.textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ]),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 학습 코치',
                    style: TextStyle(
                        color: _C.lime,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('오늘은 긴 요약보다 핵심 포인트 확인과 짧은 질문 정리가 학습 흐름을 유지하는 데 좋아요.',
                    style: TextStyle(
                        color: _C.textSec, fontSize: 11, height: 1.6)),
              ],
            ),
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
  final bool diagnosed;
  final VoidCallback onDiagnosis;
  const _AiDiagCard({
    required this.diagnosed,
    required this.onDiagnosis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.lavMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.lavMid),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: _C.lime, borderRadius: BorderRadius.circular(20)),
          child: Text(diagnosed ? 'AI 분석 완료' : '진단 필요',
              style: const TextStyle(
                  color: _C.limeDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        Text(diagnosed ? '나의 학습 성향' : '학습 성향 진단',
            style: TextStyle(
                color: _C.lavender, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (diagnosed) ...[
          _row('상태', pill: '맞춤 교안 준비됨'),
          _row('기준', val: 'VARK · 집중 · 난이도 · 이탈 위험'),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _C.bg, borderRadius: BorderRadius.circular(8)),
          child: const Text(
            '진단 결과는 교안 재해석, 영상 요약, 질문 답변의 설명 방식에 반영됩니다.',
            style: TextStyle(color: _C.textSec, fontSize: 11, height: 1.6),
          ),
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
            child: Center(
                child: Text(diagnosed ? '진단 다시하기' : '진단하러 가기',
                    style: const TextStyle(
                        color: _C.lavender,
                        fontSize: 11,
                        fontWeight: FontWeight.w600))),
          ),
        ),
      ]),
    );
  }

  Widget _row(String label, {String? pill, String? val}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
            width: 44,
            child: Text(label,
                style: const TextStyle(color: _C.textSec, fontSize: 11))),
        if (pill != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: _C.lavender, borderRadius: BorderRadius.circular(20)),
            child: Text(pill,
                style: const TextStyle(
                    color: _C.lavMid,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          )
        else
          Expanded(
            child: Text(
              val ?? '',
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                  color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
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
    required this.title,
    required this.sub,
    required this.label,
    required this.progress,
    required this.color,
    required this.colorBg,
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: colorBg, borderRadius: BorderRadius.circular(8)),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // 추가: 내부 높이에 딱 맞게 설정
            children: [
              // ── 수정 포인트 02: 제목 maxLines 변경 ──────────────────
              Text(
                title,
                maxLines: 2, // 두 줄 허용
                overflow: TextOverflow.ellipsis, // 세 줄부터 '...' 처리
                style: const TextStyle(
                  color: _C.textPri,
                  fontSize: 11, // 폰트 크기를 12 -> 11로 아주 살짝 줄이면 훨씬 안정적입니다
                  fontWeight: FontWeight.w600,
                  height: 1.2, // 줄 간격 추가
                ),
              ),
              const SizedBox(height: 2),

              // ── 수정 포인트 03: 서브텍스트 한 줄 유지 ────────────────
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _C.textSec, fontSize: 10),
              ),

              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: _C.border,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 로딩 패널
// ════════════════════════════════════════════════════════════════
class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 228,
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _C.lime, strokeWidth: 2),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 빈 상태 카드
// ════════════════════════════════════════════════════════════════
class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyStateCard({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _C.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(color: _C.textSec, height: 1.5)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.key_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 인라인 힌트 카드
// ════════════════════════════════════════════════════════════════
class _InlineHintCard extends StatelessWidget {
  final String title;
  final String body;

  const _InlineHintCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: _C.textSec, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(body,
            style:
                const TextStyle(color: _C.textMute, fontSize: 12, height: 1.5)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 작은 색상 칩
// ════════════════════════════════════════════════════════════════
class _TinyChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 아이콘 + 텍스트 정보 행
// ════════════════════════════════════════════════════════════════
class _InfoText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: _C.textMute),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: _C.textMute, fontSize: 12)),
    ]);
  }
}
