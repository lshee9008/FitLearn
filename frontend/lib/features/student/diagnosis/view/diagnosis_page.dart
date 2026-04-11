import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../provider/diagnosis_provider.dart';

// ════════════════════════════════════════════════════════════
// 컬러
// ════════════════════════════════════════════════════════════
class _C {
  static const bg        = Color(0xFF0E0E11);
  static const surface   = Color(0xFF13131A);
  static const surface2  = Color(0xFF1A1A24);
  static const border    = Color(0xFF1E1E2A);
  static const lime      = Color(0xFFC8F135);
  static const limeDark  = Color(0xFF1A2400);
  static const lavender  = Color(0xFFA78BFA);
  static const lavDark   = Color(0xFF2D1B69);
  static const lavMid    = Color(0xFF1E1830);
  static const coral     = Color(0xFFFB7185);
  static const coralDark = Color(0xFF3D0A14);
  static const amber     = Color(0xFFFBBF24);
  static const amberDark = Color(0xFF3D2800);
  static const textPri   = Color(0xFFF0F0F4);
  static const textSec   = Color(0xFF8888A0);
  static const textMute  = Color(0xFF4A4A5A);
}

// ════════════════════════════════════════════════════════════
// 질문 모델
// ════════════════════════════════════════════════════════════
enum _QType { choice, text, scenario }

class _Q {
  final String id;
  final String phase;
  final String dimension;   // 측정 차원
  final String emoji;
  final String? scenarioText;
  final String text;
  final String? subtitle;
  final List<String> options;
  final _QType type;

  const _Q({
    required this.id,
    required this.phase,
    required this.dimension,
    required this.text,
    this.options = const [],
    this.type = _QType.choice,
    this.emoji = '',
    this.scenarioText,
    this.subtitle,
  });
}

// ════════════════════════════════════════════════════════════
// 질문 데이터 (S1 ~ S18)
// ════════════════════════════════════════════════════════════

// ── Phase 0: 워밍업 서술 ─────────────────────────────────────
const _qS1 = _Q(
  id: 'S1', phase: 'P0', dimension: '무의식 학습 패턴',
  emoji: '✍️',
  text: '최근 뭔가를 처음 배워야 했던 순간, 어떻게 시작했나요?',
  subtitle: '앱, 업무 툴, 요리, 운동 뭐든 OK',
  type: _QType.text,
);

// ── Phase 1: 분기 기준 문항 ──────────────────────────────────
const _qS2 = _Q(
  id: 'S2', phase: 'P1', dimension: '진입 방식',
  emoji: '📱',
  scenarioText: '새로운 디자인 툴을 오늘부터 써야 합니다.',
  text: '제일 먼저 뭐 해요?',
  options: [
    '유튜브에서 입문 강의 찾아봄',
    '공식 문서나 튜토리얼 정독',
    '일단 열어서 이것저것 눌러봄',
    '잘 쓰는 사람한테 바로 질문',
  ],
  type: _QType.scenario,
);

// ── S3 분기 문항 4가지 ───────────────────────────────────────
const _qS3A = _Q(
  id: 'S3-A', phase: 'P1', dimension: 'VARK 시각형',
  emoji: '🎬',
  text: '영상 볼 때 보통 어떻게 봐요?',
  options: [
    '1.5~2배속으로 전체 흐름 파악 먼저',
    '처음부터 끝까지 정속으로 따라함',
    '궁금한 부분만 골라서 반복 시청',
    '영상 보면서 동시에 직접 따라함',
  ],
);

const _qS3B = _Q(
  id: 'S3-B', phase: 'P1', dimension: 'VARK 읽기형',
  emoji: '📖',
  text: '읽다가 모르는 용어 나오면?',
  options: [
    '일단 넘기고 전체 맥락 파악 먼저',
    '그 자리에서 검색해서 완전히 이해',
    '형광펜 치고 나중에 몰아서 찾음',
    '아는 사람한테 한 줄 설명 요청',
  ],
);

const _qS3C = _Q(
  id: 'S3-C', phase: 'P1', dimension: 'Kolb 행동형',
  emoji: '🔧',
  text: '이것저것 눌러보다 막혔을 때?',
  options: [
    '검색창에 에러 메시지 복붙',
    '되던 상태로 되돌아가서 다시',
    '다른 방법으로 우회해서 일단 진행',
    '잠깐 멈추고 구조를 머릿속으로 정리',
  ],
);

const _qS3D = _Q(
  id: 'S3-D', phase: 'P1', dimension: 'VARK 청각형',
  emoji: '💬',
  text: '질문할 때 주로 어떻게 물어봐요?',
  options: [
    '내가 뭘 모르는지 정확히 짚어서 질문',
    '상황 전체를 설명하고 어떻게 하면 되냐고',
    '일단 물어보고 답 들으면서 이해',
    '비슷한 사례 찾아보고 그래도 모르면 질문',
  ],
);

// ── Phase 1 공통 시나리오 ────────────────────────────────────
const _qS4 = _Q(
  id: 'S4', phase: 'P1', dimension: '마감 압박 대응',
  emoji: '⏰',
  scenarioText: '내일 오전까지 처음 써보는 툴로 결과물을 내야 합니다. 지금 자정.',
  text: '어떻게 해요?',
  options: [
    '핵심 기능만 빠르게 파악 후 완성',
    '비슷한 레퍼런스 찾아서 따라함',
    '30분 안에 전체 기능 훑고 최적 경로 선택',
    '잘 아는 사람한테 SOS 연락',
  ],
  type: _QType.scenario,
);

const _qS5 = _Q(
  id: 'S5', phase: 'P1', dimension: '오개념 처리',
  emoji: '🤔',
  scenarioText: '강의에서 이해한 내용대로 했는데 실습에서 결과가 다르게 나옵니다.',
  text: '어떻게 해요?',
  options: [
    '강의 해당 구간 다시 돌려봄',
    '왜 다른지 직접 변수 바꿔가며 실험',
    '검색으로 원인 추적',
    '일단 되는 방향으로 진행하고 나중에 확인',
  ],
  type: _QType.scenario,
);

