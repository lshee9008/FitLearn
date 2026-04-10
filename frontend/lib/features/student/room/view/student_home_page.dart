import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/providers/room_data_providers.dart';
import '../../../../shared/services/api_service.dart';

class _C {
  static const bg = Color(0xFF111111);
  static const surface = Color(0xFF18181C);
  static const surface2 = Color(0xFF202028);
  static const border = Color(0xFF2B2B35);
  static const lime = Color(0xFFC8F135);
  static const limeDark = Color(0xFF1A2E00);
  static const mint = Color(0xFF67E8B2);
  static const rose = Color(0xFFFF6B5B);
  static const gold = Color(0xFFFFD166);
  static const lavender = Color(0xFFC5B8F8);
  static const textPri = Color(0xFFF7F7FA);
  static const textSec = Color(0xFFB8BAC6);
  static const textMute = Color(0xFF707382);
}

const _kTags = ['전체', '온라인', '오프라인', '신청 가능', '승인 대기'];

class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<StudentHomePage> {
  String _activeTag = '전체';
  String _searchQuery = '';

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  void _goToDiagnosis() => context.push('/student/diagnosis');

  void _refreshHub(String userId) {
    ref.invalidate(studentServiceHubProvider(userId));
    ref.invalidate(studentHomeSummaryProvider(userId));
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
                room['synopsis'] as String? ?? room['description'] as String? ?? '',
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
      final needsQuiz = questions.isNotEmpty && (subjectLevel == null || subjectLevel.isEmpty);

      if (needsQuiz && mounted) {
        final completed = await context.push<bool>('/student/subject_quiz/$roomId');
        if (completed != true || !mounted) return;
        _refreshHub(userId);
      }
    } catch (_) {
      // 퀴즈가 아직 없으면 입장을 막지 않는다.
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
    final nextLectureId = room['next_lecture_id'] as String?;
    if (nextLectureId == null || nextLectureId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 입장 가능한 교안이 없습니다.')),
      );
      return;
    }

