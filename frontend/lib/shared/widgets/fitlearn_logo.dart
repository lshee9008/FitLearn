import 'package:flutter/material.dart';

class FitLearnLogo extends StatelessWidget {
  static const iconAsset = 'assets/brand/fitlearn_logo_icon.png';
  static const wordmarkAsset = 'assets/brand/fitlearn_logo_wordmark.png';

  final double height;
  final bool iconOnly;
  final BoxFit fit;

  const FitLearnLogo({
    super.key,
    this.height = 28,
    this.iconOnly = false,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      iconOnly ? iconAsset : wordmarkAsset,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Text(
        'FitLearn',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: height * 0.72,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
      ),
    );
  }
}

class FitLearnMarkBox extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final BorderRadiusGeometry? borderRadius;

  const FitLearnMarkBox({
    super.key,
    this.size = 36,
    this.backgroundColor = Colors.black,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(size * 0.28),
      ),
      child: Image.asset(
        FitLearnLogo.iconAsset,
        fit: BoxFit.cover,
      ),
    );
  }
}
