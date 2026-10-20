import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/sse_client.dart';
import '../../../../shared/widgets/fl_markdown.dart';
import '../../../../shared/widgets/fl_ui.dart';
import '../../../../shared/widgets/lecture_video.dart';
import '../../../auth/provider/auth_provider.dart';

enum _GenStatus { idle, connecting, streaming, done, error }

/// 학생 맞춤 교안 리더 — 성향별 재구성 교안을 실시간 스트리밍으로 보여준다.
class LectureReaderPage extends ConsumerStatefulWidget {
  final String roomId;
  final String lectureId;
  final String? userId;
  final String roomTitle;

  const LectureReaderPage({
    super.key,
    required this.roomId,
    required this.lectureId,
    this.userId,
    this.roomTitle = '',
  });

  @override
  ConsumerState<LectureReaderPage> createState() => _LectureReaderPageState();
}

class _LectureReaderPageState extends ConsumerState<LectureReaderPage> {
  Map<String, dynamic>? _lecture;
  List<Map<String, dynamic>> _lectures = [];
  Map<String, dynamic>? _room;
  String? _loadError;

  final Map<String, String> _contents = {};
  String? _primaryStyle;
  String _activeStyle = '';
  String _streamText = '';
  _GenStatus _status = _GenStatus.idle;
  String? _genError;
  bool _fallback = false;
  Map<String, dynamic>? _profile;
  StreamSubscription<Map<String, dynamic>>? _sub;
  DateTime? _genStartedAt;
  int _elapsed = 0;
  Timer? _ticker;

  bool _compare = false;
  bool _completing = false;
  final _scroll = ScrollController();
  double _readProgress = 0;

