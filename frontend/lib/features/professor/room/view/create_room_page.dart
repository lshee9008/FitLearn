import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/providers/room_data_providers.dart';
import '../../../../shared/services/api_service.dart';

// ─── 허용 확장자 ──────────────────────────────────────────────────
const _allowedExtensions = [
  'pdf', 'ppt', 'pptx', 'docx', 'hwp', 'hwpx', 'md', 'txt',
  'py', 'js', 'ts', 'java', 'c', 'cpp', 'cs', 'go', 'rs', 'kt', 'swift',
  'jpg', 'jpeg', 'png', 'webp', 'csv', 'json', 'xml',
];
const _videoExtensions = ['mp4', 'mov', 'webm', 'm4v'];

// ─── 컬러 ─────────────────────────────────────────────────────────
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
  static const textPri  = Color(0xFFF0F0F4);
  static const textSec  = Color(0xFF9D9DB0);
  static const textMute = Color(0xFF6E6E80);
}

// ─── 강의 입력 모델 ───────────────────────────────────────────────
class LectureInput {
  final TextEditingController titleCtrl = TextEditingController();
  PlatformFile? videoFile;
  PlatformFile? materialFile;

  void dispose() => titleCtrl.dispose();
}

// ══════════════════════════════════════════════════════════════════
// 신규 강의 생성 페이지
// ══════════════════════════════════════════════════════════════════
class CreateRoomPage extends ConsumerStatefulWidget {
  const CreateRoomPage({super.key});

