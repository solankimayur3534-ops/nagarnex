import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Animated NagarNex logo widget with smooth entrance spring, subtle glow,
/// and hover/tap scale micro-interaction. Safe for `pumpAndSettle` in tests.
class AnimatedLogo extends StatefulWidget {
  final double size;
  final bool darkBackground;
  final VoidCallback? onTap;

  const AnimatedLogo({
    super.key,
    this.size = 34,
    this.darkBackground = false,
    this.onTap,
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = (widget.size * 0.28).clamp(6.0, 14.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.78, end: 1.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return AnimatedScale(
              scale: _hovered ? scale * 1.08 : scale,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: child,
            );
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: widget.darkBackground
                    ? AppColors.emeraldMint.withValues(alpha: 0.65)
                    : AppColors.emerald.withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.darkBackground
                          ? AppColors.emeraldMint
                          : AppColors.forest)
                      .withValues(alpha: _hovered ? 0.35 : 0.18),
                  blurRadius: _hovered ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular((radius - 1).clamp(4.0, 13.0)),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.recycling_rounded,
                  color: AppColors.forest,
                  size: widget.size * 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
