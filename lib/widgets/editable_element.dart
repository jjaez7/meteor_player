import 'package:flutter/material.dart';

class EditableElement extends StatelessWidget {
  final Widget child;
  final bool isEditMode;
  final double width;
  final double height;
  final Function(Offset) onDrag;
  final Function(double) onResizeDelta;

  const EditableElement({
    super.key,
    required this.child,
    required this.isEditMode,
    required this.width,
    required this.height,
    required this.onDrag,
    required this.onResizeDelta,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 실제 버튼 (편집 모드가 아닐 땐 얘만 살아있음)
          child,

          // 2. 편집 모드일 때만 '위에' 덮개 레이어를 씌움
          // Fluid AI 톤: 편집 모드 진입/해제가 딱 끊기지 않고 fade로 이어짐
          if (isEditMode)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                opacity: 1.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleUpdate: (details) {
                    if (details.pointerCount == 1) {
                      onDrag(details.focalPointDelta);
                    } else if (details.scale != 1.0) {
                      double delta = (details.scale > 1.0) ? 2.0 : -2.0;
                      onResizeDelta(delta);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      color: Colors.transparent, // 투명하지만 터치는 받는 영역
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}