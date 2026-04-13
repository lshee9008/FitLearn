import 'package:file_picker/file_picker.dart';
import 'package:fitlearn/features/auth/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/room_data_providers.dart';
import '../../../../shared/services/api_service.dart';
import '../../lecture/view/core_point_review_page.dart';

// ── 지원 확장자 ────────────────────────────────────────────────────
const _allowedExtensions = [
  'pdf',
  'ppt',
  'pptx',
  'docx',
  'hwp',
  'hwpx',
  'md',
  'txt',
  'py',
  'js',
  'ts',
  'java',
  'c',
  'cpp',
  'cs',
  'go',
  'rs',
  'kt',
  'swift',
  'jpg',
  'jpeg',
  'png',
  'webp',
  'csv',
  'json',
  'xml',
];
const _videoExtensions = ['mp4', 'mov', 'webm', 'm4v'];

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
  static const mint = Color(0xFF34D399);
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
  final bool createMode;
  const RoomDetailPage({
    super.key,
    required this.roomId,
    this.createMode = false,
  });

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _LectureDraft {
  final TextEditingController titleCtrl = TextEditingController();
  PlatformFile? materialFile;
  PlatformFile? videoFile;

  void dispose() {
    titleCtrl.dispose();
  }
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  // ── 탭 ──────────────────────────────────────────────────────────
  int _selectedIndex = 0;

  // ── 강의 인라인 폼 상태 ──────────────────────────────────────────
  bool _showLectureForm = false;
  Map<String, dynamic>? _editingLecture; // null = 신규 생성
  PlatformFile? _lectureFile;
  PlatformFile? _videoFile;
  bool _uploadingLecture = false;
  String? _uploadError;
  final _lectureTitleCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _roomNameCtrl = TextEditingController();
  final _roomDescCtrl = TextEditingController();
  final _roomCurriculumCtrl = TextEditingController();
  final _roomPriceCtrl = TextEditingController();
  PlatformFile? _curriculumFile;
  final List<_LectureDraft> _lectureDrafts = [_LectureDraft()];
  bool _creatingRoom = false;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [
      _lectureTitleCtrl,
      _videoUrlCtrl,
      _roomNameCtrl,
      _roomDescCtrl,
      _roomCurriculumCtrl,
      _roomPriceCtrl,
    ]) {
      ctrl.addListener(_refreshFormState);
    }
    _lectureDrafts.first.titleCtrl.addListener(_refreshFormState);
  }

  @override
  void dispose() {
    _lectureTitleCtrl.dispose();
    _videoUrlCtrl.dispose();
    _roomNameCtrl.dispose();
    _roomDescCtrl.dispose();
    _roomCurriculumCtrl.dispose();
    _roomPriceCtrl.dispose();
    for (final draft in _lectureDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _refreshFormState() {
    if (mounted) setState(() {});
  }

  // ── 폼 열기: 신규 ─────────────────────────────────────────────
  void _openCreateForm() {
    _editingLecture = null;
    _lectureFile = null;
    _videoFile = null;
    _uploadError = null;
    _lectureTitleCtrl.clear();
    _videoUrlCtrl.clear();
    setState(() => _showLectureForm = true);
  }

  // ── 폼 열기: 수정 ─────────────────────────────────────────────
  void _openEditForm(Map<String, dynamic> lec) {
    _editingLecture = lec;
    _lectureFile = null;
    _videoFile = null;
    _uploadError = null;
    _lectureTitleCtrl.text = lec['title'] as String? ?? '';
    _videoUrlCtrl.text = lec['video_url'] as String? ?? '';
    setState(() => _showLectureForm = true);
  }

  // ── 파일 선택 ─────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      final f = r.files.first;
      setState(() {
        _lectureFile = f;
        _uploadError = null;
        if (_lectureTitleCtrl.text.trim().isEmpty) {
          final name = f.name;
          _lectureTitleCtrl.text = name.contains('.')
              ? name.substring(0, name.lastIndexOf('.'))
              : name;
        }
      });
    }
  }

  Future<void> _pickVideoFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _videoExtensions,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      setState(() {
        _videoFile = r.files.first;
        _uploadError = null;
      });
    }
  }

  Future<void> _pickCurriculumFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      setState(() => _curriculumFile = r.files.first);
    }
  }

  Future<void> _pickDraftMaterial(_LectureDraft draft) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      final file = r.files.first;
      setState(() {
        draft.materialFile = file;
        if (draft.titleCtrl.text.trim().isEmpty) {
          draft.titleCtrl.text = file.name.contains('.')
              ? file.name.substring(0, file.name.lastIndexOf('.'))
              : file.name;
        }
      });
    }
  }

  Future<void> _pickDraftVideo(_LectureDraft draft) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _videoExtensions,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      setState(() => draft.videoFile = r.files.first);
    }
  }

  void _addLectureDraft() {
    final draft = _LectureDraft();
    draft.titleCtrl.addListener(_refreshFormState);
    setState(() => _lectureDrafts.add(draft));
  }

  void _removeLectureDraft(int index) {
    if (_lectureDrafts.length == 1) return;
    final draft = _lectureDrafts.removeAt(index);
    draft.dispose();
    setState(() {});
  }

  bool get _canCreateRoomWithLectures {
    if (_creatingRoom) return false;
    if (_roomNameCtrl.text.trim().isEmpty) return false;
    return _lectureDrafts.any((draft) =>
        draft.titleCtrl.text.trim().isNotEmpty ||
        draft.materialFile != null ||
        draft.videoFile != null);
  }

  Future<void> _submitRoomWithLectures() async {
    if (!_canCreateRoomWithLectures) return;
    final user = ref.read(authNotifierProvider);
    if (user == null) return;

    for (var i = 0; i < _lectureDrafts.length; i++) {
      final draft = _lectureDrafts[i];
      final hasAny = draft.titleCtrl.text.trim().isNotEmpty ||
          draft.materialFile != null ||
          draft.videoFile != null;
      if (!hasAny) continue;
    }

    setState(() {
      _creatingRoom = true;
      _uploadError = null;
    });

    try {
      final concepts = _roomCurriculumCtrl.text
          .split('\n')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      final price = int.tryParse(
            _roomPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      final roomData = await ApiService().createRoom(
        professorUid: user.userId,
        subject: _roomNameCtrl.text.trim(),
        description: _roomDescCtrl.text.trim(),
        roomType: 'online',
        synopsis: _roomDescCtrl.text.trim(),
        coreConcepts: concepts,
        price: price,
      );
      final roomId = roomData['room_id'] as String? ?? '';
      if (roomId.isEmpty) throw Exception('생성된 강의실 ID가 없습니다.');

      final extractedConcepts = <String>[];
      final shellLectures = <Map<String, dynamic>>[];
      final shellDrafts = <_LectureDraft>[];
      for (var i = 0; i < _lectureDrafts.length; i++) {
        final draft = _lectureDrafts[i];
        final title = draft.titleCtrl.text.trim();
        if (title.isEmpty &&
            draft.materialFile == null &&
            draft.videoFile == null) continue;
        if (draft.materialFile == null) {
          shellLectures.add({
            'title': title.isEmpty ? '${i + 1}강' : title,
            'order': i + 1,
            'video_url': '',
            'material_url': '',
          });
          shellDrafts.add(draft);
          continue;
        }

        final uploadData = await ApiService().uploadLecture(
          roomId: roomId,
          professorUid: user.userId,
          fileBytes: draft.materialFile!.bytes!,
          fileName: draft.materialFile!.name,
          weekNumber: 0,
          lectureTitle: title.isEmpty ? '${i + 1}강' : title,
          orderIndex: i + 1,
          videoFileBytes: draft.videoFile?.bytes,
          videoFileName: draft.videoFile?.name,
        );
        final lectureId = uploadData['lecture_id'] as String? ?? '';
        final points = (uploadData['core_points'] as List<dynamic>? ?? const [])
            .map((point) => Map<String, dynamic>.from(point as Map))
            .toList();
        if (lectureId.isNotEmpty) {
          if (!mounted) return;
          setState(() => _creatingRoom = false);
          final confirmed = await _openCorePointReviewDialog(
            roomId: roomId,
            lectureId: lectureId,
            uploadData: uploadData,
          );
          if (!mounted) return;
          if (confirmed != true) {
            ref.invalidate(currentProfessorRoomsProvider);
            ref.invalidate(professorRoomDetailProvider(roomId));
            setState(() {
              _creatingRoom = false;
              _uploadError = '핵심포인트 확정을 마치면 이어서 강의실을 생성합니다.';
            });
            return;
          }
          setState(() => _creatingRoom = true);
          extractedConcepts.addAll(
            points
                .map((point) => (point['content'] as String? ?? '').trim())
                .where((value) => value.isNotEmpty),
          );
        }
      }
      if (shellLectures.isNotEmpty) {
        final shellResult =
            await ApiService().createLectureShells(roomId, shellLectures);
        final created = (shellResult['lectures'] as List<dynamic>? ?? const []);
        for (var i = 0; i < created.length && i < shellDrafts.length; i++) {
          final draft = shellDrafts[i];
          if (draft.videoFile == null) continue;
          final lecture = Map<String, dynamic>.from(created[i] as Map);
          final lectureId = lecture['lecture_id'] as String? ?? '';
          final bytes = draft.videoFile?.bytes;
          if (lectureId.isEmpty || bytes == null) continue;
          await ApiService().uploadLectureVideoAsset(
            roomId: roomId,
            lectureId: lectureId,
            videoFileBytes: bytes,
            videoFileName: draft.videoFile!.name,
          );
        }
      }
      if (extractedConcepts.isNotEmpty) {
        await ApiService().updateRoomMeta(roomId, {
          'synopsis': _roomDescCtrl.text.trim().isNotEmpty
              ? _roomDescCtrl.text.trim()
              : extractedConcepts.take(4).join('\n'),
          'core_concepts': [
            ...concepts,
            ...extractedConcepts.take(12),
          ],
        });
      }

      ref.invalidate(currentProfessorRoomsProvider);
      ref.invalidate(professorRoomDetailProvider(roomId));
      if (!mounted) return;
      context.go('/professor/room/$roomId');
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = '강의 생성 오류: $e';
          _creatingRoom = false;
        });
      }
    }
  }

  Future<bool?> _openCorePointReviewDialog({
    required String roomId,
    required String lectureId,
    required Map<String, dynamic> uploadData,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 980,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.92,
            ),
            child: CorePointReviewPage(
              roomId: roomId,
              lectureId: lectureId,
              uploadData: uploadData,
              embedded: true,
            ),
          ),
        ),
      ),
    );
  }

  // ── 업로드 / 저장 로직 수정 ─────────────────────────────────────────────
  bool get _canSubmit {
    if (_uploadingLecture) return false;
    final hasTitle = _lectureTitleCtrl.text.trim().isNotEmpty;
    if (_editingLecture != null) return hasTitle; // 수정: 파일 없어도 메타 저장 가능
    return hasTitle && _lectureFile != null; // 신규: 파일 필수
  }

  Future<void> _submitLecture() async {
    if (!_canSubmit) return;
    final isEditing = _editingLecture != null;
    setState(() {
      _uploadingLecture = true;
      _uploadError = null;
    });

    try {
      // 교안(문서) 파일이나, 영상 파일 둘 중 하나라도 새로 선택했다면 통합 업로드 API 호출
      if (!isEditing || _lectureFile != null || _videoFile != null) {
        final user = ref.read(authNotifierProvider);
        if (user == null) {
          throw Exception('로그인 정보를 확인하지 못했습니다. 다시 로그인 후 시도해주세요.');
        }

        final data = await ApiService().uploadLecture(
          roomId: widget.roomId,
          professorUid: user.userId,
          fileBytes: _lectureFile?.bytes, // 문서가 없을 땐 null 전송
          fileName: _lectureFile?.name,
          weekNumber:
              isEditing ? (_editingLecture!['week_number'] as int? ?? 0) : 0,
          lectureTitle: _lectureTitleCtrl.text.trim(),
          lectureId: isEditing
              ? (_editingLecture!['lecture_id'] as String? ?? '')
              : '',
          orderIndex:
              isEditing ? (_editingLecture!['order_index'] as int? ?? 0) : 0,
          videoUrl: '',
          materialUrl: '',
          videoFileBytes: _videoFile?.bytes,
          videoFileName: _videoFile?.name,
        );

        if (!mounted) return;

        // 새 교안(문서)이 업로드된 경우(또는 완전 신규)에만 핵심포인트 다이얼로그 호출
        if (!isEditing || _lectureFile != null) {
          await _openCorePointReviewDialog(
            roomId: widget.roomId,
            lectureId: data['lecture_id'] as String? ?? '',
            uploadData: data,
          );
        }

        if (!mounted) return;
        setState(() {
          _uploadingLecture = false;
          _showLectureForm = false;
        });
        ref.invalidate(professorRoomDetailProvider(widget.roomId));
      } else {
        // 영상도 문서도 변경 없이 메타(제목)만 수정
        await ApiService().updateLectureMeta(
          widget.roomId,
          _editingLecture!['lecture_id'] as String,
          {
            'title': _lectureTitleCtrl.text.trim(),
          },
        );
        ref.invalidate(professorRoomDetailProvider(widget.roomId));
        if (mounted)
          setState(() {
            _showLectureForm = false;
            _uploadingLecture = false;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _uploadError = '오류: $e';
          _uploadingLecture = false;
        });
    }
  }

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
    if (widget.createMode) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: Column(children: [
          _buildTopBar('강의 생성'),
          Expanded(child: _buildRoomCreateLectures()),
        ]),
      );
    }

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
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        _buildTopBar(roomName),
        Expanded(
          child: summaryAsync.isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: _C.lime, strokeWidth: 2))
              : summaryAsync.hasError || room == null
                  ? const Center(
                      child: Text('강의실 데이터를 불러오지 못했습니다',
                          style: TextStyle(color: _C.textMute)))
                  : Row(children: [
                      _LeftPanel(
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() {
                          _selectedIndex = i;
                          _showLectureForm = false;
                        }),
                        students: students,
                        lectures: lectures,
                        notices: notices,
                        pendingCount: pendingApplications.length,
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: [
                            _buildLectures(lectures),
                            _buildNotices(room, notices),
                            _buildStudents(students, pendingApplications),
                          ],
                        ),
                      ),
                    ]),
        ),
      ]),
    );
  }

  // ── 상단 헤더 ─────────────────────────────────────────────────
  Widget _buildTopBar(String roomName) {
    return Container(
      height: 52,
      color: _C.surface,
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _C.border))),
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
      ]),
    );
  }

  // ── 교안 탭 ───────────────────────────────────────────────────
  Widget _buildLectures(List<dynamic> lectures) {
    if (_showLectureForm) return _buildLectureForm();

    // 강의가 없고 폼이 아직 표시안 된 상태면 신규 생성 폼을 바로 보여줌
    if (lectures.isEmpty) {
      return Column(children: [
        _TabHeader(
          title: '교안 관리',
          sub: '첫 번째 강의를 등록해주세요',
          action: _ActionBtn(
            label: '강의 추가',
            icon: Icons.upload_file_rounded,
            color: _C.lime,
            onTap: _openCreateForm,
          ),
        ),
        Expanded(child: _buildLectureFormBody()),
      ]);
    }

    return Column(children: [
      _TabHeader(
        title: '교안 관리',
        sub: '${lectures.length}개의 강의 항목',
        action: _ActionBtn(
          label: '강의 추가',
          icon: Icons.upload_file_rounded,
          color: _C.lime,
          onTap: _openCreateForm,
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          itemCount: lectures.length,
          itemBuilder: (_, i) {
            final lec = lectures[i] as Map<String, dynamic>;
            final confirmed = lec['confirmed'] as bool? ?? false;
            final order = lec['order_index'] as int? ?? (i + 1);
            final hasVideo =
                (lec['video_url'] as String? ?? '').trim().isNotEmpty ||
                    (lec['video_asset_url'] as String? ?? '').trim().isNotEmpty;
            final hasMat =
                (lec['original_file_url'] as String? ?? '').trim().isNotEmpty ||
                    (lec['material_url'] as String? ?? '').trim().isNotEmpty;
            return _LectureCard(
              lec: lec,
              order: order,
              confirmed: confirmed,
              hasVideo: hasVideo,
              hasMaterial: hasMat,
              onView: () => context.push('/student/lecture', extra: {
                'room_id': widget.roomId,
                'lecture_id': lec['lecture_id'] as String? ?? '',
                'user_id': ref.read(authNotifierProvider)?.userId ??
                    'professor-preview',
                'title': lec['title'] as String? ?? '강의',
              }),
              onEdit: () => _openEditForm(lec),
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

  Widget _buildRoomCreateLectures() {
    return Column(children: [
      const _TabHeader(
        title: '교안 관리',
        sub: '새 강의실 생성과 강의 자료 등록을 한 번에 진행합니다',
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionHeader(index: '01', title: '강의 정보'),
            const SizedBox(height: 20),
            const _FieldLabel('강의명'),
            const SizedBox(height: 8),
            _FormField(ctrl: _roomNameCtrl, hint: '예: 딥러닝 프레임워크'),
            const SizedBox(height: 18),
            const _FieldLabel('한 줄 소개'),
            const SizedBox(height: 8),
            _FormField(ctrl: _roomDescCtrl, hint: '학생에게 보일 강의 소개를 입력하세요'),
            const SizedBox(height: 18),
            const _FieldLabel('강의 결제 비용'),
            const SizedBox(height: 8),
            _FormField(ctrl: _roomPriceCtrl, hint: '예: 99000'),
            const SizedBox(height: 18),
            const _FieldLabel('커리큘럼'),
            const SizedBox(height: 8),
            _SettingsField(ctrl: _roomCurriculumCtrl, maxLines: 4),
            const SizedBox(height: 10),
            _InlineFileButton(
              label: _curriculumFile == null
                  ? '커리큘럼 파일 넣기'
                  : _curriculumFile!.name,
              icon: Icons.description_rounded,
              color: _C.lime,
              onTap: _pickCurriculumFile,
              onRemove: _curriculumFile == null
                  ? null
                  : () => setState(() => _curriculumFile = null),
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              index: '02',
              title: '강의 자료',
              trailing: _ActionBtn(
                label: '강의 추가',
                icon: Icons.add_rounded,
                color: _C.lime,
                onTap: _addLectureDraft,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_lectureDrafts.length, (index) {
              final draft = _lectureDrafts[index];
              return _LectureDraftCard(
                index: index,
                draft: draft,
                onPickVideo: () => _pickDraftVideo(draft),
                onPickMaterial: () => _pickDraftMaterial(draft),
                onRemoveVideo: () => setState(() => draft.videoFile = null),
                onRemoveMaterial: () =>
                    setState(() => draft.materialFile = null),
                onRemoveLecture: _lectureDrafts.length == 1
                    ? null
                    : () => _removeLectureDraft(index),
              );
            }),
            if (_uploadError != null) ...[
              const SizedBox(height: 10),
              _InlineError(message: _uploadError!),
            ],
            const SizedBox(height: 28),
            _PrimarySubmitButton(
              enabled: _canCreateRoomWithLectures,
              loading: _creatingRoom,
              label: '분석 시작 — 강의실 생성 및 자료 저장',
              loadingLabel: '강의실 생성 및 AI 분석 중...',
              onTap: _submitRoomWithLectures,
            ),
          ]),
        ),
      ),
    ]);
  }

  // ── 강의 인라인 폼 ────────────────────────────────────────────
  // 수정 모드 전용 인라인 폼
  Widget _buildLectureForm() {
    final isEditing = _editingLecture != null;

    final existingFileUrl =
        ((_editingLecture?['original_file_url'] as String?) ??
                (_editingLecture?['material_url'] as String?) ??
                '')
            .trim();
    final existingFileName = existingFileUrl.isNotEmpty
        ? ((_editingLecture!['original_file_name'] as String?) ??
            (_editingLecture!['material_name'] as String?) ??
            '${_editingLecture!['title'] as String? ?? '기존'} 자료')
        : null;
    final existingVideoUrl =
        ((_editingLecture?['video_asset_url'] as String?) ??
                (_editingLecture?['video_url'] as String?) ??
                '')
            .trim();
    final existingVideoName =
        (_editingLecture?['video_file_name'] as String?) ??
            (_editingLecture?['video_title'] as String?) ??
            '기존 영상';

    return Column(children: [
      _TabHeader(
        title: isEditing ? '강의 수정' : '강의 추가',
        sub: isEditing ? '기존 강의 자료와 영상을 확인하고 수정합니다' : '새 강의를 등록합니다',
        action: _ActionBtn(
          label: '목록으로',
          icon: Icons.arrow_back_rounded,
          color: _C.textSec,
          onTap: () => setState(() => _showLectureForm = false),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 섹션 01: 강의 정보
            const _SectionHeader(index: '01', title: '강의 정보'),
            const SizedBox(height: 20),

            const _FieldLabel('제목'),
            const SizedBox(height: 8),
            _FormField(ctrl: _lectureTitleCtrl, hint: '강의 제목을 입력하세요'),
            const SizedBox(height: 20),

            // 영상 파일
            const _FieldLabel('영상 파일'),
            const SizedBox(height: 8),
            _InlineFileButton(
              label: _videoFile == null ? '영상 파일 넣기' : _videoFile!.name,
              icon: Icons.video_file_rounded,
              color: _C.lavender,
              onTap: _uploadingLecture ? null : _pickVideoFile,
              onRemove: _videoFile == null
                  ? null
                  : () => setState(() => _videoFile = null),
            ),

            // 선택된 영상 파일 미리보기
            if (isEditing && _videoFile == null && existingVideoUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('$existingVideoName · 새 파일을 선택하면 교체됩니다.',
                    style: const TextStyle(color: _C.textMute, fontSize: 11)),
              ),

            const SizedBox(height: 32),

            // 섹션 02: 강의 자료
            const _SectionHeader(index: '02', title: '강의 자료'),
            const SizedBox(height: 16),

            // 파일 드롭존
            GestureDetector(
              onTap: _uploadingLecture ? null : _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _lectureFile != null
                      ? _C.limeDark.withValues(alpha: 0.6)
                      : _C.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _lectureFile != null
                        ? _C.lime.withValues(alpha: 0.35)
                        : _C.border,
                    width: _lectureFile != null ? 1.5 : 1,
                  ),
                ),
                child: _lectureFile != null
                    ? _FileRowContent(
                        icon: Icons.insert_drive_file_rounded,
                        iconColor: _C.lime,
                        iconBg: _C.lime.withValues(alpha: 0.12),
                        name: _lectureFile!.name,
                        sub:
                            '${(_lectureFile!.size / 1024).toStringAsFixed(1)} KB',
                        onRemove: () => setState(() => _lectureFile = null),
                      )
                    : isEditing && existingFileName != null
                        ? Column(children: [
                            _FileRowContent(
                              icon: Icons.insert_drive_file_rounded,
                              iconColor: _C.textSec,
                              iconBg: _C.surface,
                              name: existingFileName,
                              sub: '기존 파일 · 새 파일 선택 시 교체됩니다',
                              onRemove: null,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _C.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _C.border),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded,
                                      color: _C.textMute, size: 14),
                                  SizedBox(width: 4),
                                  Text('새 파일로 교체',
                                      style: TextStyle(
                                          color: _C.textMute,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ])
                        : Column(children: [
                            const Icon(Icons.upload_rounded,
                                color: _C.textMute, size: 32),
                            const SizedBox(height: 10),
                            const Text('파일을 선택하세요',
                                style: TextStyle(
                                    color: _C.textSec,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('PDF · PPT · DOCX · HWP · 코드파일 · 이미지',
                                style: TextStyle(
                                    color: _C.textMute, fontSize: 11)),
                          ]),
              ),
            ),

            const SizedBox(height: 6),
            const Text('* 이미지 파일은 OCR로, 코드 파일은 텍스트로 읽습니다',
                style: TextStyle(color: _C.textMute, fontSize: 11)),

            const SizedBox(height: 24),

            // AI 파이프라인 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI 분석 파이프라인',
                        style: TextStyle(
                            color: _C.textMute,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 12),
                    ...[
                      ('텍스트 추출', '다형식 파싱 — PDF·PPT·HWP·코드·이미지'),
                      ('전처리', '노이즈 제거 · 구조 정규화'),
                      ('핵심 추출', 'RAG 기반 핵심 포인트 5개 도출'),
                      ('난이도 분류', 'Sweller CLT 기반 인지부하 추정'),
                      ('학습 목표', '학습 목표 및 검토 질문 자동 생성'),
                    ].map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                  color: _C.lime, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Text(e.$1,
                                style: const TextStyle(
                                    color: _C.textSec,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Text('— ${e.$2}',
                                style: const TextStyle(
                                    color: _C.textMute, fontSize: 11)),
                          ]),
                        )),
                  ]),
            ),

            if (_uploadError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.coral.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.coral.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: _C.coral, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_uploadError!,
                        style: const TextStyle(color: _C.coral, fontSize: 12)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 28),

            // 제출 버튼
            GestureDetector(
              onTap: _canSubmit ? _submitLecture : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: _uploadingLecture
                      ? _C.lime
                      : (_canSubmit ? _C.lime : _C.surface2),
                  borderRadius: BorderRadius.circular(14),
                  border: (_uploadingLecture || _canSubmit)
                      ? null
                      : Border.all(color: _C.border),
                ),
                child: Center(
                  child: _uploadingLecture
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: _C.limeDark),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isEditing && _lectureFile == null
                                  ? '업로드 및 저장 중...'
                                  : '업로드 및 AI 분석 중...',
                              style: const TextStyle(
                                  color: _C.limeDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        )
                      : Text(
                          isEditing && _lectureFile == null
                              ? (_videoFile != null ? '영상 업로드 및 저장' : '수정사항 저장')
                              : '분석 시작 — 핵심 포인트 추출',
                          style: TextStyle(
                            color: _canSubmit ? _C.limeDark : _C.textMute,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // 본문 영역만 (헤더 없이) — 리스트 빈 상태에서 사용
  Widget _buildLectureFormBody() {
    final isEditing = _editingLecture != null;
    final existingFileUrl =
        ((_editingLecture?['original_file_url'] as String?) ?? '').trim();
    final existingFileName = existingFileUrl.isNotEmpty
        ? (_editingLecture!['title'] as String? ?? '기존 파일')
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(index: '01', title: '강의 정보'),
        const SizedBox(height: 20),
        const _FieldLabel('제목'),
        const SizedBox(height: 8),
        _FormField(ctrl: _lectureTitleCtrl, hint: '강의 제목을 입력하세요'),
        const SizedBox(height: 20),
        const _FieldLabel('영상 파일'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadingLecture ? null : _pickVideoFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _videoFile != null ? _C.lavMid : _C.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _videoFile != null
                    ? _C.lavender.withValues(alpha: 0.5)
                    : _C.border,
              ),
            ),
            child: Row(children: [
              Icon(
                _videoFile != null
                    ? Icons.video_file_rounded
                    : Icons.video_file_outlined,
                color: _videoFile != null ? _C.lavender : _C.textMute,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _videoFile != null
                      ? _videoFile!.name
                      : '영상 파일 선택 (mp4, mov, webm)',
                  style: TextStyle(
                    color: _videoFile != null ? _C.lavender : _C.textMute,
                    fontSize: 13,
                    fontWeight:
                        _videoFile != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_videoFile != null)
                GestureDetector(
                  onTap: () => setState(() => _videoFile = null),
                  child: const Icon(Icons.close_rounded,
                      color: _C.lavender, size: 16),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 32),
        const _SectionHeader(index: '02', title: '강의 자료'),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _uploadingLecture ? null : _pickFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _lectureFile != null
                  ? _C.limeDark.withValues(alpha: 0.6)
                  : _C.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _lectureFile != null
                    ? _C.lime.withValues(alpha: 0.35)
                    : _C.border,
                width: _lectureFile != null ? 1.5 : 1,
              ),
            ),
            child: _lectureFile != null
                ? _FileRowContent(
                    icon: Icons.insert_drive_file_rounded,
                    iconColor: _C.lime,
                    iconBg: _C.lime.withValues(alpha: 0.12),
                    name: _lectureFile!.name,
                    sub: '${(_lectureFile!.size / 1024).toStringAsFixed(1)} KB',
                    onRemove: () => setState(() => _lectureFile = null),
                  )
                : isEditing && existingFileName != null
                    ? Column(children: [
                        _FileRowContent(
                          icon: Icons.insert_drive_file_rounded,
                          iconColor: _C.textSec,
                          iconBg: _C.surface,
                          name: existingFileName,
                          sub: '기존 파일 · 새 파일 선택 시 교체됩니다',
                          onRemove: null,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _C.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _C.border),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded,
                                  color: _C.textMute, size: 14),
                              SizedBox(width: 4),
                              Text('새 파일로 교체',
                                  style: TextStyle(
                                      color: _C.textMute,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ])
                    : Column(children: [
                        const Icon(Icons.upload_rounded,
                            color: _C.textMute, size: 32),
                        const SizedBox(height: 10),
                        const Text('파일을 선택하세요',
                            style: TextStyle(
                                color: _C.textSec,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('PDF · PPT · DOCX · HWP · 코드파일 · 이미지',
                            style: TextStyle(color: _C.textMute, fontSize: 11)),
                      ]),
          ),
        ),
        const SizedBox(height: 6),
        const Text('* 이미지 파일은 OCR로, 코드 파일은 텍스트로 읽습니다',
            style: TextStyle(color: _C.textMute, fontSize: 11)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI 분석 파이프라인',
                style: TextStyle(
                    color: _C.textMute,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 12),
            ...[
              ('텍스트 추출', '다형식 파싱 — PDF·PPT·HWP·코드·이미지'),
              ('전처리', '노이즈 제거 · 구조 정규화'),
              ('핵심 추출', 'RAG 기반 핵심 포인트 5개 도출'),
              ('난이도 분류', 'Sweller CLT 기반 인지부하 추정'),
              ('학습 목표', '학습 목표 및 검토 질문 자동 생성'),
            ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: _C.lime, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(e.$1,
                        style: const TextStyle(
                            color: _C.textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text('— ${e.$2}',
                        style:
                            const TextStyle(color: _C.textMute, fontSize: 11)),
                  ]),
                )),
          ]),
        ),
        if (_uploadError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.coral.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.coral.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _C.coral, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_uploadError!,
                    style: const TextStyle(color: _C.coral, fontSize: 12)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _canSubmit ? _submitLecture : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: _uploadingLecture
                  ? _C.lime
                  : (_canSubmit ? _C.lime : _C.surface2),
              borderRadius: BorderRadius.circular(14),
              border: (_uploadingLecture || _canSubmit)
                  ? null
                  : Border.all(color: _C.border),
            ),
            child: Center(
              child: _uploadingLecture
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: _C.limeDark),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEditing && _lectureFile == null
                              ? '업로드 및 저장 중...'
                              : '업로드 및 AI 분석 중...',
                          style: const TextStyle(
                              color: _C.limeDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    )
                  : Text(
                      isEditing && _lectureFile == null
                          ? (_videoFile != null ? '영상 업로드 및 저장' : '수정사항 저장')
                          : '분석 시작 — 핵심 포인트 추출',
                      style: TextStyle(
                        color: _canSubmit ? _C.limeDark : _C.textMute,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ]),
    );
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
                itemBuilder: (_, i) => _NoticeCard(
                  notice: notices[i] as Map<String, dynamic>,
                  onDelete: () =>
                      _deleteNotice(notices[i] as Map<String, dynamic>),
                ),
              ),
      ),
    ]);
  }

  // ── 수강생 탭 ─────────────────────────────────────────────────
  Widget _buildStudents(
    List<dynamic> students,
    List<Map<String, dynamic>> pendingApplications,
  ) {
    return Column(children: [
      _TabHeader(title: '수강생', sub: '총 ${students.length}명 수강 중'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
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
                                        Text(
                                            app['student_name'] as String? ??
                                                '',
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
                                      ]),
                                ),
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
                      color: _C.lime, borderRadius: BorderRadius.circular(14)),
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

  const _LeftPanel({
    required this.selectedIndex,
    required this.onSelect,
    required this.students,
    required this.lectures,
    required this.notices,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _C.surface,
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: _C.border))),
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
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
    ]);
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
          border: Border(bottom: BorderSide(color: _C.border))),
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
  final VoidCallback onView;
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
    required this.onView,
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
                  ])),
              Column(children: [
                _ArrowBtn(
                    icon: Icons.keyboard_arrow_up_rounded,
                    enabled: onUp != null,
                    onTap: onUp),
                _ArrowBtn(
                    icon: Icons.keyboard_arrow_down_rounded,
                    enabled: onDown != null,
                    onTap: onDown),
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
                  label: '보기',
                  icon: Icons.visibility_rounded,
                  color: _C.lime,
                  onTap: onView),
              const SizedBox(width: 6),
              _ActionBtn(
                  label: '편집',
                  icon: Icons.edit_rounded,
                  color: _C.textSec,
                  onTap: onEdit),
              const SizedBox(width: 6),
              _ActionBtn(
                  label: '삭제',
                  icon: Icons.delete_outline_rounded,
                  color: _C.coral,
                  onTap: onDelete),
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
                  onTap: onDelete),
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

