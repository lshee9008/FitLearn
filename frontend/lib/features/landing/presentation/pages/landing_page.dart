import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/demo_launcher.dart';
import '../../../../shared/widgets/fitlearn_logo.dart';
import '../../../../shared/widgets/fl_markdown.dart';
import '../../../../shared/widgets/fl_ui.dart';
import '../../../auth/provider/auth_provider.dart';

// ── 강의 모델 ─────────────────────────────────────────────────────
class CourseModel {
  final String id;
  final String title;
  final String description;
  final String instructor;
  final List<String> tags;
  final int lectureCount;
  final bool isDemo;

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.instructor,
    this.tags = const [],
    this.lectureCount = 0,
    this.isDemo = false,
  });

  factory CourseModel.fromJson(Map<String, dynamic> data) => CourseModel(
        id: data['id'] as String? ?? data['roomId'] as String? ?? '',
        title: (data['title'] as String?) ?? (data['subject'] as String?) ?? '',
        description: (data['description'] as String?) ?? (data['synopsis'] as String?) ?? '',
        instructor: (data['instructor'] as String?) ?? (data['professor_name'] as String?) ?? '',
        tags: List<String>.from(data['tags'] as List? ?? const []),
        lectureCount: (data['lecture_count'] as num?)?.toInt() ?? 0,
        isDemo: data['is_demo'] == true,
      );
}

enum _ServerState { checking, ready, waking }

// ══════════════════════════════════════════════════════════════════
// LandingPage
// ══════════════════════════════════════════════════════════════════
class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final _scroll = ScrollController();
  final _howKey = GlobalKey();
  final _coursesKey = GlobalKey();
  _ServerState _server = _ServerState.checking;
  late Future<List<CourseModel>> _courses;

  @override
  void initState() {
    super.initState();
    _wakeServer();
    _courses = _loadCourses();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 무료 서버 콜드스타트 대비 — 랜딩 진입과 동시에 서버를 깨운다.
  Future<void> _wakeServer() async {
    final quick = await ApiService().ping(timeout: const Duration(seconds: 4));
    if (!mounted) return;
    if (quick) return setState(() => _server = _ServerState.ready);
    setState(() => _server = _ServerState.waking);
    final ok = await ApiService().ping();
    if (!mounted) return;
    setState(() => _server = ok ? _ServerState.ready : _ServerState.waking);
    if (ok) setState(() { _courses = _loadCourses(); });
  }

  Future<List<CourseModel>> _loadCourses() async {
    final items = await ApiService().getCourses();
    return items
        .whereType<Map>()
        .map((e) => CourseModel.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);
    return Scaffold(
      backgroundColor: FL.bg,
      body: Column(children: [
        _NavBar(
          user: user,
          server: _server,
          onHow: () => _scrollTo(_howKey),
          onCourses: () => _scrollTo(_coursesKey),
          onDemo: () => launchDemo(context, ref, UserRole.student),
          onContinue: user == null
              ? null
              : () => context.go(user.role == UserRole.student ? '/student/home' : '/professor/home'),
          onLogin: () => context.push('/auth'),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: Column(children: [
              _Hero(
                onStudent: () => launchDemo(context, ref, UserRole.student),
                onProfessor: () => launchDemo(context, ref, UserRole.professor),
              ),
              _Section(key: _howKey, child: const _HowItWorks()),
              const _Section(child: _ForWhom()),
              _Section(
                key: _coursesKey,
                child: _CourseSection(
                  future: _courses,
                  onRetry: () => setState(() { _courses = _loadCourses(); }),
                  onTap: (c) => context.push('/course/${c.id}'),
                ),
              ),
              _FinalCta(onStart: () => launchDemo(context, ref, UserRole.student)),
              const _Footer(),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── 공통 레이아웃 ─────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w < 600 ? 16 : 32, vertical: w < 600 ? 48 : 80),
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: FL.maxContent), child: child),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? body;
  const _SectionTitle({required this.eyebrow, required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FLLabel(eyebrow, color: FL.lime),
      const SizedBox(height: 10),
      Text(title,
          style: TextStyle(
              color: FL.text,
              fontSize: narrow ? 26 : 34,
              fontWeight: FontWeight.w900,
              height: 1.3,
              letterSpacing: -1)),
      if (body != null) ...[
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(body!, style: const TextStyle(color: FL.textSec, fontSize: 16, height: 1.65)),
        ),
      ],
    ]);
  }
}

// ── 내비게이션 바 ─────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final UserProfile? user;
  final _ServerState server;
  final VoidCallback onHow;
  final VoidCallback onCourses;
  final VoidCallback onDemo;
  final VoidCallback? onContinue;
  final VoidCallback onLogin;

  const _NavBar({
    required this.user,
    required this.server,
    required this.onHow,
    required this.onCourses,
    required this.onDemo,
    required this.onContinue,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 760;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 32),
      decoration: BoxDecoration(
        color: FL.bg.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: FL.border)),
      ),
      child: Row(children: [
        const FitLearnLogo(height: 26),
        if (!compact) ...[
          const SizedBox(width: 36),
          _NavLink('작동 방식', onHow),
          _NavLink('강의 둘러보기', onCourses),
        ],
        const Spacer(),
        if (!compact) ...[_ServerPill(server: server), const SizedBox(width: 14)],
        if (onContinue != null)
          FLButton(
            compact ? '이어서' : '${user!.name}님, 이어서 학습',
            icon: Icons.play_arrow_rounded,
            onPressed: onContinue,
          )
        else ...[
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FLButton('로그인', kind: FLButtonKind.ghost, onPressed: onLogin),
            ),
          FLButton(compact ? '체험하기' : '무료로 체험하기', onPressed: onDemo),
        ],
      ]),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: FL.textSec),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );
}

