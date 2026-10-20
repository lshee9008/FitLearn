// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// 강의 영상 (업로드 영상 / 외부 URL). 유튜브 등 임베드 불가 링크는 새 탭 열기로 대체.
class LectureVideo extends StatelessWidget {
  final String videoUrl;
  final String videoType;
  final String videoStatus;

  const LectureVideo({
    super.key,
    required this.videoUrl,
    required this.videoType,
    required this.videoStatus,
  });

  static final Set<String> _registered = {};

  @override
  Widget build(BuildContext context) {
    final viewType = 'fitlearn-video-${videoUrl.hashCode.abs()}';
    final embedUrl = _embedUrl(videoUrl, videoType);
    final temporary = videoUrl.contains('/api/v1/lectures/assets/');
    final canEmbed = embedUrl.isNotEmpty && !temporary;
    if (canEmbed && !_registered.contains(viewType)) {
      _registered.add(viewType);
      ui_web.platformViewRegistry.registerViewFactory(viewType, (_) {
        if (videoType == 'upload' || _looksLikeDirectVideo(embedUrl)) {
          return html.VideoElement()
            ..src = embedUrl
            ..controls = true
            ..setAttribute('playsinline', 'true')
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'contain'
            ..style.backgroundColor = '#000000';
        }
        return html.IFrameElement()
          ..src = embedUrl
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
          ..allowFullscreen = true
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(FL.r16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: FL.border),
          borderRadius: BorderRadius.circular(FL.r16),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: canEmbed
              ? HtmlElementView(viewType: viewType)
              : _Fallback(
                  videoUrl: videoUrl,
                  status: temporary ? 'temporary_expired' : videoStatus,
                ),
        ),
      ),
    );
  }

  static String _embedUrl(String url, String type) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (type == 'youtube' || uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      final id = uri.host.contains('youtu.be')
          ? uri.pathSegments.firstOrNull
          : uri.queryParameters['v'] ?? (uri.pathSegments.length > 1 ? uri.pathSegments.last : null);
      return id == null || id.isEmpty ? '' : 'https://www.youtube.com/embed/$id';
    }
    return url;
  }

  static bool _looksLikeDirectVideo(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.contains('firebasestorage') ||
        lower.contains('storage.googleapis.com');
  }
}

class _Fallback extends StatelessWidget {
  final String videoUrl;
  final String status;
  const _Fallback({required this.videoUrl, required this.status});

  @override
  Widget build(BuildContext context) {
    final title = switch (status) {
      'processing' => '영상 업로드 처리 중입니다',
      'temporary_expired' => '임시 영상 링크가 만료되었습니다',
      _ => '앱 안에서 재생할 수 없는 영상입니다',
    };
    return Container(
      color: FL.surface,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.ondemand_video_rounded, color: FL.textMute, size: 44),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: FL.text, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => html.window.open(videoUrl, '_blank'),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('새 탭에서 열기'),
        ),
      ]),
    );
  }
}