const _qS6 = _Q(
  id: 'S6', phase: 'P1', dimension: '메타인지',
  emoji: '📝',
  scenarioText: '열심히 한 과제에서 예상보다 낮은 점수를 받았습니다.',
  text: '어떻게 해요?',
  options: [
    '채점 기준표 다시 꼼꼼히 읽음',
    '잘 받은 사람 결과물과 내 것 비교',
    '강사한테 어디서 틀렸는지 직접 질문',
    '다음번에 더 잘하면 된다고 넘김',
  ],
  type: _QType.scenario,
);

const _qS7 = _Q(
  id: 'S7', phase: 'P1', dimension: '협업 스타일',
  emoji: '👥',
  scenarioText: '팀 프로젝트에서 내 파트가 생각보다 복잡합니다.',
  text: '어떻게 해요?',
  options: [
    '혼자 밤새워서 해결함',
    '팀원한테 도움 요청',
    '내 파트 범위를 줄여서 확실하게만',
    '유사 사례 찾아서 구조 참고',
  ],
  type: _QType.scenario,
);

// ── Phase 2: 행동 패턴 (응답시간 측정) ──────────────────────
const _qS8 = _Q(
  id: 'S8', phase: 'P2', dimension: 'VARK 유형',
  text: '새로운 개념을 배울 때 더 잘 이해되는 방식은?',
  options: ['그림이나 도식으로 보기', '말로 설명 듣기', '직접 해보기', '글로 읽기'],
);

const _qS9 = _Q(
  id: 'S9', phase: 'P2', dimension: '집중 패턴',
  text: '공부할 때 나한테 더 잘 맞는 건?',
  options: [
    '짧게 여러 번 (25분 집중 + 휴식)',
    '길게 한 번에 (2시간+ 몰입)',
    '그때그때 다름',
    '아주 짧게 자주 (10분씩 틈틈이)',
  ],
);

const _qS10 = _Q(
  id: 'S10', phase: 'P2', dimension: '복습 방식',
  text: '배운 내용을 복습할 때 주로?',
  options: [
    '핵심만 정리한 노트 다시 보기',
    '강의 영상 다시 돌려보기',
    '문제 풀거나 실습으로 확인',
    '누군가에게 설명해보기',
  ],
);

const _qS11 = _Q(
  id: 'S11', phase: 'P2', dimension: '난이도 대응',
  text: '강의 내용이 너무 어렵게 느껴질 때?',
  options: [
    '더 기초 자료 찾아서 채우고 다시',
    '일단 계속 보다 보면 이해되겠지',
    '어려운 부분만 메모하고 질문',
    '쉬운 부분부터 해결하고 어려운 건 나중에',
  ],
);

const _qS12 = _Q(
  id: 'S12', phase: 'P2', dimension: '동기 유형',
  text: '공부할 때 가장 힘이 나는 순간은?',
  options: [
    '뭔가 완성됐을 때 (결과물)',
    '개념이 딱 이해됐을 때 (깨달음)',
    '주변 사람이 잘한다고 할 때 (인정)',
    '목표 달성이 가까워질 때 (진척)',
  ],
);

// ── Phase 3: 실패 역추적 ─────────────────────────────────────
const _qS13 = _Q(
  id: 'S13', phase: 'P3', dimension: '이탈 위험 인자',
  text: '공부하다 포기한 적 있다면, 그때 가장 큰 이유는?',
  options: [
    '너무 어려워서 진도가 막힘',
    '왜 배우는지 이해가 안 됨',
    '시간이 부족하거나 루틴이 무너짐',
    '혼자라서 의지할 데가 없었음',
    '흥미가 떨어짐',
  ],
);

const _qS14 = _Q(
  id: 'S14', phase: 'P3', dimension: '성공 패턴',
  text: '지금까지 가장 빠르게 실력이 늘었던 분야나 과목이 있다면?',
  options: [
    '이과 계열 (수학/과학/코딩)',
    '문과 계열 (언어/역사/글쓰기)',
    '예체능 계열 (미술/음악/체육)',
    '실무 스킬 (자격증/툴/업무)',
    '딱히 없음',
  ],
);

// S15: 서술형 (성공 요인)
const _qS15 = _Q(
  id: 'S15', phase: 'P3', dimension: '성공 요인 분석',
  emoji: '💡',
  text: 'S14에서 선택한 분야를\n잘할 수 있었던 이유가 뭐라고 생각해요?\n\n(1~2줄이면 충분해요)',
  type: _QType.text,
);

// ── Phase 4: 신뢰도 교차 검증 ────────────────────────────────
const _qS16 = _Q(
  id: 'S16', phase: 'P4', dimension: 'VARK 교차검증 (↔S8)',
  text: '친구한테 처음 가는 맛집을 설명할 때?',
  options: [
    '지도 캡처 보내줌',
    '랜드마크 기준으로 말로 설명',
    '같이 가자고 함',
    '주소 텍스트로 보내줌',
  ],
);

const _qS17 = _Q(
  id: 'S17', phase: 'P4', dimension: '집중 패턴 교차검증 (↔S9)',
  text: '넷플릭스 볼 때 주로?',
  options: [
    '에피소드 1~2개만 보고 끊음',
    '시즌 전체 한 번에 정주행',
    '그날 기분에 따라 다름',
    '출퇴근 등 짬짬이 조금씩',
  ],
);

const _qS18 = _Q(
  id: 'S18', phase: 'P4', dimension: '난이도 대응 교차검증 (↔S11)',
  text: '조립 설명서가 이해 안 될 때?',
  options: [
    '설명서 처음부터 다시 읽음',
    '유튜브 조립 영상 찾음',
    '일단 감으로 해보다 안 되면 설명서',
    '아는 사람한테 전화',
  ],
);

// ════════════════════════════════════════════════════════════
// 분기 맵 & 플로우
// ════════════════════════════════════════════════════════════

