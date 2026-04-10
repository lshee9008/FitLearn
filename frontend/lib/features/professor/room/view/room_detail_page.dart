import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/room_data_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _createNotice(Map<String, dynamic> room) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('공지 작성', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: '제목',
                  filled: true,
                  fillColor: AppColors.bg,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: '내용',
                  filled: true,
                  fillColor: AppColors.bg,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('등록'),
          ),
        ],
      ),
    );

    if (created != true) return;
    if (!mounted) return;

    try {
      await ApiService().createNotice(
        widget.roomId,
        room['professor_uid'] as String? ?? '',
        contentCtrl.text.trim(),
        title: titleCtrl.text.trim(),
      );
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공지 등록 오류: $e')),
      );
    }
  }

  Future<void> _deleteNotice(Map<String, dynamic> notice) async {
    try {
      await ApiService().deleteNotice(widget.roomId, notice['notice_id'] as String);
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공지 삭제 오류: $e')),
      );
    }
  }

  Future<void> _editLecture(Map<String, dynamic> lecture) async {
    final titleCtrl = TextEditingController(text: lecture['title'] as String? ?? '');
    final videoCtrl = TextEditingController(text: lecture['video_url'] as String? ?? '');
    final materialCtrl = TextEditingController(text: lecture['material_url'] as String? ?? '');
    final weekCtrl = TextEditingController(text: ((lecture['week_number'] as int?) ?? 0).toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('강의 항목 편집', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: '강의 제목', filled: true, fillColor: AppColors.bg),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weekCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: '주차', filled: true, fillColor: AppColors.bg),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: videoCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: '영상 링크', filled: true, fillColor: AppColors.bg),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: materialCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: '보조 자료 링크', filled: true, fillColor: AppColors.bg),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    try {
      await ApiService().updateLectureMeta(
        widget.roomId,
        lecture['lecture_id'] as String,
        {
          'title': titleCtrl.text.trim(),
          'week_number': int.tryParse(weekCtrl.text.trim()) ?? 0,
          'video_url': videoCtrl.text.trim(),
          'material_url': materialCtrl.text.trim(),
        },
      );
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('강의 수정 오류: $e')),
      );
    }
  }

  Future<void> _moveLecture(List<dynamic> lectures, int index, int delta) async {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= lectures.length) return;
    final reordered = [...lectures];
    final current = reordered.removeAt(index);
    reordered.insert(nextIndex, current);

    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < reordered.length; i++) {
      final lecture = reordered[i] as Map<String, dynamic>;
      items.add({
        'lecture_id': lecture['lecture_id'],
        'order_index': i + 1,
      });
    }

    try {
      await ApiService().reorderLectures(widget.roomId, items);
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('강의 정렬 오류: $e')),
      );
    }
  }

  Future<void> _deleteLecture(Map<String, dynamic> lecture) async {
    try {
      await ApiService().deleteLecture(widget.roomId, lecture['lecture_id'] as String);
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('강의 삭제 오류: $e')),
      );
    }
  }

  Future<void> _reviewApplication(Map<String, dynamic> application, String status) async {
    try {
      await ApiService().reviewRoomApplication(
        roomId: widget.roomId,
        userId: application['user_id'] as String,
        status: status,
      );
      ref.invalidate(professorRoomDetailProvider(widget.roomId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청 처리 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(professorRoomDetailProvider(widget.roomId));
    final summary = summaryAsync.valueOrNull;
    final room = summary?.room;
    final lectures = summary?.lectures ?? const <dynamic>[];
    final students = summary?.students ?? const <dynamic>[];
    final notices = summary?.notices ?? const <dynamic>[];
    final applications = summary?.applications ?? const <dynamic>[];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(room?['subject'] as String? ?? '강의 방'),
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
      body: summaryAsync.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : summaryAsync.hasError || room == null
              ? const Center(
                  child: Text(
                    '강의실 데이터를 불러오지 못했습니다',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
          : TabBarView(
              controller: _tabs,
              children: [
                _buildLectures(lectures),
                _buildNotices(room, notices),
                _buildStudents(room, students, applications),
                _buildSettings(room),
              ],
            ),
    );
  }

  Widget _buildLectures(List<dynamic> lectures) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '강의 항목 관리',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lectures.length}개의 강의 항목을 편집하고 순서를 정렬할 수 있습니다',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/professor/lecture/${widget.roomId}/upload'),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('자료 업로드'),
              ),
            ],
          ),
        ),
        Expanded(
          child: lectures.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('📄', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('아직 교안이 없습니다', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('교안 업로드 버튼을 눌러 시작하세요', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: lectures.length,
                  itemBuilder: (_, i) {
                    final lec = lectures[i] as Map<String, dynamic>;
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
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: i == 0 ? null : () => _moveLecture(lectures, i, -1),
                                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                                  ),
                                  IconButton(
                                    onPressed: i == lectures.length - 1 ? null : () => _moveLecture(lectures, i, 1),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                  ),
                                ],
                              ),
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
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _editLecture(lec),
                                  icon: const Icon(Icons.edit_rounded, size: 16),
                                  label: const Text('편집'),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _deleteLecture(lec),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.rose),
                                  label: const Text('삭제', style: TextStyle(color: AppColors.rose)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStudents(
    Map<String, dynamic> room,
    List<dynamic> students,
    List<dynamic> applications,
  ) {
    final code = room['room_code'] as String? ?? '';
    final pendingApplications = applications
        .where((item) => (item as Map<String, dynamic>)['status'] == 'pending')
        .cast<Map<String, dynamic>>()
        .toList();

      return Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
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
              if (pendingApplications.isNotEmpty) ...[
                const SizedBox(height: 16),
                AppCard(
                  borderColor: AppColors.gold.withValues(alpha: 0.24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '수강 신청 대기',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${pendingApplications.length}명',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...pendingApplications.map((application) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                                    child: Text(
                                      ((application['student_name'] as String?) ?? '?').substring(0, 1),
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          application['student_name'] as String? ?? '',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if ((application['note'] as String? ?? '').trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              application['note'] as String,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _reviewApplication(application, 'rejected'),
                                    child: const Text(
                                      '반려',
                                      style: TextStyle(color: AppColors.rose),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () => _reviewApplication(application, 'approved'),
                                    child: const Text('승인'),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: students.isEmpty
            ? const Center(child: Text('아직 입장한 학생이 없습니다', style: TextStyle(color: AppColors.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: students.length,
                itemBuilder: (_, i) {
                  final s = students[i] as Map<String, dynamic>;
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

  Widget _buildNotices(Map<String, dynamic> room, List<dynamic> notices) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '공지사항',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${notices.length}개의 공지가 학생에게 노출됩니다',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _createNotice(room),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('공지 작성'),
              ),
            ],
          ),
        ),
        Expanded(
          child: notices.isEmpty
              ? const Center(
                  child: Text('아직 등록된 공지가 없습니다', style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: notices.length,
                  itemBuilder: (_, i) {
                    final notice = notices[i] as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (notice['title'] as String?)?.trim().isNotEmpty == true
                                        ? notice['title'] as String
                                        : '제목 없는 공지',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteNotice(notice),
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notice['content'] as String? ?? '',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              notice['created_at'] as String? ?? '',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettings(Map<String, dynamic> room) {
    final ctrlSynopsis = TextEditingController(text: room['synopsis'] ?? '');
    final ctrlConcepts = TextEditingController(text: ((room['core_concepts'] as List<dynamic>?) ?? []).join(', '));
    final ctrlYoutube = TextEditingController(text: room['youtube_url'] ?? '');
    
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
                    ref.invalidate(professorRoomDetailProvider(widget.roomId));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('설정이 저장되었습니다.')));
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
