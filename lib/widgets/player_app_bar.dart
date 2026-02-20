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
  final VoidCallback onPassUpdated; 

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
    required this.onPassUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isFlipCover = size.width > size.height && size.width < 600;

    if (isPip || isFlipCover) return const SizedBox.shrink();

    // 🚀 글래스모피즘 스타일 적용 (배경 투명도 및 테두리 강조)
    final glassColor = bgColor.withValues(alpha: 0.85); // 조금 더 불투명하게 조정하여 가독성 확보

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
              elevation: 8, // 글래스 레이어감을 위해 그림자 살짝 추가
              offset: const Offset(0, 50), // 버튼 아래로 띄우기
              constraints: const BoxConstraints(minWidth: 160),
              shape: RoundedRectangleBorder(
                // 🚀 테두리를 밝게 하여 유리 광택 느낌 부여
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                borderRadius: BorderRadius.circular(22),
              ),
              icon: Icon(Icons.expand_more_rounded, size: 32, color: textColor),
              onSelected: (val) => LeftMenuActions.handleLeftMenuClick(
                context: context, 
                value: val,
                onLockEnabled: onLockToggle,
              ),
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
                letterSpacing: 4, // 간격을 넓혀 고급스러움 강조
                fontSize: 13,
                color: textColor.withValues(alpha: 0.9),
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2)),
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
                    icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
                    onPressed: onResetLayout,
                  ),
                
                PopupMenuButton<String>(
                  color: glassColor,
                  elevation: 10,
                  offset: const Offset(0, 50),
                  constraints: const BoxConstraints(minWidth: 200),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  icon: Icon(Icons.more_vert_rounded, color: textColor, size: 28),
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
                    onPassUpdated: onPassUpdated,
                  ),
                  itemBuilder: (context) => [
                    // 🚀 프리패스 메뉴 강조 (Amber 색상 아이콘)
                    _menuItem("GLASNYL PASS", Icons.bolt_rounded, "pass", isHighlight: true),
                    const PopupMenuDivider(height: 1),
                    
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

  // 🚀 수정된 메뉴 아이템 빌더
  PopupMenuItem<String> _menuItem(String title, IconData icon, String value, {bool isHighlight = false}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              // 하이라이트 메뉴는 색상을 다르게
              color: isHighlight 
                  ? Colors.amber.withValues(alpha: 0.2) 
                  : textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon, 
              color: isHighlight ? Colors.amber : textColor.withValues(alpha: 0.8), 
              size: 18
            ),
          ),
          const SizedBox(width: 14),
          Text(
            title, 
            style: TextStyle(
              color: isHighlight ? Colors.amber : textColor, 
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            )
          ),
        ],
      ),
    );
  }
}