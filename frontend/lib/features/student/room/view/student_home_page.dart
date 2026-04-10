import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';

// ─── 컬러 ───────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF0D0D0D);
  static const surface   = Color(0xFF161616);
  static const surface2  = Color(0xFF1E1E1E);
  static const border    = Color(0xFF262626);
  static const borderHi  = Color(0xFF333333);
  static const lime      = Color(0xFFC8F135);
  static const limeDark  = Color(0xFF182600);
  static const limeDeep  = Color(0xFFA8D010);
  static const salmon    = Color(0xFFFF6B5B);
  static const salmonDk  = Color(0xFF3D0A04);
  static const lavender  = Color(0xFFC5B8F8);
  static const lavDark   = Color(0xFF26215C);
  static const sky       = Color(0xFF38BDF8);
  static const skyDark   = Color(0xFF0C2A3D);
  static const textPri   = Color(0xFFFFFFFF);
  static const textSec   = Color(0xFF999999);
  static const textMute  = Color(0xFF555555);
}

// ════════════════════════════════════════════════════════════════════════════
// 메인 페이지
// ════════════════════════════════════════════════════════════════════════════
class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<StudentHomePage> {
  final _codeCtrl = TextEditingController();
  List<Map<String, dynamic>> _rooms = [];
  Map<String, List<dynamic>> _lecturesByRoom = {};
  bool _loadingRooms = true;
  bool _joining = false;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyRooms());
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyRooms() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    setState(() => _loadingRooms = true);
    try {
      final rooms = await ApiService().getStudentRooms(user.userId);
      final roomList = rooms.whereType<Map<String, dynamic>>().toList();
      final lectureMap = <String, List<dynamic>>{};
      for (final room in roomList) {
        final roomId = room['room_id'] as String? ?? '';
        if (roomId.isNotEmpty) {
          try {
            lectureMap[roomId] = await ApiService().getRoomLectures(roomId);
          } catch (_) {
            lectureMap[roomId] = [];
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _rooms = roomList;
        _lecturesByRoom = lectureMap;
        _loadingRooms = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  Future<void> _joinRoom() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _joinError = '6자리 방 코드를 입력해주세요.');
      return;
    }
    setState(() { _joining = true; _joinError = null; });
    try {
      await ApiService().joinRoom(userId: user.userId, roomCode: code);
      _codeCtrl.clear();
      await _loadMyRooms();
    } catch (_) {
      if (mounted) setState(() { _joinError = '유효하지 않은 코드입니다.'; _joining = false; });
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);
    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(children: [
        _Sidebar(onLogout: _logout, onDiagnosis: () => context.push('/student/diagnosis')),
        Expanded(child: _buildMain(user)),
      ]),
    );
  }

  Widget _buildMain(UserProfile? user) {
    final hasDiagnosis = user != null; // TODO: 실제 진단 완료 여부 확인
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _TopBar(user: user, onLogout: _logout)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── 학습 성향 진단 배너 ─────────────────────────────────
              _DiagnosisBanner(
                diagnosed: hasDiagnosis,
                onTap: () => context.push('/student/diagnosis'),
              ),
              const SizedBox(height: 24),

              // ── 강의실 입장 ─────────────────────────────────────────
              _SectionLabel(label: '강의실 입장'),
              const SizedBox(height: 10),
              _JoinRoomBar(
                ctrl: _codeCtrl,
                joining: _joining,
                error: _joinError,
                onJoin: _joinRoom,
              ),
              const SizedBox(height: 32),

              // ── 내 강의실 ──────────────────────────────────────────
              _SectionLabel(
                label: '내 강의실',
                badge: '${_rooms.length}개',
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),

        // 강의실 목록
        if (_loadingRooms)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(color: _C.lime, strokeWidth: 2)),
            ),
          )
        else if (_rooms.isEmpty)
          SliverToBoxAdapter(child: _EmptyRooms(onJoin: () => _codeCtrl.clear()))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RoomCard(
                    room: _rooms[i],
                    lectures: _lecturesByRoom[_rooms[i]['room_id']] ?? [],
                    user: ref.read(authNotifierProvider),
                    onTapLecture: (lec) => context.push('/student/lecture', extra: {
                      'room_id': _rooms[i]['room_id'],
                      'lecture_id': lec['lecture_id'],
                      'user_id': ref.read(authNotifierProvider)?.userId ?? '',
                      'title': lec['title'],
                    }),
                  ),
                ),
                childCount: _rooms.length,
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 48)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 상단바
// ════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final UserProfile? user;
  final VoidCallback onLogout;
  const _TopBar({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              user?.name != null ? '안녕하세요, ${user!.name}님' : 'FitLearn',
              style: const TextStyle(
                color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'AI 맞춤 교안 학습 플랫폼',
              style: TextStyle(color: _C.textMute, fontSize: 12),
            ),
          ]),
        ),
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _C.limeDark,
            shape: BoxShape.circle,
            border: Border.all(color: _C.lime, width: 1.5),
          ),
          child: Center(
            child: Text(
              (user?.name ?? '?').isNotEmpty ? user!.name.substring(0, 1) : '?',
              style: const TextStyle(color: _C.lime, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 사이드바
// ════════════════════════════════════════════════════════════════════════════
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
    ('학습 성향', Icons.psychology_outlined),
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
                onTap: () {
                  setState(() => _idx = i);
                  if (i == 1) widget.onDiagnosis();
                },
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

// ════════════════════════════════════════════════════════════════════════════
// 학습 성향 진단 배너
// ════════════════════════════════════════════════════════════════════════════
class _DiagnosisBanner extends StatelessWidget {
  final bool diagnosed;
  final VoidCallback onTap;
  const _DiagnosisBanner({required this.diagnosed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: diagnosed ? _C.limeDark : _C.salmonDk,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: diagnosed ? _C.lime.withValues(alpha: 0.35) : _C.salmon.withValues(alpha: 0.4),
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: diagnosed
                  ? _C.lime.withValues(alpha: 0.15)
                  : _C.salmon.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              diagnosed ? Icons.psychology_rounded : Icons.psychology_outlined,
              color: diagnosed ? _C.lime : _C.salmon,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              diagnosed ? '학습 성향 진단 완료' : '학습 성향 진단을 먼저 해주세요',
              style: TextStyle(
                color: diagnosed ? _C.lime : _C.salmon,
                fontSize: 14, fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              diagnosed
                  ? 'AI가 내 성향에 맞게 교안을 재해석합니다'
                  : '진단 후 맞춤 교안을 받을 수 있습니다',
              style: TextStyle(
                color: diagnosed
                    ? _C.lime.withValues(alpha: 0.6)
                    : _C.salmon.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ])),
          Icon(
            diagnosed ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
            color: diagnosed ? _C.lime : _C.salmon,
            size: diagnosed ? 22 : 14,
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 강의실 입장 바
// ════════════════════════════════════════════════════════════════════════════
class _JoinRoomBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool joining;
  final String? error;
  final VoidCallback onJoin;
  const _JoinRoomBar({
    required this.ctrl, required this.joining,
    required this.error, required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: _C.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: error != null ? _C.salmon : _C.border),
            ),
            child: TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                color: _C.textPri, fontSize: 16,
                fontWeight: FontWeight.w800, letterSpacing: 3,
              ),
              decoration: const InputDecoration(
                hintText: '방 코드 6자리 입력',
                hintStyle: TextStyle(
                  color: _C.textMute, fontSize: 13,
                  fontWeight: FontWeight.w400, letterSpacing: 0,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                counterText: '',
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: joining ? null : onJoin,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: joining ? _C.limeDark : _C.lime,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: joining
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _C.limeDark),
                    )
                  : const Text('입장', style: TextStyle(
                      color: _C.limeDark, fontSize: 14, fontWeight: FontWeight.w800,
                    )),
            ),
          ),
        ),
      ]),
      if (error != null) ...[ 
        const SizedBox(height: 6),
        Text(error!, style: const TextStyle(color: _C.salmon, fontSize: 12)),
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 강의실 카드 (교안 목록 포함)
// ════════════════════════════════════════════════════════════════════════════
class _RoomCard extends StatefulWidget {
  final Map<String, dynamic> room;
  final List<dynamic> lectures;
  final UserProfile? user;
  final void Function(Map<String, dynamic>) onTapLecture;
  const _RoomCard({
    required this.room, required this.lectures,
    required this.user, required this.onTapLecture,
  });

  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final subject = widget.room['subject'] as String? ?? '';
    final code = widget.room['room_code'] as String? ?? '';
    final confirmedLectures = widget.lectures
        .whereType<Map<String, dynamic>>()
        .where((l) => l['confirmed'] == true)
        .toList();
    final pendingCount = widget.lectures.length - confirmedLectures.length;

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 헤더
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _C.limeDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: _C.lime, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subject, style: const TextStyle(
                  color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 2),
                Row(children: [
                  Text('${confirmedLectures.length}개 교안 열람 가능',
                      style: const TextStyle(color: _C.textSec, fontSize: 12)),
                  if (pendingCount > 0) ...[ 
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _C.salmonDk,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('$pendingCount개 준비 중',
                          style: const TextStyle(color: _C.salmon, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
              ])),
              // 방 코드
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: code)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _C.limeDark,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(code, style: const TextStyle(
                    color: _C.lime, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2,
                  )),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _expanded ? 0 : -0.25,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded, color: _C.textMute, size: 20),
              ),
            ]),
          ),
        ),

        // 교안 목록
        if (_expanded) ...[ 
          Container(height: 1, color: _C.border),
          if (confirmedLectures.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Icon(Icons.hourglass_empty_rounded, color: _C.textMute, size: 16),
                const SizedBox(width: 8),
                const Text('교수님이 교안을 준비 중입니다.',
                    style: TextStyle(color: _C.textMute, fontSize: 13)),
              ]),
            )
          else
            ...confirmedLectures.asMap().entries.map((e) {
              final lec = e.value;
              final isLast = e.key == confirmedLectures.length - 1;
              final week = lec['week_number'] as int? ?? 0;
              final difficulty = lec['estimated_difficulty'] as String? ?? '중';
              final diffColor = difficulty == '상' ? _C.salmon : difficulty == '중' ? _C.lavender : _C.lime;

              return GestureDetector(
                onTap: () => widget.onTapLecture(lec),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : _C.border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Row(children: [
                    // 주차 배지
                    Container(
                      width: 38, height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _C.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.border),
                      ),
                      child: Text(
                        week == 0 ? '—' : '$week',
                        style: const TextStyle(
                          color: _C.textSec, fontSize: 13, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lec['title'] as String? ?? '', style: const TextStyle(
                        color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w600,
                      ), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        if (week > 0) ...[ 
                          Text('${week}주차', style: const TextStyle(color: _C.textMute, fontSize: 11)),
                          const Text(' · ', style: TextStyle(color: _C.textMute, fontSize: 11)),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: diffColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('난이도 $difficulty', style: TextStyle(
                            color: diffColor, fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ),
                      ]),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _C.limeDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome_rounded, color: _C.lime, size: 12),
                        SizedBox(width: 4),
                        Text('AI 교안 보기', style: TextStyle(
                          color: _C.lime, fontSize: 11, fontWeight: FontWeight.w700,
                        )),
                      ]),
                    ),
                  ]),
                ),
              );
            }),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 빈 강의실 상태
// ════════════════════════════════════════════════════════════════════════════
class _EmptyRooms extends StatelessWidget {
  final VoidCallback onJoin;
  const _EmptyRooms({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border, style: BorderStyle.solid),
        ),
        child: Column(children: [
          Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(color: _C.limeDark, shape: BoxShape.circle),
            child: const Icon(Icons.school_outlined, color: _C.lime, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('아직 입장한 강의실이 없습니다', style: TextStyle(
            color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 6),
          const Text('교수님께 방 코드를 받아 입장해 보세요',
              style: TextStyle(color: _C.textSec, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 공통 위젯
// ════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? badge;
  const _SectionLabel({required this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: const TextStyle(
        color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w800,
      )),
      if (badge != null) ...[ 
        const SizedBox(width: 8),
        Text(badge!, style: const TextStyle(color: _C.textMute, fontSize: 13)),
      ],
    ]);
  }
}