// S2 선택 → S3 분기
const _kS3Branch = {
  'A': _qS3A,
  'B': _qS3B,
  'C': _qS3C,
  'D': _qS3D,
};

// 파트 컬러 (Phase별)
const _kPhaseColor = {
  'P0': _C.lavender,
  'P1': _C.lime,
  'P2': _C.coral,
  'P3': _C.amber,
  'P4': _C.lavender,
};

const _kPhaseLabel = {
  'P0': '워밍업',
  'P1': '시나리오',
  'P2': '행동 패턴',
  'P3': '학습 이력',
  'P4': '신뢰도 검증',
};

// ════════════════════════════════════════════════════════════
// Phase 열거형
// ════════════════════════════════════════════════════════════
enum _Phase { writing, questions, history, analyzing }

// ════════════════════════════════════════════════════════════
// 메인 진단 페이지
// ════════════════════════════════════════════════════════════
class DiagnosisPage extends ConsumerStatefulWidget {
  const DiagnosisPage({super.key});

  @override
  ConsumerState<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends ConsumerState<DiagnosisPage>
    with TickerProviderStateMixin {

  // ── 플로우 상태 ──────────────────────────────────────────
  _Phase _phase = _Phase.writing;

  // ── 질문 플로우 (동적 빌드) ─────────────────────────────
  late List<_Q> _flow;
  int _current = 0;

  // ── 응답 데이터 ─────────────────────────────────────────
  final _writingCtrl = TextEditingController();    // S1
  final _s15Ctrl = TextEditingController();        // S15 서술
  final Map<String, String> _answers = {};         // id → 선택지 레이블
  final Map<String, int> _responseTimes = {};      // id → ms
  DateTime? _qStartTime;

  // ── 학습 이력 ────────────────────────────────────────────
  final _historySubjectCtrl = TextEditingController();
  String? _historyReason;
  String? _historyDifficulty;

  // ── 애니메이션 ───────────────────────────────────────────
  late AnimationController _slideCtrl;
  late Animation<Offset> _slide;

  // 총 스텝
  static const int _totalSteps = 22;

  int get _currentStep {
    switch (_phase) {
      case _Phase.writing: return 0;
      case _Phase.questions: return 1 + _current;
      case _Phase.history: return 9;
      case _Phase.analyzing: return _totalSteps;
    }
  }

  _Q get _q => _flow[_current];

  @override
  void initState() {
    super.initState();
    _buildFlow('');   // 초기 플로우
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _buildAnim(true);
    _slideCtrl.forward();
    _qStartTime = DateTime.now();
    _writingCtrl.addListener(() => setState(() {}));
    _s15Ctrl.addListener(() => setState(() {}));
  }

  void _buildFlow(String s2Answer) {
    final s3 = _kS3Branch[s2Answer] ?? _qS3A;
    _flow = [
      _qS2,
      s3,
      _qS4, _qS5, _qS6, _qS7,
      _qS8, _qS9, _qS10, _qS11, _qS12,
      _qS13, _qS14, _qS15,
      _qS16, _qS17, _qS18,
    ];
  }

  void _buildAnim(bool fwd) {
    _slide = Tween<Offset>(
      begin: Offset(fwd ? 1.0 : -1.0, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _writingCtrl.dispose();
    _s15Ctrl.dispose();
    _historySubjectCtrl.dispose();
    super.dispose();
  }

  void _recordTime(String qId) {
    if (_qStartTime != null) {
      _responseTimes[qId] =
          DateTime.now().difference(_qStartTime!).inMilliseconds;
    }
  }

  void _select(String label) {
    _recordTime(_q.id);
    setState(() => _answers[_q.id] = label);
  }

  void _animNext() {
    _buildAnim(true);
    _slideCtrl.reset();
    _slideCtrl.forward();
  }

  void _animPrev() {
    _buildAnim(false);
    _slideCtrl.reset();
    _slideCtrl.forward();
  }

  Future<void> _onNext() async {
    switch (_phase) {
      case _Phase.writing:
        if (_writingCtrl.text.trim().length < 20) return;
        _animNext();
        setState(() {
          _phase = _Phase.questions;
          _current = 0;
          _qStartTime = DateTime.now();
        });

      case _Phase.questions:
        final q = _q;

        if (q.type == _QType.text && q.id == 'S15') {
          if (_s15Ctrl.text.trim().length < 5) return;
        } else if (q.type != _QType.text) {
          if (_answers[q.id] == null) return;
        }

        if (q.id == 'S2') {
          final picked = _answers['S2'] ?? 'A';
          _buildFlow(picked);
        }

        if (_current == 10) {
          _animNext();
          setState(() => _phase = _Phase.history);
          return;
        }

        if (_current == _flow.length - 1) {
          await _submit();
          return;
        }

        _animNext();
        setState(() {
          _current++;
          _qStartTime = DateTime.now();
        });

      case _Phase.history:
        if (_historySubjectCtrl.text.trim().isEmpty) return;
        _animNext();
        setState(() {
          _phase = _Phase.questions;
          _current = 11;
          _qStartTime = DateTime.now();
        });

      case _Phase.analyzing:
        break;
    }
  }

  void _onBack() {
    switch (_phase) {
      case _Phase.writing:
        Navigator.of(context).maybePop();

      case _Phase.questions:
        if (_current == 11) {
          _animPrev();
          setState(() => _phase = _Phase.history);
          return;
        }
        if (_current == 0) {
          _animPrev();
          setState(() => _phase = _Phase.writing);
          return;
        }
        _animPrev();
        setState(() {
          _current--;
          _qStartTime = DateTime.now();
        });

      case _Phase.history:
        _animPrev();
        setState(() {
          _phase = _Phase.questions;
          _current = 10;
          _qStartTime = DateTime.now();
        });

      case _Phase.analyzing:
        break;
    }
  }

  String _pick(Map<String, String> map, String qid, {String fallback = 'A'}) {
    final value = _answers[qid];
    return map[value] ?? fallback;
  }

  List<Map<String, dynamic>> _buildEngineAnswers() {
    final answers = <Map<String, dynamic>>[];

    void put(int qid, String answer, {String source = ''}) {
      final rt = source.isEmpty ? 0 : (_responseTimes[source] ?? 0);
      answers.add({
        'question_id': qid,
        'answer': answer,
        'response_time_ms': rt,
      });
    }

    put(1, _pick({'A': 'A', 'B': 'B', 'C': 'D', 'D': 'C'}, 'S8'), source: 'S8');
    put(2, _pick({'A': 'A', 'B': 'C', 'C': 'D', 'D': 'B'}, 'S2'), source: 'S2');
    put(3, _pick({'A': 'A', 'B': 'C', 'C': 'D', 'D': 'B'}, _flow[1].id), source: _flow[1].id);
    put(4, _pick({'A': 'A', 'B': 'C', 'C': 'D', 'D': 'B'}, 'S16'), source: 'S16');
    put(5, _pick({'A': 'C', 'B': 'A', 'C': 'D', 'D': 'B'}, 'S10'), source: 'S10');

    put(6, _pick({'A': 'A', 'B': 'B', 'C': 'A', 'D': 'B'}, 'S4'), source: 'S4');
    put(7, _pick({'A': 'A', 'B': 'B', 'C': 'A', 'D': 'B'}, 'S5'), source: 'S5');
    put(8, _pick({'A': 'A', 'B': 'B', 'C': 'B', 'D': 'B'}, 'S6'), source: 'S6');
    put(9, _pick({'A': 'A', 'B': 'B', 'C': 'A', 'D': 'A'}, 'S7'), source: 'S7');
    put(10, _pick({'A': 'A', 'B': 'B', 'C': 'B', 'D': 'A'}, 'S12'), source: 'S12');

    put(11, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D'}, 'S11'), source: 'S11');
    put(12, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'A'}, 'S9'), source: 'S9');
    put(13, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'C'}, 'S10'), source: 'S10');
    put(14, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D', 'E': 'C'}, 'S13'), source: 'S13');
    put(15, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D', 'E': 'C'}, 'S14'), source: 'S14');

    put(16, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'A'}, 'S17'), source: 'S17');
    put(17, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D'}, 'S11'), source: 'S11');
    put(18, _pick({'A': 'A', 'B': 'B', 'C': 'D', 'D': 'C'}, 'S16'), source: 'S16');
    put(19, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'B'}, 'S7'), source: 'S7');
    put(20, _pick({'A': 'A', 'B': 'B', 'C': 'D', 'D': 'C'}, 'S2'), source: 'S2');
    put(21, _pick({'A': 'A', 'B': 'D', 'C': 'B', 'D': 'C'}, 'S5'), source: 'S5');
    put(22, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D'}, 'S4'), source: 'S4');
    put(23, _pick({'A': 'A', 'B': 'D', 'C': 'B', 'D': 'C'}, 'S2'), source: 'S2');
    put(24, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'C'}, 'S17'), source: 'S17');
    put(25, _pick({'A': 'A', 'B': 'B', 'C': 'C', 'D': 'B'}, 'S12'), source: 'S12');

    return answers;
  }

  Future<void> _submit() async {
    setState(() => _phase = _Phase.analyzing);
    final user = ref.read(authNotifierProvider);
    if (user == null) return;

    final answers = _buildEngineAnswers();

    try {
      final result = await ref
          .read(diagnosisNotifierProvider.notifier)
          .submit(
            userId: user.userId,
            answers: answers,
            writingResponse: _writingCtrl.text.trim(),
            learningHistory: {
              'subject': _historySubjectCtrl.text.trim(),
              'reason': _historyReason ?? '',
              'difficulty': _historyDifficulty ?? '',
              'success_reason': _s15Ctrl.text.trim(),
            },
          );
      if (mounted) {
        context.push('/student/diagnosis/result', extra: result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.questions;
          _current = _flow.length - 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('분석 실패: $e'),
          backgroundColor: _C.coral,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.analyzing) return const _AnalyzingScreen();

    bool canProceed = false;
    String btnText = '다음 →';

    switch (_phase) {
      case _Phase.writing:
        canProceed = _writingCtrl.text.trim().length >= 20;
        btnText = '진단 시작 →';

      case _Phase.questions:
        if (_q.type == _QType.text && _q.id == 'S15') {
          canProceed = _s15Ctrl.text.trim().length >= 5;
        } else if (_q.type == _QType.text) {
          canProceed = true;
        } else {
          canProceed = _answers[_q.id] != null;
        }
        final isLast = _current == _flow.length - 1;
        btnText = isLast ? '결과 분석하기 →' : '다음 →';

      case _Phase.history:
        canProceed = _historySubjectCtrl.text.trim().isNotEmpty;
        btnText = '계속하기 →';

      case _Phase.analyzing:
        break;
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: _phase == _Phase.writing || _phase == _Phase.history
            ? Column(children: [
                _buildHeader(),
                Expanded(
                  child: SlideTransition(
                    position: _slide,
                    child: _buildBody(),
                  ),
                ),
                _buildNavBtn(canProceed, btnText),
              ])
            : Column(children: [
                _buildWebTopBar(),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _QuestionLeftPanel(
                        partColor: _kPhaseColor[_q.phase] ?? _C.lime,
                        phaseLabel: '${_q.phase} · ${_kPhaseLabel[_q.phase] ?? ''}',
                        phaseSteps: const [
                          'Phase 0 · 워밍업',
                          'Phase 1 · 시나리오',
                          'Phase 2 · 행동 패턴',
                          'Phase 3 · 학습 이력',
                          'Phase 4 · 신뢰도 검증',
                        ],
                        currentPhaseIndex: const {
                          'P0': 0, 'P1': 1, 'P2': 2, 'P3': 3, 'P4': 4,
                        }[_q.phase] ?? 1,
                        currentStep: _currentStep,
                        totalSteps: _totalSteps,
                      ),
                      Expanded(
                        child: SlideTransition(
                          position: _slide,
                          child: _buildCenterOnly(),
                        ),
                      ),
                      _QuestionRightPanel(question: _q),
                    ],
                  ),
                ),
                _buildWebNavBtn(canProceed, btnText),
              ]),
      ),
    );
  }

    // ── 웹 상단 바 ─────────────────────────────────────────────
  Widget _buildWebTopBar() {
    final barColor = _phase == _Phase.questions
        ? (_kPhaseColor[_q.phase] ?? _C.lime)
        : _C.amber;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: ClipRRect(
        child: LinearProgressIndicator(
          value: (_currentStep + 1) / _totalSteps,
          minHeight: 3,
          backgroundColor: _C.surface,
          valueColor: AlwaysStoppedAnimation(barColor),
        ),
      ),
    );
  }

  // ── 웹 하단 네비게이션 버튼 ─────────────────────────────────
  Widget _buildWebNavBtn(bool canProceed, String btnText) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        const SizedBox(width: 220),
        Container(width: 1, color: _C.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _onBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _C.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _C.border),
                    ),
                    child: const Text('← 이전',
                        style: TextStyle(
                            color: _C.textSec,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                GestureDetector(
                  onTap: canProceed ? _onNext : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    decoration: BoxDecoration(
                      color: canProceed ? _C.lime : _C.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(btnText,
                        style: TextStyle(
                          color: canProceed ? _C.limeDark : _C.textMute,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: _C.border),
        const SizedBox(width: 220),
      ]),
    );
  }

  // ── 모바일용 헤더 + 진행바 ─────────────────────────────────
  Widget _buildHeader() {
    final progress = (_currentStep + 1) / _totalSteps;

    Color barColor = _C.lavender;
    String label = '워밍업';

    if (_phase == _Phase.questions) {
      barColor = _kPhaseColor[_q.phase] ?? _C.lime;
      label = _kPhaseLabel[_q.phase] ?? '';
    } else if (_phase == _Phase.history) {
      barColor = _C.amber;
      label = '학습 이력';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: _onBack,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _C.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _C.textSec, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text('${_currentStep + 1} / $_totalSteps',
              style: const TextStyle(
                  color: _C.textSec, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _C.surface2,
            valueColor: AlwaysStoppedAnimation(barColor),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── writing / history용 바디 ───────────────────────────────
  Widget _buildBody() {
    if (_phase == _Phase.writing) {
      return _WritingCard(
        key: const ValueKey('S1'),
        controller: _writingCtrl,
        question: _qS1,
      );
    }
    if (_phase == _Phase.history) {
      return _HistoryCard(
        key: const ValueKey('history'),
        subjectCtrl: _historySubjectCtrl,
        reason: _historyReason,
        difficulty: _historyDifficulty,
        onReasonChanged: (v) => setState(() => _historyReason = v),
        onDifficultyChanged: (v) =>
            setState(() => _historyDifficulty = v),
      );
    }
    return const SizedBox.shrink();
  }

  // ── 질문 화면 중앙 콘텐츠 (슬라이드 대상) ───────────────────
  Widget _buildCenterOnly() {
    final q = _q;
    if (q.id == 'S15') {
      return _WritingCenter(
        key: ValueKey(q.id),
        controller: _s15Ctrl,
        question: q,
        minLength: 5,
      );
    }
    return _QuestionCenter(
      key: ValueKey(q.id),
      question: q,
      partColor: _kPhaseColor[q.phase] ?? _C.lime,
      answered: _answers[q.id],
      onSelect: _select,
    );
  }

  // ── 모바일 하단 버튼 ────────────────────────────────────────
  Widget _buildNavBtn(bool canProceed, String btnText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: GestureDetector(
        onTap: canProceed ? _onNext : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            color: canProceed ? _C.lime : _C.surface2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              btnText,
              style: TextStyle(
                color: canProceed ? _C.limeDark : _C.textMute,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 서술형 전체 카드 (S1용)
// ════════════════════════════════════════════════════════════
class _WritingCard extends StatelessWidget {
  final TextEditingController controller;
  final _Q question;
  final int minLength;

  const _WritingCard({
    super.key,
    required this.controller,
    required this.question,
    this.minLength = 20,
  });

  @override
  Widget build(BuildContext context) {
    final len = controller.text.trim().length;
    final reached = len >= minLength;
    final isS1 = question.id == 'S1';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 왼쪽 패널
        Container(
          width: 220,
          padding: const EdgeInsets.fromLTRB(32, 32, 24, 32),
          decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: _C.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('현재 단계',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _C.textMute, letterSpacing: 1)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _C.lavender.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.lavender.withValues(alpha: 0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.lavender, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('P0 · 워밍업',
                    style: TextStyle(color: _C.lavender, fontSize: 12, fontWeight: FontWeight.w700)),
              ])),
            const SizedBox(height: 28),
            const Text('AI 분석',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _C.textMute, letterSpacing: 1)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
              child: const Text(
                '자유 서술 텍스트에서\n무의식적 학습 패턴을\n감지합니다.',
                style: TextStyle(color: _C.textSec, fontSize: 11, height: 1.6))),
          ])),

        // 중앙 콘텐츠
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 32, 48, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.lavMid,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.lavender.withValues(alpha: 0.25))),
                child: Row(children: [
                  Text(question.emoji.isNotEmpty ? question.emoji : '✍️', style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('자유 서술',
                          style: TextStyle(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        isS1 ? 'AI가 글쓰기 패턴으로 학습 성향을 분석합니다' : 'FitLearn이 성공 요인을 분석합니다',
                        style: const TextStyle(color: _C.textSec, fontSize: 12)),
                    ])),
                ])),
              const SizedBox(height: 32),
              Text(question.text,
                  style: const TextStyle(
                    color: _C.textPri, fontSize: 26,
                    fontWeight: FontWeight.w700, height: 1.4, letterSpacing: -0.1)),
              if (question.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(question.subtitle!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: _C.textSec,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    )),
              ],
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: reached ? _C.lime.withValues(alpha: 0.6) : _C.border,
                    width: reached ? 1.5 : 1)),
                child: TextField(
                  controller: controller,
                  maxLines: isS1 ? 7 : 5,
                  style: const TextStyle(color: _C.textPri, fontSize: 15, height: 1.65),
                  decoration: InputDecoration(
                    hintText: isS1
                        ? '예) 유튜브에서 튜토리얼 찾아보고, 직접 따라하면서 익혔어요...'
                        : '예) 직접 해볼 기회가 많아서 자연스럽게 익혔던 것 같아요',
                    hintStyle: const TextStyle(color: _C.textMute, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20)))),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('$len자', style: TextStyle(color: reached ? _C.lime : _C.textSec, fontSize: 12)),
                if (!reached) ...[
                  const SizedBox(width: 4),
                  Text('(최소 ${minLength}자)', style: const TextStyle(color: _C.textMute, fontSize: 12)),
                ],
              ]),
            ]))),

        // 오른쪽 패널
        Container(
          width: 220,
          padding: const EdgeInsets.fromLTRB(24, 32, 32, 32),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _C.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.lavender.withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _C.lavMid, borderRadius: BorderRadius.circular(20)),
                  child: const Text('분석 항목',
                      style: TextStyle(color: _C.lavender, fontSize: 9, fontWeight: FontWeight.w700))),
                const SizedBox(height: 10),
                const Text('무의식 학습 패턴',
                    style: TextStyle(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const _AnalysisRow('문체', '간결 vs 상세'),
                const _AnalysisRow('단어', '시각/청각/행동'),
                const _AnalysisRow('구조', '순차 vs 비선형'),
                const _AnalysisRow('감정', '표현 방식'),
              ])),
          ])),
      ]);
  }
}

