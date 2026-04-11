import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';

// ── 컬러 ─────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFF0E0E11);
  static const surface  = Color(0xFF13131A);
  static const surface2 = Color(0xFF1A1A24);
  static const border   = Color(0xFF1E1E2A);
  static const lime     = Color(0xFFC8F135);
  static const limeDark = Color(0xFF1A2400);
  static const lavender = Color(0xFFA78BFA);
  static const lavMid   = Color(0xFF1E1830);
  static const coral    = Color(0xFFFB7185);
  static const mint     = Color(0xFF34D399);
  static const amber    = Color(0xFFFBBF24);
  static const textPri  = Color(0xFFF0F0F4);
  static const textSec  = Color(0xFF8888A0);
  static const textMute = Color(0xFF4A4A5A);
}

// ══════════════════════════════════════════════════════════════════
// CourseDetailPage
// ══════════════════════════════════════════════════════════════════
class CourseDetailPage extends ConsumerStatefulWidget {
  final String courseId;
  const CourseDetailPage({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends ConsumerState<CourseDetailPage> {
  Map<String, dynamic>? _course;
  bool _loading = true;
  bool _paying = false;
  bool _enrolled = false;
  String? _enrolledRoomId;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .get();
      if (doc.exists) {
        setState(() {
          _course = {'id': doc.id, ...doc.data()!};
        });
      } else {
        // 더미 데이터 폴백
        setState(() {
          _course = _dummyCourses[widget.courseId] ?? _dummyCourses.values.first;
        });
      }
    } catch (_) {
      setState(() {
        _course = _dummyCourses[widget.courseId] ?? _dummyCourses.values.first;
      });
    }

    // 이미 등록 여부 확인
    final profile = ref.read(authNotifierProvider);
    if (profile != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('enrollments')
            .where('userId', isEqualTo: profile.userId)
            .where('courseId', isEqualTo: widget.courseId)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          setState(() {
            _enrolled = true;
            _enrolledRoomId = snap.docs.first.data()['roomId'] as String?;
          });
        }
      } catch (_) {}
    }

