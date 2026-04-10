// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/widgets/app_card.dart';

const _styles = ['시각형', '청각형', '읽기형', '실습형', '요약형', '상세형'];

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
  String? _primaryStyle;
  String? _subjectLevel;
  String _selectedStyle = '읽기형';
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
      final data = await ApiService().getReforgedLecture(
        roomId: widget.roomId,
        lectureId: widget.lectureId,
        userId: widget.userId,
      );
      final rawStyles = data['styles'] as Map<String, dynamic>? ?? {};
      setState(() {
        _styleContents = rawStyles.map((k, v) => MapEntry(k, v as String));
        _primaryStyle = data['primary_style'] as String? ?? '읽기형';
        _subjectLevel = data['subject_level'] as String?;
        _selectedStyle = _primaryStyle!;
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
            _buildStyleTabs(),
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

  Widget _buildStyleTabs() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _styles[i];
          final isSelected = _selectedStyle == s;
          final hasContent = _styleContents?.containsKey(s) == true;
          final color = _styleColors[s] ?? AppColors.primary;
          final isPrimary = s == _primaryStyle;
          return GestureDetector(
            onTap: hasContent ? () => setState(() => _selectedStyle = s) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_styleEmojis[s] ?? '📄',
                    style: TextStyle(fontSize: 14, color: hasContent ? null : AppColors.textMuted.withValues(alpha: 0.4))),
                const SizedBox(width: 6),
                Text(s, style: TextStyle(
                  color: isSelected ? color : (hasContent ? AppColors.textMuted : AppColors.textMuted.withValues(alpha: 0.4)),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                )),
                if (isPrimary) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    final content = _styleContents?[_selectedStyle];
    if (content == null) {
      return const Center(child: Text('해당 스타일의 교안이 없습니다.',
          style: TextStyle(color: AppColors.textMuted)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      child: Column(children: [
        _StyleHeader(style: _selectedStyle),
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

// ── 마크다운 렌더러 ──────────────────────────────────────────────────────────

class _MarkdownText extends StatelessWidget {
  final String content;
  const _MarkdownText(this.content);

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _renderLine(line)).toList(),
    );
  }

  Widget _renderLine(String line) {
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
        child: Text(line.substring(4), style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800,
        )),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
        child: Text(line.substring(3), style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900,
        )),
      );
    }
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        child: Text(line.substring(2), style: const TextStyle(
          color: AppColors.primaryLight, fontSize: 20, fontWeight: FontWeight.w900,
        )),
      );
    }
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 7, 8, 0),
            child: CircleAvatar(radius: 3, backgroundColor: AppColors.primaryLight),
          ),
          Expanded(child: Text(line.substring(2), style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 14, height: 1.6,
          ))),
        ]),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(line, style: const TextStyle(
        color: AppColors.textSecondary, fontSize: 14, height: 1.7,
      )),
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
