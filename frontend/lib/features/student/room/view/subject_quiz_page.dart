import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/provider/auth_provider.dart';

class SubjectQuizPage extends ConsumerStatefulWidget {
  final String roomId;
  const SubjectQuizPage({super.key, required this.roomId});

  @override
  ConsumerState<SubjectQuizPage> createState() => _SubjectQuizPageState();
}

class _SubjectQuizPageState extends ConsumerState<SubjectQuizPage> {
  bool _loading = true;
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  List<int> _answers = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final res = await ApiService().getRoomQuiz(widget.roomId);
      final questions = res['questions'] as List<dynamic>? ?? [];
      
      if (questions.isEmpty) {
        // 교수가 아직 퀴즈를 생성하지 않았다면 바로 넘어가도 됨 (MVP)
        if (mounted) context.pop();
        return;
      }
      
      setState(() {
        _questions = questions;
        _answers = List.filled(questions.length, -1);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        // 오류가 나면 스킵 (아직 퀴즈가 없거나 서버 에러)
        context.pop();
      }
    }
  }

  Future<void> _submit() async {
    final user = ref.read(authNotifierProvider);
    if (user == null || _answers.contains(-1)) return;
    
    setState(() => _submitting = true);
    try {
      final result = await ApiService().submitQuiz(widget.roomId, user.userId, _answers);
      if (mounted) {
        _showResultDialog(result['subject_level'] as String, result['score'] as int);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('제출 실패: $e')));
      setState(() => _submitting = false);
    }
  }

  void _showResultDialog(String level, int score) {
    String message = '';
    Color levelColor = AppColors.primary;
    String badge = '';
    
    if (level == 'advanced') {
      badge = '고급';
      levelColor = AppColors.primaryLight;
      message = '대단하시네요! 심화 내용과 최적화 관점의 교안을 제공해드릴게요.';
    } else if (level == 'intermediate') {
      badge = '중급';
      levelColor = AppColors.gold;
      message = '기본기는 갖추셨군요! 응용과 사례 충심으로 구성된 교안을 준비할게요.';
    } else {
      badge = '입문';
      levelColor = AppColors.accent;
      message = '처음이신가요? 괜찮습니다! 쉬운 용어와 차근차근 단계별 교안으로 채워드릴게요.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎉', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('$score점', style: TextStyle(color: levelColor, fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('수준: $badge', style: TextStyle(color: levelColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pop(true); // 완료되었음을 반환
                  },
                  child: const Text('강의실 입장하기', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('과목 수준 퀴즈를 불러오는 중...', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentIndex] as Map<String, dynamic>;
    final options = q['options'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false, // 뒤로가기 방지 (퀴즈 필수)
        title: Text('과목 수준 진단 (${_currentIndex + 1}/${_questions.length})'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                q['question'] as String? ?? '',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final isSelected = _answers[_currentIndex] == i;
                    return GestureDetector(
                      onTap: () {
                        setState(() { _answers[_currentIndex] = i; });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.bgSurface,
                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: isSelected ? AppColors.primary : AppColors.textMuted),
                                color: isSelected ? AppColors.primary : Colors.transparent,
                              ),
                              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                options[i] as String,
                                style: TextStyle(
                                  color: isSelected ? AppColors.primaryLight : AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _answers[_currentIndex] != -1 ? AppColors.primary : AppColors.bgSurface,
                foregroundColor: Colors.black,
              ),
              onPressed: _answers[_currentIndex] == -1 || _submitting ? null : () {
                if (_currentIndex < _questions.length - 1) {
                  setState(() => _currentIndex++);
                } else {
                  _submit();
                }
              },
              child: _submitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text(
                    _currentIndex < _questions.length - 1 ? '다음 문제' : '제출하고 결과 보기',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _answers[_currentIndex] != -1 ? Colors.black : AppColors.textMuted
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