class _ServerPill extends StatelessWidget {
  final _ServerState server;
  const _ServerPill({required this.server});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (server) {
      _ServerState.ready => ('AI 서버 준비됨', FL.mint),
      _ServerState.waking => ('AI 서버 깨우는 중…', FL.amber),
      _ServerState.checking => ('연결 확인 중', FL.textMute),
    };
    return Tooltip(
      message: '무료 서버라 한동안 접속이 없으면 잠들어요. 첫 접속은 최대 1분 걸릴 수 있어요.',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (server == _ServerState.ready)
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
        else
          FLPulseDot(color: color),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── 히어로 ───────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final VoidCallback onStudent;
  final VoidCallback onProfessor;
  const _Hero({required this.onStudent, required this.onProfessor});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 1024;
    final narrow = w < 600;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FLTag('AI 개인 맞춤 학습 엔진', icon: Icons.auto_awesome_rounded),
        const SizedBox(height: 22),
        Text.rich(
          const TextSpan(children: [
            TextSpan(text: '같은 교안,\n'),
            TextSpan(text: '나에게 맞는 설명으로.', style: TextStyle(color: FL.lime)),
          ]),
          style: TextStyle(
            color: FL.text,
            fontSize: narrow ? 38 : (w < 1240 ? 46 : 56),
            fontWeight: FontWeight.w900,
            height: 1.18,
            letterSpacing: narrow ? -1.4 : -2.0,
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'FitLearn은 1분 진단으로 학습 성향을 파악하고, 교수님이 올린 교안을 '
            '그림형·대화형·실습형 등 내게 맞는 방식으로 실시간 재구성합니다.',
            style: TextStyle(color: FL.textSec, fontSize: narrow ? 16 : 18, height: 1.65),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FLButton('학생으로 바로 체험', icon: Icons.school_rounded, large: true, onPressed: onStudent),
          FLButton('교수 대시보드 체험',
              icon: Icons.insights_rounded, large: true, kind: FLButtonKind.secondary, onPressed: onProfessor),
        ]),
        const SizedBox(height: 18),
        const Wrap(spacing: 18, runSpacing: 8, children: [
          _Check('회원가입 없이 바로'),
          _Check('1분 진단'),
          _Check('실시간 AI 재구성'),
        ]),
      ],
    );

    final showcase = const _StyleShowcase();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -0.6),
          radius: 1.2,
          colors: [Color(0xFF1A2108), FL.bg],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 32, vertical: narrow ? 48 : 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: FL.maxContent),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(flex: 5, child: copy),
                  const SizedBox(width: 56),
                  Expanded(flex: 6, child: showcase),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  copy,
                  const SizedBox(height: 48),
                  showcase,
                ]),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final String text;
  const _Check(this.text);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_rounded, size: 16, color: FL.lime),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: FL.textSec, fontSize: 13.5, fontWeight: FontWeight.w600)),
      ]);
}

