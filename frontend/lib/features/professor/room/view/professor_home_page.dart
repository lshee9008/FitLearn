import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
 
// ─── 컬러 ────────────────────────────────────────────────────
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
 
// ════════════════════════════════════════════════════════════
// 메인 페이지
// ════════════════════════════════════════════════════════════
class ProfessorHomePage extends ConsumerStatefulWidget {
  const ProfessorHomePage({super.key});
 
  @override
  ConsumerState<ProfessorHomePage> createState() => _ProfessorHomePageState();
}
 
class _ProfessorHomePageState extends ConsumerState<ProfessorHomePage> {
  // ── 기존 연결 상태 완전 유지 ────────────────────────────────
  List<dynamic> _rooms = [];
  bool _loading = true;
 
  @override
  void initState() {
    super.initState();
    _loadRooms();
  }
 
  // ── 기존 액션 완전 유지 ──────────────────────────────────────
  Future<void> _loadRooms() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final rooms = await ApiService().getProfessorRooms(user.userId);
      setState(() { _rooms = rooms; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }
 
  Future<void> _createRoom() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CreateRoomDialog(),
    );
    if (result == null) return;
    try {
      await ApiService().createRoom(
        professorUid: user.userId,
        subject: result['subject']!,
        description: result['description'] ?? '',
        roomType: result['room_type'] ?? 'offline',
        synopsis: result['synopsis'] ?? '',
        coreConcepts: (result['core_concepts'] ?? '').split('|').where((e) => e.isNotEmpty).toList(),
      );
      _loadRooms();
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('방 생성 중 오류가 발생했습니다.')),
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
    final totalStudents = _rooms.fold<int>(
      0, (s, r) => s + ((r['student_count'] as int?) ?? 0),
    );
 
    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        children: [
          _Sidebar(onLogout: _logout, onCreateRoom: _createRoom),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRooms,
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
                          _WelcomeBanner(name: user?.name ?? ''),
                          const SizedBox(height: 20),
                          _StatsRow(
                            roomCount: _rooms.length,
                            studentCount: totalStudents,
                          ),
                          const SizedBox(height: 24),
                          _SectionTitle(
                            title: '내 강의 방',
                            sub: '${_rooms.length}개',
                            trailing: _CreateRoomButton(onTap: _createRoom),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
 
                  // ── 로딩 ──────────────────────────────────────
                  if (_loading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _C.lime, strokeWidth: 2,
                        ),
                      ),
                    )
 
                  // ── 빈 상태 ───────────────────────────────────
                  else if (_rooms.isEmpty)
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
                              room: _rooms[i] as Map<String, dynamic>,
                              onDelete: _loadRooms,
                            ),
                          ),
                          childCount: _rooms.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _RightPanel(rooms: _rooms),
        ],
      ),
    );
  }
}
 
// ════════════════════════════════════════════════════════════
// 사이드바
// ════════════════════════════════════════════════════════════
class _Sidebar extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onCreateRoom;
  const _Sidebar({required this.onLogout, required this.onCreateRoom});
 
  @override
  State<_Sidebar> createState() => _SidebarState();
}
 
class _SidebarState extends State<_Sidebar> {
  int _idx = 0;
 