  @override
  ConsumerState<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends ConsumerState<CreateRoomPage> {
  final _roomNameCtrl   = TextEditingController();
  final _roomDescCtrl   = TextEditingController();
  final _curriculumCtrl = TextEditingController();
  PlatformFile? _curriculumFile;

  final List<LectureInput> _lectures = [LectureInput()];

  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      !_submitting &&
      _roomNameCtrl.text.trim().isNotEmpty &&
      _lectures.any((l) => l.titleCtrl.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _roomNameCtrl.addListener(_rebuild);
    _curriculumCtrl.addListener(_rebuild);
    _lectures.first.titleCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _roomDescCtrl.dispose();
    _curriculumCtrl.dispose();
    for (final l in _lectures) {
      l.dispose();
    }
    super.dispose();
  }

  // ── 파일 선택 헬퍼 ───────────────────────────────────────────
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

  Future<void> _pickVideoFile(int i) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _videoExtensions,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      setState(() => _lectures[i].videoFile = r.files.first);
    }
  }

  Future<void> _pickMaterialFile(int i) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      setState(() => _lectures[i].materialFile = r.files.first);
    }
  }

  void _addLecture() {
    final input = LectureInput();
    input.titleCtrl.addListener(_rebuild);
    setState(() => _lectures.add(input));
  }

  void _removeLecture(int i) {
    _lectures[i].dispose();
    setState(() => _lectures.removeAt(i));
  }

  // ── 제출 ─────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_canSubmit) return;
    final user = ref.read(authNotifierProvider);
    if (user == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // 1) 방 생성
      final coreConcepts = _curriculumCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final roomData = await ApiService().createRoom(
        professorUid: user.userId,
        subject:      _roomNameCtrl.text.trim(),
        description:  _roomDescCtrl.text.trim(),
        synopsis:     _curriculumCtrl.text.trim(),
        coreConcepts: coreConcepts,
      );
      final roomId = roomData['room_id'] as String? ?? '';

      // 2) 강의 shells
      final valid = _lectures
          .where((l) => l.titleCtrl.text.trim().isNotEmpty)
          .toList();
      final seeds = <Map<String, dynamic>>[];
      for (var i = 0; i < valid.length; i++) {
        seeds.add({
          'title': valid[i].titleCtrl.text.trim(),
          'order': i + 1,
          'video_url': '',
          'material_url': '',
        });
      }

      Map<String, dynamic>? shellsResult;
      if (roomId.isNotEmpty && seeds.isNotEmpty) {
        shellsResult = await ApiService().createLectureShells(roomId, seeds);
      }

      // 3) 파일이 있는 강의 업로드
      final created =
          (shellsResult?['lectures'] as List<dynamic>?) ?? [];
      for (var i = 0; i < valid.length; i++) {
        final l = valid[i];
        final mat = l.materialFile;
        if (mat == null || mat.bytes == null) continue;

        String lid = '';
        if (i < created.length) {
          lid = (created[i] as Map<String, dynamic>)['lecture_id']
                  as String? ??
              '';
        }
        await ApiService().uploadLecture(
          roomId:         roomId,
          professorUid:   user.userId,
          fileBytes:      mat.bytes!,
          fileName:       mat.name,
          lectureTitle:   l.titleCtrl.text.trim(),
          lectureId:      lid,
          orderIndex:     i + 1,
          videoFileBytes: l.videoFile?.bytes,
          videoFileName:  l.videoFile?.name,
        );
      }

      // 4) 목록 갱신
      ref.invalidate(currentProfessorRoomsProvider);

      if (!mounted) return;
      final inviteCode = roomData['room_code'] as String? ?? '';
      if (inviteCode.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (_) => _InviteCodeDialog(
            code: inviteCode,
            subject: _roomNameCtrl.text.trim(),
          ),
        );
      }
      if (mounted) context.go('/professor/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '오류: $e';
          _submitting = false;
        });
      }
    }
  }

  // ── input decoration ─────────────────────────────────────────
  InputDecoration _deco(String hint, {bool active = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
      filled: true,
      fillColor: _C.surface2,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: active ? _C.lime : _C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
            color: active ? _C.lime.withValues(alpha: 0.5) : _C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _C.lime, width: 1.5),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 01 강의 정보 ─────────────────────────────
                const _SectionRow(index: '01', title: '강의 정보'),
                const SizedBox(height: 20),

                _label('강의명', required: true),
                const SizedBox(height: 8),
                TextField(
                  controller: _roomNameCtrl,
                  style: const TextStyle(color: _C.textPri, fontSize: 14),
                  decoration: _deco('예: 파이썬 프로그래밍 기초',
                      active: _roomNameCtrl.text.isNotEmpty),
                ),
                const SizedBox(height: 18),

                _label('한 줄 소개'),
                const SizedBox(height: 8),
                TextField(
                  controller: _roomDescCtrl,
                  style: const TextStyle(color: _C.textPri, fontSize: 14),
                  decoration: _deco('강의를 한 줄로 소개해주세요'),
                ),
                const SizedBox(height: 18),

                // 커리큘럼 — 영상 연결 자리
                _label('커리큘럼'),
                const SizedBox(height: 4),
                const Text(
                  '각 줄이 핵심 개념으로 반영됩니다. 파일로도 첨부할 수 있습니다.',
                  style: TextStyle(color: _C.textMute, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextField(
                      controller: _curriculumCtrl,
                      maxLines: 4,
                      style: const TextStyle(
                          color: _C.textPri, fontSize: 14, height: 1.6),
                      decoration: _deco(
                        '예)\n재귀 함수의 원리\nO(n log n) 이해\n분할 정복 알고리즘',
                        active: _curriculumCtrl.text.isNotEmpty,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 파일 첨부 버튼
                  GestureDetector(
                    onTap: _pickCurriculumFile,
                    child: _FilePickBtn(
                      label: _curriculumFile != null ? '파일 선택됨' : '파일 첨부',
                      icon: _curriculumFile != null
                          ? Icons.insert_drive_file_rounded
                          : Icons.upload_file_rounded,
                      active: _curriculumFile != null,
                      activeColor: _C.lime,
                    ),
                  ),
                ]),
                if (_curriculumFile != null) ...[
                  const SizedBox(height: 8),
                  _Chip(
                    icon: Icons.insert_drive_file_rounded,
                    name: _curriculumFile!.name,
                    color: _C.lime,
                    onRemove: () => setState(() => _curriculumFile = null),
                  ),
                ],

                const SizedBox(height: 36),

                // ── 02 강의 자료 ─────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  const Expanded(
                      child: _SectionRow(index: '02', title: '강의 자료')),
                  const SizedBox(width: 16),
                  _AddLectureBtn(onTap: _addLecture),
                ]),
                const SizedBox(height: 16),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lectures.length,
                  itemBuilder: (_, i) => _LectureCard(
                    key: ObjectKey(_lectures[i]),
                    index: i,
                    input: _lectures[i],
                    canRemove: _lectures.length > 1,
                    onRemove: () => _removeLecture(i),
                    onPickVideo: () => _pickVideoFile(i),
                    onPickMaterial: () => _pickMaterialFile(i),
                    onClearVideo: () =>
                        setState(() => _lectures[i].videoFile = null),
                    onClearMaterial: () =>
                        setState(() => _lectures[i].materialFile = null),
                    onTitleChanged: (_) => setState(() {}),
                    deco: _deco,
                  ),
                ),

                // 에러
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBox(message: _error!),
                ],

                const SizedBox(height: 32),

                // 분석 시작 버튼
                _SubmitBtn(
                  enabled: _canSubmit,
                  loading: _submitting,
                  onTap: _submit,
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(bottom: BorderSide(color: _C.border))),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _C.textSec, size: 16),
          onPressed: () => context.pop(),
          splashRadius: 18,
        ),
        const SizedBox(width: 4),
        const Text('새 강의 생성',
            style: TextStyle(
                color: _C.textPri,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(children: [
      Text(text,
          style: const TextStyle(
              color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600)),
      if (required) ...[
        const SizedBox(width: 4),
        const Text('*',
            style: TextStyle(color: _C.lime, fontSize: 12)),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// 강의 카드 (강의 제목 + 영상/교안 파일 버튼)
// ══════════════════════════════════════════════════════════════════
class _LectureCard extends StatelessWidget {
  final int index;
  final LectureInput input;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onPickVideo;
  final VoidCallback onPickMaterial;
  final VoidCallback onClearVideo;
  final VoidCallback onClearMaterial;
  final ValueChanged<String> onTitleChanged;
  final InputDecoration Function(String, {bool active}) deco;

  const _LectureCard({
    super.key,
    required this.index,
    required this.input,
    required this.canRemove,
    required this.onRemove,
    required this.onPickVideo,
    required this.onPickMaterial,
    required this.onClearVideo,
    required this.onClearMaterial,
    required this.onTitleChanged,
    required this.deco,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo    = input.videoFile != null;
    final hasMaterial = input.materialFile != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 헤더
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.limeDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${index + 1}강',
                style: const TextStyle(
                    color: _C.lime,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _C.surface2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _C.border),
                ),
                child: const Icon(Icons.close_rounded,
                    color: _C.textMute, size: 14),
              ),
            ),
        ]),
        const SizedBox(height: 14),

        // 강의 제목
        const Text('강의 제목',
            style: TextStyle(
                color: _C.textSec,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: input.titleCtrl,
          style: const TextStyle(color: _C.textPri, fontSize: 13),
          onChanged: onTitleChanged,
          decoration: deco('예: 파이썬 기초 문법',
              active: input.titleCtrl.text.isNotEmpty),
        ),
        const SizedBox(height: 14),

        // 영상 + 교안 파일 버튼 행
        Row(children: [
          Expanded(
            child: _FileBtnFull(
              label: hasVideo ? input.videoFile!.name : '영상 파일 넣기',
              icon: hasVideo
                  ? Icons.video_file_rounded
                  : Icons.video_file_outlined,
              active: hasVideo,
              activeColor: _C.lavender,
              activeBg: _C.lavMid,
              onTap: onPickVideo,
              onClear: hasVideo ? onClearVideo : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FileBtnFull(
              label: hasMaterial ? input.materialFile!.name : '교안 파일 넣기',
              icon: hasMaterial
                  ? Icons.insert_drive_file_rounded
                  : Icons.upload_file_outlined,
              active: hasMaterial,
              activeColor: _C.lime,
              activeBg: _C.limeDark,
              onTap: onPickMaterial,
              onClear: hasMaterial ? onClearMaterial : null,
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── 작은 공용 위젯들 ──────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String index;
  final String title;
  const _SectionRow({required this.index, required this.title});

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
    ]);
  }
}

// 작은 파일 첨부 버튼 (상단 커리큘럼용)
class _FilePickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  const _FilePickBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.15) : _C.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? activeColor.withValues(alpha: 0.5) : _C.border,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            color: active ? activeColor : _C.textMute, size: 15),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: active ? activeColor : _C.textMute,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// 강의 카드 내 파일 버튼 (전width)
class _FileBtnFull extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color activeBg;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _FileBtnFull({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.activeBg,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? activeBg.withValues(alpha: 0.8) : _C.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.45)
                : _C.border,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: active ? activeColor : _C.textMute, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: active ? activeColor : _C.textMute,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          if (active && onClear != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded,
                  color: activeColor, size: 13),
            ),
          ],
        ]),
      ),
    );
  }
}