// ── 섹션 헤더 ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String index;
  final String title;
  final Widget? trailing;
  const _SectionHeader(
      {required this.index, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(index,
          style: const TextStyle(
              color: _C.lime,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 1, color: _C.border)),
      if (trailing != null) ...[
        const SizedBox(width: 12),
        trailing!,
      ],
    ]);
  }
}

// ── 파일 행 콘텐츠 (드롭존 내부) ──────────────────────────────────
class _FileRowContent extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String name;
  final String sub;
  final VoidCallback? onRemove;
  const _FileRowContent({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.name,
    required this.sub,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: iconBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: const TextStyle(
                color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: _C.textMute, fontSize: 11)),
      ])),
      if (onRemove != null)
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, color: _C.textMute, size: 18),
        ),
    ]);
  }
}

class _InlineFileButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _InlineFileButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final selected = onRemove != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : _C.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.38) : _C.border,
          ),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? color : _C.textMute, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? color : _C.textSec,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close_rounded, color: color, size: 16),
            )
          else
            Icon(Icons.upload_rounded, color: color, size: 16),
        ]),
      ),
    );
  }
}

class _LectureDraftCard extends StatelessWidget {
  final int index;
  final _LectureDraft draft;
  final VoidCallback onPickVideo;
  final VoidCallback onPickMaterial;
  final VoidCallback onRemoveVideo;
  final VoidCallback onRemoveMaterial;
  final VoidCallback? onRemoveLecture;

