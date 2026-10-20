import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import '../../core/constants/api_constants.dart';

/// 브라우저 EventSource 기반 SSE 수신기.
/// 서버가 보내는 JSON 이벤트(`data: {...}`)를 Map으로 흘려보내고,
/// done/error 이벤트를 받으면 자동 재접속을 막기 위해 연결을 닫는다.
class SseClient {
  static Stream<Map<String, dynamic>> connect(
    String path, {
    Map<String, String> query = const {},
    Duration idleTimeout = const Duration(seconds: 60),
  }) {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    late final StreamController<Map<String, dynamic>> controller;
    html.EventSource? source;
    Timer? idle;

    void close() {
      idle?.cancel();
      source?.close();
      if (!controller.isClosed) controller.close();
    }

    void armIdle() {
      idle?.cancel();
      idle = Timer(idleTimeout, () {
        if (!controller.isClosed) {
          controller.add({'type': 'error', 'message': '응답이 지연되고 있습니다. 다시 시도해주세요.'});
        }
        close();
      });
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        source = html.EventSource(uri.toString());
        armIdle();
        source!.onMessage.listen((event) {
          armIdle();
          final raw = event.data;
          if (raw is! String || raw.isEmpty) return;
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              controller.add(decoded);
              final type = decoded['type'];
              if (type == 'done' || type == 'error') close();
            }
          } catch (_) {}
        });
        source!.onError.listen((_) {
          if (!controller.isClosed) {
            controller.add({'type': 'error', 'message': '서버 연결이 끊어졌습니다.'});
          }
          close();
        });
      },
      onCancel: close,
    );
    return controller.stream;
  }
}
