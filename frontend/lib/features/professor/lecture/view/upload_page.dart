import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';

// 지원 확장자 목록
const _allowedExtensions = [
  'pdf', 'ppt', 'pptx', 'docx', 'hwp', 'hwpx', 'md', 'txt',
  'py', 'js', 'ts', 'java', 'c', 'cpp', 'cs', 'go', 'rs', 'kt', 'swift',
  'jpg', 'jpeg', 'png', 'webp',
  'csv', 'json', 'xml',
];

const _videoExtensions = ['mp4', 'mov', 'webm', 'm4v'];

class LectureUploadPage extends ConsumerStatefulWidget {
  final String roomId;
  const LectureUploadPage({super.key, required this.roomId});

  @override
  ConsumerState<LectureUploadPage> createState() => _LectureUploadPageState();
}

class _LectureUploadPageState extends ConsumerState<LectureUploadPage> {
  PlatformFile? _file;
  PlatformFile? _videoFile;
  bool _uploading = false;
  String? _error;
  int _weekNumber = 0;       // 0 = 주차 미지정
  final _titleCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _materialUrlCtrl = TextEditingController();
  List<dynamic> _lectureOptions = [];
  String? _selectedLectureId;
  int _selectedOrderIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLectureOptions();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _videoUrlCtrl.dispose();
    _materialUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLectureOptions() async {
    try {
      final lectures = await ApiService().getRoomLectures(widget.roomId);
      if (!mounted) return;
      setState(() => _lectureOptions = lectures);
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      setState(() {
        _file = f;
        _error = null;
        // 파일명에서 제목 자동 입력 (비어있을 때)
        if (_titleCtrl.text.trim().isEmpty) {
          final nameWithoutExt = f.name.contains('.')
              ? f.name.substring(0, f.name.lastIndexOf('.'))
              : f.name;
          _titleCtrl.text = nameWithoutExt;
        }
      });
    }
  }

