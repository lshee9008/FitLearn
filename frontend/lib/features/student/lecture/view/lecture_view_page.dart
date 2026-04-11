// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/widgets/app_card.dart';

const _styleColors = {
  '시각형': AppColors.primary,
  '청각형': AppColors.secondary,
  '읽기형': Color(0xFF10B981),
  '실습형': AppColors.accent,
  '요약형': Color(0xFFF59E0B),
  '상세형': Color(0xFFEC4899),
};

class LectureViewPage extends ConsumerStatefulWidget {
  final String roomId;
  final String lectureId;
  final String userId;
  final String title;

  const LectureViewPage({
    super.key,
    required this.roomId,
    required this.lectureId,
    required this.userId,
    required this.title,
  });

  @override
  ConsumerState<LectureViewPage> createState() => _LectureViewPageState();
}

class _LectureViewPageState extends ConsumerState<LectureViewPage> {
  Map<String, String>? _styleContents;
  Map<String, dynamic>? _lectureMeta;
  Map<String, dynamic>? _profileSummary;
  String? _primaryStyle;
  String? _subjectLevel;
  String? _segmentAnswer;
  bool _segmentLoading = false;
  final _segmentStartCtrl = TextEditingController(text: '0');
  final _segmentEndCtrl = TextEditingController(text: '5');
  final _segmentQuestionCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _segmentStartCtrl.dispose();
    _segmentEndCtrl.dispose();
    _segmentQuestionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService().getLecture(widget.roomId, widget.lectureId),
        ApiService().getReforgedLecture(
          roomId: widget.roomId,
          lectureId: widget.lectureId,
          userId: widget.userId,
        ),
      ]);
      final lecture = results[0];
      final data = results[1];
      final rawStyles = data['styles'] as Map<String, dynamic>? ?? {};
      setState(() {
        _lectureMeta = lecture;
        _styleContents = rawStyles.map((k, v) => MapEntry(k, v as String));
        _profileSummary = data['profile'] as Map<String, dynamic>?;
        _primaryStyle = data['primary_style'] as String? ?? '읽기형';
        _subjectLevel = data['subject_level'] as String?;
        _loading = false;
      });
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail'] as String?)
          : null;
      setState(() {
        _error = detail?.trim().isNotEmpty == true ? detail : e.toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          if (_loading)
            const Expanded(child: _LoadingView())
          else if (_error != null)
            Expanded(child: _ErrorView(message: _error!, onRetry: _load))
          else if (_styleContents == null)
            Expanded(child: _EmptyView(onRetry: _load))
          else ...[
            Expanded(child: _buildContent()),
          ],
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textMuted, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_primaryStyle != null)
              Row(children: [
                Text(
                  '자동 맞춤 교안 · $_primaryStyle',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (_subjectLevel != null && _subjectLevel!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _levelLabel(_subjectLevel!),
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ]),
          ]),
        ),
        IconButton(
          tooltip: '원본 강의자료 다운로드',
          icon: const Icon(Icons.download_rounded,
              color: AppColors.textMuted, size: 22),
          onPressed: _downloadOriginal,
        ),
      ]),
    );
  }

  String _levelLabel(String level) {
    switch (level) {
      case 'advanced':
        return '고급';
      case 'intermediate':
        return '중급';
      case 'beginner':
        return '입문';
      default:
        return level;
    }
  }

  Future<void> _downloadOriginal() async {
    try {
      final res = await ApiService()
          .getOriginalLectureUrl(widget.roomId, widget.lectureId);
      final url = res['url'] as String?;
      if (url == null || url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('원본 파일을 찾을 수 없습니다.')),
        );
        return;
      }
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..target = '_blank'
        ..download = widget.title;
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('원본 파일 다운로드 실패: $e')),
      );
    }
  }

  Future<void> _askVideoSegment() async {
    setState(() => _segmentLoading = true);
    try {
      final data = await ApiService().askVideoSegment(
        roomId: widget.roomId,
        lectureId: widget.lectureId,
        userId: widget.userId,
        startMinute: int.tryParse(_segmentStartCtrl.text.trim()) ?? 0,
        endMinute: int.tryParse(_segmentEndCtrl.text.trim()) ?? 0,
        question: _segmentQuestionCtrl.text.trim(),
      );
      setState(() {
        _segmentAnswer = data['answer'] as String? ?? '';
        _segmentLoading = false;
      });
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail'] as String?)
          : null;
      setState(() {
        _segmentAnswer = detail ?? '영상 구간 도움말을 불러오지 못했습니다.';
        _segmentLoading = false;
      });
    } catch (e) {
      setState(() {
        _segmentAnswer = '영상 구간 도움말 오류: $e';
        _segmentLoading = false;
      });
    }
  }

  Widget _buildContent() {
    final activeStyle = _primaryStyle ?? '읽기형';
    final content = _styleContents?[activeStyle] ??
        _styleContents?['읽기형'] ??
        (_styleContents?.values.isNotEmpty == true
            ? _styleContents!.values.first
            : null);
    if (content == null) {
      return const Center(
          child: Text('맞춤 교안이 아직 없습니다.',
              style: TextStyle(color: AppColors.textMuted)));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: _LearningExperienceShell(
                lecture: _lectureMeta,
                title: widget.title,
                content: content,
                activeStyle: activeStyle,
                profile: _profileSummary,
                subjectLevel: _subjectLevel,
                onDownloadOriginal: _downloadOriginal,
                startController: _segmentStartCtrl,
                endController: _segmentEndCtrl,
                questionController: _segmentQuestionCtrl,
                segmentAnswer: _segmentAnswer,
                segmentLoading: _segmentLoading,
                onAskSegment: _askVideoSegment,
                useSplit: constraints.maxWidth >= 1040,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── 스타일 선택 바텀시트 ──────────────────────────────────────────────────────

// ── 빈 상태 ───────────────────────────────────────────────────────────────────

class _LearningExperienceShell extends StatelessWidget {
  final Map<String, dynamic>? lecture;
  final String title;
  final String content;
  final String activeStyle;
  final Map<String, dynamic>? profile;
  final String? subjectLevel;
  final VoidCallback onDownloadOriginal;
  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController questionController;
  final String? segmentAnswer;
  final bool segmentLoading;
  final VoidCallback onAskSegment;
  final bool useSplit;

  const _LearningExperienceShell({
    required this.lecture,
    required this.title,
    required this.content,
    required this.activeStyle,
    required this.profile,
    required this.subjectLevel,
    required this.onDownloadOriginal,
    required this.startController,
    required this.endController,
    required this.questionController,
    required this.segmentAnswer,
    required this.segmentLoading,
    required this.onAskSegment,
    required this.useSplit,
  });

  @override
  Widget build(BuildContext context) {
    final videoUrl = lecture?['video_url'] as String? ?? '';
    final videoType = lecture?['video_type'] as String? ?? 'none';
    final videoStatus = lecture?['video_status'] as String? ?? 'none';
    final transcriptionStatus =
        lecture?['transcription_status'] as String? ?? 'idle';
    final videoSummary = lecture?['video_summary'] as String? ?? '';
    final materialUrl = lecture?['material_url'] as String? ?? '';
    final hasOriginal =
        (lecture?['original_file_url'] as String? ?? '').isNotEmpty;
    final hasVideo = videoUrl.trim().isNotEmpty;

    final document = _NotionDocument(
      style: activeStyle,
      title: title,
      content: content,
    );
    final sidePanel = _LearningSidePanel(
      hasVideo: hasVideo,
      transcriptionStatus: transcriptionStatus,
      videoSummary: videoSummary,
      materialUrl: materialUrl,
      hasOriginal: hasOriginal,
      onDownloadOriginal: onDownloadOriginal,
      profile: profile,
      activeStyle: activeStyle,
      subjectLevel: subjectLevel,
      startController: startController,
      endController: endController,
      questionController: questionController,
      segmentAnswer: segmentAnswer,
      segmentLoading: segmentLoading,
      onAskSegment: onAskSegment,
    );

    if (!useSplit) {
      return Column(
        children: [
          if (hasVideo) ...[
            _VideoStage(
                videoUrl: videoUrl,
                videoType: videoType,
                videoStatus: videoStatus),
            const SizedBox(height: 14),
          ],
          sidePanel,
          const SizedBox(height: 16),
          document,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              if (hasVideo) ...[
                _VideoStage(
                    videoUrl: videoUrl,
                    videoType: videoType,
                    videoStatus: videoStatus),
                const SizedBox(height: 18),
              ],
              document,
            ],
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(width: 390, child: sidePanel),
      ],
    );
  }
}

class _LearningSidePanel extends StatelessWidget {
  final bool hasVideo;
  final String transcriptionStatus;
  final String videoSummary;
  final String materialUrl;
  final bool hasOriginal;
  final VoidCallback onDownloadOriginal;
  final Map<String, dynamic>? profile;
  final String activeStyle;
  final String? subjectLevel;
  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController questionController;
  final String? segmentAnswer;
  final bool segmentLoading;
  final VoidCallback onAskSegment;

  const _LearningSidePanel({
    required this.hasVideo,
    required this.transcriptionStatus,
    required this.videoSummary,
    required this.materialUrl,
    required this.hasOriginal,
    required this.onDownloadOriginal,
    required this.profile,
    required this.activeStyle,
    required this.subjectLevel,
    required this.startController,
    required this.endController,
    required this.questionController,
    required this.segmentAnswer,
    required this.segmentLoading,
    required this.onAskSegment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StudyModePanel(
          hasVideo: hasVideo,
          transcriptionStatus: transcriptionStatus,
        ),
        const SizedBox(height: 14),
        if (hasVideo) ...[
          _VideoAssistPanel(
            startController: startController,
            endController: endController,
            questionController: questionController,
            answer: segmentAnswer,
            loading: segmentLoading,
            onAsk: onAskSegment,
          ),
          const SizedBox(height: 14),
        ],
        if (hasVideo && videoSummary.trim().isNotEmpty) ...[
          _VideoSummaryCard(summary: videoSummary),
          const SizedBox(height: 14),
        ] else if (hasVideo && transcriptionStatus != 'ready') ...[
          _VideoSummaryStatusCard(status: transcriptionStatus),
          const SizedBox(height: 14),
        ],
        _ResourceDock(
          materialUrl: materialUrl,
          hasOriginal: hasOriginal,
          onDownloadOriginal: onDownloadOriginal,
        ),
        const SizedBox(height: 14),
        _PersonalizationBasisCard(
          profile: profile,
          primaryStyle: activeStyle,
          subjectLevel: subjectLevel,
        ),
      ],
    );
  }
}

class _VideoSummaryCard extends StatelessWidget {
  final String summary;

  const _VideoSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.primaryLight.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.subject_rounded,
                  color: AppColors.primaryLight, size: 18),
              SizedBox(width: 8),
              Text(
                '영상 요약',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MarkdownText(summary),
        ],
      ),
    );
  }
}