    await _goToLecture(
      {
        'lecture_id': nextLectureId,
        'title': room['next_lecture_title'] ?? room['subject'] ?? '강의',
      },
      userId,
      roomId: room['room_id'] as String,
      subjectLevel: subjectLevel,
    );
  }

  List<Map<String, dynamic>> _filterRooms(List<dynamic> rooms) {
    final items = rooms.cast<Map<String, dynamic>>();
    return items.where((room) {
      final subject = (room['subject'] as String? ?? '').toLowerCase();
      final synopsis = (room['synopsis'] as String? ?? '').toLowerCase();
      final professor = (room['professor_name'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesQuery = query.isEmpty ||
          subject.contains(query) ||
          synopsis.contains(query) ||
          professor.contains(query);

      final roomType = room['room_type'] as String? ?? 'offline';
      final status = room['application_status'] as String?;
      final matchesTag = switch (_activeTag) {
        '온라인' => roomType == 'online',
        '오프라인' => roomType == 'offline',
        '신청 가능' => status == null || status.isEmpty || status == 'rejected',
        '승인 대기' => status == 'pending',
        _ => true,
      };

      return matchesQuery && matchesTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);
    final hubAsync = ref.watch(currentStudentServiceHubProvider);

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
            user: user,
            hubAsync: hubAsync,
            onDiagnosis: _goToDiagnosis,
            onJoinByCode: user == null ? null : () => _joinByCode(user.userId),
          ),
        ],
      ),
    );
  }

  Widget _buildMain(UserProfile? user, AsyncValue<StudentServiceHub?> hubAsync) {
    final hub = hubAsync.valueOrNull;
    final activeRoom = hub?.activeRoom;
    final enrolledRooms = hub?.enrolledRooms ?? const <dynamic>[];
    final discoverRooms = _filterRooms(hub?.discoverRooms ?? const <dynamic>[]);
    final applications = hub?.applications ?? const <dynamic>[];
    final activeRoomLectures = hub?.activeRoomLectures ?? const <dynamic>[];

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
                  onSearchChanged: (value) => setState(() => _searchQuery = value),
                  onJoinByCode: user == null ? null : () => _joinByCode(user.userId),
                ),
                const SizedBox(height: 20),
                _WelcomeBanner(
                  name: user?.name ?? '',
                  enrolledCount: enrolledRooms.length,
                  pendingCount: applications.where((item) {
                    return (item as Map<String, dynamic>)['status'] == 'pending';
                  }).length,
                ),
                const SizedBox(height: 18),
                _TagFilter(
                  tags: _kTags,
                  active: _activeTag,
                  onTap: (tag) => setState(() => _activeTag = tag),
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: '내 강의실',
                  sub: enrolledRooms.isEmpty ? '수강 중인 강의가 없습니다' : '${enrolledRooms.length}개 수강 중',
                ),
                const SizedBox(height: 12),
                if (hubAsync.isLoading)
                  const _LoadingPanel()
                else if (enrolledRooms.isEmpty)
                  _EmptyStateCard(
                    title: '아직 수강 중인 강의실이 없습니다',
                    description: '아래 강의 탐색에서 수강 신청을 하거나 초대 코드로 바로 입장해보세요.',
                    actionLabel: '초대 코드로 입장',
                    onAction: user == null ? null : () => _joinByCode(user.userId),
                  )
                else
                  SizedBox(
                    height: 228,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: enrolledRooms.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, index) {
                        final room = enrolledRooms[index] as Map<String, dynamic>;
                        return _EnrolledRoomCard(
                          room: room,
                          highlighted: activeRoom?['room_id'] == room['room_id'],
                          onEnter: user == null
                              ? null
                              : () => _enterRoom(
                                    room,
                                    user.userId,
                                    subjectLevel: room['subject_level'] as String?,
                                  ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: '신청 진행 상황',
                  sub: applications.isEmpty ? '진행 중인 신청 없음' : '${applications.length}건 확인',
                ),
                const SizedBox(height: 12),
                if (applications.isEmpty)
                  const _InlineHintCard(
                    title: '신청 내역이 비어 있습니다',
                    body: '승인 대기, 반려, 승인 완료 상태가 이곳에 정리됩니다.',
                  )
                else
                  Column(
                    children: applications
                        .cast<Map<String, dynamic>>()
                        .map((application) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ApplicationStatusCard(application: application),
                            ))
                        .toList(),
                  ),
                if (activeRoom != null) ...[
                  const SizedBox(height: 28),
                  _SubjectLevelBanner(
                    roomName: activeRoom['subject'] as String? ?? '강의실',
                    subjectLevel: hub?.activeSubjectLevel,
                    score: hub?.activeSubjectScore,
                    onAction: () async {
                      final completed = await context.push<bool>(
                        '/student/subject_quiz/${activeRoom['room_id']}',
                      );
                      if (completed == true && user != null) {
                        _refreshHub(user.userId);
                      }
                    },
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
                                            roomId: activeRoom['room_id'] as String,
                                            subjectLevel: hub?.activeSubjectLevel,
                                          ),
                                ),
                              ))
                          .toList(),
                    ),
                ],
                const SizedBox(height: 28),
                _SectionTitle(
                  title: '강의 탐색',
                  sub: discoverRooms.isEmpty ? '조건에 맞는 강의가 없습니다' : '${discoverRooms.length}개 강의실',
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (discoverRooms.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            sliver: SliverToBoxAdapter(
              child: _InlineHintCard(
                title: '새로 탐색할 강의가 없습니다',
                body: '검색 조건을 바꾸거나 교수님이 새 강의를 열 때까지 기다려주세요.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, index) {
                  final room = discoverRooms[index];
                  return _DiscoverRoomCard(
                    room: room,
                    onApply: user == null ? null : () => _applyToRoom(room, user.userId),
                  );
                },
                childCount: discoverRooms.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
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
    ('내 강의실', Icons.meeting_room_outlined),
    ('학습 성향', Icons.tune_rounded),
    ('학습 지원', Icons.forum_outlined),
    ('설정', Icons.settings_outlined),
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
                  decoration: BoxDecoration(
                    color: _C.lime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_mosaic_rounded, color: _C.bg),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FitLearn',
                      style: TextStyle(
                        color: _C.textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
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
                    if (index == 3) widget.onDiagnosis();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? _C.limeDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? _C.lime.withValues(alpha: 0.2) : Colors.transparent,
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
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
            leading: const Icon(Icons.logout_rounded, color: _C.rose, size: 18),
            title: const Text('로그아웃', style: TextStyle(color: _C.rose, fontSize: 13)),
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
        OutlinedButton.icon(
          onPressed: onJoinByCode,
          icon: const Icon(Icons.key_rounded),
          label: const Text('초대 코드'),
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
              style: const TextStyle(color: _C.textPri, fontWeight: FontWeight.w700),
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
  final int pendingCount;

  const _WelcomeBanner({
    required this.name,
    required this.enrolledCount,
    required this.pendingCount,
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
                  '강의 탐색부터 신청, 승인, 강의실 입장까지 한 화면에서 이어지도록 정리했습니다.',
                  style: TextStyle(color: Color(0xFF314200), height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MetricPill(label: '수강 중', value: '$enrolledCount개'),
                    const SizedBox(width: 10),
                    _MetricPill(label: '승인 대기', value: '$pendingCount건'),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.school_rounded, color: _C.limeDark, size: 34),
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
          Text(label, style: const TextStyle(color: Color(0xFF314200), fontSize: 12)),
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
    final lectureCount = room['lecture_count'] as int? ?? 0;
    final confirmedCount = room['confirmed_lecture_count'] as int? ?? 0;
    final progress = lectureCount == 0 ? 0.0 : confirmedCount / lectureCount;
    final roomType = room['room_type'] as String? ?? 'offline';
    final accent = roomType == 'online' ? _C.lime : _C.lavender;

    return Container(
      width: 308,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlighted ? _C.surface2 : _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlighted ? accent.withValues(alpha: 0.4) : _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TinyChip(
                label: roomType == 'online' ? '온라인' : '오프라인',
                color: accent,
              ),
              const Spacer(),
              Text(
                room['room_code'] as String? ?? '',
                style: const TextStyle(
                  color: _C.textMute,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
            (room['synopsis'] as String? ?? room['description'] as String? ?? '강의 설명이 아직 등록되지 않았습니다.'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.textSec, height: 1.45),
          ),
          const Spacer(),
          Row(
            children: [
              _InfoText(icon: Icons.groups_2_outlined, text: '${room['student_count'] ?? 0}명'),
              const SizedBox(width: 12),
              _InfoText(icon: Icons.menu_book_rounded, text: '$confirmedCount / $lectureCount'),
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
                confirmedCount > 0 ? '강의실 입장' : '오픈 대기',
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
      'rejected' => _C.rose,
      _ => _C.gold,
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
                    ? _C.gold
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
            (room['synopsis'] as String? ?? room['description'] as String? ?? '강의 소개가 곧 등록됩니다.'),
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
              icon: Icon(status == 'pending' ? Icons.hourglass_top_rounded : Icons.send_rounded),
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
        return _C.gold;
      case 'beginner':
        return _C.rose;
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
            icon: Icon(diagnosed ? Icons.refresh_rounded : Icons.play_arrow_rounded),
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
                confirmed ? Icons.menu_book_rounded : Icons.lock_outline_rounded,
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

class _RightPanel extends StatelessWidget {
  final UserProfile? user;
  final AsyncValue<StudentServiceHub?> hubAsync;
  final VoidCallback onDiagnosis;
  final VoidCallback? onJoinByCode;

  const _RightPanel({
    required this.user,
    required this.hubAsync,
    required this.onDiagnosis,
    required this.onJoinByCode,
  });

  @override
  Widget build(BuildContext context) {
    final hub = hubAsync.valueOrNull;
    final enrolledCount = hub?.enrolledRooms.length ?? 0;
    final discoverCount = hub?.discoverRooms.length ?? 0;
    final pendingCount = hub?.applications.where((item) {
          return (item as Map<String, dynamic>)['status'] == 'pending';
        }).length ??
        0;

    return Container(
      width: 318,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(left: BorderSide(color: _C.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '학습 운영 패널',
            style: TextStyle(
              color: _C.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${user?.name ?? '학생'}님의 강의 흐름과 진단 상태를 요약해 보여줍니다.',
            style: const TextStyle(color: _C.textMute, height: 1.45),
          ),
          const SizedBox(height: 16),
          _StatCard(title: '수강 중', value: '$enrolledCount', color: _C.lime),
          const SizedBox(height: 10),
          _StatCard(title: '탐색 가능', value: '$discoverCount', color: _C.lavender),
          const SizedBox(height: 10),
          _StatCard(title: '승인 대기', value: '$pendingCount', color: _C.gold),
          const SizedBox(height: 20),
          _ActionCard(
            title: '학습 성향 다시 보기',
            body: 'VARK, 집중 패턴, 난이도 대응, 이탈 위험 인자를 다시 확인합니다.',
            icon: Icons.psychology_alt_rounded,
            color: _C.mint,
            onTap: onDiagnosis,
          ),
          const SizedBox(height: 10),
          _ActionCard(
            title: '초대 코드로 빠른 입장',
            body: '교수님이 전달한 코드가 있다면 승인 절차 없이 바로 강의실에 연결합니다.',
            icon: Icons.key_rounded,
            color: _C.lime,
            onTap: onJoinByCode,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '서비스 흐름',
                  style: TextStyle(
                    color: _C.textPri,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                _TimelineRow(
                  icon: Icons.travel_explore_rounded,
                  title: '1. 강의 탐색',
                  body: '줄거리와 수업 형태를 보고 나에게 맞는 강의를 찾습니다.',
                ),
                _TimelineRow(
                  icon: Icons.send_rounded,
                  title: '2. 수강 신청',
                  body: '필요하면 메모를 남기고 교수 승인 절차를 기다립니다.',
                ),
                _TimelineRow(
                  icon: Icons.meeting_room_outlined,
                  title: '3. 강의실 입장',
                  body: '승인 후 강의실에 들어가 과목 수준 퀴즈와 교안을 진행합니다.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_graph_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _C.textMute, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _C.textPri,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: _C.textPri, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: _C.textSec, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: _C.textSec),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _C.textPri, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: _C.textMute, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoText({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _C.textMute),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: _C.textMute, fontSize: 12)),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _C.lime),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onAction;

  const _EmptyStateCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.explore_outlined, color: _C.lavender, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _C.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: _C.textSec, height: 1.5)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.lime,
              foregroundColor: _C.bg,
            ),
            icon: const Icon(Icons.key_rounded),
            label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _InlineHintCard extends StatelessWidget {
  final String title;
  final String body;

  const _InlineHintCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: _C.textPri, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: _C.textSec, height: 1.45)),
        ],
      ),
    );
  }
}