  String get _userId => widget.userId ?? ref.read(authNotifierProvider)?.userId ?? '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final p = max <= 0 ? 0.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    if ((p - _readProgress).abs() > 0.01) setState(() => _readProgress = p);
  }

  Future<void> _bootstrap() async {
    await ref.read(authNotifierProvider.notifier).ready();
    try {
      final results = await Future.wait([
        ApiService().getLecture(widget.roomId, widget.lectureId),
        ApiService().getRoomLectures(widget.roomId),
        ApiService().getRoom(widget.roomId).catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _lecture = Map<String, dynamic>.from(results[0] as Map);
        _lectures = (results[1] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['confirmed'] == true)
            .toList()
          ..sort((a, b) => ((a['order_index'] as num?) ?? 0).compareTo((b['order_index'] as num?) ?? 0));
        _room = Map<String, dynamic>.from(results[2] as Map);
      });
      _generate(null);
    } catch (e) {
      if (mounted) setState(() => _loadError = '강의를 불러오지 못했습니다.');
    }
  }

  void _generate(String? style, {bool refresh = false}) {
    _sub?.cancel();
    _ticker?.cancel();
    setState(() {
      if (style != null) _activeStyle = style;
      _status = _GenStatus.connecting;
      _streamText = '';
      _genError = null;
      _fallback = false;
      _genStartedAt = DateTime.now();
      _elapsed = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _genStartedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_genStartedAt!).inSeconds);
    });

    final buffer = StringBuffer();
    var lastPaint = DateTime.fromMillisecondsSinceEpoch(0);
    _sub = SseClient.connect(
      '/api/v1/lectures/${widget.roomId}/${widget.lectureId}/reforged/stream',
      query: {
        if (_userId.isNotEmpty) 'user_id': _userId,
        if (style != null) 'style': style,
        if (refresh) 'refresh': 'true',
      },
    ).listen((event) {
      if (!mounted) return;
      switch (event['type']) {
        case 'meta':
          setState(() {
            _activeStyle = event['style'] as String? ?? _activeStyle;
            _primaryStyle ??= event['primary_style'] as String?;
            _profile = (event['profile'] as Map?)?.cast<String, dynamic>() ?? _profile;
            _status = _GenStatus.streaming;
          });
        case 'delta':
          buffer.write(event['text'] as String? ?? '');
          final now = DateTime.now();
          if (now.difference(lastPaint).inMilliseconds > 90) {
            lastPaint = now;
            setState(() => _streamText = buffer.toString());
          }
        case 'done':
          _ticker?.cancel();
          final content = (event['content'] as String?)?.trim();
          setState(() {
            final text = (content == null || content.isEmpty) ? buffer.toString() : content;
            _contents[_activeStyle] = text;
            _streamText = text;
            _fallback = event['fallback'] == true;
            _status = _GenStatus.done;
          });
        case 'error':
          _ticker?.cancel();
          setState(() {
            _genError = event['message'] as String? ?? '맞춤 교안을 만들지 못했습니다.';
            _status = _GenStatus.error;
          });
      }
    });
  }

  void _selectStyle(String style) {
    if (style == _activeStyle && _status != _GenStatus.error) return;
    final cached = _contents[style];
    if (cached != null) {
      _sub?.cancel();
      _ticker?.cancel();
      setState(() {
        _activeStyle = style;
        _streamText = cached;
        _status = _GenStatus.done;
        _genError = null;
      });
      return;
    }
    _generate(style);
  }

  int get _currentIndex => _lectures.indexWhere(
      (l) => (l['lecture_id'] ?? l['id'])?.toString() == widget.lectureId);

  void _openLecture(Map<String, dynamic> lecture) {
    final id = (lecture['lecture_id'] ?? lecture['id']).toString();
    context.pushReplacement('/learn/${widget.roomId}/$id');
  }

  Future<void> _complete() async {
    setState(() => _completing = true);
    try {
      if (_userId.isNotEmpty) {
        await ApiService().markLectureProgress(
          roomId: widget.roomId,
          lectureId: widget.lectureId,
          userId: _userId,
        );
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _completing = false);
    final idx = _currentIndex;
    if (idx != -1 && idx < _lectures.length - 1) {
      _openLecture(_lectures[idx + 1]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 이 강의의 모든 교안을 완료했어요!')),
      );
      context.go('/student/home');
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FL.bg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(
            roomTitle: (_room?['subject'] as String?) ?? widget.roomTitle,
            lectureTitle: _lecture?['title'] as String? ?? '',
            index: _currentIndex,
            total: _lectures.length,
            progress: _readProgress,
            onBack: () => context.canPop() ? context.pop() : context.go('/student/home'),
            onPrev: _currentIndex > 0 ? () => _openLecture(_lectures[_currentIndex - 1]) : null,
            onNext: _currentIndex != -1 && _currentIndex < _lectures.length - 1
                ? () => _openLecture(_lectures[_currentIndex + 1])
                : null,
          ),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return _CenteredMessage(
        icon: Icons.cloud_off_rounded,
        title: _loadError!,
        body: '서버가 잠들어 있었다면 깨어나는 데 최대 1분이 걸릴 수 있어요.',
        action: FLButton('다시 시도', icon: Icons.refresh_rounded, onPressed: () {
          setState(() => _loadError = null);
          _bootstrap();
        }),
      );
    }
    if (_lecture == null) {
      return const Center(child: CircularProgressIndicator(color: FL.lime, strokeWidth: 2));
    }

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1100;
      final pad = c.maxWidth < 600 ? 16.0 : 32.0;
      final doc = _buildDocumentColumn(wide: wide);
      if (!wide) {
        return SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 80),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            doc,
            const SizedBox(height: 28),
            _SidePanel(
              profile: _profile,
              activeStyle: _activeStyle,
              lecture: _lecture!,
              roomId: widget.roomId,
              lectureId: widget.lectureId,
              userId: _userId,
            ),
          ]),
        );
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(pad, 28, 24, 96),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _compare ? 1400 : FL.maxReading + 40),
                child: doc,
              ),
            ),
          ),
        ),
        if (!_compare)
          Container(
            width: 360,
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: FL.border))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              child: _SidePanel(
                profile: _profile,
                activeStyle: _activeStyle,
                lecture: _lecture!,
                roomId: widget.roomId,
                lectureId: widget.lectureId,
                userId: _userId,
              ),
            ),
          ),
      ]);
    });
  }

  Widget _buildDocumentColumn({required bool wide}) {
    final meta = StyleMeta.of(_activeStyle.isEmpty ? (_primaryStyle ?? '읽기형') : _activeStyle);
    final videoUrl = ((_lecture?['video_url'] as String?)?.trim().isNotEmpty ?? false)
        ? _lecture!['video_url'] as String
        : (_lecture?['video_asset_url'] as String? ?? '');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (videoUrl.trim().isNotEmpty) ...[
        LectureVideo(
          videoUrl: videoUrl,
          videoType: _lecture?['video_type'] as String? ?? 'none',
          videoStatus: _lecture?['video_status'] as String? ?? 'none',
        ),
        const SizedBox(height: 24),
      ],
      _StyleSwitcher(
        active: _activeStyle,
        primary: _primaryStyle,
        generated: _contents.keys.toSet(),
        busy: _status == _GenStatus.connecting || _status == _GenStatus.streaming,
        onSelect: _selectStyle,
      ),
      const SizedBox(height: 14),
      Row(children: [
        _ModeToggle(
          compare: _compare,
          onChanged: (v) => setState(() => _compare = v),
        ),
        const Spacer(),
        _StatusLine(status: _status, meta: meta, elapsed: _elapsed, chars: _streamText.length),
      ]),
      const SizedBox(height: 20),
      if (_compare)
        _CompareView(
          original: _lecture?['original_text'] as String? ?? '',
          reforged: _documentBody(meta),
          meta: meta,
          wide: wide,
        )
      else
        _documentBody(meta),
      if (_status == _GenStatus.done) ...[
        const SizedBox(height: 40),
        _CompletionBar(
          hasNext: _currentIndex != -1 && _currentIndex < _lectures.length - 1,
          loading: _completing,
          onComplete: _complete,
          onRegenerate: () => _generate(_activeStyle, refresh: true),
        ),
      ],
    ]);
  }

  Widget _documentBody(StyleMeta meta) {
    if (_status == _GenStatus.error) {
      return _CenteredMessage(
        icon: Icons.auto_awesome_outlined,
        title: _genError ?? '맞춤 교안을 만들지 못했습니다.',
        body: 'AI 응답이 지연되었을 수 있어요. 다시 시도하거나 다른 스타일을 골라보세요.',
        action: FLButton('다시 생성', icon: Icons.refresh_rounded,
            onPressed: () => _generate(_activeStyle.isEmpty ? null : _activeStyle)),
      );
    }
    if (_streamText.isEmpty) return _GeneratingPlaceholder(meta: meta, connecting: _status == _GenStatus.connecting);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_fallback)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FLCard(
              color: FL.amber.withValues(alpha: 0.08),
              borderColor: FL.amber.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(14),
              child: const Text(
                'AI 사용량이 많아 원본 근거 기반의 기본 교안을 먼저 보여드려요. 잠시 후 "다시 생성"을 눌러보세요.',
                style: TextStyle(color: FL.amber, fontSize: 13, height: 1.5),
              ),
            ),
          ),
        FLMarkdown(_streamText, accent: meta.color),
        if (_status == _GenStatus.streaming)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FLPulseDot(color: meta.color),
          ),
      ]),
    );
  }
}

