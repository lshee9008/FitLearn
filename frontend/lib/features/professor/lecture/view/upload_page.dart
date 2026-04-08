import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'ppt', 'pptx', 'docx', 'md', 'txt'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() { _file = result.files.first; _error = null; });
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
      );
      if (mounted) {
        context.push('/professor/lecture/${widget.roomId}/${data['lecture_id']}/review',
            extra: data);
      }
    } catch (e) {
      setState(() { _error = '업로드 중 오류가 발생했습니다.'; _uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('교안 업로드'), backgroundColor: AppColors.bg),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle(title: '교안 파일 업로드', subtitle: 'PDF, PPT, PPTX, DOCX, MD 지원'),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _uploading ? null : _pickFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: _file != null
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _file != null ? AppColors.accent : AppColors.borderLight,
                  style: BorderStyle.solid,
                  width: _file != null ? 2 : 1,
                ),
              ),
              child: Center(
                child: _file == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.upload_file_rounded, color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        const Text('파일을 선택하세요', style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600,
                        )),
                        const SizedBox(height: 4),
                        const Text('PDF, PPT, PPTX, DOCX, MD, TXT', style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12,
                        )),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 48),
                        const SizedBox(height: 12),
                        Text(_file!.name, style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
                        )),
                        const SizedBox(height: 4),
                        Text('${(_file!.size / 1024).toStringAsFixed(1)} KB', style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12,
                        )),
                      ]),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 13)),
          ],
          const Spacer(),
          GlowButton(
            text: _uploading ? '분석 중...' : 'AI 핵심 포인트 추출',
            loading: _uploading,
            onTap: _file != null && !_uploading ? _upload : null,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('AI가 교안을 분석해 핵심 포인트를 자동 추출합니다', style: TextStyle(
              color: AppColors.textMuted, fontSize: 12,
            )),
          ),
        ]),
      ),
    );
  }
}