// ════════════════════════════════════════════════════════════
// 서술형 중앙 콘텐츠 (S15용)
// ════════════════════════════════════════════════════════════
class _WritingCenter extends StatelessWidget {
  final TextEditingController controller;
  final _Q question;
  final int minLength;

  const _WritingCenter({
    super.key,
    required this.controller,
    required this.question,
    this.minLength = 20,
  });

  @override
  Widget build(BuildContext context) {
    final len = controller.text.trim().length;
    final reached = len >= minLength;
    final isS1 = question.id == 'S1';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _C.lavMid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.lavender.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Text(question.emoji.isNotEmpty ? question.emoji : '✍️', style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('자유 서술',
                    style: TextStyle(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  isS1 ? 'AI가 글쓰기 패턴으로 학습 성향을 분석합니다' : 'FitLearn이 성공 요인을 분석합니다',
                  style: const TextStyle(color: _C.textSec, fontSize: 12)),
              ])),
          ])),
        const SizedBox(height: 32),
        Text(question.text,
            style: const TextStyle(
              color: _C.textPri, fontSize: 28,
              fontWeight: FontWeight.w700, height: 1.4, letterSpacing: -0.3)),
        if (question.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(question.subtitle!,
              style: const TextStyle(
                fontSize: 16,
                color: _C.textSec,
                fontWeight: FontWeight.w400,
                height: 1.5,
              )),
        ],
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: reached ? _C.lime.withValues(alpha: 0.6) : _C.border,
              width: reached ? 1.5 : 1)),
          child: TextField(
            controller: controller,
            maxLines: isS1 ? 7 : 5,
            style: const TextStyle(color: _C.textPri, fontSize: 15, height: 1.65),
            decoration: InputDecoration(
              hintText: isS1
                  ? '예) 유튜브에서 튜토리얼 찾아보고, 직접 따라하면서 익혔어요...'
                  : '예) 직접 해볼 기회가 많아서 자연스럽게 익혔던 것 같아요',
              hintStyle: const TextStyle(color: _C.textMute, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20)))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('$len자', style: TextStyle(color: reached ? _C.lime : _C.textSec, fontSize: 12)),
          if (!reached) ...[
            const SizedBox(width: 4),
            Text('(최소 ${minLength}자)', style: const TextStyle(color: _C.textMute, fontSize: 12)),
          ],
        ]),
      ]));
  }
}

