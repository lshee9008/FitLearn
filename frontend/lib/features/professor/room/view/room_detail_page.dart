import 'package:fitlearn/features/auth/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/room_data_providers.dart';
import '../../../../shared/services/api_service.dart';

// ── 컬러 ─────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0E0E11);
  static const surface = Color(0xFF13131A);
  static const surface2 = Color(0xFF1A1A24);
  static const border = Color(0xFF1E1E2A);
  static const border2 = Color(0xFF252532);
  static const lime = Color(0xFFC8F135);
  static const limeDark = Color(0xFF1A2400);
  static const lavender = Color(0xFFA78BFA);
  static const lavMid = Color(0xFF1E1830);
  static const coral = Color(0xFFFB7185);
  static const coralDark = Color(0xFF3D0A14);
  static const amber = Color(0xFFFBBF24);
  static const amberDark = Color(0xFF3D2800);
  static const mint = Color(0xFF34D399);
  static const mintDark = Color(0xFF064E3B);
  static const textPri = Color(0xFFF0F0F4);
  static const textSec = Color(0xFF8888A0);
  static const textMute = Color(0xFF4A4A5A);
}

// ── 학습 유형 유틸 ────────────────────────────────────────────────
class _StyleUtil {
  static Color color(String style) {
    if (style.contains('요약')) return _C.lime;
    if (style.contains('상세')) return _C.lavender;
    if (style.contains('예시')) return _C.mint;
    return _C.amber;
  }

  static String emoji(String style) {
    if (style.contains('요약')) return '⚡';
    if (style.contains('상세')) return '📖';
    if (style.contains('예시')) return '💡';
    return '🎯';
  }
}

// ══════════════════════════════════════════════════════════════════
class RoomDetailPage extends ConsumerStatefulWidget {
  final String roomId;
  const RoomDetailPage({super.key, required this.roomId});

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  int _selectedIndex = 0;