class _VideoSummaryStatusCard extends StatelessWidget {
  final String status;

  const _VideoSummaryStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      'queued' ||
      'processing' =>
        '영상 전사와 요약을 준비 중입니다. 잠시 후 다시 열면 영상 요약이 표시됩니다.',
      'failed' => '영상 자막을 가져오지 못했습니다. 자막이 없는 유튜브 영상이거나 접근이 제한된 영상일 수 있습니다.',
      _ => '영상 요약은 전사 완료 후 표시됩니다.',
    };
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyModePanel extends StatelessWidget {
  final bool hasVideo;
  final String transcriptionStatus;

  const _StudyModePanel({
    required this.hasVideo,
    required this.transcriptionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.primaryLight.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasVideo
                      ? Icons.ondemand_video_rounded
                      : Icons.menu_book_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasVideo ? '영상 학습실' : '교안 학습실',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _TranscriptStatusPill(
                  status: transcriptionStatus, hasVideo: hasVideo),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasVideo
                ? '좌측에서 영상을 따라가고, 우측에서 구간 질문과 맞춤 교안을 함께 확인합니다.'
                : '원본 교안과 교수 핵심 포인트를 기준으로 재해석된 문서를 읽습니다.',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptStatusPill extends StatelessWidget {
  final String status;
  final bool hasVideo;

  const _TranscriptStatusPill({
    required this.status,
    required this.hasVideo,
  });

  @override
  Widget build(BuildContext context) {
    final label = !hasVideo
        ? '오프라인'
        : switch (status) {
            'ready' => '전사 완료',
            'processing' || 'queued' => '전사 중',
            'failed' => '전사 확인',
            _ => '교안 기준',
          };
    final color = status == 'ready'
        ? AppColors.primaryLight
        : status == 'failed'
            ? AppColors.accent
            : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ResourceDock extends StatelessWidget {
  final String materialUrl;
  final bool hasOriginal;
  final VoidCallback onDownloadOriginal;

  const _ResourceDock({
    required this.materialUrl,
    required this.hasOriginal,
    required this.onDownloadOriginal,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '자료',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _WorkspaceAction(
            icon: hasOriginal
                ? Icons.file_download_outlined
                : Icons.insert_drive_file_outlined,
            title: hasOriginal ? '원본 자료' : '원본 준비 중',
            subtitle: hasOriginal ? '교수 업로드 파일 열기' : '원본 파일 URL이 아직 없습니다.',
            color: hasOriginal ? AppColors.accent : AppColors.textMuted,
            onTap: hasOriginal ? onDownloadOriginal : null,
          ),
          const SizedBox(height: 10),
          _WorkspaceAction(
            icon: materialUrl.isNotEmpty
                ? Icons.link_rounded
                : Icons.link_off_rounded,
            title: materialUrl.isNotEmpty ? '보조 자료' : '보조 자료 없음',
            subtitle: materialUrl.isNotEmpty
                ? '실습 링크 또는 외부 자료'
                : '추가 링크가 연결되면 표시됩니다.',
            color: materialUrl.isNotEmpty
                ? AppColors.primaryLight
                : AppColors.textMuted,
            onTap: materialUrl.isNotEmpty
                ? () => html.window.open(materialUrl, '_blank')
                : null,
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.article_outlined,
            color: AppColors.primaryLight, size: 30),
      ),
      const SizedBox(height: 16),
      const Text(
        '교안이 아직 준비되지 않았습니다',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '교수님이 핵심 포인트를 확정하면\n개인화 교안이 생성됩니다',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
      const SizedBox(height: 28),
      GlowButton(text: '다시 불러오기', onTap: onRetry),
    ]));
  }
}

class _NotionDocument extends StatelessWidget {
  final String style;
  final String title;
  final String content;

  const _NotionDocument({
    required this.style,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final color = _styleColors[style] ?? AppColors.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF121319),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.1),
                  const Color(0xFF121319),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    '$style · 자동 맞춤 교안',
                    style: TextStyle(
                      color: Color.lerp(color, Colors.white, 0.16),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '원본 자료와 교수 핵심 포인트를 바탕으로 학생 성향과 과목 수준에 맞게 재해석했습니다.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: _MarkdownText(content),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalizationBasisCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final String primaryStyle;
  final String? subjectLevel;

  const _PersonalizationBasisCard({
    required this.profile,
    required this.primaryStyle,
    required this.subjectLevel,
  });

  @override
  Widget build(BuildContext context) {
    final reliability = profile?['reliability'] as Map<String, dynamic>? ?? {};
    final confidence = profile?['confidence_score'] as int? ?? 0;
    final dropout = profile?['dropout_risk'] as String? ?? '';
    final difficulty = profile?['difficulty_response'] as String? ?? '숙고형';
    final focus = profile?['focus_pattern'] as String? ?? '단기집중형';
    final subject = profile?['subject_level'] as String? ?? subjectLevel ?? '';
    final subjectScore = profile?['subject_score'];

    return AppCard(
      borderColor: AppColors.secondary.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.psychology_alt_rounded,
                    color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '개인화 기준',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '진단 결과와 과목 수준을 자동 적용해 교안을 재구성합니다.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _BasisChip(
                  label: 'VARK 유형',
                  value: _varkLabel(
                      profile?['vark_type'] as String? ?? primaryStyle)),
              _BasisChip(label: '집중 패턴', value: _focusLabel(focus)),
              _BasisChip(label: '난이도 대응', value: _difficultyLabel(difficulty)),
              _BasisChip(
                  label: '이탈 위험',
                  value: dropout.trim().isEmpty ? '기본 관리' : dropout),
              _BasisChip(
                  label: '과목 수준', value: _levelLabel(subject, subjectScore)),
              _BasisChip(
                  label: '신뢰도',
                  value: confidence > 0 ? '$confidence점' : '진단 보정'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReliabilityPill(
                label: 'S8↔S16',
                value: reliability['pair_s8_s16'],
              ),
              _ReliabilityPill(
                label: 'S9↔S17',
                value: reliability['pair_s9_s17'],
              ),
              _ReliabilityPill(
                label: 'S11↔S18',
                value: reliability['pair_s11_s18'],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _varkLabel(String value) {
    switch (value) {
      case '시각형':
        return '시각';
      case '청각형':
        return '청각';
      case '읽기형':
        return '읽기';
      case '실습형':
      case '행동형':
        return '행동';
      default:
        return value;
    }
  }

  static String _focusLabel(String value) {
    switch (value) {
      case '단기집중형':
        return '단기집중';
      case '장기몰입형':
        return '장기몰입';
      default:
        return value.isEmpty ? '분산형' : value;
    }
  }

  static String _difficultyLabel(String value) {
    switch (value) {
      case '속도형':
        return '직진형';
      case '숙고형':
        return '우회형';
      default:
        return value;
    }
  }

  static String _levelLabel(String value, Object? score) {
    final label = switch (value) {
      'advanced' => '고급',
      'intermediate' => '중급',
      'beginner' => '입문',
      _ => '미진단',
    };
    return score == null ? label : '$label · $score점';
  }
}

class _BasisChip extends StatelessWidget {
  final String label;
  final String value;

  const _BasisChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReliabilityPill extends StatelessWidget {
  final String label;
  final Object? value;

  const _ReliabilityPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final raw = value is num ? (value as num).toDouble() : 0.75;
    final percent = raw <= 1 ? (raw * 100).round() : raw.round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label $percent%',
        style: const TextStyle(
          color: AppColors.primaryLight,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VideoStage extends StatelessWidget {
  final String videoUrl;
  final String videoType;
  final String videoStatus;

  static final Set<String> _registeredViewTypes = {};

  const _VideoStage({
    required this.videoUrl,
    required this.videoType,
    required this.videoStatus,
  });

  @override
  Widget build(BuildContext context) {
    final viewType = 'fitlearn-video-${videoUrl.hashCode.abs()}';
    final embedUrl = _embedUrl(videoUrl, videoType);
    final canEmbed = embedUrl.isNotEmpty && videoStatus != 'processing';
    if (canEmbed && !_registeredViewTypes.contains(viewType)) {
      _registeredViewTypes.add(viewType);
      ui_web.platformViewRegistry.registerViewFactory(viewType, (_) {
        if (videoType == 'upload' || _looksLikeDirectVideo(embedUrl)) {
          return html.VideoElement()
            ..src = embedUrl
            ..controls = true
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'contain'
            ..style.backgroundColor = '#050509';
        }

        return html.IFrameElement()
          ..src = embedUrl
          ..allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
          ..allowFullscreen = true
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
      });
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF07070B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: canEmbed
                  ? HtmlElementView(viewType: viewType)
                  : _VideoFallback(
                      videoUrl: videoUrl,
                      videoStatus: videoStatus,
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0E0E14),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: AppColors.primaryLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _videoTypeLabel(videoType),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => html.window.open(videoUrl, '_blank'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('새 탭'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _embedUrl(String url, String type) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (type == 'youtube' ||
        uri.host.contains('youtube.com') ||
        uri.host.contains('youtu.be')) {
      final id = _youtubeId(uri);
      return id == null ? url : 'https://www.youtube.com/embed/$id';
    }
    return url;
  }

  static String? _youtubeId(Uri uri) {
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    if (uri.queryParameters['v'] != null) {
      return uri.queryParameters['v'];
    }
    final segments = uri.pathSegments;
    final embedIndex = segments.indexOf('embed');
    if (embedIndex >= 0 && segments.length > embedIndex + 1) {
      return segments[embedIndex + 1];
    }
    final shortsIndex = segments.indexOf('shorts');
    if (shortsIndex >= 0 && segments.length > shortsIndex + 1) {
      return segments[shortsIndex + 1];
    }
    return null;
  }

  static bool _looksLikeDirectVideo(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.contains('firebasestorage') ||
        lower.contains('storage.googleapis.com');
  }

  static String _videoTypeLabel(String type) {
    switch (type) {
      case 'youtube':
        return '온라인 영상 강의';
      case 'upload':
        return '업로드 영상 강의';
      case 'external':
        return '외부 영상 강의';
      default:
        return '영상 강의';
    }
  }
}

class _VideoAssistPanel extends StatelessWidget {
  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController questionController;
  final String? answer;
  final bool loading;
  final VoidCallback onAsk;

  const _VideoAssistPanel({
    required this.startController,
    required this.endController,
    required this.questionController,
    required this.answer,
    required this.loading,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101217),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppColors.primaryLight.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notes_rounded,
                    color: AppColors.primaryLight, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '구간 이해 도우미',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '모르는 구간을 적으면 교안과 핵심 포인트를 근거로 설명합니다.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final questionField = TextField(
                controller: questionController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '예: 이 구간의 코드 흐름이 이해가 안 돼요',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              );
              final button = SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : onAsk,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(loading ? '분석 중' : '요약 확인'),
                ),
              );

              if (compact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _MinuteField(
                                label: '시작', controller: startController)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _MinuteField(
                                label: '끝', controller: endController)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    questionField,
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: button),
                  ],
                );
              }

              return Row(
                children: [
                  _MinuteField(label: '시작', controller: startController),
                  const SizedBox(width: 10),
                  _MinuteField(label: '끝', controller: endController),
                  const SizedBox(width: 10),
                  Expanded(child: questionField),
                  const SizedBox(width: 10),
                  button,
                ],
              );
            },
          ),
          if (answer != null && answer!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: _MarkdownText(answer!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MinuteField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _MinuteField({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: '$label(분)',
          labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  final String videoUrl;
  final String videoStatus;

  const _VideoFallback({
    required this.videoUrl,
    required this.videoStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08080D),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.ondemand_video_rounded,
              color: AppColors.textMuted, size: 54),
          const SizedBox(height: 14),
          Text(
            videoStatus == 'processing'
                ? '영상 업로드 처리 중입니다'
                : '앱 안에서 재생할 수 없는 영상입니다',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '새 탭으로 열면 원본 영상 페이지에서 확인할 수 있습니다.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => html.window.open(videoUrl, '_blank'),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('영상 열기'),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _WorkspaceAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
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

// ── 마크다운 렌더러 ──────────────────────────────────────────────────────────

class _MarkdownText extends StatelessWidget {
  final String content;
  const _MarkdownText(this.content);

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    final codeBuffer = <String>[];
    var inCodeBlock = false;

    for (final line in lines) {
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(_CodeBlock(code: codeBuffer.join('\n')));
          codeBuffer.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.add(line);
      } else {
        widgets.add(_renderLine(line));
      }
    }

    if (codeBuffer.isNotEmpty) {
      widgets.add(_CodeBlock(code: codeBuffer.join('\n')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _renderLine(String line) {
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
        child: _SectionHeading(text: line.substring(4), level: 3),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 30, 0, 10),
        child: _SectionHeading(text: line.substring(3), level: 2),
      );
    }
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
        child: _SectionHeading(text: line.substring(2), level: 1),
      );
    }
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 10, 12, 0),
            child: CircleAvatar(
                radius: 2.5, backgroundColor: AppColors.primaryLight),
          ),
          Expanded(
            child: SelectableText(
              line.substring(2),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.65,
              ),
            ),
          ),
        ]),
      );
    }
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          border:
              Border(left: BorderSide(color: AppColors.primaryLight, width: 3)),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ).copyWith(
          color: AppColors.primary.withValues(alpha: 0.06),
        ),
        child: SelectableText(
          line.substring(2),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      );
    }
    if (line.trim().isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText(
        line,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.7,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  final int level;

  const _SectionHeading({
    required this.text,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = level == 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isTop ? AppColors.primaryLight : AppColors.border,
            width: isTop ? 3 : 2,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: isTop ? 14 : 12),
        child: SelectableText(
          text,
          style: TextStyle(
            color: isTop ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isTop ? 24 : (level == 2 ? 19 : 16),
            fontWeight: isTop ? FontWeight.w900 : FontWeight.w800,
            height: 1.35,
            letterSpacing: isTop ? -0.55 : -0.2,
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;

  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF080A0F),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.primaryLight.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF10131B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Icon(Icons.code_rounded,
                    color: AppColors.primaryLight, size: 16),
                SizedBox(width: 8),
                Text(
                  '실습 코드',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              code,
              style: const TextStyle(
                color: Color(0xFFE7EAF3),
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 로딩 / 에러 ──────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🤖', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            'AI가 6가지 스타일로 교안을 재가공하고 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '시각형·청각형·읽기형·실습형·요약형·상세형 동시 생성 중',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppColors.bgSurface,
              valueColor: AlwaysStoppedAnimation(AppColors.primaryLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final lower = message.toLowerCase();
    String title = '교안 로드 실패';
    String hint = '잠시 후 다시 시도해주세요.';
    if (message.contains('학습 성향 진단을 먼저 완료해주세요')) {
      title = '학습 성향 진단이 필요합니다';
      hint = '학생 홈에서 학습 성향 진단을 먼저 완료한 뒤 다시 열어주세요.';
    } else if (message.contains('교수가 아직 핵심 포인트를 확정')) {
      title = '교안 검토가 아직 진행 중입니다';
      hint = '교수님이 핵심 포인트를 확정하면 개인화 교안을 볼 수 있습니다.';
    } else if (lower.contains('404')) {
      hint = '강의 자료가 아직 업로드되지 않았거나 삭제되었을 수 있습니다.';
    }
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 8),
        Text(hint,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        GlowButton(text: '다시 불러오기', onTap: onRetry),
      ]),
    ));
  }
}
