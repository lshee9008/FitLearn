import 'package:flutter/material.dart';

class FitLearnLogo extends StatelessWidget {
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
      iconOnly
          ? 'assets/brand/fitlearn_logo_icon.png'
          : 'assets/brand/fitlearn_logo_wordmark.png',
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
