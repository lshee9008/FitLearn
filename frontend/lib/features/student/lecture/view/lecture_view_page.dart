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

const _styleEmojis = {
  '시각형': '👁️',
  '청각형': '👂',
  '읽기형': '📖',
  '실습형': '🔧',
  '요약형': '⚡',
  '상세형': '🔍',
};

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
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
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
      setState(() { _error = e.toString(); _loading = false; });
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800,
          ), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (_primaryStyle != null)
            Row(children: [
              Text('${_styleEmojis[_primaryStyle]} $_primaryStyle 맞춤 교안',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              if (_subjectLevel != null && _subjectLevel!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_levelLabel(_subjectLevel!),
                      style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
        ])),
        IconButton(
          tooltip: '원본 강의자료 다운로드',
          icon: const Icon(Icons.download_rounded, color: AppColors.textMuted, size: 22),
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
      final res = await ApiService().getOriginalLectureUrl(widget.roomId, widget.lectureId);
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

  Widget _buildContent() {
    final activeStyle = _primaryStyle ?? '읽기형';
    final content = _styleContents?[activeStyle] ??
        _styleContents?['읽기형'] ??
        (_styleContents?.values.isNotEmpty == true ? _styleContents!.values.first : null);
    if (content == null) {
      return const Center(child: Text('맞춤 교안이 아직 없습니다.',
          style: TextStyle(color: AppColors.textMuted)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      child: Column(children: [
        _LearningWorkspaceHeader(
          lecture: _lectureMeta,
          onDownloadOriginal: _downloadOriginal,
        ),
        const SizedBox(height: 16),
        _PersonalizationBasisCard(
          profile: _profileSummary,
          primaryStyle: activeStyle,
          subjectLevel: _subjectLevel,
        ),
        const SizedBox(height: 16),
        _StyleHeader(style: activeStyle),
        const SizedBox(height: 16),
        _MarkdownText(content),
      ]),
    );
  }
}

// ── 스타일 선택 바텀시트 ──────────────────────────────────────────────────────

// ── 빈 상태 ───────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🎯', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('교안이 아직 준비되지 않았습니다', style: TextStyle(
        color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800,
      )),
      const SizedBox(height: 8),
      const Text('교수님이 핵심 포인트를 확정하면\n개인화 교안이 생성됩니다', textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      const SizedBox(height: 28),
      GlowButton(text: '다시 불러오기', onTap: onRetry),
    ]));
  }
}

// ── 스타일 헤더 ───────────────────────────────────────────────────────────────

class _StyleHeader extends StatelessWidget {
  final String style;
  const _StyleHeader({required this.style});

  @override
  Widget build(BuildContext context) {
    final color = _styleColors[style] ?? AppColors.primary;
    final emoji = _styleEmojis[style] ?? '📄';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$style 맞춤 교안', style: TextStyle(
            color: color, fontSize: 14, fontWeight: FontWeight.w800,
          )),
          const Text('AI가 학습 성향에 맞게 재가공한 교안입니다',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
      ]),
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
                child: const Icon(Icons.psychology_alt_rounded, color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 재해석 기준',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '학생이 고르는 옵션이 아니라, 진단 결과와 과목 수준으로 자동 적용됩니다.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
              _BasisChip(label: 'VARK 유형', value: _varkLabel(profile?['vark_type'] as String? ?? primaryStyle)),
              _BasisChip(label: '집중 패턴', value: _focusLabel(focus)),
              _BasisChip(label: '난이도 대응', value: _difficultyLabel(difficulty)),
              _BasisChip(label: '이탈 위험', value: dropout.trim().isEmpty ? '기본 관리' : dropout),
              _BasisChip(label: '과목 수준', value: _levelLabel(subject, subjectScore)),
              _BasisChip(label: '신뢰도', value: confidence > 0 ? '$confidence점' : '진단 보정'),
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
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2)),
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

class _LearningWorkspaceHeader extends StatelessWidget {
  final Map<String, dynamic>? lecture;
  final VoidCallback onDownloadOriginal;

