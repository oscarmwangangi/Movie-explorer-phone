import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';

/// A shimmering placeholder block used while content loads. Uses a
/// diagonal light sweep across a dark base rather than a simple
/// fade-in/out, closer to the shimmer effect used by real streaming
/// apps' loading states.
class Skeleton extends StatefulWidget {
  final double? height;
  final double? width;
  final double borderRadius;

  const Skeleton({this.height, this.width, this.borderRadius = 8, super.key});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.5 + _controller.value * 3, -0.3),
                  end: Alignment(-0.5 + _controller.value * 3, 0.3),
                  colors: const [
                    AppColors.surfaceElevated,
                    Color(0xFF33333A),
                    AppColors.surfaceElevated,
                  ],
                  stops: const [0.35, 0.5, 0.65],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
