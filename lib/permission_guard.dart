import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionGuard extends StatefulWidget {
  final Widget child;
  final bool isPlaying;

  const PermissionGuard({
    super.key,
    required this.child,
    this.isPlaying = false,
  });

  @override
  State<PermissionGuard> createState() => PermissionGuardState();
}

class PermissionGuardState extends State<PermissionGuard>
    with WidgetsBindingObserver {
  bool _isPermissionGranted = true;
  bool _hasShowBootAlarm = false; // 부팅 알림 중복 방지
  int _stableFrameCount = 0; // 연속 안정 프레임 카운트

  DateTime? _lastBackPressTime;

  DateTime? _lastLagTime;
  final int _lagThresholdMs = 300;

  // 테마 컬러
  final Color _accentColor = const Color(0xFFD1C4E9); // 소프트 퍼플
  final Color _bgDark = const Color(0xFF12121A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🚀 수정 1: 화면이 먼저 뜬 후, 1.5초 뒤에 권한을 체크합니다. (먹통 방지)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _checkPermission(isInitial: true);
      }
    });

    // 🚀 수정 2: 프레임 감지 로직도 UI가 완전히 안정된 후에 시작하도록 예약합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startLagDetection();
      }
    });
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
          showTopStatusAlarm(); // 부팅 알림 호출
        }
      }

      // 2. 기존 렉 감지 로직
      if (widget.isPlaying && frameTime > _lagThresholdMs) {
        final now = DateTime.now();
        if (_lastLagTime == null ||
            now.difference(_lastLagTime!) > const Duration(seconds: 10)) {
          _lastLagTime = now;
          showTopStatusAlarm(isLag: true, ms: frameTime.toInt());
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

      audioHandler.refreshMetadata();
    }
  }

  Future<void> _checkPermission({bool isInitial = false}) async {
    try {
      // 초기 지연 (네이티브 안정화 대기)
      //if (isInitial) await Future.delayed(const Duration(milliseconds: 500));

      final bool notificationStatus =
          await NotificationListenerService.isPermissionGranted();

      bool audioStatus = true;
      if (Platform.isAndroid) {
        // Android 13 이상은 audio, 이하는 storage 체크
        if (await Permission.audio.isGranted ||
            await Permission.storage.isGranted) {
          audioStatus = true;
        } else {
          audioStatus = false;
        }
      }

      final bool totalStatus = notificationStatus && audioStatus;

      if (mounted && _isPermissionGranted != totalStatus) {
        setState(() {
          _isPermissionGranted = totalStatus;
        });
      }
    } catch (e) {
      // 에러 발생 시 앱이 튕기지 않도록 false 처리
      if (mounted) setState(() => _isPermissionGranted = false);
    }
  }

  // ✨ 상단에서 내려오는 커스텀 글래스 알림 호출
  void showTopStatusAlarm({
    bool isLag = false,
    int ms = 0,
    bool isSyncing = false,
    bool isExitWarning = false,
  }) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TopAlarmWidget(
        accentColor: (isLag || isExitWarning)
            ? Colors.orangeAccent
            : _accentColor,
        isLag: isLag,
        isSyncing: isSyncing,
        isExitWarning: isExitWarning,
        lagMs: ms,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 시스템 수준의 뒤로가기 기본 동작을 막음
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;

          // 🚀 이제 isSyncing이 아니라 isExitWarning을 true로 보냅니다.
          showTopStatusAlarm(isExitWarning: true);

          debugPrint("GLASNYL OS: Press back again to shutdown.");
        } else {
          exit(0);
        }
      },

      child: Scaffold(
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
                          "To sync the high-fidelity vinyl engine,\nplease enable Audio and Notification Access.",
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
                          try {
                            // 1. 알림 권한 설정창 열기 (사용자가 직접 허용해야 함)
                            await NotificationListenerService.requestPermission();

                            // 2. 혹시 미디어 권한이 여전히 없다면 여기서 한 번 더 요청 (안전장치)
                            if (Platform.isAndroid) {
                              await [
                                Permission.audio,
                                Permission.storage,
                              ].request();
                            }

                            // 3. 사용자가 돌아오길 기다렸다가 상태 새로고침
                            Future.delayed(
                              const Duration(milliseconds: 1000),
                              () {
                                if (mounted) _checkPermission();
                              },
                            );
                          } catch (e) {
                            debugPrint("Grant Access Error: $e");
                          }
                        }),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
  final bool isSyncing;
  final bool isExitWarning;

  const _TopAlarmWidget({
    required this.accentColor,
    required this.onDismiss,
    this.isLag = false,
    this.lagMs = 0,
    this.isSyncing = false,
    this.isExitWarning = false,
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
    // 1. 화면 사이즈 감지
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    // 플립 커버 스크린 여부 판단 (보통 세로가 500px 미만)
    final bool isSmallScreen = screenHeight < 500;

    String label;
    if (widget.isExitWarning) {
      // 🚀 뒤로가기 경고 전용 (isExitWarning이 true일 때)
      label = _showVersion
          ? "PRESS BACK AGAIN TO SHUTDOWN"
          : "SYSTEM EXIT RESTRICTED";
    } else if (widget.isSyncing) {
      // ✅ 기존에 찾으시던 로직 그대로 유지!
      label = _showVersion
          ? "GLASYNL ENGINE STABILIZED"
          : "SYSTEM RE-SYNCING...";
    } else if (widget.isLag) {
      label = _showVersion
          ? "CORE ENGINE OPTIMIZING..."
          : "PERFORMANCE DROP: ${widget.lagMs}ms";
    } else {
      label = _showVersion
          ? "GLASNYL OS v$appVersion CORE ONLINE"
          : "SYSTEM READY: GLASNYL ONLINE";
    }

    return SafeArea(
      // 2. 작은 화면에서는 상단 여백을 최소화
      top: true,
      bottom: false,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 24, // 옆 간격 축소
              vertical: isSmallScreen ? 8 : 20, // 위 간격 축소
            ),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    // 3. 작은 화면에서 너무 길어지지 않게 최대 너비 제한
                    constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 14 : 20,
                      vertical: isSmallScreen ? 10 : 16, // 높이 대폭 축소
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        isSmallScreen ? 12 : 20,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isExitWarning
                              ? Icons
                                    .warning_amber_rounded // 1. 종료 경고일 때 아이콘
                              : (widget.isSyncing
                                    ? Icons
                                          .sync_problem_rounded // 2. 기존 싱크 중일 때 아이콘
                                    : (widget.isLag
                                          ? Icons
                                                .bolt_rounded // 3. 렉 걸렸을 때 아이콘
                                          : Icons.auto_awesome)), // 4. 기본 아이콘
                          color: widget.accentColor,
                          size: isSmallScreen ? 14 : 18, // 아이콘 크기 조절
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 14),
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
                              label,
                              key: ValueKey<String>(label),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 9 : 11, // 폰트 크기 조절
                                fontWeight: FontWeight.w900,
                                letterSpacing: isSmallScreen ? 1.0 : 1.5,
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
