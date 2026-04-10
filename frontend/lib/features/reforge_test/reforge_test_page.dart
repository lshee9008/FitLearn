import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

// ── 학습 프로파일 태그 데이터 ──────────────────────────────────────────────────

class _ProfileData {
  final String vark;
  final String focusPattern;
  final String difficultyResponse;
  final List<String> churnRisk;
  final String confidence;

  const _ProfileData({
    required this.vark,
    required this.focusPattern,
    required this.difficultyResponse,
    required this.churnRisk,
    required this.confidence,
  });
}

_ProfileData _deriveProfile(Map<int, String> selected) {
  final vark = selected[0] ?? '혼합형';

  final density = selected[2];
  final focus = density == '요약형'
      ? '단기집중'
      : density == '상세형'
          ? '장기몰입'
          : density == '예시형'
              ? '분산형'
              : '단기집중';

  final cognitive = selected[1];
  final difficulty = cognitive == '분석형' ? '직진형' : cognitive == '직관형' ? '우회형' : '직진형';

  return _ProfileData(
    vark: vark,
    focusPattern: focus,
    difficultyResponse: difficulty,
    churnRisk: const [],
    confidence: 'DEMO',
  );
}

// ── 페이지 ────────────────────────────────────────────────────────────────────

class ReforgeTestPage extends StatefulWidget {
  const ReforgeTestPage({super.key});

  @override
  State<ReforgeTestPage> createState() => _ReforgeTestPageState();
}

class _ReforgeTestPageState extends State<ReforgeTestPage>
    with SingleTickerProviderStateMixin {
  final Map<int, String> _selected = {};

  final _textCtrl = TextEditingController();
  PlatformFile? _file;
  int _inputTab = 0;

  bool _running = false;
  String _reforged = '';
  List<String> _tags = [];
  String? _error;
  bool _done = false;
  _ProfileData? _profile;

  late final TabController _tabCtrl;

  final _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 180),
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
      setState(() {
        _file = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _reforged = '';
      _tags = [];
      _error = null;
      _done = false;
      _profile = _deriveProfile(_selected);
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

      await for (final chunk
          in stream.cast<List<int>>().transform(utf8.decoder)) {
        buffer.write(chunk);
        final raw = buffer.toString();
        final lines = raw.split('\n');
        buffer.clear();

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              setState(() {
                _done = true;
                _running = false;
              });
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
        _profile = null;
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
        surfaceTintColor: Colors.transparent,
        leading: BackButton(color: AppColors.textMuted),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text('AI 교안 재가공',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Center(
                child: Text('DEMO',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2))),
          ),
        ],
      );

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
        ..._groups.asMap().entries.map((entry) {
          final gi = entry.key;
          final group = entry.value;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(group.label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      )),
                ]),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: group.styles.map((s) {
                      final isSelected = _selected[gi] == s.name;
                      return GestureDetector(
                        onTap: () => setState(() {
                          isSelected
                              ? _selected.remove(gi)
                              : _selected[gi] = s.name;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? s.color.withValues(alpha: 0.12)
                                : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? s.color : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(s.emoji,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? s.color
                                            : AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      )),
                                  Text(s.desc,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                      )),
                                ]),
                          ]),
                        ),
                      );
                    }).toList()),
                const SizedBox(height: 20),
              ]);
        }),

        if (_selected.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text('선택: $_learningType',
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── 교안 입력 ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            Row(children: [
              _InputTab(
                  label: '텍스트 입력',
                  index: 0,
                  current: _inputTab,
                  onTap: () {
                    _tabCtrl.index = 0;
                    setState(() => _inputTab = 0);
                  }),
              _InputTab(
                  label: '파일 업로드',
                  index: 1,
                  current: _inputTab,
                  onTap: () {
                    _tabCtrl.index = 1;
                    setState(() => _inputTab = 1);
                  }),
            ]),
            const Divider(height: 1, color: AppColors.border),
            if (_inputTab == 0)
              TextField(
                controller: _textCtrl,
                maxLines: 12,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(14),
                  border: InputBorder.none,
                  hintText:
                      '교안 내용을 붙여넣으세요\n(강의 노트, PDF 복사 텍스트 등)',
                  hintStyle: TextStyle(
                      color: AppColors.textMuted, fontSize: 13, height: 1.6),
                ),
              ),
            if (_inputTab == 1)
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: _file == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                              Icon(Icons.upload_file_rounded,
                                  color: AppColors.textMuted, size: 36),
                              SizedBox(height: 8),
                              Text('파일 선택',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(height: 4),
                              Text('PDF · DOCX · PPTX · HWP · TXT · MD',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                            ])
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 32),
                              const SizedBox(height: 8),
                              Text(_file!.name,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text(
                                  '${(_file!.size / 1024).toStringAsFixed(1)} KB',
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                            ]),
                ),
              ),
          ]),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: _running
              ? _RunningIndicator()
              : ElevatedButton(
                  onPressed: _canRun ? _run : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canRun ? AppColors.primary : AppColors.bgCard,
                    disabledBackgroundColor: AppColors.bgCard,
                    foregroundColor:
                        _canRun ? const Color(0xFF0A0A0F) : AppColors.textMuted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _selected.isEmpty ? '성향을 선택하세요' : '재가공 시작',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
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
              border:
                  Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
            ),
            child: Text(_error!,
                style:
                    const TextStyle(color: AppColors.rose, fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  // ── 결과 패널 ─────────────────────────────────────────────────────────────

  Widget _buildOutputPanel() {
    if (!_running && _reforged.isEmpty && _error == null) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            const Text('재가공 결과가 여기에 표시됩니다',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 8),
            const Text('성향을 선택하고 교안을 입력한 후 재가공을 시작하세요',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── 결과 헤더 ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border:
              Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('재가공 결과',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            if (_running)
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.primaryLight))),
            if (_done) ...[
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 4),
              const Text('완료',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
            const Spacer(),
            if (_done)
              GestureDetector(
                onTap: _reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('초기화',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
          ]),

          // ── 스타일 태그 ──────────────────────────────────────
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _tags
                    .map((t) => _GreenBadge(label: t))
                    .toList()),
          ],

          // ── 학습 프로파일 태그 ───────────────────────────────
          if (_profile != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            _ProfileTagsRow(profile: _profile!),
          ],
        ]),
      ),

      // ── 본문 마크다운 ──────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: _reforged.isEmpty && _running
              ? _StreamingPlaceholder()
              : _NotionMarkdown(_reforged),
        ),
      ),
    ]);
  }
}