// ════════════════════════════════════════════════════════════
// 선택형 질문 중앙 콘텐츠 (_QuestionCenter)
// ════════════════════════════════════════════════════════════
class _QuestionCenter extends StatelessWidget {
  final _Q question;
  final Color partColor;
  final String? answered;
  final void Function(String) onSelect;

  const _QuestionCenter({
    super.key,
    required this.question,
    required this.partColor,
    required this.answered,
    required this.onSelect,
  });

  static const _labels = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final opts = question.options.where((o) => o.isNotEmpty).toList();
    final isScenario = question.type == _QType.scenario;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 80),   // 아래 여백 크게 추가 (오류 방지)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: partColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: partColor.withValues(alpha: 0.2))),
            child: Text(question.dimension,
                style: TextStyle(color: partColor, fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(height: 14),

          if (isScenario && question.scenarioText != null) ...[
            _ScenarioBanner(
              emoji: question.emoji,
              text: question.scenarioText!,
              color: partColor),
            const SizedBox(height: 20),
          ],

          Text(question.text,
              style: const TextStyle(
                color: _C.textPri,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.5)),
          const SizedBox(height: 36),

          // 선택지 카드들
          ...List.generate(opts.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChoiceCard(
              key: ValueKey('${question.id}_$i'),
              label: _labels[i],
              text: opts[i],
              selected: answered == _labels[i],
              partColor: partColor,
              onTap: () => onSelect(_labels[i]),
            ),
          )),

          const SizedBox(height: 100), // 안전 여백
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 왼쪽 패널
// ════════════════════════════════════════════════════════════
class _QuestionLeftPanel extends StatelessWidget {
  final Color partColor;
  final String phaseLabel;
  final List<String> phaseSteps;
  final int currentPhaseIndex;
  final int currentStep;
  final int totalSteps;

  const _QuestionLeftPanel({
    required this.partColor,
    required this.phaseLabel,
    required this.phaseSteps,
    required this.currentPhaseIndex,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(32, 32, 24, 32),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _C.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('현재 단계',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _C.textMute, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: partColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: partColor.withValues(alpha: 0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: partColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(phaseLabel,
                style: TextStyle(color: partColor, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        const SizedBox(height: 28),
        ...List.generate(phaseSteps.length, (i) {
          final isDone = i < currentPhaseIndex;
          final isCurrent = i == currentPhaseIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: isDone || isCurrent ? partColor : _C.border,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [BoxShadow(color: partColor.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
                      : null)),
              const SizedBox(width: 10),
              Text(phaseSteps[i], style: TextStyle(
                fontSize: 12,
                color: isCurrent ? partColor : isDone ? _C.textSec : _C.textMute,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400)),
            ]));
        }),
        const SizedBox(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('전체 진행률',
              style: TextStyle(fontSize: 10, color: _C.textMute, fontWeight: FontWeight.w600)),
          Text('$currentStep / $totalSteps',
              style: TextStyle(fontSize: 10, color: partColor, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            minHeight: 3,
            backgroundColor: _C.border,
            valueColor: AlwaysStoppedAnimation(partColor))),
      ]));
  }
}

// ════════════════════════════════════════════════════════════
// 오른쪽 패널
// ════════════════════════════════════════════════════════════
class _QuestionRightPanel extends StatelessWidget {
  final _Q question;

  const _QuestionRightPanel({required this.question});

  static const _hints = <String, List<String>>{
    '진입 방식': ['시각 탐색형', '텍스트 분석형', '실험 행동형', '사회 의존형'],
    'VARK 시각형': ['요약 시각형', '순차 시각형', '선택 시각형', '실습 병행형'],
    'VARK 읽기형': ['전체 우선형', '깊이 탐구형', '병렬 정리형', '사회 확인형'],
    'Kolb 행동형': ['검색 해결형', '원점 회귀형', '우회 실용형', '구조 분석형'],
    'VARK 청각형': ['정밀 질문형', '맥락 공유형', '즉흥 청취형', '사전 탐색형'],
    '마감 압박 대응': ['핵심 집중형', '참조 의존형', '전략 탐색형', '사회 협력형'],
    '오개념 처리': ['반복 학습형', '실험 탐구형', '독립 탐색형', '실용 진행형'],
    '메타인지': ['기준 분석형', '비교 학습형', '직접 소통형', '자기 수용형'],
    '협업 스타일': ['독립 완수형', '협력 지향형', '범위 조정형', '사례 참조형'],
    'VARK 유형': ['시각형', '청각형', '행동형', '읽기형'],
    '집중 패턴': ['분산 집중형', '장기 몰입형', '유동 집중형', '틈새 학습형'],
    '복습 방식': ['요약 정리형', '반복 시청형', '실습 검증형', '설명 학습형'],
    '난이도 대응': ['기초 보완형', '지속 노출형', '선택 질문형', '단계 분리형'],
    '동기 유형': ['결과 지향형', '이해 추구형', '인정 반응형', '진척 동기형'],
    '이탈 위험 인자': ['난이도 이탈', '목적 이탈', '루틴 이탈', '고립 이탈', '흥미 이탈'],
    '성공 패턴': ['논리 기반형', '언어 기반형', '감각 기반형', '실무 기반형', '중립형'],
    'VARK 교차검증': ['시각형', '청각형', '행동형', '읽기형'],
    '집중 패턴 교차검증': ['단기 분산형', '장기 몰입형', '유동형', '틈새형'],
    '난이도 대응 교차검증': ['텍스트 복귀형', '영상 탐색형', '직관 실험형', '사회 확인형'],
    '성공 요인 분석': [],
  };

  static const _labels = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final hints = _hints[question.dimension] ?? [];
    final opts = question.options.where((o) => o.isNotEmpty).toList();
    final partColor = _kPhaseColor[question.phase] ?? _C.lime;

    if (question.type == _QType.text) {
      return Container(
        width: 220,
        padding: const EdgeInsets.fromLTRB(24, 32, 32, 32),
        decoration: const BoxDecoration(border: Border(left: BorderSide(color: _C.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.lavender.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _C.lavMid, borderRadius: BorderRadius.circular(20)),
                child: const Text('분석 항목',
                    style: TextStyle(color: _C.lavender, fontSize: 9, fontWeight: FontWeight.w700))),
              const SizedBox(height: 10),
              const Text('성공 요인 분석',
                  style: TextStyle(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const _AnalysisRow('흥미', '재미 vs 의무'),
              const _AnalysisRow('방법', '학습 방식'),
              const _AnalysisRow('환경', '외부 요인'),
              const _AnalysisRow('특성', '분야 성향'),
            ])),
        ]));
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(24, 32, 32, 32),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: _C.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _C.limeDark, borderRadius: BorderRadius.circular(20)),
              child: const Text('AI 분석 포인트',
                  style: TextStyle(color: _C.lime, fontSize: 9, fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            if (hints.isNotEmpty)
              ...List.generate(
                hints.length > opts.length ? opts.length : hints.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 20, height: 20, alignment: Alignment.center,
                      decoration: BoxDecoration(color: _C.surface2, borderRadius: BorderRadius.circular(5)),
                      child: Text(_labels[i],
                          style: const TextStyle(color: _C.textMute, fontSize: 10, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(hints[i],
                        style: const TextStyle(color: _C.textSec, fontSize: 11, height: 1.4))),
                  ])))
            else
              const Text('응답을 선택해주세요',
                  style: TextStyle(color: _C.textMute, fontSize: 12)),
          ])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('측정 항목',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _C.textMute, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(question.dimension,
                style: TextStyle(color: partColor, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('선택 내용과 응답 시간이\n함께 분석됩니다.',
                style: TextStyle(color: _C.textMute, fontSize: 11, height: 1.5)),
          ])),
      ]));
  }
}

