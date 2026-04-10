import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

const _styleDescs = {
  '시각형': '도식·흐름도·색상 구분',
  '청각형': '대화체·스토리텔링',
  '읽기형': '체계적 텍스트·목록',
  '실습형': '단계별 실습 가이드',
  '요약형': '핵심만 3-5줄 압축',
  '상세형': '단계별 상세·예외 포함',
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
  String _selectedStyle = '읽기형';
  bool _loading = false;
  String? _error;
  String? _testStyle; // 테스트 모드 선택 스타일

  @override
  void initState() {
    super.initState();
    // 시작 시 스타일 선택 시트 표시
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStylePicker());
  }

  Future<void> _showStylePicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StylePickerSheet(current: _testStyle),
    );
    if (picked != null) {
      setState(() {
        _testStyle = picked;
        _selectedStyle = picked;
      });
      await _load(testStyle: picked);
    }
  }

  Future<void> _load({String? testStyle}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getReforgedLecture(
        roomId: widget.roomId,
        lectureId: widget.lectureId,
        userId: widget.userId,
        testStyle: testStyle ?? _testStyle,
      );
      final rawStyles = data['styles'] as Map<String, dynamic>? ?? {};
      setState(() {
        _styleContents = rawStyles.map((k, v) => MapEntry(k, v as String));
        _primaryStyle = data['primary_style'] as String? ?? testStyle ?? '읽기형';
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
      floatingActionButton: _styleContents != null
          ? FloatingActionButton.extended(
              onPressed: _showStylePicker,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.tune_rounded, color: Colors.white),
              label: const Text('스타일 변경',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          if (_loading)
            const Expanded(child: _LoadingView())
          else if (_error != null)
            Expanded(child: _ErrorView(message: _error!, onRetry: _showStylePicker))
          else if (_styleContents == null)
            Expanded(child: _EmptyView(onPick: _showStylePicker))
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
              if (_testStyle != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('테스트 모드',
                      style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
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

class _StylePickerSheet extends StatelessWidget {
  final String? current;
  const _StylePickerSheet({this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        const Text('학습 성향 선택',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('교안을 재가공할 학습 스타일을 선택하세요',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        ...List.generate(_styles.length, (i) {
          final s = _styles[i];
          final color = _styleColors[s] ?? AppColors.primary;
          final isSelected = s == current;
          return GestureDetector(
            onTap: () => Navigator.pop(context, s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.12) : AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Text(_styleEmojis[s] ?? '📄', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s, style: TextStyle(
                    color: isSelected ? color : AppColors.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w700,
                  )),
                  Text(_styleDescs[s] ?? '', style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12,
                  )),
                ])),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 20)
                else
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: AppColors.textMuted, size: 14),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── 빈 상태 ───────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptyView({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🎯', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('학습 성향을 선택하세요', style: TextStyle(
        color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800,
      )),
      const SizedBox(height: 8),
      const Text('AI가 선택한 성향에 맞게\n교안을 재가공합니다', textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      const SizedBox(height: 28),
      GlowButton(text: '성향 선택하기', onTap: onPick),
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

// ── 마크다운 렌더러 (flutter_markdown) ───────────────────────────────────────

class _MarkdownText extends StatelessWidget {
  final String content;
  const _MarkdownText(this.content);

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
            color: AppColors.primaryLight,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.3),
        h1Padding: const EdgeInsets.only(top: 8, bottom: 14),
        h2: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.3),
        h2Padding: const EdgeInsets.only(top: 24, bottom: 8),
        h3: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.4),
        h3Padding: const EdgeInsets.only(top: 18, bottom: 6),
        p: const TextStyle(
            color: AppColors.textSecondary, fontSize: 14, height: 1.75),
        pPadding: const EdgeInsets.only(bottom: 4),
        listBullet: const TextStyle(color: AppColors.primary, fontSize: 14),
        listBulletPadding: const EdgeInsets.only(right: 8),
        listIndent: 20,
        blockquote: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            height: 1.5),
        blockquoteDecoration: BoxDecoration(
          border: const Border(
              left: BorderSide(color: AppColors.primary, width: 4)),
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        code: const TextStyle(
            color: AppColors.primaryLight,
            backgroundColor: Color(0xFF141420),
            fontSize: 12,
            fontFamily: 'monospace'),
        codeblockDecoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        codeblockPadding: const EdgeInsets.all(14),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        strong: const TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        em: const TextStyle(
            color: AppColors.textSecondary, fontStyle: FontStyle.italic),
        tableHead: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13),
        tableBody:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        tableBorder: TableBorder.all(color: AppColors.border, width: 1),
        tableCellsPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
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
        GlowButton(text: '스타일 다시 선택', onTap: onRetry),
      ]),
    ));
  }
}
