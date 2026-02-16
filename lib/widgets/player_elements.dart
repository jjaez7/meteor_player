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

  @override
  Widget build(BuildContext context) {
    // 이동 중일 때는 사용자의 손가락 위치를, 평소에는 재생 위치를 보여줍니다.
    final displayFactor = (_isSeeking && _dragFactor != null)
        ? _dragFactor!.clamp(0.0, 1.0)
        : widget.factor.clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _isSeeking = true;
          _dragFactor = (details.localPosition.dx / widget.width).clamp(0.0, 1.0);
        });
        _handleSeek(_dragFactor!);
      },
      onHorizontalDragEnd: (_) async {
        // 스트림 업데이트와 충돌 방지를 위한 지연 시간
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _dragFactor = null;
            _isSeeking = false;
          });
        }
      },
      onTapDown: (details) async {
        double newFactor = (details.localPosition.dx / widget.width).clamp(0.0, 1.0);
        setState(() {
          _isSeeking = true;
          _dragFactor = newFactor;
        });
        _handleSeek(newFactor);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _dragFactor = null;
            _isSeeking = false;
          });
        }
      },
      child: Container(
        width: widget.width,
        height: 40, // 조작 편의를 위한 넓은 터치 영역
        color: Colors.transparent, // 영역 시각화 방지
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. [배경 바] 불투명한 유리의 느낌 (Glass Base)
              Container(
                width: widget.width,
                height: 6, // 요즘은 아주 얇은 것보다 살짝 두께감 있는 게 트렌드
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              // 2. [진행 바] 쨍한 화이트 + 은은한 Glow 효과
              Container(
                width: widget.width * displayFactor,
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

              // 3. [노브] 물리적 버튼이 아닌, 빛나는 포인트 느낌
              Positioned(
                left: (widget.width * displayFactor) - 9,
                top: -6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      // 🚀 노브가 공중에 떠 있는 것처럼 보이게 하는 깊은 그림자
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // 노브 안쪽에 아주 작은 점을 찍어 디테일을 살립니다 (선택 사항)
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
      ),
    );
  }

  void _handleSeek(double ratio) {
    HapticFeedback.lightImpact(); // 햅틱 피드백은 짧고 간결하게
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 55,
        height: 55,
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
          size: 30,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 80,
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
            size: 45,
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
