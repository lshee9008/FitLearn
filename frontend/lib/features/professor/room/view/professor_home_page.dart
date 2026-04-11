import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/providers/room_data_providers.dart';
import '../../../../shared/services/api_service.dart';

// ─── 컬러 ────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0E0E11);
  static const surface = Color(0xFF13131A);
  static const surface2 = Color(0xFF1A1A24);
  static const border = Color(0xFF1E1E2A);
  static const border2 = Color(0xFF252532);
  static const lime = Color(0xFFC8F135);
  static const limeDeep = Color(0xFFA8D010);
  static const limeDark = Color(0xFF1A2400);
  static const lavender = Color(0xFFA78BFA);
  static const lavDark = Color(0xFF2D1B69);
  static const lavMid = Color(0xFF1E1830);
  static const coral = Color(0xFFFB7185);
  static const coralDark = Color(0xFF3D0A14);
  static const amber = Color(0xFFFBBF24);
  static const amberDark = Color(0xFF3D2800);
  static const mint = Color(0xFF34D399);
  static const mintDark = Color(0xFF064E3B);
  static const blue = Color(0xFF60A5FA);
  static const blueDark = Color(0xFF1E3A5F);
  static const textPri = Color(0xFFF0F0F4);
  static const textSec = Color(0xFF8888A0);
  static const textMute = Color(0xFF4A4A5A);
}

// ── 강의 아이템 모델 ──────────────────────────────────────────
class LectureItem {
  String title;
  String videoUrl;
  String materialUrl;
  LectureItem({this.title = '', this.videoUrl = '', this.materialUrl = ''});
}

// ════════════════════════════════════════════════════════════
// 메인 페이지
// ════════════════════════════════════════════════════════════
class ProfessorHomePage extends ConsumerStatefulWidget {
  const ProfessorHomePage({super.key});

  @override
  ConsumerState<ProfessorHomePage> createState() => _ProfessorHomePageState();
}

class _ProfessorHomePageState extends ConsumerState<ProfessorHomePage> {
  int _pageIndex = 0;

  Future<void> _refreshRooms() async {
    final user = ref.read(authNotifierProvider);
    if (user != null) {
      ref.invalidate(professorRoomsProvider(user.userId));
    }
    ref.invalidate(currentProfessorRoomsProvider);
    try {
      await ref.read(currentProfessorRoomsProvider.future);
    } catch (_) {}
  }

  Future<void> _createRoom() async {
    await context.push('/professor/room/new');
    // 돌아왔을 때 목록 갱신
    await _refreshRooms();
  }

  Future<void> _deleteRoom(Map<String, dynamic> room) async {
    final roomId = room['room_id'] as String? ?? '';
    final subject = room['subject'] as String? ?? '이 강의 방';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('강의 방 삭제',
            style: TextStyle(
                color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('"$subject"을 삭제할까요?\n삭제 후 복구가 불가능합니다.',
            style:
                const TextStyle(color: _C.textSec, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: _C.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제',
                style: TextStyle(color: _C.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ApiService().deleteRoom(roomId);
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshRooms();
    } catch (_) {
      await _refreshRooms();
    }
  }

  Future<void> _editRoom(Map<String, dynamic> room) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EditRoomDialog(room: room),
    );
    if (result == null) return;
    try {
      await ApiService().updateRoom(
        roomId: room['room_id'] as String? ?? '',
        subject: result['subject'] ?? '',
        description: result['description'] ?? '',
        synopsis: result['synopsis'] ?? '',
        coreConcepts: result['core_concepts'] ?? '',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshRooms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 오류: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);
    final roomsAsync = ref.watch(currentProfessorRoomsProvider);
    final rooms = roomsAsync.valueOrNull ?? const <dynamic>[];
    final totalStudents = rooms.fold<int>(
      0,
      (s, r) => s + ((r['student_count'] as int?) ?? 0),
    );
    final avgCompletion = rooms.isEmpty
        ? 0
        : (rooms.fold<num>(
                  0,
                  (s, r) => s + ((r['completion_rate'] as num?) ?? 0),
                ) /
                rooms.length)
            .round();

    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        children: [
          _Sidebar(
            onLogout: _logout,
            onCreateRoom: _createRoom,
            selectedIndex: _pageIndex,
            onSelect: (index) => setState(() => _pageIndex = index),
          ),
          Expanded(
            child: _pageIndex == 1
                ? _ProfessorSettingsView(onLogout: _logout)
                : RefreshIndicator(
              onRefresh: _refreshRooms,
              color: _C.lime,
              backgroundColor: _C.surface,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopBar(user: user, onLogout: _logout),
                          const SizedBox(height: 20),
                          _WelcomeBanner(
                            name: user?.name ?? '',
                            completionRate: avgCompletion,
                            studentCount: totalStudents,
                          ),
                          const SizedBox(height: 20),
                          _StatsRow(
                            roomCount: rooms.length,
                            studentCount: totalStudents,
                            completionRate: avgCompletion,
                          ),
                          const SizedBox(height: 24),
                          _SectionTitle(
                            title: '내 강의 방',
                            sub: '${rooms.length}개',
                            trailing: _CreateRoomButton(onTap: _createRoom),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // ── 로딩 ──────────────────────────────────────
                  if (roomsAsync.isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _C.lime,
                          strokeWidth: 2,
                        ),
                      ),
                    )

                  // ── 빈 상태 ───────────────────────────────────
                  else if (roomsAsync.hasError)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          '강의실 목록을 불러오지 못했습니다',
                          style: TextStyle(color: _C.textSec, fontSize: 14),
                        ),
                      ),
                    )
                  else if (rooms.isEmpty)
                    SliverFillRemaining(
                      child: _EmptyRooms(onCreateRoom: _createRoom),
                    )

                  // ── 방 목록 ───────────────────────────────────
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RoomCard(
                              room: rooms[i] as Map<String, dynamic>,
                              onDelete: () =>
                                  _deleteRoom(rooms[i] as Map<String, dynamic>),
                              onEdit: () =>
                                  _editRoom(rooms[i] as Map<String, dynamic>),
                            ),
                          ),
                          childCount: rooms.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 사이드바
// ════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onCreateRoom;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _Sidebar({
    required this.onLogout,
    required this.onCreateRoom,
    required this.selectedIndex,
    required this.onSelect,
  });

