import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

enum FLButtonKind { primary, secondary, ghost }

/// 브랜드 버튼 — primary(라임) / secondary(테두리) / ghost(텍스트)
class FLButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final FLButtonKind kind;
  final bool loading;
  final bool large;
  final bool expand;

  const FLButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.kind = FLButtonKind.primary,
    this.loading = false,
    this.large = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg, border) = switch (kind) {
      FLButtonKind.primary => (FL.lime, FL.limeInk, Colors.transparent),
      FLButtonKind.secondary => (FL.surface2, FL.text, FL.borderStrong),
      FLButtonKind.ghost => (Colors.transparent, FL.textSec, Colors.transparent),
    };
    final h = large ? 54.0 : 44.0;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: large ? 20 : 18, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: large ? 16 : 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 6),
          Icon(trailingIcon, size: large ? 20 : 18, color: fg),
        ],
      ],
    );
    return Opacity(
      opacity: enabled || loading ? 1 : 0.45,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FL.r12),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(FL.r12),
          hoverColor: fg.withValues(alpha: 0.06),
          child: Container(
            height: h,
            padding: EdgeInsets.symmetric(horizontal: large ? 24 : 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 작은 태그/배지
class FLTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;
  const FLTag(this.text, {super.key, this.color = FL.lime, this.icon, this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: solid ? 0 : 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: solid ? FL.limeInk : color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            color: solid ? FL.limeInk : color,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
      ]),
    );
  }
}

/// 기본 카드 컨테이너
class FLCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  const FLCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? FL.surface,
        borderRadius: BorderRadius.circular(FL.r16),
        border: Border.all(color: borderColor ?? FL.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: box),
    );
  }
}

/// 섹션 라벨 (작은 대문자형 캡션)
class FLLabel extends StatelessWidget {
  final String text;
  final Color color;
  const FLLabel(this.text, {super.key, this.color = FL.textMute});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      );
}

/// 로딩 스켈레톤 (은은하게 깜빡이는 막대)
class FLSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const FLSkeleton({super.key, this.height = 14, this.width, this.radius = 6});

  @override
  State<FLSkeleton> createState() => _FLSkeletonState();
}

class _FLSkeletonState extends State<FLSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(FL.surface2, FL.surface3, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// 깜빡이는 점 — "생성 중" 표시
class FLPulseDot extends StatefulWidget {
  final Color color;
  const FLPulseDot({super.key, this.color = FL.lime});

  @override
  State<FLPulseDot> createState() => _FLPulseDotState();
}

class _FLPulseDotState extends State<FLPulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