  // ── 공지 생성 ─────────────────────────────────────────────────
  Future<void> _createNotice(Map<String, dynamic> room) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogShell(
        title: '공지 작성',
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(ctrl: titleCtrl, label: '제목'),
          const SizedBox(height: 12),
          _DialogField(ctrl: contentCtrl, label: '내용', maxLines: 6),
        ]),
        actions: [
          _DlgBtn(label: '취소', onTap: () => Navigator.pop(context, false)),
          _DlgBtn(
              label: '등록',
              primary: true,
              onTap: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (created != true || !mounted) return;
    try {
      await ApiService().createNotice(
        widget.roomId,
        room['professor_uid'] as String? ?? '',
        contentCtrl.text.trim(),
        title: titleCtrl.text.trim(),
      );
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('공지 등록 오류: $e')));
    }
  }

  // ── 공지 삭제 ─────────────────────────────────────────────────
  Future<void> _deleteNotice(Map<String, dynamic> notice) async {
    try {
      await ApiService()
          .deleteNotice(widget.roomId, notice['notice_id'] as String);
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('공지 삭제 오류: $e')));
    }
  }

  // ── 강의 편집 ─────────────────────────────────────────────────
  Future<void> _editLecture(Map<String, dynamic> lecture) async {
    final titleCtrl =
        TextEditingController(text: lecture['title'] as String? ?? '');
    final videoCtrl =
        TextEditingController(text: lecture['video_url'] as String? ?? '');
    final materialCtrl =
        TextEditingController(text: lecture['material_url'] as String? ?? '');
    final weekCtrl = TextEditingController(
        text: ((lecture['week_number'] as int?) ?? 0).toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogShell(
        title: '강의 항목 편집',
        width: 500,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(ctrl: titleCtrl, label: '강의 제목'),
          const SizedBox(height: 12),
          _DialogField(
              ctrl: weekCtrl, label: '주차', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _DialogField(ctrl: videoCtrl, label: '영상 링크'),
          const SizedBox(height: 12),
          _DialogField(ctrl: materialCtrl, label: '보조 자료 링크'),
        ]),
        actions: [
          _DlgBtn(label: '취소', onTap: () => Navigator.pop(context, false)),
          _DlgBtn(
              label: '저장',
              primary: true,
              onTap: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await ApiService()
          .updateLectureMeta(widget.roomId, lecture['lecture_id'] as String, {
        'title': titleCtrl.text.trim(),
        'week_number': int.tryParse(weekCtrl.text.trim()) ?? 0,
        'video_url': videoCtrl.text.trim(),
        'material_url': materialCtrl.text.trim(),
      });
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('강의 수정 오류: $e')));
    }
  }

  // ── 강의 순서 이동 ────────────────────────────────────────────
  Future<void> _moveLecture(
      List<dynamic> lectures, int index, int delta) async {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= lectures.length) return;
    final reordered = [...lectures];
    final current = reordered.removeAt(index);
    reordered.insert(nextIndex, current);
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < reordered.length; i++) {
      final lec = reordered[i] as Map<String, dynamic>;
      items.add({'lecture_id': lec['lecture_id'], 'order_index': i + 1});
    }
    try {
      await ApiService().reorderLectures(widget.roomId, items);
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('강의 정렬 오류: $e')));
    }
  }

  // ── 강의 삭제 ─────────────────────────────────────────────────
  Future<void> _deleteLecture(Map<String, dynamic> lecture) async {
    try {
      await ApiService()
          .deleteLecture(widget.roomId, lecture['lecture_id'] as String);
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('강의 삭제 오류: $e')));
    }
  }

  // ── 수강 신청 처리 ────────────────────────────────────────────
  Future<void> _reviewApplication(
      Map<String, dynamic> application, String status) async {
    try {
      await ApiService().reviewRoomApplication(
        roomId: widget.roomId,
        userId: application['user_id'] as String,
        status: status,
      );
      // 1. 상세 화면 갱신
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
      ref.invalidate(currentProfessorRoomsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('신청 처리 오류: $e')));
    }
  }

  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(professorRoomDetailProvider(widget.roomId));
    final summary = summaryAsync.valueOrNull;
    final room = summary?.room;
    final lectures = summary?.lectures ?? const <dynamic>[];
    final students = summary?.students ?? const <dynamic>[];
    final notices = summary?.notices ?? const <dynamic>[];
    final applications = summary?.applications ?? const <dynamic>[];

    final pendingApplications = applications
        .where((a) => (a as Map<String, dynamic>)['status'] == 'pending')
        .cast<Map<String, dynamic>>()
        .toList();

    final roomName = room?['subject'] as String? ?? '강의 방';
    final roomCode = room?['room_code'] as String? ?? '';

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        // ── 상단 헤더 ──────────────────────────────────────────
        _buildTopBar(roomName, roomCode),
        // ── 본문 ───────────────────────────────────────────────
        Expanded(
          child: summaryAsync.isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: _C.lime, strokeWidth: 2))
              : summaryAsync.hasError || room == null
                  ? const Center(
                      child: Text('강의실 데이터를 불러오지 못했습니다',
                          style: TextStyle(color: _C.textMute)),
                    )
                  : Row(children: [
                      // 왼쪽 패널
                      _LeftPanel(
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() => _selectedIndex = i),
                        students: students,
                        lectures: lectures,
                        notices: notices,
                        pendingCount: pendingApplications.length,
                        roomId: widget.roomId,
                      ),
                      // 오른쪽 콘텐츠
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: [
                            _buildLectures(lectures),
                            _buildNotices(room, notices),
                            _buildStudents(room, students, applications,
                                pendingApplications),
                            _buildSettings(room),
                          ],
                        ),
                      ),
                    ]),
        ),
      ]),
    );
  }

  // ── 상단 헤더 ─────────────────────────────────────────────────
  Widget _buildTopBar(String roomName, String roomCode) {
    return Container(
      height: 52,
      color: _C.surface,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _C.textSec, size: 16),
          onPressed: () => context.go('/professor/home'),
          splashRadius: 18,
        ),
        const SizedBox(width: 4),
        Text(roomName,
            style: const TextStyle(
                color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (roomCode.isNotEmpty)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('방 코드가 복사되었습니다')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _C.limeDark,
                border: Border.all(color: _C.lime.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.key_rounded, size: 12, color: _C.lime),
                const SizedBox(width: 6),
                Text(roomCode,
                    style: const TextStyle(
                        color: _C.lime,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3)),
              ]),
            ),
          ),
        const SizedBox(width: 12),
        IconButton(
          icon:
              const Icon(Icons.dashboard_rounded, color: _C.textSec, size: 20),
          onPressed: () =>
              context.push('/professor/dashboard/${widget.roomId}'),
          splashRadius: 18,
          tooltip: '대시보드',
        ),
      ]),
    );
  }

  // ── 교안 탭 ───────────────────────────────────────────────────
  Widget _buildLectures(List<dynamic> lectures) {
    return Column(children: [
      _TabHeader(
        title: '교안 관리',
        sub: '${lectures.length}개의 강의 항목',
        action: _ActionBtn(
          label: '자료 업로드',
          icon: Icons.upload_file_rounded,
          color: _C.lime,
          onTap: () =>
              context.push('/professor/lecture/${widget.roomId}/upload'),
        ),
      ),
      Expanded(
        child: lectures.isEmpty
            ? const _EmptyState(
                icon: '📄', message: '아직 교안이 없습니다', sub: '교안 업로드 버튼을 눌러 시작하세요')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                itemCount: lectures.length,
                itemBuilder: (_, i) {
                  final lec = lectures[i] as Map<String, dynamic>;
                  final confirmed = lec['confirmed'] as bool? ?? false;
                  final order = lec['order_index'] as int? ?? (i + 1);
                  final hasVideo =
                      (lec['video_url'] as String? ?? '').trim().isNotEmpty;
                  final hasMat = (lec['original_file_url'] as String? ?? '')
                          .trim()
                          .isNotEmpty ||
                      (lec['material_url'] as String? ?? '').trim().isNotEmpty;
                  return _LectureCard(
                    lec: lec,
                    order: order,
                    confirmed: confirmed,
                    hasVideo: hasVideo,
                    hasMaterial: hasMat,
                    isFirst: i == 0,
                    isLast: i == lectures.length - 1,
                    onEdit: () => _editLecture(lec),
                    onDelete: () => _deleteLecture(lec),
                    onUp: i == 0 ? null : () => _moveLecture(lectures, i, -1),
                    onDown: i == lectures.length - 1
                        ? null
                        : () => _moveLecture(lectures, i, 1),
                  );
                },
              ),
      ),
    ]);
  }

  // ── 공지 탭 ───────────────────────────────────────────────────
  Widget _buildNotices(Map<String, dynamic> room, List<dynamic> notices) {
    return Column(children: [
      _TabHeader(
        title: '공지사항',
        sub: '${notices.length}개의 공지가 학생에게 노출됩니다',
        action: _ActionBtn(
          label: '공지 작성',
          icon: Icons.edit_rounded,
          color: _C.amber,
          onTap: () => _createNotice(room),
        ),
      ),
      Expanded(
        child: notices.isEmpty
            ? const _EmptyState(icon: '📢', message: '아직 등록된 공지가 없습니다')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                itemCount: notices.length,
                itemBuilder: (_, i) {
                  final notice = notices[i] as Map<String, dynamic>;
                  return _NoticeCard(
                    notice: notice,
                    onDelete: () => _deleteNotice(notice),
                  );
                },
              ),
      ),
    ]);
  }

  // ── 수강생 탭 ─────────────────────────────────────────────────
  Widget _buildStudents(
    Map<String, dynamic> room,
    List<dynamic> students,
    List<dynamic> applications,
    List<Map<String, dynamic>> pendingApplications,
  ) {
    return Column(children: [
      _TabHeader(
        title: '수강생',
        sub: '총 ${students.length}명 수강 중',
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            // 승인 대기 섹션
            if (pendingApplications.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _C.coralDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.coral.withValues(alpha: 0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.pending_rounded,
                            color: _C.coral, size: 15),
                        const SizedBox(width: 6),
                        const Text('수강 신청 대기',
                            style: TextStyle(
                                color: _C.coral,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _C.coral.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _C.coral.withValues(alpha: 0.3)),
                          ),
                          child: Text('${pendingApplications.length}명',
                              style: const TextStyle(
                                  color: _C.coral,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      ...pendingApplications.map((app) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _C.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _C.border),
                              ),
                              child: Row(children: [
                                _Avatar(
                                    name: app['student_name'] as String? ?? '?',
                                    color: _C.coral,
                                    bg: _C.coralDark),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(app['student_name'] as String? ?? '',
                                          style: const TextStyle(
                                              color: _C.textPri,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      if ((app['note'] as String? ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        Text(app['note'] as String,
                                            style: const TextStyle(
                                                color: _C.textSec,
                                                fontSize: 11)),
                                    ])),
                                GestureDetector(
                                  onTap: () =>
                                      _reviewApplication(app, 'rejected'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _C.coralDark,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color:
                                              _C.coral.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text('반려',
                                        style: TextStyle(
                                            color: _C.coral,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () =>
                                      _reviewApplication(app, 'approved'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _C.lime,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('승인',
                                        style: TextStyle(
                                            color: _C.limeDark,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ]),
                            ),
                          )),
                    ]),
              ),
              const SizedBox(height: 16),
            ],
            // 수강생 목록
            if (students.isEmpty)
              const _EmptyState(icon: '👩‍🎓', message: '아직 입장한 학생이 없습니다')
            else
              ...students.map((raw) {
                final s = raw as Map<String, dynamic>;
                final style = s['primary_style'] as String?;
                final styleColor =
                    style != null ? _StyleUtil.color(style) : _C.lavender;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.border),
                    ),
                    child: Row(children: [
                      _Avatar(
                          name: s['name'] as String? ?? '?',
                          color: styleColor,
                          bg: _C.lavMid),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(s['name'] as String? ?? '',
                                style: const TextStyle(
                                    color: _C.textPri,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            if (style != null)
                              Text(
                                  '${_StyleUtil.emoji(style)} $style'
                                  '${(s['social_type'] as String?)?.isNotEmpty == true ? " · ${s['social_type']}" : ""}'
                                  '${(s['cognitive_type'] as String?)?.isNotEmpty == true ? " · ${s['cognitive_type']}" : ""}',
                                  style: const TextStyle(
                                      color: _C.textMute, fontSize: 11)),
                          ])),
                      if (style != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _C.lavMid,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: styleColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(style,
                              style: TextStyle(
                                  color: styleColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ),
    ]);
  }

  // ── 설정 탭 ───────────────────────────────────────────────────
  Widget _buildSettings(Map<String, dynamic> room) {
    final ctrlSynopsis = TextEditingController(text: room['synopsis'] ?? '');
    final ctrlConcepts = TextEditingController(
        text: ((room['core_concepts'] as List<dynamic>?) ?? []).join(', '));
    final ctrlYoutube = TextEditingController(text: room['youtube_url'] ?? '');

    return Column(children: [
      const _TabHeader(title: '강의실 설정', sub: '강의 정보 및 AI 학습 설정을 관리합니다'),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.border),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLabel('강의 줄거리 / 목표'),
              const SizedBox(height: 8),
              _SettingsField(ctrl: ctrlSynopsis, maxLines: 3),
              const SizedBox(height: 20),
              const _FieldLabel('핵심 개념 (쉼표 구분) — AI 퀴즈 자동 생성에 사용됨'),
              const SizedBox(height: 8),
              _SettingsField(ctrl: ctrlConcepts),
              const SizedBox(height: 20),
              const _FieldLabel('YouTube URL (온라인 강의 시)'),
              const SizedBox(height: 8),
              _SettingsField(ctrl: ctrlYoutube),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () async {
                  final concepts = ctrlConcepts.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  try {
                    await ApiService().updateRoomMeta(widget.roomId, {
                      'synopsis': ctrlSynopsis.text.trim(),
                      'core_concepts': concepts,
                      'youtube_url': ctrlYoutube.text.trim(),
                    });
                    ref.invalidate(professorRoomDetailProvider(widget.roomId));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('설정이 저장되었습니다.')));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('오류: $e')));
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _C.lime,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('변경사항 저장 및 AI 재생성',
                        style: TextStyle(
                            color: _C.limeDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// 왼쪽 사이드 패널
// ══════════════════════════════════════════════════════════════════
class _LeftPanel extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<dynamic> students;
  final List<dynamic> lectures;
  final List<dynamic> notices;
  final int pendingCount;
  final String roomId;

  const _LeftPanel({
    required this.selectedIndex,
    required this.onSelect,
    required this.students,
    required this.lectures,
    required this.notices,
    required this.pendingCount,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _C.surface,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _C.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 네비 목록
        Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('강의 관리',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.textMute,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _NavItem(
                icon: Icons.menu_book_rounded,
                label: '교안 관리',
                index: 0,
                accentColor: _C.lime,
                selected: selectedIndex == 0,
                onTap: onSelect),
            _NavItem(
                icon: Icons.campaign_rounded,
                label: '공지사항',
                index: 1,
                accentColor: _C.amber,
                selected: selectedIndex == 1,
                onTap: onSelect),
            _NavItem(
                icon: Icons.people_rounded,
                label: '수강생',
                index: 2,
                accentColor: _C.lavender,
                selected: selectedIndex == 2,
                onTap: onSelect),
            _NavItem(
                icon: Icons.settings_rounded,
                label: '설정',
                index: 3,
                accentColor: _C.textSec,
                selected: selectedIndex == 3,
                onTap: onSelect),
          ]),
        ),

        const Divider(color: _C.border, height: 1),

        // 통계 요약
        Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('강의실 현황',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.textMute,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _StatRow(
                label: '총 수강생',
                value: '${students.length}명',
                color: _C.lavender),
            const SizedBox(height: 8),
            _StatRow(
                label: '강의 항목', value: '${lectures.length}개', color: _C.lime),
            const SizedBox(height: 8),
            _StatRow(
                label: '공지사항', value: '${notices.length}개', color: _C.amber),
            if (pendingCount > 0) ...[
              const SizedBox(height: 8),
              _StatRow(
                  label: '승인 대기', value: '$pendingCount명', color: _C.coral),
            ],
          ]),
        ),

        const Spacer(),

        // 교안 업로드 버튼
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: GestureDetector(
            onTap: () => context.push('/professor/lecture/$roomId/upload'),
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: _C.lime,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file_rounded, color: _C.limeDark, size: 16),
                  SizedBox(width: 6),
                  Text('교안 업로드',
                      style: TextStyle(
                          color: _C.limeDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── 네비 아이템 ───────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final Color accentColor;
  final bool selected;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _C.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _C.border2 : Colors.transparent),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color:
                  selected ? accentColor.withValues(alpha: 0.15) : _C.surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 15, color: selected ? accentColor : _C.textMute),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: selected ? _C.textPri : _C.textMute,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          if (selected) ...[
            const Spacer(),
            Container(
              width: 4,
              height: 4,
              decoration:
                  const BoxDecoration(color: _C.lime, shape: BoxShape.circle),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── 통계 행 ───────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _C.textMute, fontSize: 11)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── 탭 공통 헤더 ──────────────────────────────────────────────────
class _TabHeader extends StatelessWidget {
  final String title;
  final String sub;
  final Widget? action;
  const _TabHeader({required this.title, required this.sub, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: _C.textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: _C.textMute, fontSize: 12)),
        ]),
        const Spacer(),
        if (action != null) action!,
      ]),
    );
  }
}

// ── 교안 카드 ─────────────────────────────────────────────────────
class _LectureCard extends StatelessWidget {
  final Map<String, dynamic> lec;
  final int order;
  final bool confirmed;
  final bool hasVideo;
  final bool hasMaterial;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  const _LectureCard({
    required this.lec,
    required this.order,
    required this.confirmed,
    required this.hasVideo,
    required this.hasMaterial,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = confirmed ? _C.lime : _C.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 상단 액센트 라인
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              // 순서 번호
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _C.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('$order강',
                      style: const TextStyle(
                          color: _C.lime,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(lec['title'] as String? ?? '',
                        style: const TextStyle(
                            color: _C.textPri,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: confirmed
                              ? _C.mint.withValues(alpha: 0.1)
                              : _C.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: confirmed
                                ? _C.mint.withValues(alpha: 0.2)
                                : _C.amber.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          confirmed ? '✓ 활성화됨' : '검토 대기',
                          style: TextStyle(
                              color: confirmed ? _C.mint : _C.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ])),
              // 순서 이동
              Column(children: [
                _ArrowBtn(
                  icon: Icons.keyboard_arrow_up_rounded,
                  enabled: onUp != null,
                  onTap: onUp,
                ),
                _ArrowBtn(
                  icon: Icons.keyboard_arrow_down_rounded,
                  enabled: onDown != null,
                  onTap: onDown,
                ),
              ]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _MetaPill(
                icon: hasVideo
                    ? Icons.ondemand_video_rounded
                    : Icons.videocam_off_rounded,
                label: hasVideo ? '영상 연결됨' : '영상 없음',
                color: hasVideo ? _C.lavender : _C.textMute,
              ),
              const SizedBox(width: 8),
              _MetaPill(
                icon: hasMaterial
                    ? Icons.attach_file_rounded
                    : Icons.note_add_outlined,
                label: hasMaterial ? '자료 연결됨' : '자료 없음',
                color: hasMaterial ? _C.mint : _C.textMute,
              ),
              const Spacer(),
              _ActionBtn(
                label: '편집',
                icon: Icons.edit_rounded,
                color: _C.textSec,
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                label: '삭제',
                icon: Icons.delete_outline_rounded,
                color: _C.coral,
                onTap: onDelete,
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── 공지 카드 ─────────────────────────────────────────────────────
class _NoticeCard extends StatelessWidget {
  final Map<String, dynamic> notice;
  final VoidCallback onDelete;
  const _NoticeCard({required this.notice, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final title = (notice['title'] as String?)?.trim().isNotEmpty == true
        ? notice['title'] as String
        : '제목 없는 공지';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 2,
          decoration: const BoxDecoration(
            color: _C.amber,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _C.textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              _ActionBtn(
                label: '삭제',
                icon: Icons.delete_outline_rounded,
                color: _C.coral,
                onTap: onDelete,
              ),
            ]),
            const SizedBox(height: 10),
            Text(notice['content'] as String? ?? '',
                style: const TextStyle(
                    color: _C.textSec, fontSize: 12, height: 1.7)),
            const SizedBox(height: 10),
            Text(notice['created_at'] as String? ?? '',
                style: const TextStyle(color: _C.textMute, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }
}

// ── 화살표 버튼 ───────────────────────────────────────────────────
class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _ArrowBtn({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: _C.surface2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: enabled ? _C.textSec : _C.textMute),
      ),
    );
  }
}

// ── 액션 버튼 ─────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── 메타 필 ───────────────────────────────────────────────────────
class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── 아바타 ────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  final Color bg;
  const _Avatar({required this.name, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    return Container(
      width: 36,
      height: 36,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Center(
        child: Text(initial,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}

// ── 빈 상태 ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String icon;
  final String message;
  final String? sub;
  const _EmptyState({required this.icon, required this.message, this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: _C.textSec, fontSize: 15)),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub!, style: const TextStyle(color: _C.textMute, fontSize: 12)),
        ],
      ]),
    );
  }
}

// ── 설정 필드 ─────────────────────────────────────────────────────
class _SettingsField extends StatelessWidget {
  final TextEditingController ctrl;
  final int maxLines;
  const _SettingsField({required this.ctrl, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: _C.textPri, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: _C.surface2,
        hintStyle: const TextStyle(color: _C.textMute),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.lime, width: 1.5),
        ),
      ),
    );
  }
}

// ── 필드 라벨 ─────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600));
  }
}

// ── 다이얼로그 셸 ─────────────────────────────────────────────────
class _DialogShell extends StatelessWidget {
  final String title;
  final double width;
  final Widget child;
  final List<Widget> actions;
  const _DialogShell({
    required this.title,
    required this.width,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(
                      color: _C.textPri,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children:
                  actions.expand((w) => [w, const SizedBox(width: 8)]).toList()
                    ..removeLast(),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  const _DialogField({
    required this.ctrl,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: _C.textPri, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _C.textSec, fontSize: 13),
        filled: true,
        fillColor: _C.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: _C.lime, width: 1.5),
        ),
      ),
    );
  }
}

class _DlgBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _DlgBtn(
      {required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? _C.lime : _C.surface2,
          borderRadius: BorderRadius.circular(10),
          border: primary ? null : Border.all(color: _C.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? _C.limeDark : _C.textSec,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