    setState(() => _loading = false);
  }

  Future<void> _pay() async {
    final profile = ref.read(authNotifierProvider);
    if (profile == null) {
      context.push('/auth');
      return;
    }
    setState(() => _paying = true);
    try {
      final roomId = _course?['roomId'] as String? ?? widget.courseId;
      await FirebaseFirestore.instance.collection('enrollments').add({
        'userId': profile.userId,
        'courseId': widget.courseId,
        'roomId': roomId,
        'paidAt': FieldValue.serverTimestamp(),
        'fitlearnActivated': true,
      });
      setState(() {
        _enrolled = true;
        _enrolledRoomId = roomId;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('결제 오류: $e',
                style: const TextStyle(color: _C.textPri)),
            backgroundColor: _C.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _C.bg,
        body: Center(
          child: CircularProgressIndicator(color: _C.lime),
        ),
      );
    }

    final course = _course ?? {};
    final title = course['title'] as String? ?? '강의';
    final instructor = course['instructor'] as String? ?? '강사';
    final description = course['description'] as String? ?? '';
    final price = course['price'] as int? ?? 0;
    final tags = (course['tags'] as List?)?.cast<String>() ?? [];
    final curriculum = (course['curriculum'] as List?)?.cast<String>() ??
        ['모듈 1: 기초 개념', '모듈 2: 심화 학습', '모듈 3: 실습 프로젝트'];

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── 메인 콘텐츠 ─────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더 바
                    _buildTopBar(context),
                    // 썸네일
                    _buildThumbnail(course),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 태그
                          if (tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              children: tags
                                  .map((t) => _Tag(label: t))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // 제목
                          Text(title,
                              style: const TextStyle(
                                  color: _C.textPri,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          // 강사
                          Row(children: [
                            const Icon(Icons.person_outline_rounded,
                                color: _C.textSec, size: 16),
                            const SizedBox(width: 6),
                            Text(instructor,
                                style: const TextStyle(
                                    color: _C.textSec, fontSize: 14)),
                          ]),
                          const SizedBox(height: 24),
                          // 설명
                          _SectionTitle(title: '강의 소개'),
                          const SizedBox(height: 12),
                          Text(description.isEmpty
                              ? '이 강의는 학습자의 이해도를 높이기 위해 설계되었습니다. FitLearn AI가 여러분의 학습 유형에 맞게 교안을 재가공하여 최적의 학습 경험을 제공합니다.'
                              : description,
                              style: const TextStyle(
                                  color: _C.textSec,
                                  fontSize: 14,
                                  height: 1.7)),
                          const SizedBox(height: 32),
                          // 커리큘럼
                          _SectionTitle(title: '커리큘럼'),
                          const SizedBox(height: 12),
                          _CurriculumList(items: curriculum),
                          const SizedBox(height: 32),
                          // FitLearn 특징
                          _FitLearnFeatureCard(),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── 하단 고정 바 ────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomBar(
              price: price,
              enrolled: _enrolled,
              paying: _paying,
              onPay: _pay,
              onEnter: () {
                if (_enrolledRoomId != null) {
                  context.go('/student/home');
                } else {
                  context.go('/welcome');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.go('/'),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _C.lime,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome_mosaic_rounded,
                  color: _C.limeDark, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('FitLearn',
                style: TextStyle(
                    color: _C.textPri,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded,
              color: _C.textSec, size: 16),
          label: const Text('목록으로',
              style: TextStyle(color: _C.textSec, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildThumbnail(Map<String, dynamic> course) {
    final idx = (course['id']?.hashCode ?? 0) % _gradients.length;
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: _gradients[idx.abs()],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(_icons[idx.abs() % _icons.length],
            color: Colors.white.withValues(alpha: 0.3), size: 80),
      ),
    );
  }
}

// ── 더미 데이터 ──────────────────────────────────────────────────
const _dummyCourses = <String, Map<String, dynamic>>{
  'course-001': {
    'id': 'course-001',
    'title': 'Flutter & Dart 완전 정복',
    'instructor': '김개발',
    'description': 'Flutter와 Dart를 처음부터 끝까지 배우는 실전 강의입니다. 기초 문법부터 상태 관리, 배포까지 모든 것을 다룹니다.',
    'price': 89000,
    'tags': ['Flutter', 'Dart', '모바일'],
    'roomId': 'room-001',
    'curriculum': [
      '모듈 1: Dart 기초 문법',
      '모듈 2: Flutter 위젯 시스템',
      '모듈 3: 상태 관리 (Riverpod)',
      '모듈 4: Firebase 연동',
      '모듈 5: 앱 배포',
    ],
  },
  'course-002': {
    'id': 'course-002',
    'title': 'Python AI 엔지니어링',
    'instructor': '이파이썬',
    'description': 'LangChain과 Claude API를 활용한 AI 애플리케이션 개발을 배웁니다.',
    'price': 120000,
    'tags': ['Python', 'AI', 'LangChain'],
    'roomId': 'room-002',
    'curriculum': [
      '모듈 1: Python 심화',
      '모듈 2: LangChain 기초',
      '모듈 3: Claude API 연동',
      '모듈 4: RAG 파이프라인',
      '모듈 5: 프로덕션 배포',
    ],
  },
  'course-003': {
    'id': 'course-003',
    'title': 'UI/UX 디자인 마스터',
    'instructor': '박디자인',
    'description': 'Figma부터 실제 구현까지, UI/UX 디자인의 모든 것을 배웁니다.',
    'price': 75000,
    'tags': ['Figma', 'UI/UX', '디자인'],
    'roomId': 'room-003',
    'curriculum': [
      '모듈 1: 디자인 원칙',
      '모듈 2: Figma 마스터',
      '모듈 3: 프로토타이핑',
      '모듈 4: 사용자 리서치',
      '모듈 5: 포트폴리오 제작',
    ],
  },
};

final _gradients = [
  const LinearGradient(
    colors: [Color(0xFF1A2400), Color(0xFF2D4000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  const LinearGradient(
    colors: [Color(0xFF1E1830), Color(0xFF2D2050)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  const LinearGradient(
    colors: [Color(0xFF1A0A14), Color(0xFF2D1020)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
];

const _icons = [
  Icons.code_rounded,
  Icons.psychology_rounded,
  Icons.brush_rounded,
];

// ── 하단 고정 바 ─────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int price;
  final bool enrolled;
  final bool paying;
  final VoidCallback onPay;
  final VoidCallback onEnter;

  const _BottomBar({
    required this.price,
    required this.enrolled,
    required this.paying,
    required this.onPay,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _C.surface,
        border: const Border(top: BorderSide(color: _C.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(children: [
            // 가격
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('수강료',
                  style: TextStyle(color: _C.textMute, fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                enrolled ? '수강 중' : '₩${_formatPrice(price)}',
                style: TextStyle(
                    color: enrolled ? _C.mint : _C.textPri,
                    fontSize: 20,
                    fontWeight: FontWeight.w900),
              ),
            ]),
            const Spacer(),
            // 버튼
            if (!enrolled) ...[
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: paying ? null : onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.lime,
                    foregroundColor: _C.limeDark,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: paying
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _C.limeDark))
                      : const Text('결제하기',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onEnter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.lavender,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('FitLearn으로 학습하기',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── 섹션 제목 ─────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            color: _C.textPri,
            fontSize: 18,
            fontWeight: FontWeight.w800));
  }
}

// ── 커리큘럼 리스트 ───────────────────────────────────────────────
class _CurriculumList extends StatelessWidget {
  final List<String> items;
  const _CurriculumList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final isLast = i == items.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _C.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: _C.lime,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 14),
              Text(items[i],
                  style: const TextStyle(
                      color: _C.textSec, fontSize: 14)),
            ]),
          );
        }),
      ),
    );
  }
}

// ── FitLearn 특징 카드 ────────────────────────────────────────────
class _FitLearnFeatureCard extends StatelessWidget {
  const _FitLearnFeatureCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.lavMid,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.lavender.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded,
              color: _C.lavender, size: 20),
          const SizedBox(width: 8),
          const Text('FitLearn AI 맞춤 학습',
              style: TextStyle(
                  color: _C.lavender,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        const Text(
          '수강 등록 후 FitLearn AI가 여러분의 학습 유형을 진단합니다. '
          '요약형·상세형·예시형 중 가장 잘 맞는 방식으로 교안을 재가공하여 '
          '학습 효율을 극대화합니다.',
          style: TextStyle(color: _C.textSec, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 8, children: const [
          _FeaturePill(icon: Icons.psychology_rounded, label: 'AI 학습 진단'),
          _FeaturePill(icon: Icons.description_rounded, label: '교안 맞춤 재가공'),
          _FeaturePill(icon: Icons.speed_rounded, label: '3배 학습 속도'),
        ]),
      ]),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _C.lavender.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.lavender.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _C.lavender, size: 13),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: _C.lavender,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── 태그 ─────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _C.lime.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _C.lime.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: _C.lime, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
