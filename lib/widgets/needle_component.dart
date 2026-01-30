import 'package:flutter/material.dart';

// AnimatedWidget을 상속받으면 controller의 변화를 가장 직접적으로 수신합니다.
class NeedleWidget extends AnimatedWidget {
  final double needleSize;
  final Color bgColor;
  final Color accentColor;

  const NeedleWidget({
    super.key,
    required Animation<double> controller, // 이름을 listenable로 전달하기 위해 명시
    required this.needleSize,
    required this.bgColor,
    required this.accentColor,
  }) : super(listenable: controller);

  // 부모로부터 받은 animation을 사용하기 편하게 getter로 설정
  Animation<double> get _controller => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    // value가 0일 때(정지): 1.2 (바깥쪽)
    // value가 1일 때(재생): 0.7 (안쪽)
    final double angle = 1.2 - (_controller.value * 0.5);

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
              // 카트리지 (바늘 끝부분)
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
        // 조인트(회전축)
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
  }
}