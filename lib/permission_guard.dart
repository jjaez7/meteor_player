import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  bool _hasShowBootAlarm = false; // 부팅 알림 중복 방지
  int _stableFrameCount = 0; // 연속 안정 프레임 카운트

  DateTime? _lastLagTime;
  final int _lagThresholdMs = 300;

  // 테마 컬러
  final Color _accentColor = const Color(0xFFD1C4E9); // 소프트 퍼플
  final Color _bgDark = const Color(0xFF12121A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission(isInitial: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startLagDetection());
  }

  // 🚀 프레임 드랍 감지 로직
  void _startLagDetection() {
    // 앱 시작 후 5초 동안은 시스템 초기화로 인해 프레임이 튈 수 있으므로 대기
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback(_onFrame);
      }
    });
  }

  void _onFrame(Duration timestamp) {
    if (!mounted) return;

    SchedulerBinding.instance.addPostFrameCallback((Duration nextTimestamp) {
      final double frameTime =
          (nextTimestamp.inMicroseconds - timestamp.inMicroseconds) / 1000;

      // 1. 부팅 알림 로직 (안정화 확인)
      if (!_hasShowBootAlarm && _isPermissionGranted) {
        if (frameTime < 33.0) {
          // 약 30fps 이상의 안정적인 상태
          _stableFrameCount++;
        } else {
          _stableFrameCount = 0; // 프레임이 튀면 다시 카운트
        }

        // 연속으로 10프레임 이상 안정적이면 "진짜 준비됨"으로 판단
        if (_stableFrameCount > 10) {
          _hasShowBootAlarm = true;
          _showTopStatusAlarm(); // 부팅 알림 호출
        }
      }

      // 2. 기존 렉 감지 로직
      if (frameTime > _lagThresholdMs) {
        final now = DateTime.now();
        if (_lastLagTime == null ||
            now.difference(_lastLagTime!) > const Duration(seconds: 10)) {
          _lastLagTime = now;
          _showTopStatusAlarm(isLag: true, ms: frameTime.toInt());
        }
      }

      if (mounted) _onFrame(nextTimestamp);
    });
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
        // 권한이 나중에 승인되었을 때도 안정화 로직이 돌아가도록 플래그만 초기화
        if (status) {
          _stableFrameCount = 0;
        }
      }
      // 🚩 여기서 기존의 Future.delayed(1초 뒤 알림) 부분은 지워주세요!
      // 이제 _onFrame에서 프레임을 감시하다가 띄워줄 겁니다.
    } catch (e) {
      debugPrint("Access Sync Error: $e");
    }
  }

  // ✨ 상단에서 내려오는 커스텀 글래스 알림 호출
  void _showTopStatusAlarm({bool isLag = false, int ms = 0}) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TopAlarmWidget(
        accentColor: isLag ? Colors.orangeAccent : _accentColor,
        isLag: isLag,
        lagMs: ms,
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
  final bool isLag;
  final int lagMs;

  const _TopAlarmWidget({
    required this.accentColor,
    required this.onDismiss,
    this.isLag = false,
    this.lagMs = 0,
  });

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
    String label;
    if (widget.isLag) {
      label = _showVersion
          ? "CORE ENGINE OPTIMIZING..."
          : "PERFORMANCE DROP: ${widget.lagMs}ms";
    } else {
      label = _showVersion
          ? "METEOR OS v1.0.7 CORE ONLINE"
          : "SYSTEM READY: METEOR ONLINE";
    }

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
                          widget.isLag
                              ? Icons.bolt_rounded
                              : Icons.auto_awesome,
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
                              label, // 🚀 3. 동적으로 바뀐 문구 적용
                              key: ValueKey<String>(
                                label,
                              ), // 🚀 키를 문구로 설정해야 애니메이션이 작동함
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
