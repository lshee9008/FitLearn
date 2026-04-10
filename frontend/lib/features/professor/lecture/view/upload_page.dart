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

class LectureUploadPage extends ConsumerStatefulWidget {
  final String roomId;
  const LectureUploadPage({super.key, required this.roomId});

  @override
  ConsumerState<LectureUploadPage> createState() => _LectureUploadPageState();
}

class _LectureUploadPageState extends ConsumerState<LectureUploadPage> {
  PlatformFile? _file;
  bool _uploading = false;
  String? _error;
  int _weekNumber = 0;       // 0 = 주차 미지정
  final _titleCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
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

  bool get _canUpload => _file != null && !_uploading;

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

            // 주차 선택
            const Text('주차',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 17,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final isSelected = _weekNumber == i;
                  return GestureDetector(
                    onTap: () => setState(() => _weekNumber = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: i == 0 ? 64 : 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        i == 0 ? '미지정' : '$i주',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF0A0A0F)
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // 제목 입력
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
                hintText: '강의 제목 (파일 선택 시 자동 입력)',
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
