import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<StudentHomePage> {
  final _codeCtrl = TextEditingController();
  Map<String, dynamic>? _room;
  List<dynamic> _lectures = [];
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = '6자리 방 코드를 입력해주세요.');
      return;
    }
    setState(() { _joining = true; _error = null; });
    try {
      final room = await ApiService().joinRoom(userId: user.userId, roomCode: code);
      final lectures = await ApiService().getRoomLectures(room['room_id'] as String);
      if (!mounted) return;
      setState(() { _room = room; _lectures = lectures; _joining = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '방을 찾을 수 없습니다. 코드를 확인해주세요.'; _joining = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(user),
                  const SizedBox(height: 32),
                  if (_room == null) ...[
                    _buildJoinCard(),
                    const SizedBox(height: 32),
                    _buildDiagnosisBanner(),
                  ] else ...[
                    _buildRoomCard(),
                    const SizedBox(height: 24),
                    SectionTitle(
                      title: '교안 목록',
                      subtitle: '${_lectures.length}개의 교안',
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              )),
            ),
            if (_room != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LectureCard(
                        lecture: _lectures[i] as Map<String, dynamic>,
                        roomId: _room!['room_id'] as String,
                        userId: user?.userId ?? '',
                      ),
                    ),
                    childCount: _lectures.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('안녕하세요, ${user?.name ?? ''}님 👋',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('오늘도 맞춤 학습을 시작해볼까요?', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800,
          )),
        ]),
        GestureDetector(
          onTap: () async {
            await ref.read(authNotifierProvider.notifier).logout();
            if (mounted) context.go('/');
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinCard() {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.meeting_room_rounded, color: AppColors.primaryLight),
          SizedBox(width: 8),
          Text('방 입장', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700,
          )),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _codeCtrl,
          style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: 'XXXXXX',
            hintStyle: TextStyle(color: AppColors.textMuted, letterSpacing: 4),
            counterText: '',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        GlowButton(text: '입장하기', loading: _joining, onTap: _joinRoom),
      ]),
    );
  }

  Widget _buildDiagnosisBanner() {
    return GestureDetector(
      onTap: () => context.push('/student/diagnosis'),
      child: GradientCard(
        colors: const [Color(0xFF4C1D95), Color(0xFF1E40AF)],
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('학습 성향 진단', style: TextStyle(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600,
            )),
            SizedBox(height: 6),
            Text('15문항으로 나의\n학습 유형을 파악하세요', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.3,
            )),
            SizedBox(height: 12),
            Row(children: [
              Text('진단 시작하기', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
            ]),
          ])),
          const Text('🧠', style: TextStyle(fontSize: 56)),
        ]),
      ),
    );
  }

  Widget _buildRoomCard() {
    return AppCard(
      borderColor: AppColors.primaryLight.withValues(alpha: 0.3),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.class_rounded, color: AppColors.primaryLight),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_room!['subject'] as String? ?? '', style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 2),
          Text('코드: ${_room!['room_code']}', style: const TextStyle(
            color: AppColors.textMuted, fontSize: 12,
          )),
        ])),
      ]),
    );
  }
}

class _LectureCard extends StatelessWidget {
  final Map<String, dynamic> lecture;
  final String roomId;
  final String userId;

  const _LectureCard({required this.lecture, required this.roomId, required this.userId});

  @override
  Widget build(BuildContext context) {
    final confirmed = lecture['confirmed'] as bool? ?? false;
    return GestureDetector(
      onTap: confirmed
          ? () => context.push('/student/lecture', extra: {
                'room_id': roomId,
                'lecture_id': lecture['lecture_id'],
                'user_id': userId,
                'title': lecture['title'],
              })
          : null,
      child: AppCard(
        child: Row(children: [
          Container(
            width: 44, height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: confirmed
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : AppColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              confirmed ? Icons.menu_book_rounded : Icons.lock_outline_rounded,
              color: confirmed ? AppColors.accent : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lecture['title'] as String? ?? '교안', style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 3),
            Text(confirmed ? '맞춤 교안 학습 가능' : '교수 검토 중', style: TextStyle(
              color: confirmed ? AppColors.accent : AppColors.textMuted, fontSize: 12,
            )),
          ])),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: confirmed ? AppColors.textSecondary : AppColors.border,
            size: 14,
          ),
        ]),
      ),
    );
  }
}
