import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';

// ── 성향 데이터 ───────────────────────────────────────────────────────────────

class _StyleGroup {
  final String label;
  final List<_Style> styles;
  const _StyleGroup(this.label, this.styles);
}

class _Style {
  final String name;
  final String emoji;
  final Color color;
  final String desc;
  const _Style(this.name, this.emoji, this.color, this.desc);
}

final _groups = [
  _StyleGroup('지각 채널 (VARK)', [
    _Style('시각형', '👁️', Color(0xFF6366F1), '도식·표·흐름도'),
    _Style('청각형', '👂', Color(0xFF8B5CF6), '대화체·스토리'),
    _Style('읽기형', '📖', Color(0xFF10B981), '체계적 텍스트'),
    _Style('운동형', '🔧', Color(0xFFF59E0B), '실습·행동 중심'),
  ]),
  _StyleGroup('인지 처리', [
    _Style('분석형', '🔬', Color(0xFF3B82F6), '논리·근거 순서'),
    _Style('직관형', '💡', Color(0xFFEC4899), '전체 그림 먼저'),
  ]),
  _StyleGroup('정보 밀도', [
    _Style('요약형', '⚡', Color(0xFFEF4444), '핵심만 압축'),
    _Style('상세형', '🔍', Color(0xFF64748B), '빠짐없이 상세'),
    _Style('예시형', '📌', Color(0xFF0EA5E9), '구체 사례 중심'),
  ]),
];

// ── 페이지 ────────────────────────────────────────────────────────────────────

class ReforgeTestPage extends StatefulWidget {
  const ReforgeTestPage({super.key});

  @override
  State<ReforgeTestPage> createState() => _ReforgeTestPageState();
}

class _ReforgeTestPageState extends State<ReforgeTestPage> with SingleTickerProviderStateMixin {
  // 성향 선택 — 그룹별로 하나씩
  final Map<int, String> _selected = {};

  // 입력
  final _textCtrl = TextEditingController();
  PlatformFile? _file;
  int _inputTab = 0; // 0=텍스트, 1=파일

  // 상태
  bool _running = false;
  String _reforged = '';
  List<String> _tags = [];
  String? _error;
  bool _done = false;

  late final TabController _tabCtrl;