/// 같은 개념(경사하강법)이 스타일별로 어떻게 달라지는지 보여주는 쇼케이스 (서버 호출 없음)
class _StyleShowcase extends StatefulWidget {
  const _StyleShowcase();

  @override
  State<_StyleShowcase> createState() => _StyleShowcaseState();
}

class _StyleShowcaseState extends State<_StyleShowcase> {
  static const _samples = <String, String>{
    '시각형': '''### 🗺️ 경사하강법 한눈에 보기

| 단계 | 하는 일 | 핵심 |
|---|---|---|
| ① 시작 | w, b를 임의로 정함 | 출발점 |
| ② 기울기 | 손실이 줄어드는 방향 계산 | 방향 |
| ③ 이동 | 학습률만큼 한 걸음 | **보폭 = α** |

> 🖼️ **그림으로 보기** — U자 골짜기를 공이 계단처럼 굴러 내려가 바닥(최소 손실)에 도착''',
    '청각형': '''### 🎧 산에서 내려오는 상상을 해볼까요?

> 🙋 눈을 가리고 산 정상에 서 있다면, 어떻게 내려갈까요?

발밑의 **경사가 가장 가파르게 내려가는 쪽**으로 한 걸음씩 가면 돼요. 이게 바로 경사하강법이에요. 한 걸음의 크기가 **학습률**이고요.

🔊 소리 내어 말해보기: "기울기 반대로, 학습률만큼, 반복!"''',
    '실습형': '''### 🎯 미션: 직접 w를 업데이트해보기

```python
w, lr = 0.0, 0.01
for step in range(3):
    grad = 2 * (w * 2 - 4) * 2   # 손실의 기울기
    w -= lr * grad
    print(step, round(w, 3))
```

✅ 확인: 출력되는 w가 점점 **2에 가까워지는지** 보세요.''',
    '요약형': '''### ⚡ TL;DR

- **경사하강법** — 손실이 줄어드는 방향으로 조금씩 이동
- **학습률(α)** — 한 번에 움직이는 보폭
- 너무 크면 발산, 너무 작으면 느림

**🔁 1분 복습** — 기울기의 (　　) 방향으로 이동한다 *(정답: 반대)*''',
  };

  String _active = '시각형';

  @override
  Widget build(BuildContext context) {
    final meta = StyleMeta.of(_active);
    return Container(
      decoration: BoxDecoration(
        color: FL.surface,
        borderRadius: BorderRadius.circular(FL.r20),
        border: Border.all(color: FL.border),
        boxShadow: [
          BoxShadow(color: meta.color.withValues(alpha: 0.10), blurRadius: 60, offset: const Offset(0, 20)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: FL.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.description_outlined, size: 15, color: FL.textMute),
              SizedBox(width: 6),
              Expanded(
                child: Text('원본 교안: 「2강. 선형회귀와 경사하강법」',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: FL.textMute, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final key in _samples.keys)
                _ShowcaseTab(
                  meta: StyleMeta.of(key),
                  selected: key == _active,
                  onTap: () => setState(() => _active = key),
                ),
            ]),
          ]),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous.map((w) => Opacity(opacity: 0, child: w)), if (current != null) current],
          ),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey(_active),
            constraints: const BoxConstraints(minHeight: 290),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: FLMarkdown(_samples[_active]!, scale: 0.92, accent: meta.color),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: meta.color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(FL.r20)),
            border: const Border(top: BorderSide(color: FL.border)),
          ),
          child: Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: meta.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${meta.key} 학습자용 — ${meta.tagline}',
                  style: TextStyle(color: meta.color, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ShowcaseTab extends StatelessWidget {
  final StyleMeta meta;
  final bool selected;
  final VoidCallback onTap;
  const _ShowcaseTab({required this.meta, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? meta.color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? meta.color : FL.border),
        ),
        child: Text('${meta.emoji} ${meta.key}',
            style: TextStyle(
              color: selected ? FL.text : FL.textSec,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            )),
      ),
    );
  }
}

