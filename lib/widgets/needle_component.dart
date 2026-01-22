import 'package:flutter/material.dart';

class NeedleWidget extends StatelessWidget {
  final Animation<double> controller;
  final double needleSize;
  final Color bgColor;
  final Color accentColor;

  const NeedleWidget({
    super.key,
    required this.controller,
    required this.needleSize,
    required this.bgColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double angle = 1.2 - (controller.value * 0.5);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // 바늘 몸체
            Transform.rotate(
              angle: angle,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 18),
                  Container(
                    width: 5,
                    height: needleSize * 0.75,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey[300]!,
                          Colors.grey[700]!,
                          Colors.grey[300]!,
                        ],
                      ),
                    ),
                  ),
                  // 카트리지
                  Transform.rotate(
                    angle: 0.25,
                    child: Container(
                      width: 22,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 조인트(축)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
