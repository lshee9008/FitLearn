import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

class RoomDetailPage extends ConsumerStatefulWidget {
  final String roomId;
  const RoomDetailPage({super.key, required this.roomId});

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _room;
  List<dynamic> _lectures = [];
  List<dynamic> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService().getRoom(widget.roomId),
        ApiService().getRoomLectures(widget.roomId),
        ApiService().getRoomStudents(widget.roomId),
      ]);
      setState(() {
        _room = results[0] as Map<String, dynamic>;
        _lectures = results[1] as List<dynamic>;
        _students = results[2] as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_room?['subject'] as String? ?? '강의 방'),
        backgroundColor: AppColors.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_rounded, color: AppColors.textSecondary),
            onPressed: () => context.push('/professor/dashboard/${widget.roomId}'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '교안'),
            Tab(text: '학생'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/professor/lecture/${widget.roomId}/upload'),
        backgroundColor: AppColors.primary,
        label: const Text('교안 업로드', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : TabBarView(
              controller: _tabs,
              children: [_buildLectures(), _buildStudents()],
            ),
    );
  }

  Widget _buildLectures() {
    if (_lectures.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('📄', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('아직 교안이 없습니다', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
        SizedBox(height: 4),
        Text('교안 업로드 버튼을 눌러 시작하세요', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _lectures.length,
      itemBuilder: (_, i) {
        final lec = _lectures[i] as Map<String, dynamic>;
        final confirmed = lec['confirmed'] as bool? ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Row(children: [
              Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (confirmed ? AppColors.accent : AppColors.gold).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  confirmed ? Icons.check_circle_rounded : Icons.pending_rounded,
                  color: confirmed ? AppColors.accent : AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lec['title'] as String? ?? '', style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 3),
                Text(
                  confirmed ? '학생 교안 활성화됨' : '검토 대기 중',
                  style: TextStyle(
                    color: confirmed ? AppColors.accent : AppColors.gold, fontSize: 12,
                  ),
                ),
              ])),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildStudents() {
    if (_room != null) {
      final code = _room!['room_code'] as String? ?? '';
      return Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('방 코드가 복사되었습니다')),
              );
            },
            child: AppCard(
              borderColor: AppColors.primaryLight.withValues(alpha: 0.3),
              child: Row(children: [
                const Text('방 코드', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const Spacer(),
                Text(code, style: const TextStyle(
                  color: AppColors.primaryLight, fontSize: 22,
                  fontWeight: FontWeight.w900, letterSpacing: 4,
                )),
                const SizedBox(width: 8),
                const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 18),
              ]),
            ),
          ),
        ),
        Expanded(child: _students.isEmpty
            ? const Center(child: Text('아직 입장한 학생이 없습니다', style: TextStyle(color: AppColors.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _students.length,
                itemBuilder: (_, i) {
                  final s = _students[i] as Map<String, dynamic>;
                  final style = s['primary_style'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Row(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: style != null
                              ? LearningStyleUtil.color(style).withValues(alpha: 0.2)
                              : AppColors.bgSurface,
                          child: Text(
                            (s['name'] as String? ?? '?').substring(0, 1),
                            style: TextStyle(
                              color: style != null ? LearningStyleUtil.color(style) : AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['name'] as String? ?? '', style: const TextStyle(
                            color: AppColors.textPrimary, fontWeight: FontWeight.w600,
                          )),
                          if (style != null)
                            Text('${LearningStyleUtil.emoji(style)} $style · ${s['social_type'] ?? ''} · ${s['cognitive_type'] ?? ''}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ])),
                        if (style != null)
                          TypeBadge(label: style, color: LearningStyleUtil.color(style)),
                      ]),
                    ),
                  );
                },
              )),
      ]);
    }
    return const SizedBox.shrink();
  }
}
