import 'package:flutter/material.dart';
//import '../menu/menu_main.dart';
import 'package:flutter/services.dart';

// --- 1. 상단 앱바 위젯 (PlayerTopBar) ---
class PlayerTopBar extends StatelessWidget {
  final bool isEditMode;
  final Function(bool) onEditModeChanged;
  final VoidCallback onReset;
  final Color textColor;
  final Widget menuButton;

  const PlayerTopBar({
    super.key,
    required this.isEditMode,
    required this.onEditModeChanged,
    required this.onReset,
    required this.textColor,
    required this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          // 🚀 상단바 자체에 아주 얇은 유리막 레이어를 씌웁니다.
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 브랜드 로고 부분
            Text(
              "GLASNYL",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 13,
                // 🚀 배경이 어두우므로 순백색을 사용하되, 살짝 투명도를 주어 세련되게
                color: Colors.white.withValues(alpha: 0.9),
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (isEditMode)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 22),
                    onPressed: onReset,
                  ),
                // 편집 모드 전환 버튼
                _buildGlassIconButton(
                  icon: isEditMode ? Icons.check_circle : Icons.dashboard_customize,
                  iconColor: isEditMode ? Colors.cyanAccent : Colors.white,
                  onPressed: () => onEditModeChanged(!isEditMode),
                ),
                // 🚀 기존 menuButton도 이 테마에 녹아들도록 감쌉니다.
                Theme(
                  data: Theme.of(context).copyWith(
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  child: menuButton,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 상단바 아이콘용 글래스 스타일 헬퍼
  Widget _buildGlassIconButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: iconColor.withValues(alpha: 0.9), size: 22),
      onPressed: onPressed,
    );
  }
}

// --- 2. 네오포미즘 프로그레스 바 (ProgressBarWidget) ---
// 기존 ProgressBarWidget(Stateless)을 삭제하고 이 코드를 붙여넣으세요.
class ProgressBarWidget extends StatefulWidget {
  final double width;
  final double factor;
  final Color bgColor;
  final Color barColor;
  final Function(double) onSeek;

  const ProgressBarWidget({
    super.key,
    required this.width,
    required this.factor,
    required this.bgColor,
    required this.barColor,
    required this.onSeek,
  });

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget> {
  double? _dragFactor;
  bool _isSeeking = false;

  // 노브 반지름 — 노브 크기(18px)의 절반
  static const double _knobR = 9.0;

  /// 실제 렌더된 [trackW] 기준으로 factor → 노브 left 픽셀 변환.
  /// 트랙의 유효 구간은 [_knobR, trackW - _knobR] 이므로
  /// factor=0 → knobR, factor=1 → trackW - knobR
  double _factorToLeft(double factor, double trackW) {
    final usable = (trackW - _knobR * 2).clamp(0.0, double.infinity);
    return _knobR + usable * factor - _knobR; // knobR 빼서 Positioned.left가 노브 왼쪽 끝 기준
  }

  /// 터치 위치 dx → factor 변환 (유효 구간 기준)
  double _dxToFactor(double dx, double trackW) {
    final usable = (trackW - _knobR * 2).clamp(1.0, double.infinity);
    return ((dx - _knobR) / usable).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final displayFactor = (_isSeeking && _dragFactor != null)
        ? _dragFactor!.clamp(0.0, 1.0)
        : widget.factor.clamp(0.0, 1.0);

    // LayoutBuilder로 실제 렌더 너비를 측정 → 가로/세로 전환 시 정확한 계산
    return LayoutBuilder(
      builder: (context, constraints) {
        // 부모가 주는 최대 너비를 우선 사용. 0이면 widget.width 폴백.
        final double trackW = (constraints.maxWidth > 0 && constraints.maxWidth != double.infinity)
            ? constraints.maxWidth
            : widget.width.clamp(1.0, double.infinity);

        // 노브 지름보다 작으면 렌더 불가 — 빈 박스 반환으로 크래시 방지
        if (trackW < _knobR * 2) {
          return SizedBox(width: trackW, height: 40);
        }

        // 노브 left = 트랙 시작점(0) + usable * factor — 반드시 [0, usable] 안에 있어야 함
        final double usable = (trackW - _knobR * 2).clamp(0.0, double.infinity);
        final double knobLeft = (usable * displayFactor).clamp(0.0, usable);
        // 진행 바 너비 = knobLeft + knobR (노브 중앙까지)
        final double fillW = (knobLeft + _knobR).clamp(0.0, trackW);

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final f = _dxToFactor(details.localPosition.dx, trackW);
            setState(() {
              _isSeeking = true;
              _dragFactor = f;
            });
            _handleSeek(f);
          },
          onHorizontalDragEnd: (_) async {
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) setState(() { _dragFactor = null; _isSeeking = false; });
          },
          onTapDown: (details) async {
            final f = _dxToFactor(details.localPosition.dx, trackW);
            setState(() {
              _isSeeking = true;
              _dragFactor = f;
            });
            _handleSeek(f);
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) setState(() { _dragFactor = null; _isSeeking = false; });
          },
          child: SizedBox(
            width: trackW,
            height: 40,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.centerLeft,
              children: [
                // 1. [배경 바] — 노브 반지름만큼 양쪽 안쪽에서 시작
                Positioned(
                  left: _knobR,
                  right: _knobR,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // 2. [진행 바] — 배경 바와 같은 left 기준, fillW까지
                Positioned(
                  left: _knobR,
                  child: Container(
                    width: (fillW - _knobR).clamp(0.0, trackW - _knobR * 2),
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. [노브] — knobLeft가 노브 왼쪽 끝 기준. 항상 트랙 안에 존재
                Positioned(
                  left: knobLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _knobR * 2,
                    height: _knobR * 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSeek(double ratio) {
    HapticFeedback.lightImpact();
    widget.onSeek(ratio);
  }
}

// --- 3. 재생 버튼 위젯 (PlayButtonsWidget) ---
class PlayButtonsWidget extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final double width;
  final Color bgColor;
  final Color textColor;
  final Color activeColor;

  const PlayButtonsWidget({
    super.key,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onNext,
    required this.onPrevious,
    required this.width,
    required this.bgColor,
    required this.textColor,
    required this.activeColor,
  });



  // 1. 사이드 버튼 (이전/다음): 극도로 미니멀한 투명 유리 느낌
  static Widget buildSideBtn({
    required IconData icon,
    required VoidCallback onTap,
    double size = 55,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.52,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  // 2. 메인 재생 버튼: 디자인 로직
  static Widget buildMainPlayBtn({
    required bool isPlaying,
    required Color activeColor,
    required VoidCallback onTap,
    double size = 80,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlaying
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            if (isPlaying)
              BoxShadow(
                color: activeColor.withValues(alpha: 0.3),
                blurRadius: 25,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: size * 0.52,
            color: isPlaying ? activeColor : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 💡 에러 해결: 호출 시 명명된 매개변수(icon:, onTap: 등)를 정확히 작성했습니다.
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          buildSideBtn(
            icon: Icons.skip_previous_rounded, 
            onTap: onPrevious,
          ),
          buildMainPlayBtn(
            isPlaying: isPlaying, 
            activeColor: activeColor, 
            onTap: onTogglePlay,
          ),
          buildSideBtn(
            icon: Icons.skip_next_rounded, 
            onTap: onNext,
          ),
        ],
      ),
    );
  }

}