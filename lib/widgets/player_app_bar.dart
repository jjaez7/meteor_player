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

  // 🎸 콘서트 모드 토글 콜백
  final VoidCallback onConcertModeToggled;
  final bool isConcertMode;

  // 📸 공유 카드 콜백
  final VoidCallback onShareCard;

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
    required this.onConcertModeToggled,
    required this.onShareCard,
    this.isConcertMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isFlipCover = size.width > size.height && size.width < 600;

    if (isPip || isFlipCover) return const SizedBox.shrink();

    final glassColor = bgColor.withValues(alpha: 0.85);

    final EdgeInsets sysPad = MediaQuery.of(context).padding;
    final double extraLeft  = sysPad.left;
    final double extraRight = sysPad.right;

    return Container(
      height: 60,
      padding: EdgeInsets.only(
        left:  10 + extraLeft,
        right: 10 + extraRight,
      ),
      child: Stack(
        children: [
          // [좌측] 메뉴 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<String>(
              color: glassColor,
              elevation: 8,
              offset: const Offset(0, 50),
              constraints: const BoxConstraints(minWidth: 160),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                borderRadius: BorderRadius.circular(22),
              ),
              icon: Icon(Icons.expand_more_rounded, size: 32, color: textColor),
              onSelected: (val) => LeftMenuActions.handleLeftMenuClick(
                context: context,
                value: val,
                onLockEnabled: onLockToggle,
                onConcertModeToggled: onConcertModeToggled,
                onShareCard: onShareCard, // ← 추가
              ),
              itemBuilder: (context) => [
                _menuItem("PiP Mode", Icons.picture_in_picture_alt_rounded, "pip"),
                _menuItem("Screen Lock", Icons.lock_outline_rounded, "lock"),
                // 🎸 콘서트 모드 메뉴 항목
                _menuItem(
                  isConcertMode ? "Exit Concert" : "Concert Mode",
                  isConcertMode ? Icons.close_rounded : Icons.celebration_rounded,
                  "concert",
                  isHighlight: !isConcertMode,
                ),
                // 📸 공유 카드
                _menuItem("Share Card", Icons.ios_share_rounded, "share"),
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
                letterSpacing: 4,
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

  PopupMenuItem<String> _menuItem(String title, IconData icon, String value, {bool isHighlight = false}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
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