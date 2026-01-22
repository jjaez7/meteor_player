import 'package:flutter/material.dart';

class PlayerAppBar extends StatelessWidget {
  final Orientation orientation;
  final Color textColor;
  final bool isEditMode;
  final VoidCallback onResetLayout;
  final Widget menuButton;

  const PlayerAppBar({
    super.key,
    required this.orientation,
    required this.textColor,
    required this.isEditMode,
    required this.onResetLayout,
    required this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    // [핵심 수정] Positioned와 SafeArea를 제거합니다.
    // 부모 위젯(VinylPlayerScreen)의 Stack에서 이미 처리하고 있기 때문입니다.
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        children: [
          // 왼쪽: 확장 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.expand_more, size: 30, color: textColor),
              onPressed: () {},
            ),
          ),
          // 중앙: 로고 텍스트
          Align(
            alignment: Alignment.center,
            child: Text(
              "METEOR PLAYER",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          // 오른쪽: 초기화 및 메뉴 버튼
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEditMode)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.redAccent),
                    onPressed: onResetLayout,
                  ),
                menuButton,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
