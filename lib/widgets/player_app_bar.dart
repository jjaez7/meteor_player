import 'package:flutter/material.dart';
import '../menu/menu_main.dart';
import '../features/left_menu_actions.dart';

class PlayerAppBar extends StatelessWidget {
  final bool isPip;
  final Orientation orientation;
  final Color textColor;
  final Color bgColor;
  final bool isEditMode;
  final VoidCallback onResetLayout;
  final Function(bool) onEditModeChanged;
  final VoidCallback onLockToggle;

  final Color lpColor;
  final Color artistColor;
  final Color barColor;
  final Color playBtnColor;
  final Function(Color, String) onColorChanged;
  final VoidCallback onResetColors;

  const PlayerAppBar({
    super.key,
    required this.isPip,
    required this.orientation,
    required this.textColor,
    required this.bgColor,
    required this.isEditMode,
    required this.onResetLayout,
    required this.onEditModeChanged,
    required this.lpColor,
    required this.artistColor,
    required this.barColor,
    required this.playBtnColor,
    required this.onColorChanged,
    required this.onResetColors,
    required this.onLockToggle,
  });

  @override
  Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final bool isFlipCover = size.width > size.height && size.width < 600;

    if (isPip || isFlipCover) return const SizedBox.shrink();
    if (isPip) return const SizedBox.shrink();

    // 글래스모피즘을 위한 소프트 컬러 계산
    final glassColor = bgColor.withValues(alpha: 0.7);

return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        children: [
          // [좌측] 메뉴 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<String>(
              color: glassColor,
              elevation: 0,
              constraints: const BoxConstraints(minWidth: 150),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: textColor.withValues(alpha: 0.1), width: 1),
                borderRadius: BorderRadius.circular(20),
              ),
              icon: Icon(Icons.expand_more_rounded, size: 32, color: textColor),
              // 🚀 수정 1: 호출 시 파라미터 이름을 명시하고 콜백을 전달합니다.
              onSelected: (val) => LeftMenuActions.handleLeftMenuClick(
                context: context, 
                value: val,
                onLockEnabled: onLockToggle,
              ),
              // 🚀 수정 2: 메뉴 아이템 리스트에 Screen Lock을 추가합니다.
              itemBuilder: (context) => [
                _menuItem("PiP Mode", Icons.picture_in_picture_alt_rounded, "pip"),
                _menuItem("Screen Lock", Icons.lock_outline_rounded, "lock"),
              ],
            ),
          ),
          
          // [중앙] 로고
          Align(
            alignment: Alignment.center,
            child: Text(
              "GLASNYL",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 14,
                color: textColor,
                shadows: [
                  Shadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
            ),
          ),

          // [우측] 리셋 & 설정 메뉴
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
                
                PopupMenuButton<String>(
                  color: glassColor,
                  elevation: 0,
                  constraints: const BoxConstraints(minWidth: 180),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: textColor.withValues(alpha: 0.1), width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  icon: Icon(Icons.more_vert, color: textColor, size: 28),
                  onSelected: (val) => handleMenuClick(
                    context: context,
                    value: val,
                    isEditMode: isEditMode,
                    onEditModeChanged: onEditModeChanged,
                    bgColor: bgColor,
                    lpColor: lpColor,
                    textColor: textColor,
                    artistColor: artistColor,
                    barColor: barColor,
                    playBtnColor: playBtnColor,
                    onColorChanged: onColorChanged,
                    onResetColors: onResetColors,
                    onResetLayout: onResetLayout,
                  ),
                  itemBuilder: (context) => [
                    _menuItem("Theme Settings", Icons.palette_outlined, "settings"),
                    _menuItem(
                      isEditMode ? "Finish Layout" : "Edit Layout",
                      isEditMode ? Icons.check_circle_rounded : Icons.dashboard_customize_outlined,
                      "edit_mode",
                    ),
                    const PopupMenuDivider(height: 1),
                    _menuItem("Creator Info", Icons.account_circle_outlined, "creator"),
                    _menuItem("Terms of Service", Icons.article_outlined, "terms"),
                    _menuItem("Manual", Icons.terminal_rounded, "manual")
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String title, IconData icon, String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: textColor.withValues(alpha: 0.8), size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            title, 
            style: TextStyle(
              color: textColor, 
              fontWeight: FontWeight.w600,
              fontSize: 13,
            )
          ),
        ],
      ),
    );
  }
}