// ── 작동 방식 ─────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.psychology_alt_rounded, FL.lime, '1분 성향 진단',
          '6가지 질문으로 시각·청각·읽기·실습 중 어떤 방식으로 배울 때 가장 잘 이해하는지 파악합니다. 정밀 진단(22문항)도 제공해요.'),
      (Icons.fact_check_rounded, FL.lavender, '교수님 핵심 포인트',
          '교수님이 교안을 올리면 AI가 핵심 포인트를 뽑고, 교수님이 직접 검토·확정합니다. 맞춤 교안은 이 포인트를 절대 빠뜨리지 않아요.'),
      (Icons.bolt_rounded, FL.sky, '실시간 맞춤 재구성',
          '같은 교안을 내 성향·집중 패턴·과목 수준에 맞춰 다시 씁니다. 글자가 써지는 걸 바로 보면서, 원본과 나란히 비교할 수 있어요.'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final cards = [
      for (var i = 0; i < steps.length; i++)
        _StepCard(index: i + 1, icon: steps[i].$1, color: steps[i].$2, title: steps[i].$3, body: steps[i].$4),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(
        eyebrow: 'HOW IT WORKS',
        title: '요약이 아니라, 재구성입니다',
        body: '단순 요약은 실습 코드와 교수님의 의도를 지워버립니다. FitLearn은 원본의 내용은 그대로 두고 전달 방식만 학습자에게 맞게 바꿉니다.',
      ),
      const SizedBox(height: 36),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ])
      else
        Column(children: [
          for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
        ]),
    ]);
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _StepCard({required this.index, required this.icon, required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return FLCard(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text('0$index',
              style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(color: FL.text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(color: FL.textSec, fontSize: 14.5, height: 1.65)),
      ]),
    );
  }
}

// ── 대상별 가치 ────────────────────────────────────────────────────

class _ForWhom extends StatelessWidget {
  const _ForWhom();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    const student = _AudienceCard(
      color: FL.lime,
      icon: Icons.school_rounded,
      who: '학생이라면',
      headline: '내가 이해하는 방식으로 다시 쓴 교안',
      points: [
        '6가지 설명 방식을 버튼 하나로 바꿔보기',
        '원본 교안과 맞춤 교안을 나란히 비교',
        '교안 근거로 답하는 AI 튜터에게 바로 질문',
        '과목 수준 퀴즈로 입문·중급·고급 난이도 조절',
      ],
    );
    const professor = _AudienceCard(
      color: FL.lavender,
      icon: Icons.insights_rounded,
      who: '교수님이라면',
      headline: '교안 한 번 올리면, 학생 수만큼의 교안',
      points: [
        'PDF·PPT·DOCX·HWP 업로드 → AI 핵심 포인트 자동 추출',
        '핵심 포인트를 검토·확정해 수업 의도를 지키기',
        '수강생 학습 성향 분포와 AI 수업 인사이트',
        '과목 수준 진단 퀴즈 자동 생성',
      ],
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(eyebrow: 'FOR EVERYONE', title: '학생도, 교수님도 편해집니다'),
      const SizedBox(height: 36),
      if (wide)
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: student),
          SizedBox(width: 16),
          Expanded(child: professor),
        ])
      else
        const Column(children: [student, SizedBox(height: 12), professor]),
    ]);
  }
}

class _AudienceCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String who;
  final String headline;
  final List<String> points;
  const _AudienceCard({
    required this.color,
    required this.icon,
    required this.who,
    required this.headline,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return FLCard(
      padding: const EdgeInsets.all(28),
      color: color.withValues(alpha: 0.04),
      borderColor: color.withValues(alpha: 0.2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(who, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        Text(headline,
            style: const TextStyle(color: FL.text, fontSize: 22, fontWeight: FontWeight.w800, height: 1.35)),
        const SizedBox(height: 20),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle_rounded, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(p, style: const TextStyle(color: FL.textSec, fontSize: 15, height: 1.5))),
            ]),
          ),
      ]),
    );
  }
}

