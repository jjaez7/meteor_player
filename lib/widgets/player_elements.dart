import 'package:flutter/material.dart';
import '../menu/menu_main.dart';
import 'package:flutter/services.dart';

// --- 1. 상단 앱바 위젯 (PlayerTopBar) ---
class PlayerTopBar extends StatelessWidget {
  final bool isEditMode;
  final Function(bool) onEditModeChanged;
  final VoidCallback onReset;
  final Color textColor;
  final Widget menuButton; // 메인에서 넘겨받은 메뉴 버튼 사용

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "METEOR PLAYER",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontSize: 14,
              color: textColor,
            ),
          ),
          Row(
            children: [
              if (isEditMode)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.redAccent),
                  onPressed: onReset,
                  tooltip: "Layout Reset",
                ),
              IconButton(
                icon: Icon(
                  isEditMode ? Icons.check_circle : Icons.dashboard_customize,
                  color: isEditMode ? Colors.blue : textColor,
                ),
                onPressed: () => onEditModeChanged(!isEditMode),
              ),
              // 메인에서 정의된 고퀄리티 PopupMenuButton
              menuButton,
            ],
          ),
        ],
      ),
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
  bool _isSeeking = false; // 추가: 이동 중인지 확인하는 플래그

  @override
  Widget build(BuildContext context) {
    // 이동 중(Seeking)일 때는 시스템 값(widget.factor)을 무시합니다.
    final displayFactor = (_isSeeking && _dragFactor != null) 
    ? _dragFactor!.clamp(0.0, 1.0) 
    : widget.factor.clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _isSeeking = true; // 시스템 업데이트 무시 시작
          _dragFactor = (details.localPosition.dx / widget.width).clamp(0.0, 1.0);
        });
        _handleSeek(_dragFactor!);
      },
      onHorizontalDragEnd: (_) async {
        // [핵심 수정] 손을 떼고 바로 리셋하지 않고 0.5초 정도 기다립니다.
        // 네이티브에서 "나 여기까지 이동했어!"라고 스트림을 쏠 시간을 주는 것입니다.
        await Future.delayed(const Duration(milliseconds: 1000));
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
        
        // 탭 시에도 지연 후 복구
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          setState(() {
            _dragFactor = null;
            _isSeeking = false;
          });
        }
      },
      child: Container(
        width: widget.width,
        height: 30, // 터치 영역 확보
        color: Colors.transparent,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 배경 바
              Container(
                width: widget.width,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.barColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 진행 바
              Container(
                width: widget.width * displayFactor,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 노브(동그라미)
              Positioned(
                left: (widget.width * displayFactor) - 7,
                top: -5,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: widget.barColor,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                    ],
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
    // 진동을 가벼운 lightImpact로 주어 진동이 멈추지 않는 현상 해결
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSideBtn(Icons.skip_previous_rounded, onPrevious),
          GestureDetector(onTap: onTogglePlay, child: _buildMainPlayBtn()),
          _buildSideBtn(Icons.skip_next_rounded, onNext),
        ],
      ),
    );
  }

  // 이전/다음 버튼
  Widget _buildSideBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(4, 4),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              offset: const Offset(-4, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, size: 30, color: textColor.withValues(alpha: 0.8)),
      ),
    );
  }

  // 메인 재생/정지 버튼 (네오포미즘 효과 극대화)
  Widget _buildMainPlayBtn() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: isPlaying
            ? [
                // 눌린 효과 (Inner Shadow 모사)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: const Offset(2, 2),
                  blurRadius: 5,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  offset: const Offset(-2, -2),
                  blurRadius: 5,
                ),
              ]
            : [
                // 튀어나온 효과
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: const Offset(6, 6),
                  blurRadius: 15,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  offset: const Offset(-6, -6),
                  blurRadius: 15,
                ),
              ],
      ),
      child: Center(
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 40,
          color: isPlaying ? activeColor : textColor,
        ),
      ),
    );
  }
}