// ── 상단 바 ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String roomTitle;
  final String lectureTitle;
  final int index;
  final int total;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _TopBar({
    required this.roomTitle,
    required this.lectureTitle,
    required this.index,
    required this.total,
    required this.progress,
    required this.onBack,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Container(
      decoration: const BoxDecoration(
        color: FL.bg,
        border: Border(bottom: BorderSide(color: FL.border)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(children: [
            IconButton(
              tooltip: '뒤로',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: FL.textSec),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  roomTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: FL.textMute, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  [if (index >= 0 && total > 0) '${index + 1}강', lectureTitle].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: FL.text, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ]),
            ),
            if (!narrow && total > 1) ...[
              _NavButton(icon: Icons.chevron_left_rounded, label: '이전', onTap: onPrev),
              const SizedBox(width: 6),
              _NavButton(icon: Icons.chevron_right_rounded, label: '다음', onTap: onNext, trailing: true),
            ],
          ]),
        ),
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          color: FL.lime,
          backgroundColor: Colors.transparent,
        ),
      ]),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool trailing;
  const _NavButton({required this.icon, required this.label, this.onTap, this.trailing = false});

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? FL.textMute.withValues(alpha: 0.5) : FL.textSec;
    final children = [
      Icon(icon, size: 18, color: color),
      Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    ];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: FL.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: trailing ? children.reversed.toList() : children),
      ),
    );
  }
}

