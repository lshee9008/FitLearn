import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/widgets/fitlearn_logo.dart';
import '../../../../shared/widgets/fl_ui.dart';
import '../../../auth/provider/auth_provider.dart';

/// 학생 홈 — "다음에 무엇을 하면 되는지"가 한눈에 보이도록 구성
class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _HomeData {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> rooms;
  final Map<String, List<Map<String, dynamic>>> lectures;
  final List<Map<String, dynamic>> discover;
  const _HomeData(this.profile, this.rooms, this.lectures, this.discover);
}

class _StudentHomePageState extends ConsumerState<StudentHomePage> {
  Future<_HomeData>? _future;
  final Set<String> _enrolling = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final user = await ref.read(authNotifierProvider.notifier).ready();
    if (!mounted) return;
    if (user == null) {
      context.go('/');
      return;
    }
    setState(() { _future = _load(user.userId); });
  }

  Future<_HomeData> _load(String userId) async {
    final results = await Future.wait([
      ApiService().getDiagnosis(userId).then<Map<String, dynamic>?>((d) => d).catchError((_) => null),
      ApiService().getStudentServiceHub(userId),
    ]);
    final diagnosis = results[0];
    var hub = results[1] as Map<String, dynamic>;
    // 무료 서버 재시작으로 체험 데이터가 초기화된 경우 데모 수강을 자동 복구
    if ((hub['enrolled_rooms'] as List? ?? const []).isEmpty && userId.startsWith('demo-student-')) {
      try {
        await ApiService().demoBootstrap(role: 'student', userId: userId);
        hub = await ApiService().getStudentServiceHub(userId);
      } catch (_) {}
    }
    final rooms = (hub['enrolled_rooms'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final lectureLists = await Future.wait(rooms.map((r) => ApiService()
        .getRoomLectures(r['room_id'] as String)
        .catchError((_) => <dynamic>[])));
    final lectures = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < rooms.length; i++) {
      lectures[rooms[i]['room_id'] as String] = lectureLists[i]
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['confirmed'] == true)
          .toList()
        ..sort((a, b) => ((a['order_index'] as num?) ?? 0).compareTo((b['order_index'] as num?) ?? 0));
    }
    final discover = (hub['discover_rooms'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return _HomeData(
      (diagnosis?['profile'] as Map?)?.cast<String, dynamic>(),
      rooms,
      lectures,
      discover,
    );
  }

  Future<void> _enroll(Map<String, dynamic> room) async {
    final user = ref.read(authNotifierProvider);
    final roomId = room['room_id'] as String?;
    if (user == null || roomId == null) return;
    setState(() => _enrolling.add(roomId));
    try {
      await ApiService().enrollRoom(roomId: roomId, userId: user.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${room['subject']}」 수강을 시작했어요')),
      );
      setState(() { _future = _load(user.userId); });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수강 등록에 실패했어요.')));
      }
    } finally {
      if (mounted) setState(() => _enrolling.remove(roomId));
    }
  }

  Future<void> _openQuiz(String roomId) async {
    final done = await context.push<bool>('/student/subject_quiz/$roomId');
    if (done == true) _reload();
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);
    final w = MediaQuery.sizeOf(context).width;
    final pad = w < 600 ? 16.0 : 32.0;
    return Scaffold(
      backgroundColor: FL.bg,
      body: SafeArea(
        child: Column(children: [
          _HomeTopBar(name: user?.name ?? '', onLogout: _logout),
          Expanded(
            child: RefreshIndicator(
              color: FL.lime,
              onRefresh: _reload,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(pad, 28, pad, 64),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: FutureBuilder<_HomeData>(
                      future: _future,
                      builder: (context, snap) {
                        if (_future == null || snap.connectionState == ConnectionState.waiting) {
                          return const _HomeSkeleton();
                        }
                        if (snap.hasError) {
                          return FLCard(
                            child: Row(children: [
                              const Icon(Icons.cloud_off_rounded, color: FL.textMute),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('학습 정보를 불러오지 못했어요. 서버가 깨어나는 중일 수 있어요.',
                                    style: TextStyle(color: FL.textSec)),
                              ),
                              FLButton('다시 시도', kind: FLButtonKind.secondary, onPressed: _reload),
                            ]),
                          );
                        }
                        return _buildContent(snap.data!, user);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent(_HomeData data, UserProfile? user) {
    final next = _nextLecture(data);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${user?.name ?? ''}님, 반가워요 👋',
          style: const TextStyle(color: FL.text, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
      const SizedBox(height: 6),
      const Text('오늘도 나에게 맞춘 교안으로 이어서 학습해볼까요?',
          style: TextStyle(color: FL.textSec, fontSize: 15)),
      const SizedBox(height: 24),
      _ProfileStrip(
        profile: data.profile,
        onDiagnose: () => context.push(
          '/student/diagnosis/quick${next == null ? '' : '?next=${Uri.encodeComponent(next.$3)}'}',
        ),
        onFull: () => context.push('/student/diagnosis'),
      ),
      const SizedBox(height: 16),
      if (next != null)
        _ContinueCard(
          roomTitle: next.$1['subject'] as String? ?? '',
          lectureTitle: next.$2['title'] as String? ?? '',
          progress: ((next.$1['progress_rate'] as num?) ?? 0).toInt(),
          diagnosed: data.profile != null,
          onTap: () => context.push(next.$3),
        ),
      const SizedBox(height: 40),
      Row(children: [
        const Text('내 강의실', style: TextStyle(color: FL.text, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Text('${data.rooms.length}', style: const TextStyle(color: FL.textMute, fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 14),
      if (data.rooms.isEmpty)
        const FLCard(
          child: Text('아직 수강 중인 강의가 없어요. 아래에서 강의를 골라 시작해보세요.',
              style: TextStyle(color: FL.textSec)),
        )
      else
        for (final room in data.rooms)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _RoomCard(
              room: room,
              lectures: data.lectures[room['room_id']] ?? const [],
              onOpen: (lec) => context.push('/learn/${room['room_id']}/${lec['lecture_id']}'),
              onQuiz: () => _openQuiz(room['room_id'] as String),
            ),
          ),
      if (data.discover.isNotEmpty) ...[
        const SizedBox(height: 32),
        const Text('다른 강의 둘러보기', style: TextStyle(color: FL.text, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 14, children: [
          for (final room in data.discover.take(6))
            SizedBox(
              width: 340,
              child: _DiscoverCard(
                room: room,
                loading: _enrolling.contains(room['room_id']),
                onEnroll: () => _enroll(room),
              ),
            ),
        ]),
      ],
    ]);
  }

  /// (강의실, 강의, 경로) — 진도 기준 다음 강의
  (Map<String, dynamic>, Map<String, dynamic>, String)? _nextLecture(_HomeData data) {
    for (final room in data.rooms) {
      final lectures = data.lectures[room['room_id']] ?? const [];
      if (lectures.isEmpty) continue;
      final nextId = room['next_lecture_id'];
      final lec = lectures.firstWhere((l) => l['lecture_id'] == nextId, orElse: () => lectures.first);
      return (room, lec, '/learn/${room['room_id']}/${lec['lecture_id']}');
    }
    return null;
  }
}

// ── 상단 바 ──────────────────────────────────────────────────────

class _HomeTopBar extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  const _HomeTopBar({required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: FL.border))),
      child: Row(children: [
        InkWell(onTap: () => context.go('/'), child: const FitLearnLogo(height: 24)),
        const SizedBox(width: 12),
        const FLTag('학생', color: FL.lime),
        const Spacer(),
        if (!compact)
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('강의 둘러보기'),
            style: TextButton.styleFrom(foregroundColor: FL.textSec),
          ),
        PopupMenuButton<String>(
          tooltip: '계정',
          color: FL.surface2,
          onSelected: (v) => v == 'logout' ? onLogout() : null,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'logout', child: Text('로그아웃', style: TextStyle(color: FL.text))),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: FL.lime.withValues(alpha: 0.15),
                child: Text(name.isEmpty ? '?' : name.characters.first,
                    style: const TextStyle(color: FL.lime, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(name, style: const TextStyle(color: FL.text, fontSize: 14, fontWeight: FontWeight.w700)),
                const Icon(Icons.expand_more_rounded, color: FL.textMute, size: 18),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── 성향 스트립 ───────────────────────────────────────────────────

class _ProfileStrip extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onDiagnose;
  final VoidCallback onFull;
  const _ProfileStrip({required this.profile, required this.onDiagnose, required this.onFull});

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return SizedBox(width: double.infinity, child: FLCard(
        color: FL.lime.withValues(alpha: 0.06),
        borderColor: FL.lime.withValues(alpha: 0.3),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 14,
          children: [
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.psychology_alt_rounded, color: FL.lime, size: 30),
              SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('먼저 1분 성향 진단을 해주세요',
                    style: TextStyle(color: FL.text, fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('진단 결과에 따라 모든 교안이 내 방식으로 다시 쓰여요.',
                    style: TextStyle(color: FL.textSec, fontSize: 13.5)),
              ]),
            ]),
            FLButton('1분 진단 시작', icon: Icons.bolt_rounded, onPressed: onDiagnose),
          ],
        ),
      ));
    }
    final meta = StyleMeta.of(profile!['learning_style'] as String? ?? '읽기형');
    return SizedBox(width: double.infinity, child: FLCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
            Text(meta.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 4),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('내 학습 성향', style: TextStyle(color: FL.textMute, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${meta.key} · ${meta.tagline}',
                  style: TextStyle(color: meta.color, fontSize: 15.5, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(width: 6),
            if (profile!['focus_pattern'] != null) FLTag(profile!['focus_pattern'] as String, color: FL.sky),
            if (profile!['preferred_format'] != null)
              FLTag('${profile!['preferred_format']} 선호', color: FL.lavender),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
              onPressed: onDiagnose,
              style: TextButton.styleFrom(foregroundColor: FL.textSec),
              child: const Text('다시 진단'),
            ),
            TextButton(
              onPressed: onFull,
              style: TextButton.styleFrom(foregroundColor: FL.textSec),
              child: const Text('정밀 진단(22문항)'),
            ),
          ]),
        ],
      ),
    ));
  }
}

// ── 이어서 학습 ──────────────────────────────────────────────────

class _ContinueCard extends StatelessWidget {
  final String roomTitle;
  final String lectureTitle;
  final int progress;
  final bool diagnosed;
  final VoidCallback onTap;
  const _ContinueCard({
    required this.roomTitle,
    required this.lectureTitle,
    required this.progress,
    required this.diagnosed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FL.r20),
        gradient: const LinearGradient(colors: [Color(0xFF1F2A0B), Color(0xFF15151D)]),
        border: Border.all(color: FL.lime.withValues(alpha: 0.25)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 18,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FLLabel('이어서 학습', color: FL.lime),
              const SizedBox(height: 10),
              Text(lectureTitle,
                  style: const TextStyle(color: FL.text, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(roomTitle, style: const TextStyle(color: FL.textSec, fontSize: 14)),
              const SizedBox(height: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 6,
                      color: FL.lime,
                      backgroundColor: FL.surface3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('진도 $progress%',
                    style: const TextStyle(color: FL.textSec, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          FLButton(diagnosed ? '맞춤 교안 열기' : '교안 열기',
              trailingIcon: Icons.arrow_forward_rounded, large: true, onPressed: onTap),
        ],
      ),
    );
  }
}

// ── 강의실 카드 ──────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final List<Map<String, dynamic>> lectures;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback onQuiz;
  const _RoomCard({required this.room, required this.lectures, required this.onOpen, required this.onQuiz});

  static String? _level(String? v) => switch (v) {
        'beginner' => '입문',
        'intermediate' => '중급',
        'advanced' => '고급',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final completed = ((room['completed_lecture_count'] as num?) ?? 0).toInt();
    final level = _level(room['subject_level'] as String?);
    final hasQuiz = room['has_quiz'] == true;
    return FLCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room['subject'] as String? ?? '',
                    style: const TextStyle(color: FL.text, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${room['professor_name'] ?? ''} · 강의 ${lectures.length}개 · 완료 $completed개',
                  style: const TextStyle(color: FL.textMute, fontSize: 13),
                ),
              ]),
            ),
            if (level != null)
              FLTag('과목 수준 · $level', color: FL.sky, icon: Icons.signal_cellular_alt_rounded)
            else if (hasQuiz)
              TextButton.icon(
                onPressed: onQuiz,
                icon: const Icon(Icons.quiz_outlined, size: 16),
                label: const Text('과목 수준 퀴즈 (2분)'),
                style: TextButton.styleFrom(foregroundColor: FL.sky),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        for (var i = 0; i < lectures.length; i++)
          _LectureRow(
            index: i + 1,
            lecture: lectures[i],
            done: i < completed,
            onTap: () => onOpen(lectures[i]),
          ),
        if (lectures.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('교수님이 교안을 준비하고 있어요.', style: TextStyle(color: FL.textMute, fontSize: 13.5)),
          ),
      ]),
    );
  }
}