class _AddLectureBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddLectureBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _C.limeDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.lime.withValues(alpha: 0.4)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, color: _C.lime, size: 14),
          SizedBox(width: 4),
          Text('강의 추가',
              style: TextStyle(
                  color: _C.lime, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String name;
  final Color color;
  final VoidCallback onRemove;
  const _Chip({
    required this.icon,
    required this.name,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(name,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close_rounded, size: 12, color: color),
        ),
      ]),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.coral.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: _C.coral, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: _C.coral, fontSize: 12)),
        ),
      ]),
    );
  }
}

class _SubmitBtn extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const _SubmitBtn({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? _C.lime : _C.surface2,
          borderRadius: BorderRadius.circular(14),
          border: enabled ? null : Border.all(color: _C.border),
        ),
        child: Center(
          child: loading
              ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _C.limeDark),
                  ),
                  SizedBox(width: 10),
                  Text('강의 생성 중...',
                      style: TextStyle(
                          color: _C.limeDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ])
              : Text(
                  '분석 시작 — 강의 방 생성',
                  style: TextStyle(
                      color: enabled ? _C.limeDark : _C.textMute,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// 초대 코드 다이얼로그
// ══════════════════════════════════════════════════════════════════
class _InviteCodeDialog extends StatefulWidget {
  final String code;
  final String subject;
  const _InviteCodeDialog({required this.code, required this.subject});

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _C.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration:
                  const BoxDecoration(color: _C.limeDark, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: _C.lime, size: 30),
            ),
            const SizedBox(height: 18),
            const Text('강의 방이 생성되었습니다!',
                style: TextStyle(
                    color: _C.textPri,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(widget.subject,
                style: const TextStyle(color: _C.textSec, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF13131A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _C.lime.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Column(children: [
                const Text('학생 초대 코드',
                    style: TextStyle(
                        color: _C.textMute, fontSize: 10, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(widget.code,
                    style: const TextStyle(
                        color: _C.lime,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10)),
              ]),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _copy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: _copied ? _C.limeDark : _C.lime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        color: _copied ? _C.lime : _C.limeDark,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Text(_copied ? '복사됨!' : '코드 복사하기',
                          style: TextStyle(
                              color: _copied ? _C.lime : _C.limeDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.border),
                ),
                child: const Text('닫기',
                    style: TextStyle(color: _C.textSec, fontSize: 12)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