  const _LectureDraftCard({
    required this.index,
    required this.draft,
    required this.onPickVideo,
    required this.onPickMaterial,
    required this.onRemoveVideo,
    required this.onRemoveMaterial,
    required this.onRemoveLecture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _C.limeDark,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _C.lime.withValues(alpha: 0.25)),
            ),
            child: Text('${index + 1}강',
                style: const TextStyle(
                    color: _C.lime, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('강의 제목 · 영상 파일 · 교안 파일',
                style: TextStyle(
                    color: _C.textMute,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          if (onRemoveLecture != null)
            GestureDetector(
              onTap: onRemoveLecture,
              child:
                  const Icon(Icons.close_rounded, color: _C.textMute, size: 18),
            ),
        ]),
        const SizedBox(height: 14),
        _FormField(ctrl: draft.titleCtrl, hint: '강의 제목'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _InlineFileButton(
              label:
                  draft.videoFile == null ? '영상 파일 넣기' : draft.videoFile!.name,
              icon: Icons.video_file_rounded,
              color: _C.lavender,
              onTap: onPickVideo,
              onRemove: draft.videoFile == null ? null : onRemoveVideo,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InlineFileButton(
              label: draft.materialFile == null
                  ? '교안 파일 넣기'
                  : draft.materialFile!.name,
              icon: Icons.insert_drive_file_rounded,
              color: _C.lime,
              onTap: onPickMaterial,
              onRemove: draft.materialFile == null ? null : onRemoveMaterial,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.coral.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: _C.coral, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style:
                  const TextStyle(color: _C.coral, fontSize: 12, height: 1.4)),
        ),
      ]),
    );
  }
}

class _PrimarySubmitButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final String label;
  final String loadingLabel;
  final VoidCallback onTap;

  const _PrimarySubmitButton({
    required this.enabled,
    required this.loading,
    required this.label,
    required this.loadingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: loading ? _C.lime : (enabled ? _C.lime : _C.surface2),
          borderRadius: BorderRadius.circular(15),
          border: (loading || enabled) ? null : Border.all(color: _C.border),
          boxShadow: (loading || enabled)
              ? [
                  BoxShadow(
                    color: _C.lime.withValues(alpha: 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _C.limeDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(loadingLabel,
                      style: const TextStyle(
                          color: _C.limeDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ])
              : Text(label,
                  style: TextStyle(
                      color: enabled ? _C.limeDark : _C.textMute,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
        ),
      ),
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
            color: _C.surface2, borderRadius: BorderRadius.circular(6)),
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

// ── 폼 입력 필드 ──────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _FormField({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: _C.textPri, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
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