  final _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 120),
  ));

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() => _inputTab = _tabCtrl.index));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  String get _learningType =>
      _selected.values.where((v) => v.isNotEmpty).join('+');

  bool get _canRun {
    final hasInput = _inputTab == 0
        ? _textCtrl.text.trim().isNotEmpty
        : _file != null;
    return hasInput && _selected.isNotEmpty && !_running;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'md', 'pptx', 'hwp'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() { _file = result.files.first; _error = null; });
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _reforged = '';
      _tags = [];
      _error = null;
      _done = false;
    });

    try {
      final formData = FormData.fromMap({
        'learning_type': _learningType,
        if (_inputTab == 0) 'content': _textCtrl.text.trim(),
        if (_inputTab == 1 && _file?.bytes != null)
          'file': MultipartFile.fromBytes(_file!.bytes!, filename: _file!.name),
      });

      final response = await _dio.post(
        '/api/v1/reforge/demo',
        data: formData,
        options: Options(responseType: ResponseType.stream),
      );

      final stream = (response.data as ResponseBody).stream;
      final buffer = StringBuffer();

      await for (final chunk in stream.cast<List<int>>().transform(utf8.decoder)) {
        buffer.write(chunk);
        // SSE 이벤트 파싱
        final raw = buffer.toString();
        final lines = raw.split('\n');
        buffer.clear();

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              setState(() { _done = true; _running = false; });
            } else {
              try {
                final json = jsonDecode(data) as Map<String, dynamic>;
                if (json['tags'] != null) {
                  setState(() => _tags = List<String>.from(json['tags']));
                } else if (json['text'] != null) {
                  setState(() => _reforged += json['text'] as String);
                } else if (json['error'] != null) {
                  setState(() {
                    _error = json['error'] as String;
                    _running = false;
                  });
                }
              } catch (_) {
                // 불완전한 청크는 버퍼에 유지
                if (i == lines.length - 1) buffer.write(line);
              }
            }
          } else if (line.isNotEmpty && i == lines.length - 1) {
            buffer.write(line);
          }
        }
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.message ?? '요청 실패';
        _running = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _running = false;
      });
    } finally {
      if (_running) setState(() => _running = false);
    }
  }

  void _reset() => setState(() {
    _reforged = '';
    _tags = [];
    _error = null;
    _done = false;
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: isWide ? _buildWide() : _buildNarrow(),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: AppColors.bg,
    elevation: 0,
    leading: BackButton(color: AppColors.textMuted),
    title: const Text('AI 교안 재가공 테스트',
        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: const Center(child: Text('DEMO',
            style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800))),
      ),
    ],
  );

  // ── 와이드 레이아웃 (좌: 입력 / 우: 결과) ──────────────────────────────────

  Widget _buildWide() => Row(children: [
    SizedBox(
      width: 420,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: _buildInputPanel(),
      ),
    ),
    Expanded(child: _buildOutputPanel()),
  ]);

  Widget _buildNarrow() => _reforged.isEmpty && !_running
      ? _buildInputPanel()
      : _buildOutputPanel();

  // ── 입력 패널 ─────────────────────────────────────────────────────────────

  Widget _buildInputPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 성향 선택 ──────────────────────────────────────────────
        ..._groups.asMap().entries.map((entry) {
          final gi = entry.key;
          final group = entry.value;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(group.label, style: const TextStyle(
              color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: group.styles.map((s) {
              final isSelected = _selected[gi] == s.name;
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selected.remove(gi);
                  } else {
                    _selected[gi] = s.name;
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? s.color.withValues(alpha: 0.15) : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? s.color : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: TextStyle(
                        color: isSelected ? s.color : AppColors.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.w700,
                      )),
                      Text(s.desc, style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10,
                      )),
                    ]),
                  ]),
                ),
              );
            }).toList()),
            const SizedBox(height: 18),
          ]);
        }),

        // 선택된 조합 표시
        if (_selected.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Text('선택: $_learningType',
                style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
        ],

        // ── 교안 입력 ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            // 탭
            Row(children: [
              _InputTab(label: '텍스트 입력', index: 0, current: _inputTab,
                  onTap: () { _tabCtrl.index = 0; setState(() => _inputTab = 0); }),
              _InputTab(label: '파일 업로드', index: 1, current: _inputTab,
                  onTap: () { _tabCtrl.index = 1; setState(() => _inputTab = 1); }),
            ]),
            const Divider(height: 1, color: AppColors.border),

            // 텍스트 입력
            if (_inputTab == 0)
              TextField(
                controller: _textCtrl,
                maxLines: 12,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(14),
                  border: InputBorder.none,
                  hintText: '교안 내용을 붙여넣으세요\n(강의 노트, PDF 복사 텍스트 등)',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.6),
                ),
              ),

            // 파일 업로드
            if (_inputTab == 1)
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: _file == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.upload_file_rounded, color: AppColors.textMuted, size: 36),
                          const SizedBox(height: 8),
                          const Text('파일 선택', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text('PDF · DOCX · PPTX · HWP · TXT · MD',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 32),
                          const SizedBox(height: 8),
                          Text(_file!.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 2, textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text('${(_file!.size / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ]),
                ),
              ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── 실행 버튼 ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: _running
              ? _RunningIndicator()
              : ElevatedButton(
                  onPressed: _canRun ? _run : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canRun ? AppColors.primary : AppColors.bgSurface,
                    disabledBackgroundColor: AppColors.bgSurface,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.auto_awesome_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _selected.isEmpty ? '성향을 선택하세요' : '재가공 시작',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ]),
                ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  // ── 결과 패널 ─────────────────────────────────────────────────────────────

  Widget _buildOutputPanel() {
    if (!_running && _reforged.isEmpty && _error == null) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🤖', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('재가공 결과가 여기에 표시됩니다',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 헤더
      Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('재가공 결과', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              if (_running) ...[
                const SizedBox(width: 8),
                SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primaryLight))),
              ],
              if (_done) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 16),
              ],
            ]),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: _tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Text(t, style: const TextStyle(
                  color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w600)),
              )).toList()),
            ],
          ])),
          if (_done)
            GestureDetector(
              onTap: _reset,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('초기화', style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ),

      // 본문 스트리밍
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: _MarkdownRenderer(_reforged),
        ),
      ),
    ]);
  }
}

// ── 탭 버튼 ───────────────────────────────────────────────────────────────────

class _InputTab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;
  const _InputTab({required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSurface : Colors.transparent,
          border: Border(bottom: BorderSide(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            width: 2,
          )),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
          fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }
}

// ── 실행 중 인디케이터 ─────────────────────────────────────────────────────────

class _RunningIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryLight))),
        const SizedBox(width: 10),
        const Text('AI 재가공 중...', style: TextStyle(
          color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
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
      return Padding(padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.primaryLight, width: 3)),
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        child: Text(line.substring(2), style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic, height: 1.5)));
    }
    if (line.trim().isEmpty) return const SizedBox(height: 8);
    // 인라인 볼드 처리
    return Padding(padding: const EdgeInsets.only(bottom: 3),
      child: _InlineText(line));
  }
}

class _InlineText extends StatelessWidget {
  final String line;
  const _InlineText(this.line);

  @override
  Widget build(BuildContext context) {
    // **bold** 파싱
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in regex.allMatches(line)) {
      if (m.start > last) {
        spans.add(TextSpan(text: line.substring(last, m.start)));
      }
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)));
      last = m.end;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last)));

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.7),
    );
  }
}