class _AnalysisRow extends StatelessWidget {
  final String label;
  final String value;
  const _AnalysisRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 36, child: Text(label, style: const TextStyle(color: _C.textMute, fontSize: 10))),
        Expanded(child: Text(value, style: const TextStyle(color: _C.textSec, fontSize: 10))),
      ]));
  }
}

// ════════════════════════════════════════════════════════════
// 시나리오 배너
// ════════════════════════════════════════════════════════════
class _ScenarioBanner extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;

  const _ScenarioBanner({
    required this.emoji,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Text('상황',
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text(text,
                  style: const TextStyle(
                      color: _C.textSec,
                      fontSize: 15,
                      height: 1.65)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 선택지 카드 - 세로 중앙 정렬 버전
// ════════════════════════════════════════════════════════════
class _ChoiceCard extends StatelessWidget {
  final String label, text;
  final bool selected;
  final Color partColor;
  final VoidCallback onTap;

  const _ChoiceCard({
    super.key,
    required this.label,
    required this.text,
    required this.selected,
    required this.partColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // vertical padding 증가
        decoration: BoxDecoration(
          color: selected 
              ? partColor.withValues(alpha: 0.12) 
              : _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? partColor : _C.border,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,   // ← 여기서 중앙 정렬
          children: [
            // 레이블
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? partColor : _C.surface2,
                shape: BoxShape.circle,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? _C.bg : _C.textSec,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 18),

            // 텍스트 - 중앙 정렬
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: selected ? _C.textPri : const Color.fromARGB(255, 218, 218, 218),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                softWrap: true,
              ),
            ),

            // 체크 아이콘
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: partColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _C.bg,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 학습 이력 카드
// ════════════════════════════════════════════════════════════
class _HistoryCard extends StatefulWidget {
  final TextEditingController subjectCtrl;
  final String? reason;
  final String? difficulty;
  final ValueChanged<String?> onReasonChanged;
  final ValueChanged<String?> onDifficultyChanged;

  const _HistoryCard({
    super.key,
    required this.subjectCtrl,
    required this.reason,
    required this.difficulty,
    required this.onReasonChanged,
    required this.onDifficultyChanged,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  static const _reasons = [
    '선생님 설명이 명확해서',
    '시각 자료나 도표가 많아서',
    '직접 실습해볼 수 있어서',
    '반복 연습 기회가 충분해서',
  ];

  static const _difficulties = [
    '일방적 강의만 있고 상호작용 없음',
    '시각 자료 없이 텍스트만 있음',
    '이론만 있고 실습이 없음',
    '너무 빠른 속도로 진행',
  ];

  @override
  void initState() {
    super.initState();
    widget.subjectCtrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final hasSubject = widget.subjectCtrl.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.amberDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.amber.withValues(alpha: 0.25)),
            ),
            child: const Row(children: [
              Text('📚', style: TextStyle(fontSize: 26)),
              SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('학습 이력',
                    style: TextStyle(
                        color: _C.textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('과거 경험으로 학습 패턴을 더 정확히 분석합니다',
                    style: TextStyle(
                        color: _C.textSec, fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 28),

          const Text('가장 잘 이해됐던 과목이나 분야는?',
              style: TextStyle(
                  color: _C.textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasSubject ? _C.amber.withValues(alpha: 0.6) : _C.border,
                width: hasSubject ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: widget.subjectCtrl,
              style: const TextStyle(color: _C.textPri, fontSize: 14),
              decoration: const InputDecoration(
                hintText: '예) 수학, 생물, 프로그래밍, 디자인...',
                hintStyle: TextStyle(color: _C.textMute, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text('잘 이해됐던 이유는?',
              style: TextStyle(
                  color: _C.textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...List.generate(_reasons.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChoiceCard(
              label: String.fromCharCode(65 + i),
              text: _reasons[i],
              selected: widget.reason == _reasons[i],
              partColor: _C.amber,
              onTap: () => widget.onReasonChanged(_reasons[i]),
            ),
          )),
          const SizedBox(height: 24),

          const Text('가장 힘들었던 학습 방식은?',
              style: TextStyle(
                  color: _C.textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...List.generate(_difficulties.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChoiceCard(
              label: String.fromCharCode(65 + i),
              text: _difficulties[i],
              selected: widget.difficulty == _difficulties[i],
              partColor: _C.amber,
              onTap: () => widget.onDifficultyChanged(_difficulties[i]),
            ),
          )),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 분석 중 화면
// ════════════════════════════════════════════════════════════
class _AnalyzingScreen extends StatefulWidget {
  const _AnalyzingScreen();

  @override
  State<_AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<_AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _msgIdx = 0;

  static const _msgs = [
    '글쓰기 패턴을 분석하고 있어요',
    '응답 시간 데이터를 처리하는 중이에요',
    '시나리오 선택 패턴을 분석 중이에요',
    '교차 검증으로 신뢰도를 높이고 있어요',
    'VARK · Felder · Kolb 모델 적용 중',
    '이탈 위험 인자를 식별하고 있어요',
    '맞춤 학습 전략을 수립하는 중이에요',
    '거의 다 됐어요 ✨',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return false;
      setState(() => _msgIdx = (_msgIdx + 1) % _msgs.length);
      return true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: _C.limeDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _C.lime.withValues(alpha: 0.3)),
              ),
              child: const Center(
                child: Text('🧠', style: TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 28),
            const Text('학습 성향 분석 중',
                style: TextStyle(
                    color: _C.textPri,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('시나리오 · 응답시간 · 글쓰기 패턴 교차 분석',
                style: TextStyle(color: _C.textSec, fontSize: 12)),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(_msgs[_msgIdx],
                  key: ValueKey(_msgIdx),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.lime, fontSize: 13)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: _C.surface2,
                valueColor: const AlwaysStoppedAnimation(_C.lime),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 14),
            const Text('최대 30초 소요될 수 있어요',
                style: TextStyle(color: _C.textMute, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}