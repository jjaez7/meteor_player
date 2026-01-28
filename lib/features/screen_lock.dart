import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenLockOverlay extends StatelessWidget {
  final VoidCallback onUnlock;

  const ScreenLockOverlay({super.key, required this.onUnlock});

  void _showUnlockNotification(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TopAlarmWidget(
        accentColor: const Color(0xFFD1C4E9), // 기존 PermissionGuard와 동일한 색상
        label: "SCREEN UNLOCKED",
        subLabel: "SYSTEM ACCESS RESTORED",
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.mediumImpact(); // 햅틱 피드백
        _showUnlockNotification(context); // 상단 커스텀 알림 호출
        onUnlock(); // 잠금 해제 실행
      },
      child: RepaintBoundary(
        child: Stack(
          children: [
            Container(color: Colors.black.withValues(alpha: 0.25)),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const SizedBox.expand(),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "LOCKED",
                    style: TextStyle(
                      color: Colors.white,
                      letterSpacing: 6,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Hold to unlock",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopAlarmWidget extends StatefulWidget {
  final Color accentColor;
  final String label;
  final String subLabel;
  final VoidCallback onDismiss;

  const _TopAlarmWidget({
    required this.accentColor,
    required this.label,
    required this.subLabel,
    required this.onDismiss,
  });

  @override
  State<_TopAlarmWidget> createState() => _TopAlarmWidgetState();
}

class _TopAlarmWidgetState extends State<_TopAlarmWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool _showSub = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    // 1초 후 보조 문구 표시
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showSub = true);
    });

    // 3초 후 자동 닫힘
    Future.delayed(const Duration(milliseconds: 3000), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSmall = MediaQuery.of(context).size.height < 500;
    final String currentText = _showSub ? widget.subLabel : widget.label;

    return SafeArea(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 20),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isSmall ? 12 : 20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(isSmall ? 12 : 20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, 
                             color: widget.accentColor, size: 16),
                        const SizedBox(width: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            currentText,
                            key: ValueKey(currentText),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmall ? 10 : 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}