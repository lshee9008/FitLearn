import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/provider/auth_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class ProfessorHomePage extends ConsumerStatefulWidget {
  const ProfessorHomePage({super.key});

  @override
  ConsumerState<ProfessorHomePage> createState() => _ProfessorHomePageState();
}

class _ProfessorHomePageState extends ConsumerState<ProfessorHomePage> {
  List<dynamic> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final rooms = await ApiService().getProfessorRooms(user.userId);
      setState(() { _rooms = rooms; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _createRoom() async {
    final user = ref.read(authNotifierProvider);
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CreateRoomDialog(),
    );
    if (result == null) return;

    try {
      await ApiService().createRoom(
        professorUid: user.userId,
        subject: result['subject']!,
        description: result['description'] ?? '',
      );
      _loadRooms();
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('방 생성 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRooms,
          color: AppColors.primaryLight,
          backgroundColor: AppColors.bgCard,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(user),
                    const SizedBox(height: 28),
                    _buildStats(),
                    const SizedBox(height: 28),
                    SectionTitle(
                      title: '내 강의 방',
                      subtitle: '${_rooms.length}개',
                      trailing: GestureDetector(
                        onTap: _createRoom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text('방 만들기', style: TextStyle(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                            )),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                )),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryLight),
                ))
              else if (_rooms.isEmpty)
                const SliverFillRemaining(child: _EmptyRooms())
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RoomCard(
                          room: _rooms[i] as Map<String, dynamic>,
                          onDelete: _loadRooms,
                        ),
                      ),
                      childCount: _rooms.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile? user) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${user?.name ?? ''} 교수님 👋', style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 14,
        )),
        const SizedBox(height: 4),
        const Text('강의 관리 대시보드', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800,
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
    ]);
  }

  Widget _buildStats() {
    final totalStudents = _rooms.fold<int>(0, (s, r) => s + ((r['student_count'] as int?) ?? 0));
    return Row(children: [
      Expanded(child: _StatCard(label: '강의 방', value: '${_rooms.length}', icon: Icons.meeting_room_rounded, color: AppColors.primary)),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(label: '전체 학생', value: '$totalStudents', icon: Icons.people_rounded, color: AppColors.secondary)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(children: [
        Container(
          width: 44, height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800,
          )),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ]),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onDelete;

  const _RoomCard({required this.room, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/professor/room/${room['room_id']}'),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(room['subject'] as String? ?? '', style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700,
            ))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(room['room_code'] as String? ?? '', style: const TextStyle(
                color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w700,
                letterSpacing: 2,
              )),
            ),
          ]),
          if ((room['description'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(room['description'] as String, style: const TextStyle(
              color: AppColors.textMuted, fontSize: 13,
            )),
          ],
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.people_outline_rounded, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 4),
            Text('${room['student_count'] ?? 0}명', style: const TextStyle(
              color: AppColors.textMuted, fontSize: 13,
            )),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 13),
          ]),
        ]),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms();

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🏫', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('아직 강의 방이 없습니다', style: TextStyle(
        color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
      )),
      const SizedBox(height: 8),
      const Text('상단 "방 만들기" 버튼으로 강의를 시작하세요', style: TextStyle(
        color: AppColors.textMuted, fontSize: 14,
      )),
    ]));
  }
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('강의 방 만들기', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 20),
          const Text('과목명', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _subjectCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: '예: 파이썬 프로그래밍 기초'),
          ),
          const SizedBox(height: 16),
          const Text('설명 (선택)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: '강의 설명을 입력하세요'),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                if (_subjectCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(context, {
                    'subject': _subjectCtrl.text.trim(),
                    'description': _descCtrl.text.trim(),
                  });
                }
              },
              child: const Text('만들기'),
            )),
          ]),
        ]),
      ),
    );
  }
}