  const _LearningWorkspaceHeader({
    required this.lecture,
    required this.onDownloadOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final videoUrl = lecture?['video_url'] as String? ?? '';
    final videoType = lecture?['video_type'] as String? ?? 'none';
    final videoStatus = lecture?['video_status'] as String? ?? 'none';
    final materialUrl = lecture?['material_url'] as String? ?? '';
    final hasOriginal = (lecture?['original_file_url'] as String? ?? '').isNotEmpty;
    final hasVideo = videoUrl.trim().isNotEmpty;

    return AppCard(
      borderColor: AppColors.primaryLight.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.view_in_ar_rounded, color: AppColors.primaryLight),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '학습 워크스페이스',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '영상, 원본 자료, AI 재해석 교안을 함께 보며 수업 흐름을 따라갑니다.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasVideo) ...[
            _VideoStage(
              videoUrl: videoUrl,
              videoType: videoType,
              videoStatus: videoStatus,
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _WorkspaceAction(
                icon: hasOriginal ? Icons.file_download_outlined : Icons.insert_drive_file_outlined,
                title: hasOriginal ? '원본 자료' : '원본 준비 중',
                subtitle: hasOriginal ? '교수 업로드 원본을 새 탭에서 확인합니다.' : '원본 파일 URL이 아직 없습니다.',
                color: hasOriginal ? AppColors.accent : AppColors.textMuted,
                onTap: hasOriginal ? onDownloadOriginal : null,
              ),
              _WorkspaceAction(
                icon: materialUrl.isNotEmpty ? Icons.link_rounded : Icons.link_off_rounded,
                title: materialUrl.isNotEmpty ? '보조 자료' : '보조 자료 없음',
                subtitle: materialUrl.isNotEmpty ? '실습 링크나 외부 자료를 엽니다.' : '추가 링크가 연결되면 표시됩니다.',
                color: materialUrl.isNotEmpty ? AppColors.primaryLight : AppColors.textMuted,
                onTap: materialUrl.isNotEmpty ? () => html.window.open(materialUrl, '_blank') : null,
              ),
            ],
          ),
        ],
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
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
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
                  child: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryLight),
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
    if (type == 'youtube' || uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
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
          const Icon(Icons.ondemand_video_rounded, color: AppColors.textMuted, size: 54),
          const SizedBox(height: 14),
          Text(
            videoStatus == 'processing' ? '영상 업로드 처리 중입니다' : '앱 안에서 재생할 수 없는 영상입니다',
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
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: _SectionHeading(text: line.substring(4), level: 3),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
        child: _SectionHeading(text: line.substring(3), level: 2),
      );
    }
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
        child: _SectionHeading(text: line.substring(2), level: 1),
      );
    }
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 7, 10, 0),
              child: CircleAvatar(radius: 3, backgroundColor: AppColors.primaryLight),
            ),
            Expanded(child: Text(line.substring(2), style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14, height: 1.65,
            ))),
          ]),
        ),
      );
    }
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.primaryLight, width: 3)),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(8), bottomRight: Radius.circular(8),
          ),
        ).copyWith(
          color: AppColors.primary.withValues(alpha: 0.06),
        ),
        child: Text(line.substring(2), style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 13,
          fontStyle: FontStyle.italic, height: 1.5,
        )),
      );
    }
    if (line.trim().isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(line, style: const TextStyle(
        color: AppColors.textSecondary, fontSize: 14, height: 1.7,
      )),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isTop ? 18 : 14, vertical: isTop ? 16 : 12),
      decoration: BoxDecoration(
        color: isTop
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.bgSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(isTop ? 18 : 14),
        border: Border.all(
          color: isTop
              ? AppColors.primaryLight.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isTop ? AppColors.primaryLight : AppColors.textPrimary,
          fontSize: isTop ? 22 : (level == 2 ? 18 : 16),
          fontWeight: FontWeight.w900,
          height: 1.35,
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
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.18)),
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
                Icon(Icons.code_rounded, color: AppColors.primaryLight, size: 16),
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
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 8),
        Text(hint, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        GlowButton(text: '다시 불러오기', onTap: onRetry),
      ]),
    ));
  }
}