  static const _items = [
    ('홈',      Icons.grid_view_rounded),
    ('수강생 관리', Icons.people_outline_rounded),
    ('강의 자료', Icons.description_outlined),
    ('Q&A 관리', Icons.chat_bubble_outline_rounded),
    ('메시지',   Icons.mail_outline_rounded),
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
        // 로고
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Row(children: [
            Container(
              width: 32, height: 32,
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
              final active = _idx == i;
              return GestureDetector(
                onTap: () => setState(() => _idx = i),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
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
                        size: 16,
                        color: active ? _C.lime : _C.textSec),
                    const SizedBox(width: 10),
                    Text(_items[i].$1,
                        style: TextStyle(
                          fontSize: 13,
                          color: active ? _C.lime : _C.textSec,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
                    if (i == 4) ...[
                      const Spacer(),
                      Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: _C.salmon,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('4',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
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
              Text('로그아웃',
                  style: TextStyle(fontSize: 13, color: _C.salmon)),
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
            Text('수강생, 강의, Q&A 검색...',
                style: TextStyle(color: _C.textMute, fontSize: 13)),
          ]),
        ),
      ),
      const SizedBox(width: 14),
      Stack(children: [
        const Icon(Icons.notifications_outlined,
            color: _C.textSec, size: 22),
        Positioned(
          right: 0, top: 0,
          child: Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
                color: _C.lime, shape: BoxShape.circle),
          ),
        ),
      ]),
      const SizedBox(width: 12),
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _C.limeDark,
          border: Border.all(color: _C.lime, width: 1.5),
        ),
        child: Center(
          child: Text(
            (user?.name ?? '').isNotEmpty
                ? user!.name.substring(0, 1)
                : '?',
            style: const TextStyle(
                color: _C.lime,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(user?.name ?? '',
          style: const TextStyle(
              color: _C.textPri,
              fontSize: 13,
              fontWeight: FontWeight.w500)),
    ]);
  }
}
 
// ════════════════════════════════════════════════════════════
// 웰컴 배너
// ════════════════════════════════════════════════════════════
class _WelcomeBanner extends StatelessWidget {
  final String name;
  const _WelcomeBanner({required this.name});
 
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
              const Text.rich(TextSpan(
                style: TextStyle(color: Color(0xFF3A4A00), fontSize: 12),
                children: [
                  TextSpan(text: '이번 주 수강생 평균 완강률 '),
                  TextSpan(
                      text: '72%',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '를 달성했습니다!'),
                ],
              )),
              const SizedBox(height: 4),
              const Text('수강생 84명 중 61명이 이번 파트를 완료했어요.',
                  style:
                      TextStyle(color: Color(0xFF3A4A00), fontSize: 11)),
            ],
          ),
        ),
        Container(
          width: 60, height: 60,
          decoration: const BoxDecoration(
              color: _C.limeDeep, shape: BoxShape.circle),
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
  const _StatsRow({required this.roomCount, required this.studentCount});
 
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
          colorBg: _C.lavDark,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: _StatCard(
          label: '완강률',
          value: '72%',
          icon: Icons.trending_up_rounded,
          color: _C.salmon,
          colorBg: _C.salmonDark,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: _StatCard(
          label: 'AI Q&A 처리',
          value: '12건',
          icon: Icons.auto_awesome_rounded,
          color: _C.yellow,
          colorBg: _C.yellowDark,
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
          width: 40, height: 40,
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
          Text(label,
              style: const TextStyle(
                  color: _C.textMute, fontSize: 11)),
        ]),
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
              color: _C.textPri,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      if (sub != null) ...[
        const SizedBox(width: 8),
        Text(sub!,
            style: const TextStyle(color: _C.textSec, fontSize: 12)),
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
          Text('방 만들기',
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
  const _RoomCard({required this.room, required this.onDelete});
 
  @override
  State<_RoomCard> createState() => _RoomCardState();
}
 
class _RoomCardState extends State<_RoomCard> {
  bool _hovered = false;
 
  @override
  Widget build(BuildContext context) {
    final studentCount = widget.room['student_count'] as int? ?? 0;
    final desc = widget.room['description'] as String? ?? '';
 
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // ── 기존 라우팅 완전 유지 ─────────────────────────────
        onTap: () => context.push(
            '/professor/room/${widget.room['room_id']}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hovered ? _C.surface2 : _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? _C.lime.withValues(alpha: 0.4)
                  : _C.border,
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
                const SizedBox(width: 10),
                // 방 코드 배지
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.limeDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.room['room_code'] as String? ?? '',
                    style: const TextStyle(
                        color: _C.lime,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3),
                  ),
                ),
              ]),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(desc,
                    style: const TextStyle(
                        color: _C.textSec, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              // 하단 정보
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
                        style: const TextStyle(
                            color: _C.textSec, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 8),
                // AI 인사이트 배지 (있을 때만)
                if (studentCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _C.limeDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: _C.lime, size: 12),
                      SizedBox(width: 4),
                      Text('AI 분석 가능',
                          style: TextStyle(
                              color: _C.lime,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: _C.textSec, size: 13),
              ]),
            ],
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
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: _C.limeDark,
              shape: BoxShape.circle),
          child: const Icon(Icons.meeting_room_outlined,
              color: _C.lime, size: 36),
        ),
        const SizedBox(height: 20),
        const Text('아직 강의 방이 없습니다',
            style: TextStyle(
                color: _C.textPri,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('"방 만들기" 버튼으로 강의를 시작하세요',
            style: TextStyle(color: _C.textSec, fontSize: 13)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onCreateRoom,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _C.lime,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('방 만들기',
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
    ('중간 과제 마감', '7월 12일', '오후 11시 59분', _C.salmon, _C.salmonDark),
    ('색보정 보충 강의', '7월 17일', '오전 8시–9시', _C.lavender, _C.lavDark),
    ('최종 발표', '7월 22일', '오전 10시–오후 1시', _C.yellow, _C.yellowDark),
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
                    title: e.$1, date: e.$2, time: e.$3,
                    color: e.$4, colorBg: e.$5,
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
                    style: TextStyle(
                        color: _C.textSec,
                        fontSize: 11,
                        height: 1.6),
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
        color: const Color(0xFF1F1F35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A6A)),
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
                color: _C.lavender,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
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
                style: const TextStyle(
                    color: _C.textPri, fontSize: 11)),
          ),
          Text('$pct%',
              style: const TextStyle(
                  color: _C.salmon,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 3,
            backgroundColor: _C.border,
            valueColor:
                const AlwaysStoppedAnimation(_C.salmon),
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
              color: _C.textPri,
              fontSize: 13,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      _distRow('예시 중심형', 27, _C.lavender, _C.lavDark),
      _distRow('상세 이해형', 42, _C.lime, _C.limeDark),
      _distRow('핵심 요약형', 31, _C.salmon, _C.salmonDark),
    ]);
  }
 
  Widget _distRow(String label, int pct, Color color, Color colorBg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: _C.textSec, fontSize: 11)),
          ),
          Text('$pct%',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
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
    required this.title, required this.date, required this.time,
    required this.color, required this.colorBg,
  });
 
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28, height: 28,
        decoration:
            BoxDecoration(color: colorBg, shape: BoxShape.circle),
        child: Center(
          child: Text(
            date.substring(3, 5),
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700),
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
              style:
                  const TextStyle(color: _C.textSec, fontSize: 10)),
        ]),
      ),
    ]);
  }
}
 
