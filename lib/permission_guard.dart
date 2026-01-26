import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

class PermissionGuard extends StatefulWidget {
  final Widget child;

  const PermissionGuard({super.key, required this.child});

  @override
  State<PermissionGuard> createState() => _PermissionGuardState();
}

class _PermissionGuardState extends State<PermissionGuard>
    with WidgetsBindingObserver {
  bool _isPermissionGranted = true;

  // 테마 컬러
  final Color _accentColor = const Color(0xFFD1C4E9); // 소프트 퍼플
  final Color _bgDark = const Color(0xFF12121A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission(isInitial: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission({bool isInitial = false}) async {
    try {
      final bool status =
          await NotificationListenerService.isPermissionGranted();
      if (_isPermissionGranted != status) {
        setState(() => _isPermissionGranted = status);
        if (status) _showTopStatusAlarm();
      } else if (isInitial && status) {
        // 앱 시작 시 권한이 이미 있다면 1초 뒤 표시
        Future.delayed(const Duration(seconds: 1), () => _showTopStatusAlarm());
      }
    } catch (e) {
      debugPrint("Access Sync Error: $e");
    }
  }

  // ✨ 상단에서 내려오는 커스텀 글래스 알림 호출
  void _showTopStatusAlarm() {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TopAlarmWidget(
        accentColor: _accentColor,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // 배경: 메인 앱 콘텐츠
          widget.child,

          // [Permission Overlay] 권한 미승인 시 나타나는 글래스 레이어
          if (!_isPermissionGranted)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- 글로우 아이콘 쉴드 ---
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock_open_rounded,
                          color: _accentColor,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 50),
                      const Text(
                        "CORE ACCESS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "To sync the high-fidelity vinyl engine,\nplease enable Notification Access.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 70),

                      // --- 글래스모피즘 액션 버튼 ---
                      _buildGlassButton("GRANT ACCESS", () async {
                        // 1. 설정 창 열기
                        await NotificationListenerService.requestPermission();

                        // 2. 사용자가 설정 마치고 돌아올 때를 대비해 살짝 지연 후 상태 체크
                        Future.delayed(const Duration(milliseconds: 500), () {
                          _checkPermission();
                        });
                      }),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 상단 알림 전용 위젯 (애니메이션 포함) ---
class _TopAlarmWidget extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onDismiss;

  const _TopAlarmWidget({required this.accentColor, required this.onDismiss});

  @override
  State<_TopAlarmWidget> createState() => _TopAlarmWidgetState();
}

class _TopAlarmWidgetState extends State<_TopAlarmWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  bool _showVersion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _offsetAnimation =
        Tween<Offset>(
          begin: const Offset(0, -1.5),
          end: const Offset(0, 0),
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic, // 부드럽게 감속하며 들어오는 효과
          ),
        );

    _controller.forward();

    // 2. 텍스트 전환 타이머: 1.5초 후 버전 표시
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showVersion = true);
      }
    });

    // 3. 전체 닫기 타이머: 문구를 다 볼 수 있게 4.5초로 연장
    Future.delayed(const Duration(milliseconds: 4500), () async {
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
    return SafeArea(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: widget.accentColor,
                          size: 18,
                        ),
                        const SizedBox(width: 14),

                        // 4. Flexible 내부를 AnimatedSwitcher로 교체
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                            child: Text(
                              _showVersion
                                  ? "METEOR OS v1.0.4 CORE ONLINE" // 전환 후 문구
                                  : "SYSTEM READY: METEOR ONLINE", // 처음 문구
                              key: ValueKey<bool>(
                                _showVersion,
                              ), // 키가 바뀌어야 애니메이션 작동
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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
