import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../features/auth/provider/auth_provider.dart';
import 'api_service.dart';

/// 로그인 없이 원클릭 체험을 시작한다.
/// - 학생: (처음이면) 1분 진단 → 데모 강의 맞춤 교안
/// - 교수: 개인 데모 강의실(가상 수강생 포함)
Future<void> launchDemo(BuildContext context, WidgetRef ref, UserRole role) async {
  final navigator = GoRouter.of(context);
  final rootNav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _DemoPreparingDialog(role: role),
  );

  String? destination;
  String? error;
  try {
    final data = await ref.read(authNotifierProvider.notifier).demoLogin(role);
    if (role == UserRole.student) {
      final learn = '/learn/${data['featured_room_id']}/${data['featured_lecture_id']}';
      var diagnosed = false;
      try {
        await ApiService().getDiagnosis(data['user_id'] as String);
        diagnosed = true;
      } catch (_) {}
      destination = diagnosed
          ? learn
          : '/student/diagnosis/quick?next=${Uri.encodeComponent(learn)}';
    } else {
      destination = '/professor/room/${data['room_id']}';
    }
  } on DioException catch (e) {
    error = e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout
        ? '서버가 깨어나는 데 시간이 오래 걸리고 있어요. 잠시 후 다시 눌러주세요.'
        : '체험 계정을 준비하지 못했어요. 잠시 후 다시 시도해주세요.';
  } catch (_) {
    error = '체험 계정을 준비하지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  rootNav.pop();
  await dialog;
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  navigator.go(destination!);
}

class _DemoPreparingDialog extends StatefulWidget {
  final UserRole role;
  const _DemoPreparingDialog({required this.role});

  @override
  State<_DemoPreparingDialog> createState() => _DemoPreparingDialogState();
}

class _DemoPreparingDialogState extends State<_DemoPreparingDialog> {
  int _seconds = 0;
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() => _seconds++);
  });

  @override
  void initState() {
    super.initState();
    _timer.isActive; // 타이머 즉시 시작
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.role == UserRole.student;
    final slow = _seconds >= 5;
    return Dialog(
      backgroundColor: FL.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FL.r20),
        side: const BorderSide(color: FL.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(color: FL.lime, strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              student ? '학생 체험을 준비하고 있어요' : '교수 체험을 준비하고 있어요',
              style: const TextStyle(color: FL.text, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              student
                  ? '데모 강의 「파이썬 머신러닝 입문」에 자동으로 수강 등록합니다.'
                  : '나만의 데모 강의실과 가상 수강생 8명을 만들고 있어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: FL.textSec, fontSize: 14, height: 1.5),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: slow
                  ? Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FL.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(FL.r12),
                          border: Border.all(color: FL.amber.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '잠들어 있던 서버를 깨우는 중이에요 (${_seconds}s)\n무료 서버라 첫 접속은 최대 1분 정도 걸릴 수 있어요.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: FL.amber, fontSize: 12.5, height: 1.5),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      ),
    );
  }
}
