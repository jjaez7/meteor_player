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
    // [수정] 여기서 Positioned를 제거하고 내부 알맹이(GestureDetector)만 리턴합니다.
    return GestureDetector(
      onScaleUpdate: isEditMode
          ? (details) {
              if (details.pointerCount == 1) {
                onDrag(details.focalPointDelta);
              } else if (details.scale != 1.0) {
                double delta = (details.scale > 1.0) ? 2.0 : -2.0;
                onResizeDelta(delta);
              }
            }
          : null,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: isEditMode
              ? Border.all(color: Colors.orange.withOpacity(0.5), width: 2)
              : null,
        ),
        child: child,
      ),
    );
  }
}
