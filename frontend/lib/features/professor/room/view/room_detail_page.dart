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
    _tabs = TabController(length: 4, vsync: this);
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
            Tab(text: '공지'),
            Tab(text: '학생'),
            Tab(text: '설정'),
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
              children: [
                _buildLectures(),
                _buildNotices(),
                _buildStudents(),
                _buildSettings(),
              ],
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
        final order = lec['order_index'] as int? ?? (i + 1);
        final hasVideo = (lec['video_url'] as String? ?? '').trim().isNotEmpty;
        final hasMaterial = (lec['original_file_url'] as String? ?? '').trim().isNotEmpty ||
            (lec['material_url'] as String? ?? '').trim().isNotEmpty;
        final isPlaceholder = lec['is_placeholder'] as bool? ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '$order강',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isPlaceholder)
                          const Text(
                            '자료 연결 대기',
                            style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      icon: hasVideo ? Icons.ondemand_video_rounded : Icons.videocam_off_rounded,
                      label: hasVideo ? '영상 연결됨' : '영상 없음',
                      color: hasVideo ? AppColors.primaryLight : AppColors.textMuted,
                    ),
                    _MetaPill(
                      icon: hasMaterial ? Icons.attach_file_rounded : Icons.note_add_outlined,
                      label: hasMaterial ? '자료 연결됨' : '자료 없음',
                      color: hasMaterial ? AppColors.secondary : AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
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

  // ── 추가 기능 (더미 혹은 외부 이동) ──────────────────────────────────
  
  Widget _buildNotices() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.campaign_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('공지사항 관리', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('추가 기능 페이지에서 구현됩니다 (MVP)', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공지사항 작성 화면으로 이동 (예정)')));
            },
            child: const Text('공지사항 쓰기'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    if (_room == null) return const SizedBox.shrink();
    
    final ctrlSynopsis = TextEditingController(text: _room!['synopsis'] ?? '');
    final ctrlConcepts = TextEditingController(text: ((_room!['core_concepts'] as List<dynamic>?) ?? []).join(', '));
    final ctrlYoutube = TextEditingController(text: _room!['youtube_url'] ?? '');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('강의실 설정', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            const Text('강의 줄거리 / 목표', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrlSynopsis,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(filled: true, fillColor: AppColors.bg),
            ),
            const SizedBox(height: 16),
            const Text('핵심 개념 (쉼표 구분) - AI 퀴즈 자동 생성에 사용됨', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrlConcepts,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(filled: true, fillColor: AppColors.bg),
            ),
            const SizedBox(height: 16),
            const Text('YouTube URL (온라인 강의 시)', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrlYoutube,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(filled: true, fillColor: AppColors.bg),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                onPressed: () async {
                  final concepts = ctrlConcepts.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  try {
                    await ApiService().updateRoomMeta(widget.roomId, {
                      'synopsis': ctrlSynopsis.text.trim(),
                      'core_concepts': concepts,
                      'youtube_url': ctrlYoutube.text.trim(),
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('설정이 저장되었습니다.')));
                    _load();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
                  }
                },
                child: const Text('변경사항 저장 및 AI 퀴즈 재생성', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
