import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

// ════════════════════════════════════════════════════════════
// VideoType
// ════════════════════════════════════════════════════════════
enum VideoType { youtube, direct, none }

VideoType detectVideoType(String? url) {
  if (url == null || url.isEmpty) return VideoType.none;
  if (url.contains('youtube.com') || url.contains('youtu.be')) {
    return VideoType.youtube;
  }
  return VideoType.direct;
}

String? extractYoutubeId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (url.contains('youtu.be')) {
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  }
  return uri.queryParameters['v'];
}

String _normalizeDisplayText(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return raw;
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return raw;

  try {
    final decoded = jsonDecode(trimmed);

    if (decoded is Map<String, dynamic>) {
      final transcript = decoded['transcript'];
      if (transcript is String && transcript.trim().isNotEmpty) {
        return transcript.trim();
      }

      final summary = decoded['summary'];
      if (summary is String && summary.trim().isNotEmpty) {
        return summary.trim();
      }

      final segments = decoded['segments'];
      if (segments is List) {
        final texts = segments
            .whereType<Map>()
            .map((segment) => segment['text'])
            .whereType<String>()
            .map((text) => text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
        if (texts.isNotEmpty) {
          return texts.join('\n\n');
        }
      }
    }

    if (decoded is List) {
      final texts = decoded
          .whereType<Map>()
          .map((segment) => segment['text'])
          .whereType<String>()
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      if (texts.isNotEmpty) {
        return texts.join('\n\n');
      }
    }
  } catch (_) {
    return raw;
  }

  return raw;
}

// ════════════════════════════════════════════════════════════
// 컬러 팔레트
// ════════════════════════════════════════════════════════════
abstract class _C {
  static const bg         = Color(0xFF0C0C0E);
  static const surface    = Color(0xFF131316);
  static const surface2   = Color(0xFF1A1A1F);
  static const border     = Color(0xFF2A2A32);
  static const lime       = Color(0xFFC8F135);
  static const limeDark   = Color(0xFF1A2E00);
  static const salmon     = Color(0xFFFF6B5B);
  static const salmonDark = Color(0xFF2E1210);
  static const lavender   = Color(0xFFC5B8F8);
  static const lavDark    = Color(0xFF1E1A3A);
  static const yellow     = Color(0xFFFFE566);
  static const text1      = Color(0xFFF0F0F4);
  static const text2      = Color(0xFF9D9DB0);
  static const text3      = Color(0xFF4A4A58);
}

// ════════════════════════════════════════════════════════════
// 샘플 데이터
// ════════════════════════════════════════════════════════════
const _kSubject   = 'UX 디자인 기초';
const _kEpNum     = 'EP 03';
const _kEpTitle   = '사용자 리서치 방법론';
const _kStyle     = '예시 중심형';

const _kChapters = [
  (title: '인트로 & 개요',         time: '00:00'),
  (title: '정성 vs 정량 리서치',    time: '05:14'),
  (title: '인터뷰 설계 방법',       time: '12:30'),
  (title: '관찰법과 섀도잉',        time: '20:05'),
  (title: '서베이 설계 팁',         time: '28:47'),
  (title: '어피니티 다이어그램',     time: '36:10'),
  (title: '인사이트 도출 실습',      time: '43:00'),
];

const _kConcepts  = ['사용자 인터뷰', '어피니티 다이어그램', '공감 지도(Empathy Map)'];

const _kTip =
    '실제 사용자 인터뷰 전 파일럿 인터뷰를 꼭 진행하세요. '
    '질문 순서나 모호한 표현을 미리 수정할 수 있어 데이터 품질이 훨씬 높아집니다.';

const _kHardSpots = [
  '20:05 – 관찰법에서 편향 제거하는 법',
  '36:10 – 어피니티 다이어그램 그룹핑 기준',
];

// 진행바 마커
class _Marker {
  final double pos;
  final Color color;
  final String label;
  const _Marker({required this.pos, required this.color, required this.label});
}

const _kMarkers = [
  _Marker(pos: 0.26, color: _C.salmon,   label: '막힌 구간'),
  _Marker(pos: 0.52, color: _C.yellow,   label: 'AI 질문'),
  _Marker(pos: 0.75, color: _C.lavender, label: '북마크'),
];

// ════════════════════════════════════════════════════════════
// LecturePage
// ════════════════════════════════════════════════════════════
class LecturePage extends StatefulWidget {
  final String? videoUrl;
  final String? roomName;
  final String? lectureTitle;
  final List<Map<String, dynamic>>? lectureList;
  final String? currentLectureId;

  const LecturePage({
    super.key,
    this.videoUrl,
    this.roomName,
    this.lectureTitle,
    this.lectureList,
    this.currentLectureId,
  });

  @override
  State<LecturePage> createState() => _LecturePageState();
}

class _LecturePageState extends State<LecturePage> {
  // ── 비디오 컨트롤러 ───────────────────────────────────────
  YoutubePlayerController?              _ytController;
  StreamSubscription<YoutubePlayerValue>? _ytValueSub;
  StreamSubscription<YoutubeVideoState>?  _ytStateSub;
  VideoPlayerController?                _vpController;
  ChewieController?                     _chewieController;
  VideoType _videoType = VideoType.none;

  // ── 플레이어 UI 상태 ──────────────────────────────────────
  bool   _playing     = false;
  double _progress    = 0.0;
  bool   _chapterOpen = false;
  double _speed       = 1.0;
  int    _totalSeconds = 48 * 60 + 22; // 초기값, 컨트롤러 초기화 후 갱신

  // ── 탭 ───────────────────────────────────────────────────
  int _tab = 0;

  // ── 텍스트 컨트롤러 ───────────────────────────────────────
  final _startCtrl = TextEditingController(text: '20:05');
  final _endCtrl   = TextEditingController(text: '28:47');
  final _chatCtrl  = TextEditingController();

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'user',
      'text': '어피니티 다이어그램에서 그룹 크기는 어느 정도가 적당한가요?',
    },
    {
      'role': 'ai',
      'text':
          '예시 중심으로 설명할게요!\n\n한 그룹당 보통 3~8개 메모지가 적당합니다. '
          'IDEO에서는 팀 전체가 포스트잇을 직접 손으로 옮기며 묶는 방식을 써요. '
          '20개 이상 몰리면 하위 그룹으로 다시 쪼개는 게 좋습니다.',
      'style': '예시 중심형',
    },
  ];

  String get _roomNameText => widget.roomName ?? _kSubject;
  String get _lectureTitleText => widget.lectureTitle ?? _kEpTitle;

  // ── initState ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initVideo(widget.videoUrl);
  }

  Future<void> _initVideo(String? url) async {
    final type = detectVideoType(url);

    if (type == VideoType.youtube) {
      final id = extractYoutubeId(url!);
      if (id == null) return;

      final ctrl = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: false,
        params: const YoutubePlayerParams(showControls: false),
      );

      // 재생 상태 동기화 (YoutubePlayerValue stream)
      _ytValueSub = ctrl.listen((v) {
        if (!mounted) return;
        setState(() {
          _playing = v.playerState == PlayerState.playing;
          final dur = v.metaData.duration.inSeconds;
          if (dur > 0) _totalSeconds = dur;
        });
      });

      // 재생 위치 동기화 (YoutubeVideoState stream)
      _ytStateSub = ctrl.videoStateStream.listen((state) {
        if (!mounted || _totalSeconds == 0) return;
        setState(() {
          _progress = state.position.inMilliseconds /
              (_totalSeconds * 1000.0);
        });
      });

      setState(() {
        _ytController = ctrl;
        _videoType    = VideoType.youtube;
      });

    } else if (type == VideoType.direct) {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url!));
      await ctrl.initialize();

      final chewie = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: false,
        showControls: false,
      );

      // 재생 상태 & 진행바 동기화
      ctrl.addListener(() {
        if (!mounted) return;
        final dur = ctrl.value.duration;
        final pos = ctrl.value.position;
        setState(() {
          _playing = ctrl.value.isPlaying;
          if (dur.inMilliseconds > 0) {
            _totalSeconds = dur.inSeconds;
            _progress = pos.inMilliseconds / dur.inMilliseconds;
          }
        });
      });

      setState(() {
        _vpController     = ctrl;
        _chewieController = chewie;
        _videoType        = VideoType.direct;
        _totalSeconds     = ctrl.value.duration.inSeconds;
      });
    }
  }

  // ── dispose ───────────────────────────────────────────────
  @override
  void dispose() {
    _ytValueSub?.cancel();
    _ytStateSub?.cancel();
    _ytController?.close();
    _chewieController?.dispose();
    _vpController?.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  // ── 재생/멈춤 토글 ────────────────────────────────────────
  void _togglePlay() {
    switch (_videoType) {
      case VideoType.youtube:
        if (_ytController!.value.playerState == PlayerState.playing) {
          _ytController!.pauseVideo();
          setState(() => _playing = false);
        } else {
          _ytController!.playVideo();
          setState(() => _playing = true);
        }
      case VideoType.direct:
        if (_vpController!.value.isPlaying) {
          _vpController!.pause();
          setState(() => _playing = false);
        } else {
          _vpController!.play();
          setState(() => _playing = true);
        }
      case VideoType.none:
        setState(() => _playing = !_playing);
    }
  }

  // ── 시크 ──────────────────────────────────────────────────
  void _seekTo(double ratio) {
    final clamped = ratio.clamp(0.0, 1.0);
    setState(() => _progress = clamped);
    switch (_videoType) {
      case VideoType.youtube:
        _ytController!.seekTo(seconds: _totalSeconds * clamped);
      case VideoType.direct:
        _vpController!.seekTo(
          Duration(seconds: (_totalSeconds * clamped).round()),
        );
      case VideoType.none:
        break;
    }
  }

  void _skipSeconds(double seconds) =>
      _seekTo(_progress + seconds / _totalSeconds);

  // ── 현재 시간 문자열 ──────────────────────────────────────
  String get _currentTime {
    final cur = (_totalSeconds * _progress).round();
    return '${(cur ~/ 60).toString().padLeft(2, '0')}:'
        '${(cur % 60).toString().padLeft(2, '0')}';
  }

  String get _durationStr {
    return '${(_totalSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(_totalSeconds % 60).toString().padLeft(2, '0')}';
  }

  // ── 다음 강의 ─────────────────────────────────────────────
  bool get _hasNextLecture {
    final list = widget.lectureList;
    if (list == null || list.isEmpty) return false;
    final idx = list.indexWhere((l) => l['id'] == widget.currentLectureId);
    return idx != -1 && idx < list.length - 1;
  }

  void _goNextLecture() {
    final list = widget.lectureList;
    if (list == null || list.isEmpty) return;
    final idx = list.indexWhere((l) => l['id'] == widget.currentLectureId);
    if (idx == -1 || idx >= list.length - 1) return;
    final next = list[idx + 1];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LecturePage(
          videoUrl: next['video_url'] as String?,
          roomName: widget.roomName,
          lectureTitle: next['title'] as String?,
          lectureList: list,
          currentLectureId: next['id'] as String?,
        ),
      ),
    );
  }

  // ── 채팅 전송 ─────────────────────────────────────────────
  void _sendMessage() {
    final txt = _chatCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': txt});
      _chatCtrl.clear();
      _messages.add({
        'role': 'ai',
        'text':
            '좋은 질문이에요! 예시를 들어 설명하겠습니다.\n\n$txt 에 대해 구체적인 사례와 함께 답변드릴게요.',
        'style': _kStyle,
      });
    });
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildVideoArea()),
                _buildRightPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 헤더 ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _C.text2, size: 18),
            onPressed: () => Navigator.maybePop(context),
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _lectureTitleText,
              style: const TextStyle(
                color: _C.text1,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.limeDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: _C.lime, size: 12),
                SizedBox(width: 4),
                Text(
                  _kStyle,
                  style: TextStyle(
                    color: _C.lime,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── 좌측 영상 영역 ────────────────────────────────────────
  Widget _buildVideoArea() {
    return Column(
      children: [
        Expanded(child: _buildVideoWidget()),
        _buildVideoInfoBar(),
        _buildProgressBar(),
        _buildControlBar(),
      ],
    );
  }

  // ── 영상 하단 정보 바 (강의명 + 다음 강의 버튼) ────────────
  Widget _buildVideoInfoBar() {
    final roomName = _roomNameText;
    final lectureTitle = _lectureTitleText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _C.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roomName,
                  style: const TextStyle(color: _C.text2, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  lectureTitle,
                  style: const TextStyle(
                    color: _C.text1,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_hasNextLecture) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _goNextLecture,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.lime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '다음 강의',
                      style: TextStyle(
                        color: _C.limeDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: _C.limeDark, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 영상 위젯 (VideoType 분기) ────────────────────────────
  Widget _buildVideoWidget() {
    Widget playerLayer;
    switch (_videoType) {
      case VideoType.youtube:
        playerLayer = YoutubePlayer(controller: _ytController!);
      case VideoType.direct:
        playerLayer = _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const ColoredBox(color: Colors.black);
      case VideoType.none:
        // 기존 검정 플레이스홀더 + 중앙 재생버튼
        playerLayer = Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _C.lime.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _C.lime.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Icon(
                    _playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: _C.lime,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        playerLayer,
        // 좌하단: EP 번호 + 강의 제목
        Positioned(
          left: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.limeDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  _kEpNum,
                  style: TextStyle(
                    color: _C.lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _lectureTitleText,
                style: const TextStyle(
                  color: _C.text1,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
            ],
          ),
        ),
        // 챕터 오버레이
        if (_chapterOpen) _buildChapterOverlay(),
      ],
    );
  }

  // ── 챕터 오버레이 ─────────────────────────────────────────
  Widget _buildChapterOverlay() {
    const currentIdx = 2;
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 260,
      child: Container(
        color: _C.bg.withValues(alpha: 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const Text('챕터 목록',
                      style: TextStyle(
                          color: _C.text1,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _chapterOpen = false),
                    child: const Icon(Icons.close_rounded,
                        color: _C.text2, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(color: _C.border, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _kChapters.length,
                itemBuilder: (context, i) {
                  final ch    = _kChapters[i];
                  final isCur = i == currentIdx;
                  return _ChapterRow(
                    number: i + 1,
                    title: ch.title,
                    time: ch.time,
                    isCurrent: isCur,
                    onTap: () => setState(() => _chapterOpen = false),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 진행바 ───────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      color: _C.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onHorizontalDragUpdate: (d) =>
                      _seekTo(_progress + d.delta.dx / w),
                  onTapDown: (d) =>
                      _seekTo(d.localPosition.dx / w),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: _C.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _C.lime,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final m in _kMarkers)
                  Positioned(
                    left: m.pos * w - 5,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: m.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.bg, width: 1.5),
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_currentTime,
                  style: const TextStyle(color: _C.text2, fontSize: 11)),
              const SizedBox(width: 16),
              for (final m in _kMarkers) ...[
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                      color: m.color, shape: BoxShape.circle),
                ),
                Text(m.label,
                    style: const TextStyle(color: _C.text3, fontSize: 10)),
                const SizedBox(width: 10),
              ],
              const Spacer(),
              Text(_durationStr,
                  style: const TextStyle(color: _C.text2, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 컨트롤바 ─────────────────────────────────────────────
  Widget _buildControlBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: _C.surface,
      child: Row(
        children: [
          // 10초 뒤로
          _CtrlBtn(
            icon: Icons.replay_10_rounded,
            onTap: () => _skipSeconds(-10),
          ),
          const SizedBox(width: 4),
          // 재생/멈춤
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: _C.lime, shape: BoxShape.circle),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: _C.bg,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 10초 앞으로
          _CtrlBtn(
            icon: Icons.forward_10_rounded,
            onTap: () => _skipSeconds(10),
          ),
          const SizedBox(width: 8),
          // 볼륨
          _CtrlBtn(icon: Icons.volume_up_rounded, onTap: () {}),
          const Spacer(),
          // 챕터
          _CtrlBtn(
            icon: Icons.menu_rounded,
            label: '챕터',
            onTap: () => setState(() => _chapterOpen = !_chapterOpen),
            active: _chapterOpen,
          ),
          const SizedBox(width: 4),
          // 배속
          GestureDetector(
            onTap: () {
              const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
              final idx = speeds.indexOf(_speed);
              setState(() => _speed = speeds[(idx + 1) % speeds.length]);
              if (_videoType == VideoType.direct) {
                _vpController?.setPlaybackSpeed(_speed);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _C.surface2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _C.border),
              ),
              child: Text(
                '${_speed}x',
                style: const TextStyle(
                    color: _C.text2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 전체화면
          _CtrlBtn(icon: Icons.fullscreen_rounded, onTap: () {}),
        ],
      ),
    );
  }

  // ── 우측 패널 ─────────────────────────────────────────────
  Widget _buildRightPanel() {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(left: BorderSide(color: _C.border)),
      ),
      child: Column(
        children: [
          _buildTabs(),
          const Divider(color: _C.border, height: 1),
          Expanded(
            child: _tab == 0
                ? _buildSyllabusTab()
                : _buildAiQuestionTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _TabBtn(
            label: '교안',
            active: _tab == 0,
            onTap: () => setState(() => _tab = 0)),
        _TabBtn(
            label: 'AI 질문',
            active: _tab == 1,
            onTap: () => setState(() => _tab = 1)),
      ],
    );
  }

  // ── 교안 탭 ───────────────────────────────────────────────
  Widget _buildSyllabusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 성향 뱃지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.lavDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline_rounded,
                    color: _C.lavender, size: 12),
                SizedBox(width: 4),
                Text(_kStyle,
                    style: TextStyle(
                      color: _C.lavender,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 강의 제목
          const Text(
            _kEpTitle,
            style: TextStyle(
              color: _C.text1,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          // AI 재가공 태그
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _C.limeDark,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_fix_high_rounded, color: _C.lime, size: 11),
                SizedBox(width: 4),
                Text('AI 맞춤 재가공',
                    style: TextStyle(
                      color: _C.lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 핵심 개념
          const _SectionTitle(label: '핵심 개념'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _kConcepts
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: CircleAvatar(
                                radius: 3,
                                backgroundColor: _C.lime,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(c,
                                  style: const TextStyle(
                                      color: _C.text1,
                                      fontSize: 13,
                                      height: 1.5)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          // 학습 팁
          const _SectionTitle(label: '학습 팁'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: _C.lime,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      _kTip,
                      style: TextStyle(
                          color: _C.text2, fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 자주 막히는 지점
          const _SectionTitle(label: '자주 막히는 지점'),
          const SizedBox(height: 10),
          Column(
            children: _kHardSpots
                .map((s) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _C.salmonDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _C.salmon.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: _C.salmon, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s,
                                style: const TextStyle(
                                    color: _C.text2,
                                    fontSize: 12,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── AI 질문 탭 ────────────────────────────────────────────
  Widget _buildAiQuestionTab() {
    return Column(
      children: [
        _buildRangeInput(),
        const Divider(color: _C.border, height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[i];
              return _ChatBubble(
                role: msg['role'] as String,
                text: msg['text'] as String,
                style: msg['style'] as String?,
              );
            },
          ),
        ),
        const Divider(color: _C.border, height: 1),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildRangeInput() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text('구간',
              style: TextStyle(color: _C.text2, fontSize: 12)),
          const SizedBox(width: 8),
          _TimeInput(controller: _startCtrl),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('~', style: TextStyle(color: _C.text2)),
          ),
          _TimeInput(controller: _endCtrl),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _C.limeDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _C.lime.withValues(alpha: 0.3)),
              ),
              child: const Text('질문하기',
                  style: TextStyle(
                      color: _C.lime,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: _C.surface,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _C.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border),
              ),
              child: TextField(
                controller: _chatCtrl,
                style: const TextStyle(color: _C.text1, fontSize: 13),
                maxLines: 1,
                decoration: const InputDecoration.collapsed(
                  hintText: '강의 내용에 대해 질문하세요...',
                  hintStyle:
                      TextStyle(color: _C.text3, fontSize: 13),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: _C.lime, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded,
                  color: _C.bg, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 소형 위젯
// ════════════════════════════════════════════════════════════

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool active;

  const _CtrlBtn({
    required this.icon,
    required this.onTap,
    this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _C.limeDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? _C.lime : _C.text2, size: 20),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label!,
                  style: TextStyle(
                      color: active ? _C.lime : _C.text2, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _C.lime : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _C.lime : _C.text2,
            fontSize: 13,
            fontWeight:
                active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  final int number;
  final String title;
  final String time;
  final bool isCurrent;
  final VoidCallback onTap;

  const _ChapterRow({
    required this.number,
    required this.title,
    required this.time,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isCurrent ? _C.limeDark : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent ? _C.lime : _C.surface2,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  color: isCurrent ? _C.bg : _C.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isCurrent ? _C.lime : _C.text2,
                  fontSize: 13,
                  fontWeight: isCurrent
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            Text(time,
                style: const TextStyle(color: _C.text3, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _C.text2,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String role;
  final String text;
  final String? style;

  const _ChatBubble({
    required this.role,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: isUser ? _C.limeDark : _C.surface2,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isUser ? 12 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 12),
              ),
              border: Border.all(
                color: isUser
                    ? _C.lime.withValues(alpha: 0.3)
                    : _C.border,
              ),
            ),
            child: Text(
              _normalizeDisplayText(text),
              style: TextStyle(
                color: isUser ? _C.lime : _C.text1,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          if (!isUser && style != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _C.lavDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                style!,
                style: const TextStyle(
                  color: _C.lavender,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeInput extends StatelessWidget {
  final TextEditingController controller;

  const _TimeInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _C.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _C.border),
        ),
        child: TextField(
          controller: controller,
          style: const TextStyle(
              color: _C.text1, fontSize: 12, fontFamily: 'monospace'),
          textAlign: TextAlign.center,
          maxLines: 1,
          decoration:
              const InputDecoration.collapsed(hintText: '00:00'),
        ),
      ),
    );
  }
}