// ── 스타일 스위처 ──────────────────────────────────────────────────────────

class _StyleSwitcher extends StatelessWidget {
  final String active;
  final String? primary;
  final Set<String> generated;
  final bool busy;
  final ValueChanged<String> onSelect;

  const _StyleSwitcher({
    required this.active,
    required this.primary,
    required this.generated,
    required this.busy,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.auto_awesome_rounded, size: 15, color: FL.lime),
        SizedBox(width: 6),
        Text('같은 교안, 다른 설명 방식',
            style: TextStyle(color: FL.text, fontSize: 14, fontWeight: FontWeight.w800)),
        SizedBox(width: 8),
        Flexible(
          child: Text('스타일을 바꾸면 AI가 즉시 다시 구성해요',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: FL.textMute, fontSize: 12.5)),
        ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in StyleMeta.all)
          _StyleChip(
            meta: m,
            selected: m.key == active,
            isPrimary: m.key == primary,
            ready: generated.contains(m.key),
            onTap: () => onSelect(m.key),
          ),
      ]),
    ]);
  }
}

class _StyleChip extends StatelessWidget {
  final StyleMeta meta;
  final bool selected;
  final bool isPrimary;
  final bool ready;
  final VoidCallback onTap;

  const _StyleChip({
    required this.meta,
    required this.selected,
    required this.isPrimary,
    required this.ready,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: meta.tagline,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? meta.color.withValues(alpha: 0.16) : FL.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? meta.color : FL.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(meta.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              meta.key,
              style: TextStyle(
                color: selected ? FL.text : FL.textSec,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (isPrimary) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: FL.lime, borderRadius: BorderRadius.circular(999)),
                child: const Text('내 성향',
                    style: TextStyle(color: FL.limeInk, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ] else if (ready && !selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded, size: 13, color: meta.color.withValues(alpha: 0.8)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool compare;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.compare, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, IconData icon, bool value) {
      final sel = compare == value;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? FL.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: sel ? FL.text : FL.textMute),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: sel ? FL.text : FL.textMute, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FL.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FL.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('맞춤 교안', Icons.auto_awesome_rounded, false),
        seg('원본과 비교', Icons.compare_rounded, true),
      ]),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final _GenStatus status;
  final StyleMeta meta;
  final int elapsed;
  final int chars;
  const _StatusLine({required this.status, required this.meta, required this.elapsed, required this.chars});

  @override
  Widget build(BuildContext context) {
    final (text, showDot) = switch (status) {
      _GenStatus.connecting => (elapsed > 6 ? '서버 연결 중… (${elapsed}s)' : '연결 중…', true),
      _GenStatus.streaming => ('${meta.key}으로 재구성 중 · ${_fmt(chars)}자', true),
      _GenStatus.done => ('${meta.key} 교안 완성', false),
      _ => ('', false),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (showDot) FLPulseDot(color: meta.color) else Icon(Icons.check_circle_rounded, size: 15, color: meta.color),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: FL.textSec, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ]);
  }

  static String _fmt(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

class _GeneratingPlaceholder extends StatelessWidget {
  final StyleMeta meta;
  final bool connecting;
  const _GeneratingPlaceholder({required this.meta, required this.connecting});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FLCard(
        color: meta.color.withValues(alpha: 0.06),
        borderColor: meta.color.withValues(alpha: 0.25),
        child: Row(children: [
          Text(meta.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                connecting ? 'AI 튜터를 부르는 중…' : '${meta.key} 맞춤 교안을 쓰고 있어요',
                style: const TextStyle(color: FL.text, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '원본 교안 + 교수님 핵심 포인트 + 내 학습 성향을 함께 반영합니다 — ${meta.tagline}',
                style: const TextStyle(color: FL.textSec, fontSize: 13, height: 1.5),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 28),
      const FLSkeleton(height: 28, width: 360),
      const SizedBox(height: 18),
      for (final w in [1.0, 0.92, 0.97, 0.6]) ...[
        FractionallySizedBox(widthFactor: w, child: const FLSkeleton()),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 18),
      const FLSkeleton(height: 120, radius: 12),
    ]);
  }
}

class _CompareView extends StatelessWidget {
  final String original;
  final Widget reforged;
  final StyleMeta meta;
  final bool wide;
  const _CompareView({required this.original, required this.reforged, required this.meta, required this.wide});

  @override
  Widget build(BuildContext context) {
    final originalPane = FLCard(
      color: FL.surface,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FLTag('원본 교안', color: FL.textSec, icon: Icons.description_outlined),
        const SizedBox(height: 16),
        FLMarkdown(original, scale: 0.9, accent: FL.textSec),
      ]),
    );
    final reforgedPane = FLCard(
      color: FL.bg,
      borderColor: meta.color.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FLTag('${meta.emoji} ${meta.key} 맞춤 교안', color: meta.color),
        const SizedBox(height: 16),
        reforged,
      ]),
    );
    if (!wide) {
      return Column(children: [originalPane, const SizedBox(height: 16), reforgedPane]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: originalPane),
      const SizedBox(width: 18),
      Expanded(child: reforgedPane),
    ]);
  }
}

