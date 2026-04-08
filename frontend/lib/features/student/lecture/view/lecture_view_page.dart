import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/widgets/app_card.dart';

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
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getReforgedLecture(
        roomId: widget.roomId,
        lectureId: widget.lectureId,
        userId: widget.userId,
      );
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primaryLight),
                SizedBox(height: 16),
                Text('맞춤 교안을 생성 중입니다...', style: TextStyle(color: AppColors.textMuted)),
              ]))
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.rose, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 20),
                    GlowButton(text: '다시 시도', onTap: _load, fullWidth: false),
                  ]))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final style = _data?['style'] as String? ?? '';
    final content = _data?['content'] as String? ?? '';
    final color = LearningStyleUtil.color(style);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 스타일 배지
              Row(children: [
                TypeBadge(
                  label: '${LearningStyleUtil.emoji(style)} $style 맞춤',
                  color: color,
                ),
              ]),
              const SizedBox(height: 20),
              // 본문 (마크다운처럼 렌더링)
              _MarkdownText(content: content),
            ]),
          ),
        ),
      ],
    );
  }
}

/// 마크다운 텍스트를 간단히 렌더링하는 위젯
class _MarkdownText extends StatelessWidget {
  final String content;
  const _MarkdownText({required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _renderLine(line)).toList(),
    );
  }

  Widget _renderLine(String line) {
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(line.substring(2), style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800,
        )),
      );
    } else if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(line.substring(3), style: const TextStyle(
          color: AppColors.primaryLight, fontSize: 17, fontWeight: FontWeight.w700,
        )),
      );
    } else if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(line.substring(4), style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
        )),
      );
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: CircleAvatar(radius: 3, backgroundColor: AppColors.primaryLight),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(line.substring(2), style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 14, height: 1.6,
          ))),
        ]),
      );
    } else if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: AppColors.primaryLight, width: 3)),
        ),
        child: Text(line.substring(2), style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 14, fontStyle: FontStyle.italic,
        )),
      );
    } else if (line.trim().isEmpty) {
      return const SizedBox(height: 8);
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(line, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 14, height: 1.7,
        )),
      );
    }
  }
}