// ── 학습 프로파일 태그 행 ──────────────────────────────────────────────────────

class _ProfileTagsRow extends StatelessWidget {
  final _ProfileData profile;
  const _ProfileTagsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 6, children: [
      _ProfileTag(icon: '🧠', label: 'VARK', value: profile.vark),
      _ProfileTag(icon: '⏱️', label: '집중패턴', value: profile.focusPattern),
      _ProfileTag(
          icon: '📈', label: '난이도대응', value: profile.difficultyResponse),
      if (profile.churnRisk.isEmpty)
        _ProfileTag(icon: '✅', label: '이탈위험', value: '없음'),
      if (profile.churnRisk.isNotEmpty)
        ...profile.churnRisk.map(
            (r) => _ProfileTag(icon: '⚠️', label: '이탈위험', value: r)),
      _ProfileTag(
        icon: '🎯',
        label: '신뢰도',
        value: profile.confidence,
        isDemo: profile.confidence == 'DEMO',
      ),
    ]);
  }
}

class _ProfileTag extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool isDemo;
  const _ProfileTag(
      {required this.icon,
      required this.label,
      required this.value,
      this.isDemo = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                color: isDemo ? AppColors.gold : AppColors.primaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── 초록 배지 ─────────────────────────────────────────────────────────────────

class _GreenBadge extends StatelessWidget {
  final String label;
  const _GreenBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── 노션 스타일 마크다운 렌더러 ────────────────────────────────────────────────

class _NotionMarkdown extends StatelessWidget {
  final String content;
  const _NotionMarkdown(this.content);

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        // Headings
        h1: const TextStyle(
            color: AppColors.primaryLight,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.3),
        h1Padding:
            const EdgeInsets.only(top: 8, bottom: 14),
        h2: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.3),
        h2Padding:
            const EdgeInsets.only(top: 24, bottom: 8),
        h3: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.4),
        h3Padding:
            const EdgeInsets.only(top: 18, bottom: 6),
        // Body
        p: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.75),
        pPadding: const EdgeInsets.only(bottom: 4),
        // Lists
        listBullet: const TextStyle(
            color: AppColors.primary, fontSize: 14),
        listBulletPadding: const EdgeInsets.only(right: 8),
        listIndent: 20,
        // Blockquote
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
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8)),
        ),
        blockquotePadding:
            const EdgeInsets.fromLTRB(16, 10, 16, 10),
        // Code
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
        // Horizontal rule
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        // Strong / Em
        strong: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800),
        em: const TextStyle(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic),
        // Table
        tableHead: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13),
        tableBody:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        tableBorder: TableBorder.all(color: AppColors.border, width: 1),
        tableHeadAlign: TextAlign.center,
        tableCellsPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tableColumnWidth: const FlexColumnWidth(),
        tableVerticalAlignment: TableCellVerticalAlignment.middle,
      ),
    );
  }
}

// ── 스트리밍 플레이스홀더 ─────────────────────────────────────────────────────

class _StreamingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
            5,
            (i) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: i == 0 ? 22 : 14,
                  width: i == 0
                      ? 180
                      : i == 4
                          ? 120
                          : double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )));
  }
}

// ── 입력 탭 버튼 ──────────────────────────────────────────────────────────────

class _InputTab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;
  const _InputTab(
      {required this.label,
      required this.index,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          )),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected
                  ? AppColors.primaryLight
                  : AppColors.textMuted,
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500,
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
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation(AppColors.primaryLight))),
        const SizedBox(width: 10),
        const Text('AI 재가공 중...',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