class _CompletionBar extends StatelessWidget {
  final bool hasNext;
  final bool loading;
  final VoidCallback onComplete;
  final VoidCallback onRegenerate;
  const _CompletionBar({
    required this.hasNext,
    required this.loading,
    required this.onComplete,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return FLCard(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('이번 교안을 다 읽었나요?',
                style: TextStyle(color: FL.text, fontSize: 15, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('완료로 표시하면 학습 진도가 교수님 대시보드에 반영돼요.',
                style: TextStyle(color: FL.textSec, fontSize: 13)),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FLButton('다시 생성', icon: Icons.refresh_rounded, kind: FLButtonKind.ghost, onPressed: onRegenerate),
            FLButton(
              hasNext ? '완료하고 다음 강의' : '학습 완료',
              trailingIcon: hasNext ? Icons.arrow_forward_rounded : Icons.check_rounded,
              loading: loading,
              onPressed: onComplete,
            ),
          ]),
        ],
      ),
    );
  }
}

// ── 사이드 패널: 개인화 근거 · 핵심 포인트 · AI 튜터 ─────────────────────────

class _SidePanel extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final String activeStyle;
  final Map<String, dynamic> lecture;
  final String roomId;
  final String lectureId;
  final String userId;

  const _SidePanel({
    required this.profile,
    required this.activeStyle,
    required this.lecture,
    required this.roomId,
    required this.lectureId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final points = (lecture['core_points'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => ((b['priority'] as num?) ?? 0).compareTo((a['priority'] as num?) ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _BasisCard(profile: profile, activeStyle: activeStyle),
      const SizedBox(height: 16),
      if (points.isNotEmpty) ...[
        FLCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.push_pin_rounded, size: 15, color: FL.lavender),
              SizedBox(width: 6),
              Text('교수님이 확정한 핵심 포인트',
                  style: TextStyle(color: FL.text, fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            const Text('맞춤 교안에 빠짐없이 반영돼요',
                style: TextStyle(color: FL.textMute, fontSize: 12)),
            const SizedBox(height: 14),
            for (var i = 0; i < points.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FL.lavender.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(color: FL.lavender, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(points[i]['content']?.toString() ?? '',
                        style: const TextStyle(color: FL.textSec, fontSize: 13, height: 1.5)),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      _TutorCard(roomId: roomId, lectureId: lectureId, userId: userId, style: activeStyle),
    ]);
  }
}

class _BasisCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final String activeStyle;
  const _BasisCard({required this.profile, required this.activeStyle});

  static String _level(String? v) => switch (v) {
        'beginner' => '입문',
        'intermediate' => '중급',
        'advanced' => '고급',
        _ => '미진단',
      };

  @override
  Widget build(BuildContext context) {
    final meta = StyleMeta.of(activeStyle.isEmpty ? '읽기형' : activeStyle);
    final rows = <(String, String)>[
      ('설명 방식', '${meta.emoji} ${meta.key} — ${meta.tagline}'),
      ('학습 성향', profile?['vark_type']?.toString() ?? '-'),
      ('집중 패턴', profile?['focus_pattern']?.toString() ?? '-'),
      ('과목 수준', _level(profile?['subject_level'] as String?)),
    ];
    return FLCard(
      color: meta.color.withValues(alpha: 0.05),
      borderColor: meta.color.withValues(alpha: 0.25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tune_rounded, size: 15, color: meta.color),
          const SizedBox(width: 6),
          const Text('이 교안이 이렇게 바뀐 이유',
              style: TextStyle(color: FL.text, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 72,
                child: Text(k, style: const TextStyle(color: FL.textMute, fontSize: 12.5)),
              ),
              Expanded(
                child: Text(v,
                    style: const TextStyle(color: FL.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _TutorCard extends StatefulWidget {
  final String roomId;
  final String lectureId;
  final String userId;
  final String style;
  const _TutorCard({required this.roomId, required this.lectureId, required this.userId, required this.style});

  @override
  State<_TutorCard> createState() => _TutorCardState();
}

class _TutorCardState extends State<_TutorCard> {
  final _ctrl = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _sub;
  String _question = '';
  String _answer = '';
  bool _busy = false;

  static const _suggestions = ['이 개념을 더 쉽게 설명해줘', '실생활 예시를 들어줘', '시험에 나올 만한 포인트는?'];

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _ask(String q) {
    final question = q.trim();
    if (question.isEmpty || _busy) return;
    _sub?.cancel();
    final buffer = StringBuffer();
    setState(() {
      _question = question;
      _answer = '';
      _busy = true;
    });
    _ctrl.clear();
    _sub = SseClient.connect(
      '/api/v1/lectures/${widget.roomId}/${widget.lectureId}/ask/stream',
      query: {
        'question': question,
        if (widget.userId.isNotEmpty) 'user_id': widget.userId,
        if (widget.style.isNotEmpty) 'style': widget.style,
      },
    ).listen((e) {
      if (!mounted) return;
      switch (e['type']) {
        case 'delta':
          buffer.write(e['text'] ?? '');
          setState(() => _answer = buffer.toString());
        case 'done':
          setState(() {
            _answer = (e['content'] as String?) ?? buffer.toString();
            _busy = false;
          });
        case 'error':
          setState(() {
            _answer = e['message'] as String? ?? '답변을 만들지 못했어요.';
            _busy = false;
          });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FLCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.forum_rounded, size: 15, color: FL.sky),
          SizedBox(width: 6),
          Text('AI 튜터에게 질문',
              style: TextStyle(color: FL.text, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 4),
        const Text('이 교안을 근거로, 내 학습 스타일에 맞춰 답해요',
            style: TextStyle(color: FL.textMute, fontSize: 12)),
        const SizedBox(height: 14),
        if (_question.isEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12, color: FL.textSec)),
                backgroundColor: FL.surface2,
                side: const BorderSide(color: FL.border),
                onPressed: () => _ask(s),
              ),
          ])
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: FL.sky.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_question, style: const TextStyle(color: FL.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          if (_answer.isEmpty)
            const Row(children: [
              FLPulseDot(color: FL.sky),
              SizedBox(width: 8),
              Text('생각하는 중…', style: TextStyle(color: FL.textMute, fontSize: 12.5)),
            ])
          else
            FLMarkdown(_answer, scale: 0.86, accent: FL.sky),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          enabled: !_busy,
          onSubmitted: _ask,
          style: const TextStyle(color: FL.text, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: _busy ? '답변 작성 중…' : '궁금한 점을 입력하세요',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: IconButton(
              tooltip: '질문하기',
              onPressed: _busy ? null : () => _ask(_ctrl.text),
              icon: const Icon(Icons.arrow_upward_rounded, color: FL.sky, size: 20),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const _CenteredMessage({required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: FL.textMute),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FL.text, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FL.textSec, fontSize: 13.5, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}
