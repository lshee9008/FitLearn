import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/theme/tokens.dart';

/// FitLearn 공용 마크다운 렌더러 — 표·코드블록·체크리스트·인용 콜아웃 지원 (GFM)
class FLMarkdown extends StatelessWidget {
  final String data;
  final double scale;
  final Color accent;

  const FLMarkdown(
    this.data, {
    super.key,
    this.scale = 1.0,
    this.accent = FL.lime,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: FL.textSec,
      fontSize: 15.5 * scale,
      height: 1.75,
      letterSpacing: -0.1,
    );
    TextStyle heading(double size) => TextStyle(
          color: FL.text,
          fontSize: size * scale,
          fontWeight: FontWeight.w800,
          height: 1.35,
          letterSpacing: -0.4,
        );

    return MarkdownBody(
      data: _normalize(data),
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: {'pre': _CodeBlockBuilder(accent)},
      checkboxBuilder: (checked) => Padding(
        padding: const EdgeInsets.only(right: 8, top: 4),
        child: Icon(
          checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
          size: 18 * scale,
          color: checked ? accent : FL.textMute,
        ),
      ),
      styleSheet: MarkdownStyleSheet(
        p: base,
        pPadding: const EdgeInsets.only(bottom: 4),
        a: base.copyWith(color: accent, decoration: TextDecoration.underline),
        strong: const TextStyle(color: FL.text, fontWeight: FontWeight.w800),
        em: const TextStyle(fontStyle: FontStyle.italic, color: FL.text),
        del: const TextStyle(decoration: TextDecoration.lineThrough),
        h1: heading(28),
        h1Padding: const EdgeInsets.only(bottom: 4),
        h2: heading(21),
        h2Padding: const EdgeInsets.only(top: 28, bottom: 2),
        h3: heading(17.5).copyWith(color: FL.text.withValues(alpha: 0.92)),
        h3Padding: const EdgeInsets.only(top: 18),
        h4: heading(15.5),
        code: TextStyle(
          color: accent,
          backgroundColor: FL.surface3,
          fontFamily: 'monospace',
          fontSize: 13.5 * scale,
        ),
        blockSpacing: 12,
        listIndent: 22,
        listBullet: base.copyWith(color: accent, fontWeight: FontWeight.w800),
        listBulletPadding: const EdgeInsets.only(right: 6),
        blockquote: base.copyWith(color: FL.text, fontSize: 15 * scale),
        blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        blockquoteDecoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(FL.r12),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        tableHead: TextStyle(color: FL.text, fontWeight: FontWeight.w800, fontSize: 14 * scale),
        tableBody: base.copyWith(fontSize: 14 * scale, height: 1.55),
        tableHeadAlign: TextAlign.left,
        tableBorder: TableBorder.all(color: FL.border, width: 1, borderRadius: BorderRadius.circular(FL.r8)),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        tableCellsDecoration: const BoxDecoration(color: FL.surface),
        tableColumnWidth: const FlexColumnWidth(),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: FL.border, width: 1)),
        ),
      ),
    );
  }

  /// 모델이 가끔 마크다운 전체를 ```markdown 으로 감싸는 경우 제거.
  static String _normalize(String text) {
    var t = text.trim();
    final wrapped = RegExp(r'^```(?:markdown|md)\s*\n([\s\S]*?)\n```$');
    final m = wrapped.firstMatch(t);
    if (m != null) t = m.group(1)!;
    // 코드블록(```) 안은 건드리지 않고 본문 줄만 보정
    var inCode = false;
    final lines = t.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('```')) {
        inCode = !inCode;
      } else if (!inCode) {
        lines[i] = _fixKoreanEmphasis(lines[i]);
      }
    }
    return lines.join('\n');
  }

  /// CommonMark는 `**(w)**와`처럼 문장부호 뒤 닫는 `**` 다음에 한글이 오면 굵게를 닫지 못한다.
  /// 굵게 구간 양끝에 폭 없는 공백(U+200B)을 넣어 항상 열리고 닫히게 한다.
  static String _fixKoreanEmphasis(String text) {
    final bold = RegExp(r'(?<![*\\])\*\*(?![\s*])([^*\n`]+?)(?<![\s\\])\*\*(?!\*)');
    return text.replaceAllMapped(bold, (m) => '**​${m.group(1)}​**');
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final Color accent;
  _CodeBlockBuilder(this.accent);

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';
    final first = element.children?.isNotEmpty == true ? element.children!.first : null;
    if (first is md.Element) {
      language = (first.attributes['class'] ?? '').replaceFirst('language-', '');
    }
    final code = element.textContent.replaceAll(RegExp(r'\n$'), '');
    return _CodeBlock(code: code, language: language, accent: accent);
  }
}

class _CodeBlock extends StatefulWidget {
  final String code;
  final String language;
  final Color accent;
  const _CodeBlock({required this.code, required this.language, required this.accent});

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.language.isEmpty ? '코드' : widget.language;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF09090D),
        borderRadius: BorderRadius.circular(FL.r12),
        border: Border.all(color: FL.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: FL.border)),
            ),
            child: Row(children: [
              Icon(Icons.terminal_rounded, size: 14, color: widget.accent),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: FL.textSec, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _copy,
                style: TextButton.styleFrom(
                  foregroundColor: _copied ? widget.accent : FL.textSec,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 14),
                label: Text(_copied ? '복사됨' : '복사'),
              ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.code,
              style: const TextStyle(
                color: Color(0xFFE4E6EF),
                fontFamily: 'monospace',
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
