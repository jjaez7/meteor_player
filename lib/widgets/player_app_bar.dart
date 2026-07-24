import 'package:flutter/material.dart';
import '../menu/menu_main.dart';
import '../features/left_menu_actions.dart';
import 'essential_view.dart'; // 🎧 에센셜 모드 토글 버튼
import 'fluid/fluid_kit.dart';

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

  // 🎧 에센셜 모드 토글 콜백
  final VoidCallback onEssentialModeToggled;
  final bool isEssentialMode;

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
    required this.onEssentialModeToggled,
    this.isConcertMode = false,
    this.isEssentialMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isFlipCover = size.width > size.height && size.width < 600;

    if (isPip || isFlipCover) return const SizedBox.shrink();

    final glassColor = bgColor.withValues(alpha: 0.85);
    // 포인트 컬러 기반 유리 메뉴 색
    final accentMenuBg = Color.lerp(Colors.black, playBtnColor, 0.06)!
        .withValues(alpha: 0.92);
    final accentBorder = playBtnColor.withValues(alpha: 0.35);

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
              color: accentMenuBg,
              elevation: 12,
              offset: const Offset(0, 50),
              constraints: const BoxConstraints(minWidth: 190),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: accentBorder, width: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _AestheticMenuIcon(
                textColor: textColor,
                icon: Icons.expand_more_rounded,
              ),
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

          // [중앙] 로고 - Essential 모드일 때 숨김
          // Fluid AI 톤: 딱 사라지지 않고 fade+살짝 scale로 사라짐/등장
          Positioned(
            left: 60,
            right: 130,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                opacity: isEssentialMode ? 0.0 : 1.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  scale: isEssentialMode ? 0.92 : 1.0,
                  child: Center(
                    child: Text(
                      "GLASNYL",
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
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
                ),
              ),
            ),
          ),

          // [우측] 에센셜 토글 & 리셋 & 설정 메뉴
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🎧 에센셜 모드 토글 버튼
                EssentialToggleButton(
                  isEssentialMode: isEssentialMode,
                  onToggle: onEssentialModeToggled,
                  accentColor: playBtnColor,
                ),
                const SizedBox(width: 4),

                if (isEditMode)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
                    onPressed: onResetLayout,
                  ),

                PopupMenuButton<String>(
                  color: accentMenuBg,
                  elevation: 12,
                  offset: const Offset(0, 50),
                  constraints: const BoxConstraints(minWidth: 210),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: accentBorder, width: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _AestheticMenuIcon(
                    textColor: textColor,
                    icon: Icons.more_vert_rounded,
                    isSmall: true,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isHighlight
                  ? Colors.amber.withValues(alpha: 0.15)
                  : playBtnColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHighlight
                    ? Colors.amber.withValues(alpha: 0.35)
                    : playBtnColor.withValues(alpha: 0.20),
                width: 0.6,
              ),
            ),
            child: Icon(
              icon,
              color: isHighlight
                  ? Colors.amber.withValues(alpha: 0.90)
                  : playBtnColor.withValues(alpha: 0.65),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isHighlight
                  ? Colors.amber.withValues(alpha: 0.95)
                  : playBtnColor.withValues(alpha: 0.85),
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
              letterSpacing: isHighlight ? 0.6 : 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _AestheticMenuIcon  —  AppBar 메뉴 버튼 (aesthetic 스타일)
// ──────────────────────────────────────────────────────────────────────────────
class _AestheticMenuIcon extends StatelessWidget {
  final Color textColor;
  final IconData icon;
  final bool isSmall;

  const _AestheticMenuIcon({
    required this.textColor,
    required this.icon,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isSmall ? 34 : 38,
      height: isSmall ? 34 : 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(isSmall ? 11 : 13),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 0.7,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: isSmall ? 18 : 22,
          color: textColor.withValues(alpha: 0.70),
        ),
      ),
    );
  }
}