// ── 강의 목록 ─────────────────────────────────────────────────────

class _CourseSection extends StatelessWidget {
  final Future<List<CourseModel>> future;
  final VoidCallback onRetry;
  final ValueChanged<CourseModel> onTap;
  const _CourseSection({required this.future, required this.onRetry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(eyebrow: 'COURSES', title: '지금 열려 있는 강의'),
      const SizedBox(height: 28),
      FutureBuilder<List<CourseModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _grid(context, List.generate(3, (_) => const FLSkeleton(height: 190, radius: 16)));
          }
          if (snap.hasError) {
            return FLCard(
              child: Row(children: [
                const Icon(Icons.cloud_off_rounded, color: FL.textMute),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('서버가 깨어나는 중이라 강의 목록을 아직 못 불러왔어요.',
                      style: TextStyle(color: FL.textSec)),
                ),
                FLButton('다시 불러오기', kind: FLButtonKind.secondary, onPressed: onRetry),
              ]),
            );
          }
          final courses = snap.data ?? const [];
          if (courses.isEmpty) {
            return const FLCard(
              child: Text('아직 공개된 강의가 없어요.', style: TextStyle(color: FL.textSec)),
            );
          }
          return _grid(context, [for (final c in courses) _CourseCard(course: c, onTap: () => onTap(c))]);
        },
      ),
    ]);
  }

  Widget _grid(BuildContext context, List<Widget> children) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1000 ? 3 : (w >= 640 ? 2 : 1);
    return LayoutBuilder(builder: (context, c) {
      final itemW = (c.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        for (final child in children) SizedBox(width: itemW, child: child),
      ]);
    });
  }
}

class _CourseCard extends StatefulWidget {
  final CourseModel course;
  final VoidCallback onTap;
  const _CourseCard({required this.course, required this.onTap});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final accent = c.title.contains('웹') ? FL.sky : (c.isDemo ? FL.lime : FL.lavender);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          padding: const EdgeInsets.all(22),
          constraints: const BoxConstraints(minHeight: 190),
          decoration: BoxDecoration(
            color: FL.surface,
            borderRadius: BorderRadius.circular(FL.r16),
            border: Border.all(color: _hover ? accent.withValues(alpha: 0.5) : FL.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(c.title.contains('웹') ? Icons.public_rounded : Icons.memory_rounded,
                    color: accent, size: 20),
              ),
              const Spacer(),
              if (c.isDemo) const FLTag('체험 가능', icon: Icons.bolt_rounded),
            ]),
            const SizedBox(height: 16),
            Text(c.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: FL.text, fontSize: 17, fontWeight: FontWeight.w800, height: 1.35)),
            const SizedBox(height: 8),
            Text(c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: FL.textSec, fontSize: 13.5, height: 1.55)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text(c.instructor,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: FL.textMute, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              if (c.lectureCount > 0)
                Text('강의 ${c.lectureCount}개',
                    style: const TextStyle(color: FL.textMute, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── 마지막 CTA / 푸터 ─────────────────────────────────────────────

class _FinalCta extends StatelessWidget {
  final VoidCallback onStart;
  const _FinalCta({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return _Section(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 48, vertical: narrow ? 40 : 56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [Color(0xFF1C2609), Color(0xFF16121F)]),
          border: Border.all(color: FL.lime.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text('지금 1분이면 내 교안이 생겨요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: FL.text, fontSize: narrow ? 24 : 32, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          const SizedBox(height: 12),
          const Text('로그인 없이 체험 계정이 바로 만들어지고, 이 브라우저에서 이어서 학습할 수 있어요.',
              textAlign: TextAlign.center, style: TextStyle(color: FL.textSec, fontSize: 15, height: 1.6)),
          const SizedBox(height: 26),
          FLButton('무료로 체험 시작', trailingIcon: Icons.arrow_forward_rounded, large: true, onPressed: onStart),
        ]),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: FL.border))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: FL.maxContent),
          child: const Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            spacing: 24,
            children: [
              FitLearnLogo(height: 20),
              Text('KIT 바이브코딩 공모전 출품작 · 팀 표리부동 (이승희 · 표제원)',
                  style: TextStyle(color: FL.textMute, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}