class _LectureRow extends StatefulWidget {
  final int index;
  final Map<String, dynamic> lecture;
  final bool done;
  final VoidCallback onTap;
  const _LectureRow({required this.index, required this.lecture, required this.done, required this.onTap});

  @override
  State<_LectureRow> createState() => _LectureRowState();
}

class _LectureRowState extends State<_LectureRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
          decoration: BoxDecoration(
            color: _hover ? FL.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.done ? FL.lime.withValues(alpha: 0.15) : FL.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: widget.done
                  ? const Icon(Icons.check_rounded, size: 15, color: FL.lime)
                  : Text('${widget.index}',
                      style: const TextStyle(color: FL.textSec, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.lecture['title'] as String? ?? '',
                  style: TextStyle(
                    color: widget.done ? FL.textSec : FL.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            Icon(Icons.chevron_right_rounded, color: _hover ? FL.lime : FL.textMute, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final bool loading;
  final VoidCallback onEnroll;
  const _DiscoverCard({required this.room, required this.loading, required this.onEnroll});

  @override
  Widget build(BuildContext context) {
    final desc = (room['description'] as String?)?.trim().isNotEmpty == true
        ? room['description'] as String
        : (room['synopsis'] as String? ?? '');
    return FLCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(room['subject'] as String? ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: FL.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: FL.textSec, fontSize: 13, height: 1.5)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text(room['professor_name'] as String? ?? '',
                overflow: TextOverflow.ellipsis, style: const TextStyle(color: FL.textMute, fontSize: 12.5)),
          ),
          FLButton('수강하기', kind: FLButtonKind.secondary, loading: loading, onPressed: onEnroll),
        ]),
      ]),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FLSkeleton(height: 30, width: 300),
      SizedBox(height: 12),
      FLSkeleton(height: 16, width: 360),
      SizedBox(height: 28),
      FLSkeleton(height: 70, radius: 16),
      SizedBox(height: 16),
      FLSkeleton(height: 150, radius: 20),
      SizedBox(height: 40),
      FLSkeleton(height: 220, radius: 16),
    ]);
  }
}
