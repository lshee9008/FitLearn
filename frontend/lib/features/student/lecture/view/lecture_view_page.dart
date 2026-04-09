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
  String _selectedStyle = '시각형';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
            Text('기본: $_primaryStyle',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ])),
      ]),
    );
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
          final color = _styleColors[s] ?? AppColors.primary;
          final isPrimary = s == _primaryStyle;
          return GestureDetector(
            onTap: _styleContents?.containsKey(s) == true
                ? () => setState(() => _selectedStyle = s)
                : null,
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
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(s, style: TextStyle(
                  color: isSelected ? color : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                )),
                if (isPrimary) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(children: [
        _StyleHeader(style: _selectedStyle),
        const SizedBox(height: 16),
        _MarkdownText(content),
      ]),
    );
  }
}

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
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.primaryLight, width: 3)),
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8), bottomRight: Radius.circular(8),
          ),
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
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🤖', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      const Text('AI가 6가지 스타일로 교안을 재가공하고 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('시각형·청각형·읽기형·실습형·요약형·상세형 동시 생성 중',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      SizedBox(width: 200, child: LinearProgressIndicator(
        backgroundColor: AppColors.bgSurface,
        valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
      )),
    ]));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        const Text('교안 로드 실패', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        GlowButton(text: '다시 시도', onTap: onRetry),
      ]),
    ));
  }
}