  Future<void> _pickVideoFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _videoExtensions,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _videoFile = result.files.first;
        _error = null;
      });
    }
  }

  void _selectLecture(Map<String, dynamic> lecture) {
    setState(() {
      _selectedLectureId = lecture['lecture_id'] as String?;
      _selectedOrderIndex = lecture['order_index'] as int? ?? 0;
      _weekNumber = lecture['week_number'] as int? ?? 0;
      _titleCtrl.text = lecture['title'] as String? ?? '';
      _videoUrlCtrl.text = lecture['video_url'] as String? ?? '';
      _materialUrlCtrl.text = lecture['material_url'] as String? ?? '';
    });
  }

  Future<void> _upload() async {
    if (_file == null || _file!.bytes == null) return;
    final user = ref.read(authNotifierProvider);
    if (user == null) return;

    setState(() { _uploading = true; _error = null; });
    try {
      final data = await ApiService().uploadLecture(
        roomId: widget.roomId,
        professorUid: user.userId,
        fileBytes: _file!.bytes!,
        fileName: _file!.name,
        weekNumber: _weekNumber,
        lectureTitle: _titleCtrl.text.trim(),
        lectureId: _selectedLectureId ?? '',
        orderIndex: _selectedOrderIndex,
        videoUrl: _videoUrlCtrl.text.trim(),
        materialUrl: _materialUrlCtrl.text.trim(),
        videoFileBytes: _videoFile?.bytes,
        videoFileName: _videoFile?.name,
      );
      if (mounted) {
        context.push(
          '/professor/lecture/${widget.roomId}/${data['lecture_id']}/review',
          extra: data,
        );
      }
    } catch (e) {
      setState(() { _error = '업로드 중 오류가 발생했습니다: $e'; _uploading = false; });
    }
  }

  bool get _canUpload => _file != null && _titleCtrl.text.trim().isNotEmpty && !_uploading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(color: AppColors.textMuted),
        title: const Text('교안 업로드',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── 섹션 1: 강의 정보 ──────────────────────────────────
            _SectionHeader(index: '01', title: '강의 정보'),
            const SizedBox(height: 16),

            const Text('등록된 강의 항목',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            if (_lectureOptions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  '아직 강의 항목이 없습니다. 강의 개설 팝업에서 강의 목록을 먼저 구성하면 업로드 시 정확히 매칭됩니다.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
                ),
              )
            else
              SizedBox(
                height: 114,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _lectureOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final lecture = _lectureOptions[i] as Map<String, dynamic>;
                    final isSelected = _selectedLectureId == lecture['lecture_id'];
                    final isPlaceholder = lecture['is_placeholder'] as bool? ?? false;
                    return GestureDetector(
                      onTap: () => _selectLecture(lecture),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 220,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.bg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${lecture['order_index'] ?? i + 1}강',
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  isPlaceholder
                                      ? Icons.schedule_rounded
                                      : Icons.check_circle_rounded,
                                  size: 16,
                                  color: isPlaceholder ? AppColors.gold : AppColors.accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              lecture['title'] as String? ?? '제목 없음',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              isPlaceholder ? '교안 미연결' : '교안 연결됨',
                              style: TextStyle(
                                color: isPlaceholder ? AppColors.gold : AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            const Text('제목',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '업로드할 강의 제목',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.bgCard,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text('영상 연결',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _videoUrlCtrl,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'YouTube 링크 또는 공개 영상 URL',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.bgCard,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _uploading ? null : _pickVideoFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _videoFile != null
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _videoFile != null ? Icons.video_file_rounded : Icons.ondemand_video_rounded,
                      color: _videoFile != null ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _videoFile?.name ?? '또는 영상 파일 업로드 (mp4, mov, webm)',
                        style: TextStyle(
                          color: _videoFile != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: _videoFile != null ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_videoFile != null)
                      GestureDetector(
                        onTap: () => setState(() => _videoFile = null),
                        child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text('보조 자료 링크',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _materialUrlCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '실습 링크, 외부 문서 링크 등',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── 섹션 2: 파일 ────────────────────────────────────────
            _SectionHeader(index: '02', title: '강의 자료'),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _uploading ? null : _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _file != null
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _file != null
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border,
                    width: _file != null ? 1.5 : 1,
                  ),
                ),
                child: _file == null
                    ? Column(children: [
                        const Icon(Icons.upload_rounded,
                            color: AppColors.textMuted, size: 36),
                        const SizedBox(height: 12),
                        const Text('파일을 선택하세요',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                            'PDF · PPT · DOCX · HWP · 코드파일 · 이미지',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12)),
                      ])
                    : Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.insert_drive_file_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_file!.name,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                Text(
                                    '${(_file!.size / 1024).toStringAsFixed(1)} KB',
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ]),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _file = null),
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.textMuted, size: 18),
                        ),
                      ]),
              ),
            ),

            const SizedBox(height: 8),
            const Text(
                '* 이미지 파일은 OCR로, 코드 파일은 텍스트로 읽습니다',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.rose.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.rose, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.rose, fontSize: 12)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 32),

            // ── AI 파이프라인 안내 ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 분석 파이프라인',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  ...[
                    ('텍스트 추출', '다형식 파싱 — PDF·PPT·HWP·코드·이미지'),
                    ('전처리', '노이즈 제거 · 구조 정규화'),
                    ('핵심 추출', 'RAG 기반 핵심 포인트 5개 도출'),
                    ('난이도 분류', 'Sweller CLT 기반 인지부하 추정'),
                    ('학습 목표', '학습 목표 및 검토 질문 자동 생성'),
                  ].map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${e.$1}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Text('— ${e.$2}',
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12)),
                        ]),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── 업로드 버튼 ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canUpload ? _upload : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canUpload ? AppColors.primary : AppColors.bgCard,
                  disabledBackgroundColor: AppColors.bgCard,
                  foregroundColor: _canUpload
                      ? const Color(0xFF0A0A0F)
                      : AppColors.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _uploading
                    ? Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    AppColors.primaryLight)),
                          ),
                          const SizedBox(width: 10),
                          const Text('AI 분석 중...',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ])
                    : const Text('분석 시작 — 핵심 포인트 추출',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String index;
  final String title;
  const _SectionHeader({required this.index, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(index,
          style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 1, color: AppColors.border)),
    ]);
  }
}