// ════════════════════════════════════════════════════════════
// 방 만들기 다이얼로그 (기존 로직 완전 유지)
// ════════════════════════════════════════════════════════════
class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();
 
  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}
 
class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _synopsisCtrl = TextEditingController();
  final _coreConceptsCtrl = TextEditingController();
  String _roomType = 'offline';

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _synopsisCtrl.dispose();
    _coreConceptsCtrl.dispose();
    super.dispose();
  }

  Widget _buildTextField(String label, String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _C.textSec, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(color: _C.textPri),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _C.textMute),
            filled: true,
            fillColor: _C.surface2,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('강의 방 만들기',
                  style: TextStyle(
                      color: _C.textPri,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
  
              Row(
                children: [
                  const Text('강의 유형', style: TextStyle(color: _C.textSec, fontSize: 12)),
                  const SizedBox(width: 16),
                  Radio<String>(
                    value: 'offline',
                    groupValue: _roomType,
                    activeColor: _C.lime,
                    onChanged: (val) => setState(() => _roomType = val!),
                  ),
                  const Text('오프라인', style: TextStyle(color: _C.textPri, fontSize: 13)),
                  const SizedBox(width: 16),
                  Radio<String>(
                    value: 'online',
                    groupValue: _roomType,
                    activeColor: _C.lime,
                    onChanged: (val) => setState(() => _roomType = val!),
                  ),
                  const Text('온라인', style: TextStyle(color: _C.textPri, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildTextField('과목명', '예: 파이썬 프로그래밍 기초', _subjectCtrl),
              const SizedBox(height: 16),
              _buildTextField('간단 설명 (선택)', '강의의 간략한 설명을 입력하세요', _descCtrl),
              const SizedBox(height: 16),
              _buildTextField('강의 줄거리 / 목표', '예: 데이터 사이언스를 위한 파이썬 문법과 라이브러리 활용', _synopsisCtrl, maxLines: 3),
              const SizedBox(height: 16),
              _buildTextField('핵심 개념 (쉼표로 구분)', '예: 변수, 반복문, 함수, 클래스', _coreConceptsCtrl),
              
              const SizedBox(height: 24),
  
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _C.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.border),
                      ),
                      child: const Center(
                        child: Text('취소',
                            style: TextStyle(
                                color: _C.textSec,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_subjectCtrl.text.trim().isNotEmpty) {
                        final concepts = _coreConceptsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        Navigator.pop(context, {
                          'subject': _subjectCtrl.text.trim(),
                          'description': _descCtrl.text.trim(),
                          'room_type': _roomType,
                          'synopsis': _synopsisCtrl.text.trim(),
                          'core_concepts': concepts.join('|'), // 나중에 리스트로 처리
                        });
                      }
                    },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _C.lime,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('만들기',
                          style: TextStyle(
                              color: _C.limeDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
