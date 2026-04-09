import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';

const _styles = ['시각형', '청각형', '읽기형', '실습형', '요약형', '상세형'];

const _styleEmojis = {
  '시각형': '👁️', '청각형': '👂', '읽기형': '📖',
  '실습형': '🔧', '요약형': '⚡', '상세형': '🔍',
};

const _styleColors = {
  '시각형': Color(0xFF6366F1),
  '청각형': Color(0xFF8B5CF6),
  '읽기형': Color(0xFF10B981),
  '실습형': Color(0xFFF59E0B),
  '요약형': Color(0xFFEF4444),
  '상세형': Color(0xFFEC4899),
};

const _styleDescs = {
  '시각형': '도식·흐름도·색상 구분으로 시각화',
  '청각형': '대화체·스토리텔링으로 설명',
  '읽기형': '체계적 텍스트·목록 중심',
  '실습형': '단계별 실습 가이드 중심',
  '요약형': 'CLT 이론: 핵심만 3-5줄 압축',
  '상세형': 'Felder-Silverman: 단계별 상세 설명',
};

class ReforgeTestPage extends StatefulWidget {
  const ReforgeTestPage({super.key});

  @override
  State<ReforgeTestPage> createState() => _ReforgeTestPageState();
}

class _ReforgeTestPageState extends State<ReforgeTestPage> {
  String _selectedStyle = '읽기형';
  final _contentCtrl = TextEditingController();
  bool _loading = false;
  Map<String, String>? _results;   // style → content
  String _viewStyle = '읽기형';
  String? _error;

  final _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 120), // AI 생성 시간
  ));

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _results = null; });
    try {
      final res = await _dio.post('/api/v1/lectures/demo/reforged', data: {
        'test_style': _selectedStyle,
        'content': _contentCtrl.text.trim(),
      });
      final raw = (res.data['styles'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
      setState(() {
        _results = raw;
        _viewStyle = _selectedStyle;
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
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('재가공 시스템 테스트',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('TEST MODE',
                style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: _results != null ? _buildResult() : _buildInput(),
    );
  }

  // ── 입력 화면 ─────────────────────────────────────────────────────────────

  Widget _buildInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 제목
        const Text('학습 성향 선택', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900,
        )),
        const SizedBox(height: 4),
        const Text('AI가 선택한 성향에 맞게 교안을 6가지 스타일로 재가공합니다',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 20),

        // 스타일 선택 그리드
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.8,
          children: _styles.map((s) {
            final isSelected = _selectedStyle == s;
            final color = _styleColors[s] ?? AppColors.primary;
            return GestureDetector(
              onTap: () => setState(() => _selectedStyle = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Text(_styleEmojis[s] ?? '', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s, style: TextStyle(
                        color: isSelected ? color : AppColors.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w700,
                      )),
                      Text(_styleDescs[s]!, style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10,
                      ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: color, size: 16),
                ]),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // 교안 입력
        Row(children: [
          const Text('교안 내용', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800,
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('비워두면 내장 샘플 사용',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _contentCtrl,
            maxLines: 10,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
              hintText: '교안 내용을 붙여넣으세요\n(PDF/PPT 텍스트, 강의 노트 등)\n\n비워두면 학습심리학 기초 샘플 교안 사용',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.6),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 12)),
          ),
        ],

        const SizedBox(height: 28),

        // 실행 버튼
        SizedBox(
          width: double.infinity,
          child: _loading
              ? _LoadingButton()
              : ElevatedButton(
                  onPressed: _run,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _styleColors[_selectedStyle] ?? AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_styleEmojis[_selectedStyle] ?? '🤖',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text('$_selectedStyle 스타일로 재가공', style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                    )),
                  ]),
                ),
        ),
        const SizedBox(height: 8),
        const Center(child: Text('6가지 스타일 동시 생성 · 약 15-30초 소요',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── 결과 화면 ─────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final color = _styleColors[_viewStyle] ?? AppColors.primary;
    final content = _results?[_viewStyle] ?? '';

    return Column(children: [
      // 상단 탭바
      Container(
        height: 52,
        color: AppColors.bg,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _styles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _styles[i];
            final isSelected = _viewStyle == s;
            final c = _styleColors[s] ?? AppColors.primary;
            final hasContent = _results?.containsKey(s) == true;
            return GestureDetector(
              onTap: hasContent ? () => setState(() => _viewStyle = s) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? c.withValues(alpha: 0.15) : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? c : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_styleEmojis[s] ?? '', style: TextStyle(
                    fontSize: 13,
                    color: hasContent ? null : AppColors.textMuted.withValues(alpha: 0.4),
                  )),
                  const SizedBox(width: 5),
                  Text(s, style: TextStyle(
                    color: isSelected ? c : (hasContent ? AppColors.textMuted : AppColors.textMuted.withValues(alpha: 0.4)),
                    fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  )),
                ]),
              ),
            );
          },
        ),
      ),

      // 스타일 헤더
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Text(_styleEmojis[_viewStyle] ?? '', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_viewStyle 맞춤 교안', style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w800,
            )),
            Text(_styleDescs[_viewStyle] ?? '',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          // 다시 테스트 버튼
          GestureDetector(
            onTap: () => setState(() { _results = null; _error = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('다시 테스트',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),

      // 본문
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: _MarkdownRenderer(content),
        ),
      ),
    ]);
  }
}

// ── 로딩 버튼 ─────────────────────────────────────────────────────────────────

class _LoadingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.primaryLight),
          ),
        ),
        const SizedBox(width: 12),
        const Text('AI 재가공 중... (약 15-30초)',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── 마크다운 렌더러 ───────────────────────────────────────────────────────────

class _MarkdownRenderer extends StatelessWidget {
  final String content;
  const _MarkdownRenderer(this.content);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content.split('\n').map(_line).toList(),
    );
  }

  Widget _line(String line) {
    if (line.startsWith('### ')) {
      return Padding(padding: const EdgeInsets.fromLTRB(0, 18, 0, 5),
        child: Text(line.substring(4), style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)));
    }
    if (line.startsWith('## ')) {
      return Padding(padding: const EdgeInsets.fromLTRB(0, 22, 0, 7),
        child: Text(line.substring(3), style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)));
    }
    if (line.startsWith('# ')) {
      return Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
        child: Text(line.substring(2), style: const TextStyle(
          color: AppColors.primaryLight, fontSize: 19, fontWeight: FontWeight.w900)));
    }
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return Padding(padding: const EdgeInsets.only(bottom: 5, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.fromLTRB(0, 7, 8, 0),
            child: CircleAvatar(radius: 3, backgroundColor: AppColors.primaryLight)),
          Expanded(child: Text(line.substring(2), style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 14, height: 1.6))),
        ]));
    }
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.primaryLight, width: 3)),
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        child: Text(line.substring(2), style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic, height: 1.5)));
    }
    if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
      return Padding(padding: const EdgeInsets.only(bottom: 3),
        child: Text(line.replaceAll('**', ''), style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800, height: 1.6)));
    }
    if (line.trim().isEmpty) return const SizedBox(height: 7);
    return Padding(padding: const EdgeInsets.only(bottom: 3),
      child: Text(line, style: const TextStyle(
        color: AppColors.textSecondary, fontSize: 14, height: 1.7)));
  }
}