  static const _items = [
    ('홈', Icons.grid_view_rounded),
    ('설정', Icons.settings_outlined),
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
        // 로고
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _C.lime,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.grid_view, color: _C.bg, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FitLearn',
                    style: TextStyle(
                        color: _C.textPri,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text('강사 포털',
                    style: TextStyle(color: _C.textMute, fontSize: 10)),
              ],
            ),
          ]),
        ),
        const Divider(color: _C.border, height: 1),
        const SizedBox(height: 12),

        // 네비
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final active = selectedIndex == i;
              return GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? _C.limeDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: active ? _C.lime : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(children: [
                    Icon(_items[i].$2,
                        size: 16, color: active ? _C.lime : _C.textSec),
                    const SizedBox(width: 10),
                    Text(_items[i].$1,
                        style: TextStyle(
                          fontSize: 13,
                          color: active ? _C.lime : _C.textSec,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ]),
                ),
              );
            },
          ),
        ),

        const Divider(color: _C.border, height: 1),
        GestureDetector(
          onTap: onLogout,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.logout_rounded, size: 16, color: _C.coral),
              SizedBox(width: 8),
              Text('로그아웃', style: TextStyle(fontSize: 13, color: _C.coral)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 상단바
// ════════════════════════════════════════════════════════════
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
            Text('수강생과 강의 검색...',
                style: TextStyle(color: _C.textMute, fontSize: 13)),
          ]),
        ),
      ),
      const SizedBox(width: 14),
      GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('알림', style: TextStyle(color: _C.textPri)),
            content: const Text('알림이 없습니다',
                style: TextStyle(color: _C.textSec, fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인', style: TextStyle(color: _C.lime)),
              ),
            ],
          ),
        ),
        child: const Icon(Icons.notifications_outlined, color: _C.textSec, size: 22),
      ),
      const SizedBox(width: 12),
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _C.limeDark,
          border: Border.all(color: _C.lime, width: 1.5),
        ),
        child: Center(
          child: Text(
            (user?.name ?? '').isNotEmpty ? user!.name.substring(0, 1) : '?',
            style: const TextStyle(
                color: _C.lime, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(user?.name ?? '',
          style: const TextStyle(
              color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// 웰컴 배너
// ════════════════════════════════════════════════════════════
class _WelcomeBanner extends StatelessWidget {
  final String name;
  final int completionRate;
  final int studentCount;
  const _WelcomeBanner({
    required this.name,
    required this.completionRate,
    required this.studentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: _C.lime,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('안녕하세요, $name 강사님 👋',
                  style: const TextStyle(
                      color: _C.limeDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text.rich(TextSpan(
                style: const TextStyle(color: Color(0xFF3A4A00), fontSize: 12),
                children: [
                  const TextSpan(text: '현재 수강생 평균 완강률 '),
                  TextSpan(
                      text: '$completionRate%',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: '를 기록 중입니다.'),
                ],
              )),
              const SizedBox(height: 4),
              Text('등록 수강생 $studentCount명 기준으로 집계됩니다.',
                  style: const TextStyle(color: Color(0xFF3A4A00), fontSize: 11)),
            ],
          ),
        ),
        Container(
          width: 60,
          height: 60,
          decoration:
              const BoxDecoration(color: _C.limeDeep, shape: BoxShape.circle),
          child: const Icon(Icons.person, color: _C.bg, size: 30),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 통계 행
// ════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  final int roomCount;
  final int studentCount;
  final int completionRate;
  const _StatsRow({
    required this.roomCount,
    required this.studentCount,
    required this.completionRate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _StatCard(
          label: '강의 방',
          value: '$roomCount',
          icon: Icons.meeting_room_rounded,
          color: _C.lime,
          colorBg: _C.limeDark,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _StatCard(
          label: '전체 수강생',
          value: '$studentCount',
          icon: Icons.people_rounded,
          color: _C.lavender,
          colorBg: _C.lavMid,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _StatCard(
          label: '완강률',
          value: '$completionRate%',
          icon: Icons.trending_up_rounded,
          color: _C.coral,
          colorBg: _C.coralDark,
        ),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color colorBg;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.colorBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: colorBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: _C.textPri,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: _C.textMute, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class _ProfessorSettingsView extends StatelessWidget {
  final VoidCallback onLogout;
  const _ProfessorSettingsView({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('설정',
            style: TextStyle(
                color: _C.textPri, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('계정과 서비스 사용 상태를 관리합니다.',
            style: TextStyle(color: _C.textSec, fontSize: 13)),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('계정',
                style: TextStyle(
                    color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('탈퇴 기능은 결제/수강 데이터 보존 정책과 함께 서버에서 처리되어야 합니다.',
                style: TextStyle(color: _C.textSec, fontSize: 12, height: 1.5)),
            const SizedBox(height: 16),
            Row(children: [
              OutlinedButton(
                onPressed: onLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.textPri,
                  side: const BorderSide(color: _C.border),
                ),
                child: const Text('로그아웃'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: _C.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('탈퇴하기',
                        style: TextStyle(color: _C.textPri)),
                    content: const Text(
                      '탈퇴 API와 결제 데이터 보존 정책 연결 후 활성화됩니다.',
                      style: TextStyle(color: _C.textSec, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('확인',
                            style: TextStyle(color: _C.lime)),
                      ),
                    ],
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.coral,
                  side: BorderSide(color: _C.coral.withValues(alpha: 0.45)),
                ),
                child: const Text('탈퇴하기'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 섹션 타이틀
// ════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.sub, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title,
          style: const TextStyle(
              color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
      if (sub != null) ...[
        const SizedBox(width: 8),
        Text(sub!, style: const TextStyle(color: _C.textSec, fontSize: 12)),
      ],
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: _C.border)),
      if (trailing != null) ...[
        const SizedBox(width: 12),
        trailing!,
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// 방 만들기 버튼
// ════════════════════════════════════════════════════════════
class _CreateRoomButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateRoomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _C.lime,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, color: _C.limeDark, size: 16),
          SizedBox(width: 4),
          Text('강의 생성',
              style: TextStyle(
                  color: _C.limeDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 강의 방 카드 (기존 라우팅 완전 유지)
// ════════════════════════════════════════════════════════════
class _RoomCard extends StatefulWidget {
  final Map<String, dynamic> room;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _RoomCard(
      {required this.room, required this.onDelete, required this.onEdit});

  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  bool _hovered = false;

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.room['_loading'] == true;
    final studentCount = widget.room['student_count'] as int? ?? 0;
    final desc = widget.room['description'] as String? ?? '';
    final dateStr = _formatDate(widget.room['created_at'] as String?);

    return Opacity(
      opacity: isLoading ? 0.5 : 1.0,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          // ── 기존 라우팅 완전 유지 ─────────────────────────────
          onTap: () =>
              context.push('/professor/room/${widget.room['room_id']}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _hovered ? _C.surface2 : _C.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered ? _C.lime.withValues(alpha: 0.4) : _C.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      widget.room['subject'] as String? ?? '',
                      style: const TextStyle(
                          color: _C.textPri,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (isLoading) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _C.limeDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('생성 중...',
                          style: TextStyle(
                              color: _C.lime,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc,
                      style: const TextStyle(color: _C.textSec, fontSize: 12)),
                ],
                const SizedBox(height: 14),
                // 하단 정보
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _C.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _C.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.people_outline_rounded,
                          color: _C.textSec, size: 13),
                      const SizedBox(width: 4),
                      Text('$studentCount명',
                          style:
                              const TextStyle(color: _C.textSec, fontSize: 12)),
                    ]),
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(dateStr,
                        style:
                            const TextStyle(color: _C.textMute, fontSize: 11)),
                  ],
                  const SizedBox(width: 8),
                  const Spacer(),
                  // 수정 버튼
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _C.limeDark,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _C.lime.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined,
                                  color: _C.lime, size: 13),
                              SizedBox(width: 4),
                              Text('수정',
                                  style: TextStyle(
                                      color: _C.lime,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 삭제 버튼
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _C.coralDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _C.coral.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: _C.coral, size: 13),
                              SizedBox(width: 4),
                              Text('삭제',
                                  style: TextStyle(
                                      color: _C.coral,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: _C.textSec, size: 13),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 빈 방 상태
// ════════════════════════════════════════════════════════════
class _EmptyRooms extends StatelessWidget {
  final VoidCallback onCreateRoom;
  const _EmptyRooms({required this.onCreateRoom});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: _C.limeDark, shape: BoxShape.circle),
          child:
              const Icon(Icons.meeting_room_outlined, color: _C.lime, size: 36),
        ),
        const SizedBox(height: 20),
        const Text('아직 강의 방이 없습니다',
            style: TextStyle(
                color: _C.textPri, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('"강의 생성" 버튼으로 강의를 시작하세요',
            style: TextStyle(color: _C.textSec, fontSize: 13)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onCreateRoom,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _C.lime,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('강의 생성',
                style: TextStyle(
                    color: _C.limeDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 오른쪽 패널
// ════════════════════════════════════════════════════════════
class _RightPanel extends StatelessWidget {
  final List<dynamic> rooms;
  const _RightPanel({required this.rooms});

  static const _schedule = [
    ('파트3 라이브 Q&A', '7월 8일', '오전 8시–9시', _C.lime, _C.limeDark),
    ('중간 과제 마감', '7월 12일', '오후 11시 59분', _C.coral, _C.coralDark),
    ('색보정 보충 강의', '7월 17일', '오전 8시–9시', _C.lavender, _C.lavMid),
    ('최종 발표', '7월 22일', '오전 10시–오후 1시', _C.amber, _C.amberDark),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(left: BorderSide(color: _C.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI 인사이트 카드
            _AiInsightCard(),
            const Divider(color: _C.border, height: 28),

            // 수강생 성향 분포
            _DistributionCard(),
            const Divider(color: _C.border, height: 28),

            // 일정
            const Text('예정된 일정',
                style: TextStyle(
                    color: _C.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ..._schedule.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ScheduleRow(
                    title: e.$1,
                    date: e.$2,
                    time: e.$3,
                    color: e.$4,
                    colorBg: e.$5,
                  ),
                )),
            const Divider(color: _C.border, height: 28),

            // AI 코치
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
                  Text('AI 인사이트',
                      style: TextStyle(
                          color: _C.lime,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text(
                    '파트3 색보정 구간에서 수강생 67%가 막혔습니다. AI Q&A 자동 답변 12건이 대기 중입니다.',
                    style:
                        TextStyle(color: _C.textSec, fontSize: 11, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// AI 인사이트 카드
// ════════════════════════════════════════════════════════════
class _AiInsightCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.lavMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.lavDark),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: _C.lime, borderRadius: BorderRadius.circular(20)),
          child: const Text('AI 분석',
              style: TextStyle(
                  color: _C.limeDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        const Text('막히는 구간 TOP 3',
            style: TextStyle(
                color: _C.lavender, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _insightRow('파트3 레이어마스크', 67),
        _insightRow('파트5 색보정 기초', 43),
        _insightRow('파트7 최종 편집', 28),
      ]),
    );
  }

  Widget _insightRow(String title, int pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(color: _C.textPri, fontSize: 11)),
          ),
          Text('$pct%',
              style: const TextStyle(
                  color: _C.coral, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 3,
            backgroundColor: _C.border,
            valueColor: const AlwaysStoppedAnimation(_C.coral),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 성향 분포 카드
// ════════════════════════════════════════════════════════════
class _DistributionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('수강생 성향 분포',
          style: TextStyle(
              color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      _distRow('예시 중심형', 27, _C.lavender, _C.lavMid),
      _distRow('상세 이해형', 42, _C.lime, _C.limeDark),
      _distRow('핵심 요약형', 31, _C.coral, _C.coralDark),
    ]);
  }

  Widget _distRow(String label, int pct, Color color, Color colorBg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: _C.textSec, fontSize: 11)),
          ),
          Text('$pct%',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 3,
            backgroundColor: _C.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 일정 행
// ════════════════════════════════════════════════════════════
class _ScheduleRow extends StatelessWidget {
  final String title, date, time;
  final Color color, colorBg;
  const _ScheduleRow({
    required this.title,
    required this.date,
    required this.time,
    required this.color,
    required this.colorBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: colorBg, shape: BoxShape.circle),
        child: Center(
          child: Text(
            date.substring(3, 5),
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: _C.textPri,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$date · $time',
              style: const TextStyle(color: _C.textSec, fontSize: 10)),
        ]),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// 방 만들기 다이얼로그 (2스텝)
// ════════════════════════════════════════════════════════════
class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _currCtrl = TextEditingController();
  final _synopsisCtrl = TextEditingController();

  String _roomType = 'offline';
  int _step = 1;

  final List<LectureItem> _lectures = [LectureItem()];

  bool get _canNext =>
      _nameCtrl.text.trim().isNotEmpty && _currCtrl.text.trim().isNotEmpty;
  bool get _canCreate => _lectures.any((l) => l.title.trim().isNotEmpty);

  static const _bg = Color(0xFF0E0E11);
  static const _surf = Color(0xFF13131A);
  static const _lime = Color(0xFFC8F135);
  static const _limeDark = Color(0xFF1A2400);
  static const _border = Color(0xFF1E1E2A);
  static const _textPri = Color(0xFFF0F0F4);
  static const _textSec = Color(0xFF8888A0);
  static const _textMute = Color(0xFF4A4A5A);
  static const _btnGhost = Color(0xFF13131A);

  @override
  void initState() {
    super.initState();
    for (final c in [_nameCtrl, _descCtrl, _currCtrl, _synopsisCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _currCtrl.dispose();
    _synopsisCtrl.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_canNext) setState(() => _step = 2);
  }

  void _onDone() {
    if (!_canCreate) return;
    Navigator.pop(context, <String, dynamic>{
      'subject': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'room_type': _roomType,
      'synopsis': _synopsisCtrl.text.trim(),
      'core_concepts': _currCtrl.text.trim(),
      'youtube_url': '',
      'lectures': _lectures,
    });
  }

  InputDecoration _inputDeco(String hint, {bool hasValue = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textMute, fontSize: 13),
      filled: true,
      fillColor: _surf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: hasValue ? _lime : _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: hasValue ? _lime.withValues(alpha: 0.5) : _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _lime, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: _border, height: 1),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const titles = ['강의 기본 정보', '강의 자료 등록'];
    const subtitles = [
      '강의의 정체성과 학습 기준을 먼저 설계합니다',
      '강의 항목별 영상·자료 연결 구조를 미리 잡습니다'
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
            children: List.generate(2, (i) {
          final active = i + 1 == _step;
          final done = i + 1 < _step;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: done || active ? _lime : _border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        })),
        const SizedBox(height: 16),
        Text(titles[_step - 1],
            style: const TextStyle(
                color: _textPri, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitles[_step - 1],
            style: const TextStyle(color: _textSec, fontSize: 13)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _step / 2,
            minHeight: 2,
            backgroundColor: _border,
            valueColor: const AlwaysStoppedAnimation(_lime),
          ),
        ),
      ]),
    );
  }

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('강의명', required: true),
      const SizedBox(height: 8),
      TextField(
        controller: _nameCtrl,
        style: const TextStyle(color: _textPri, fontSize: 14),
        decoration:
            _inputDeco('예: 파이썬 프로그래밍 기초', hasValue: _nameCtrl.text.isNotEmpty),
      ),
      const SizedBox(height: 20),
      _label('한 줄 소개 (선택)', required: false),
      const SizedBox(height: 8),
      TextField(
        controller: _descCtrl,
        style: const TextStyle(color: _textPri, fontSize: 14),
        decoration:
            _inputDeco('강의를 한 줄로 소개해주세요', hasValue: _descCtrl.text.isNotEmpty),
      ),
      const SizedBox(height: 20),
      _label('강의 줄거리', required: false),
      const SizedBox(height: 4),
      const Text('학생 수준판단 퀴즈와 AI 재해석 기준에 함께 사용됩니다.',
          style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
      const SizedBox(height: 8),
      TextField(
        controller: _synopsisCtrl,
        maxLines: 4,
        style: const TextStyle(color: _textPri, fontSize: 14, height: 1.6),
        decoration: _inputDeco(
          '예) 파이썬의 기본 문법부터 함수, 자료구조, 파일 처리, 간단한 프로젝트까지 단계적으로 다룹니다.',
          hasValue: _synopsisCtrl.text.isNotEmpty,
        ),
      ),
      const SizedBox(height: 20),
      _label('커리큘럼 (필수)', required: true),
      const SizedBox(height: 4),
      const Text('각 줄이 하나의 핵심 개념이 됩니다. AI가 분석하여 교안 재해석에 반영합니다.',
          style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
      const SizedBox(height: 8),
      TextField(
        controller: _currCtrl,
        maxLines: 5,
        style: const TextStyle(color: _textPri, fontSize: 14, height: 1.6),
        decoration: _inputDeco(
          '예)\n재귀 함수의 원리\n시간복잡도 O(n log n) 이해\n분할 정복 알고리즘',
          hasValue: _currCtrl.text.isNotEmpty,
        ),
      ),
      const SizedBox(height: 20),
      _label('강의 형식', required: false),
      const SizedBox(height: 10),
      Row(children: [
        _RoomTypeChip(
          label: '오프라인',
          icon: Icons.location_on_rounded,
          selected: _roomType == 'offline',
          onTap: () => setState(() => _roomType = 'offline'),
        ),
        const SizedBox(width: 10),
        _RoomTypeChip(
          label: '온라인',
          icon: Icons.videocam_rounded,
          selected: _roomType == 'online',
          onTap: () => setState(() => _roomType = 'online'),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Text(
          _roomType == 'online'
              ? '온라인 강의는 각 강의 항목에 업로드 영상과 대본을 연결해 관리합니다.'
              : '오프라인 강의는 교안, 실습 코드, 공지 중심으로 관리됩니다.',
          style: const TextStyle(color: _textSec, fontSize: 12, height: 1.5),
        ),
      ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 헤더 Row
      Row(children: [
        const Text('강의 목록',
            style: TextStyle(
                color: _textSec, fontSize: 11, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _lectures.add(LectureItem())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _limeDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _lime.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, color: _lime, size: 13),
              SizedBox(width: 4),
              Text('+ 강의 추가',
                  style: TextStyle(
                      color: _lime, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      const Text(
        '이 목록은 업로드 화면에서 그대로 선택되어 교안과 영상이 정확히 매칭됩니다.',
        style: TextStyle(color: _textMute, fontSize: 11),
      ),
      const SizedBox(height: 12),
      // 강의 목록
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _lectures.length,
        itemBuilder: (context, i) {
          final lec = _lectures[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 행
                  Row(children: [
                    Text('${i + 1}강',
                        style: const TextStyle(
                            color: _textSec,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_lectures.length > 1)
                      GestureDetector(
                        onTap: () => setState(() => _lectures.removeAt(i)),
                        child: const Icon(Icons.close_rounded,
                            color: _textMute, size: 16),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  // 제목
                  TextField(
                    style: const TextStyle(color: _textPri, fontSize: 13),
                    decoration:
                        _inputDeco('강의 제목', hasValue: lec.title.isNotEmpty),
                    onChanged: (v) => setState(() => lec.title = v),
                  ),
                  const SizedBox(height: 8),
                  // 교안 URL
                  TextField(
                    style: const TextStyle(color: _textPri, fontSize: 13),
                    decoration: _inputDeco('교안 URL 또는 교안 파일 pdf 등 (선택)',
                        hasValue: lec.materialUrl.isNotEmpty),
                    onChanged: (v) => setState(() => lec.materialUrl = v),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildFooter() {
    final String leftLabel;
    final VoidCallback leftAction;
    final String rightLabel;
    final VoidCallback? rightAction;
    final bool rightEnabled;

    if (_step == 1) {
      leftLabel = '취소';
      leftAction = () => Navigator.pop(context);
      rightLabel = '다음 →';
      rightAction = _canNext ? _onNext : null;
      rightEnabled = _canNext;
    } else {
      leftLabel = '← 이전';
      leftAction = () => setState(() => _step = 1);
      rightLabel = '강의 방 만들기';
      rightAction = _canCreate ? _onDone : null;
      rightEnabled = _canCreate;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
      child: Row(children: [
        GestureDetector(
          onTap: leftAction,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: _btnGhost,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Center(
              child: Text(leftLabel,
                  style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: rightAction,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: rightEnabled ? _lime : _btnGhost,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(rightLabel,
                  style: TextStyle(
                      color: rightEnabled ? _limeDark : const Color(0xFF333333),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text, {required bool required}) {
    return Row(children: [
      Text(text,
          style: const TextStyle(
              color: _textSec, fontSize: 12, fontWeight: FontWeight.w600)),
      if (required) ...[
        const SizedBox(width: 4),
        const Text('*',
            style: TextStyle(color: Color(0xFFC8F135), fontSize: 12)),
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// 요약 섹션 (step 3)
// ════════════════════════════════════════════════════════════════
class _SummarySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SummarySection(
      {required this.icon, required this.title, required this.child});

  static const _surf = Color(0xFF13131A);
  static const _lime = Color(0xFFC8F135);
  static const _border = Color(0xFF1E1E2A);
  static const _textMute = Color(0xFF4A4A5A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: _lime, size: 14),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                color: _textMute,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              )),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _SummaryLink extends StatelessWidget {
  final IconData icon;
  final String label, url;
  const _SummaryLink(
      {required this.icon, required this.label, required this.url});

  static const _lime = Color(0xFFC8F135);
  static const _limeDark = Color(0xFF1A2400);
  static const _textSec = Color(0xFF8888A0);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: _limeDark, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _lime, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: _lime, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textSec, fontSize: 11)),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// 첨부 카드 (다이얼로그 내부용)
// ════════════════════════════════════════════════════════════════
class _AttachCard extends StatefulWidget {
  final IconData icon;
  final String label, hint;
  final TextEditingController ctrl;

  const _AttachCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.ctrl,
  });

  @override
  State<_AttachCard> createState() => _AttachCardState();
}

class _AttachCardState extends State<_AttachCard> {
  static const _surf = Color(0xFF13131A);
  static const _lime = Color(0xFFC8F135);
  static const _border = Color(0xFF1E1E2A);
  static const _textPri = Color(0xFFF0F0F4);
  static const _textMute = Color(0xFF4A4A5A);

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.ctrl.text.trim().isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValue ? _lime.withValues(alpha: 0.6) : _border,
          width: hasValue ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(widget.icon, color: hasValue ? _lime : _textMute, size: 16),
          const SizedBox(width: 6),
          Text(widget.label,
              style: TextStyle(
                color: hasValue ? _lime : _textMute,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              )),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: widget.ctrl,
          style: const TextStyle(color: _textPri, fontSize: 12),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: _textMute, fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF0E0E11),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _lime),
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 강의 방 수정 다이얼로그
// ════════════════════════════════════════════════════════════════
class _EditRoomDialog extends StatefulWidget {
  final Map<String, dynamic> room;
  const _EditRoomDialog({required this.room});

  @override
  State<_EditRoomDialog> createState() => _EditRoomDialogState();
}

class _EditRoomDialogState extends State<_EditRoomDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _synopsisCtrl;
  late final TextEditingController _currCtrl;

  String _roomType = 'offline';
  int _step = 1;

  bool get _canNext =>
      _nameCtrl.text.trim().isNotEmpty && _currCtrl.text.trim().isNotEmpty;

  static const _bg = Color(0xFF0E0E11);
  static const _surf = Color(0xFF13131A);
  static const _lime = Color(0xFFC8F135);
  static const _limeDark = Color(0xFF1A2400);
  static const _border = Color(0xFF1E1E2A);
  static const _textPri = Color(0xFFF0F0F4);
  static const _textSec = Color(0xFF8888A0);
  static const _textMute = Color(0xFF4A4A5A);
  static const _btnGhost = Color(0xFF13131A);

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.room['subject'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: widget.room['description'] as String? ?? '');
    _synopsisCtrl =
        TextEditingController(text: widget.room['synopsis'] as String? ?? '');
    _currCtrl = TextEditingController(
        text: widget.room['core_concepts'] as String? ?? '');
    _roomType = widget.room['room_type'] as String? ?? 'offline';
    for (final c in [_nameCtrl, _descCtrl, _synopsisCtrl, _currCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _synopsisCtrl.dispose();
    _currCtrl.dispose();
    super.dispose();
  }

  void _onDone() {
    Navigator.pop(context, <String, String>{
      'subject': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'room_type': _roomType,
      'synopsis': _synopsisCtrl.text.trim(),
      'core_concepts': _currCtrl.text.trim(),
    });
  }

  InputDecoration _inputDeco(String hint, {bool hasValue = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textMute, fontSize: 13),
      filled: true,
      fillColor: _surf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: hasValue ? _lime : _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: hasValue ? _lime.withValues(alpha: 0.5) : _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _lime, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: _border, height: 1),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const titles = ['강의 기본 정보', '강의 줄거리'];
    const subtitles = ['강의 이름과 커리큘럼을 수정해주세요', '강의 줄거리와 소개를 수정해주세요'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('강의 방 수정',
              style: TextStyle(
                  color: _lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(width: 8),
          ...List.generate(2, (i) {
            final active = i + 1 == _step;
            final done = i + 1 < _step;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: done || active ? _lime : _border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ]),
        const SizedBox(height: 16),
        Text(titles[_step - 1],
            style: const TextStyle(
                color: _textPri, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitles[_step - 1],
            style: const TextStyle(color: _textSec, fontSize: 13)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _step / 2,
            minHeight: 2,
            backgroundColor: _border,
            valueColor: const AlwaysStoppedAnimation(_lime),
          ),
        ),
      ]),
    );
  }

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('강의명', required: true),
      const SizedBox(height: 8),
      TextField(
        controller: _nameCtrl,
        style: const TextStyle(color: _textPri, fontSize: 14),
        decoration:
            _inputDeco('예: 파이썬 프로그래밍 기초', hasValue: _nameCtrl.text.isNotEmpty),
      ),
      const SizedBox(height: 20),
      _label('한 줄 소개 (선택)', required: false),
      const SizedBox(height: 8),
      TextField(
        controller: _descCtrl,
        style: const TextStyle(color: _textPri, fontSize: 14),
        decoration:
            _inputDeco('강의를 한 줄로 소개해주세요', hasValue: _descCtrl.text.isNotEmpty),
      ),
      const SizedBox(height: 20),
      _label('커리큘럼 (필수)', required: true),
      const SizedBox(height: 8),
      TextField(
        controller: _currCtrl,
        maxLines: 5,
        style: const TextStyle(color: _textPri, fontSize: 14, height: 1.6),
        decoration: _inputDeco(
          '각 줄이 하나의 핵심 개념입니다.',
          hasValue: _currCtrl.text.isNotEmpty,
        ),
      ),
      const SizedBox(height: 20),
      _label('강의 형식', required: false),
      const SizedBox(height: 10),
      Row(children: [
        _RoomTypeChip(
          label: '오프라인',
          icon: Icons.location_on_rounded,
          selected: _roomType == 'offline',
          onTap: () => setState(() => _roomType = 'offline'),
        ),
        const SizedBox(width: 10),
        _RoomTypeChip(
          label: '온라인',
          icon: Icons.videocam_rounded,
          selected: _roomType == 'online',
          onTap: () => setState(() => _roomType = 'online'),
        ),
      ]),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('강의 줄거리', required: false),
      const SizedBox(height: 8),
      TextField(
        controller: _synopsisCtrl,
        maxLines: 4,
        style: const TextStyle(color: _textPri, fontSize: 14, height: 1.6),
        decoration: _inputDeco(
          '이 강의에서 학생들이 배우게 될 내용을 간략히 설명해주세요',
          hasValue: _synopsisCtrl.text.isNotEmpty,
        ),
      ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildFooter() {
    final String leftLabel;
    final VoidCallback leftAction;
    final String rightLabel;
    final VoidCallback? rightAction;
    final bool rightEnabled;

    if (_step == 1) {
      leftLabel = '취소';
      leftAction = () => Navigator.pop(context);
      rightLabel = '다음 →';
      rightAction = _canNext ? () => setState(() => _step = 2) : null;
      rightEnabled = _canNext;
    } else {
      leftLabel = '← 이전';
      leftAction = () => setState(() => _step = 1);
      rightLabel = '수정 완료';
      rightAction = _onDone;
      rightEnabled = true;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
      child: Row(children: [
        GestureDetector(
          onTap: leftAction,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: _btnGhost,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Center(
              child: Text(leftLabel,
                  style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: rightAction,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: rightEnabled ? _lime : _btnGhost,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(rightLabel,
                  style: TextStyle(
                      color: rightEnabled ? _limeDark : const Color(0xFF333333),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text, {required bool required}) {
    return Row(children: [
      Text(text,
          style: const TextStyle(
              color: _textSec, fontSize: 12, fontWeight: FontWeight.w600)),
      if (required) ...[
        const SizedBox(width: 4),
        const Text('*',
            style: TextStyle(color: Color(0xFFC8F135), fontSize: 12)),
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// 초대 코드 다이얼로그
// ════════════════════════════════════════════════════════════════
class _InviteCodeDialog extends StatefulWidget {
  final String code;
  final String subject;
  const _InviteCodeDialog({required this.code, required this.subject});

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  bool _copied = false;

  static const _bg = Color(0xFF0E0E11);
  static const _surf = Color(0xFF13131A);
  static const _lime = Color(0xFFC8F135);
  static const _limeDark = Color(0xFF1A2400);
  static const _border = Color(0xFF1E1E2A);
  static const _textSec = Color(0xFF8888A0);
  static const _textMute = Color(0xFF4A4A5A);

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                    color: _limeDark, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: _lime, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                '강의 방이 생성되었습니다!',
                style: TextStyle(
                    color: _C.textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subject,
                style: const TextStyle(color: _textSec, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // 초대 코드 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: _surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _lime.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(children: [
                  const Text(
                    '학생 초대 코드',
                    style: TextStyle(
                        color: _textMute, fontSize: 11, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.code,
                    style: const TextStyle(
                      color: _lime,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              // 복사 버튼
              GestureDetector(
                onTap: _copyCode,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _copied ? _limeDark : _lime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          color: _copied ? _lime : _limeDark,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _copied ? '복사됨!' : '코드 복사하기',
                          style: TextStyle(
                            color: _copied ? _lime : _limeDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '학생들이 이 코드를 입력하면 강의 방에 참여할 수 있습니다.',
                style: TextStyle(color: _textMute, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: _surf,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(color: _textSec, fontSize: 13),
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

// ── 강의 형식 선택 칩 ─────────────────────────────────────────────────────────
class _RoomTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoomTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const _lime = Color(0xFFC8F135);
  static const _limeDark = Color(0xFF1A2400);
  static const _border = Color(0xFF1E1E2A);
  static const _surf = Color(0xFF13131A);
  static const _textPri = Color(0xFFF0F0F4);
  static const _textSec = Color(0xFF8888A0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _limeDark : _surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _lime : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? _lime : _textSec, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: selected ? _lime : _textSec,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              )),
        ]),
      ),
    );
  }
}
