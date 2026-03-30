import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'vinyl_component.dart';
import 'dart:ui' as ui;

/// === GLASNYL 턴테이블 뷰 (글래스모피즘) ===
///
/// 바늘(톤암) 방향 규칙:
///   재생 → 톤암이 LP 위로 내려옴  (tonearmController: 0.0 → 1.0)
///   정지 → 톤암이 LP 바깥으로 올라감 (tonearmController: 1.0 → 0.0)
///
/// [Controller 의미]
///   0.0 = 대기 위치 (LP 오른쪽 바깥으로 젖혀진 상태)
///   1.0 = 재생 위치 (LP 표면 위 착지)
///
/// [Progress]
///   0.0 = LP 외곽 트랙 / 1.0 = LP 중심 트랙
class VinylTurntableView extends StatefulWidget {
  final AnimationController lpController;
  final double size;           // 전체 뷰의 너비 기준
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;
  final bool isPlaying;
  final double progress;       // 0.0 ~ 1.0
  final Stream<double>? progressStream; // player_screen에서 단일 구독 후 분배
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(double ratio) onSeek;
  final Color accentColor;
  final Color bgColor;

  const VinylTurntableView({
    super.key,
    required this.lpController,
    required this.size,
    this.albumArtBytes,
    required this.title,
    required this.artist,
    required this.isPlaying,
    required this.progress,
    this.progressStream,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
    required this.accentColor,
    required this.bgColor,
  });

  @override
  State<VinylTurntableView> createState() => _VinylTurntableViewState();
}

class _VinylTurntableViewState extends State<VinylTurntableView>
    with TickerProviderStateMixin {

  /// tonearmController:
  ///   0.0 = 대기(LP 바깥)
  ///   1.0 = 재생(LP 위 착지)
  late AnimationController _tonearmController;

  /// progress 전용 컨트롤러 — value(0.0~1.0)가 곧 바늘 위치
  /// - 시크: animateTo()로 부드럽게 보간
  /// - 일반 재생: value = 직접 세팅 (notify → AnimatedBuilder 즉시 리빌드)
  late AnimationController _progressController;

  bool _isScrubbing = false;
  double _scrubStartAngle = 0.0;
  double _scrubProgress = 0.0;

  // ── progressStream 구독 (player_screen에서 단일 구독 후 분배받음)
  StreamSubscription? _mediaStatusSub;
  double _lastStreamProgress = 0.0;

  // ── Haptic throttle (onPanUpdate 매 이벤트 → 80ms 제한)
  DateTime? _lastHaptic;

  @override
  void initState() {
    super.initState();

    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // value = 현재 progress로 초기화 (0.0~1.0)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.progress,
    );

    _scrubProgress = widget.progress;
    _lastStreamProgress = widget.progress;

    // 초기 상태: 재생 중이면 착지(1.0), 정지면 대기(0.0)
    _tonearmController.value = widget.isPlaying ? 1.0 : 0.0;

    // ── progressStream 구독 (EventChannel 직접 구독 제거 → 이중 구독 해소)
    // player_screen의 단일 media_status 구독에서 분배받음
    if (widget.progressStream != null) {
      _mediaStatusSub = widget.progressStream!.listen((newP) {
        if (_isScrubbing) return;
        final double diff = (newP - _lastStreamProgress).abs();
        if (diff > 0.0001) {
          _lastStreamProgress = newP;
          if (diff > 0.02) {
            _progressController.animateTo(
              newP,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            );
          } else {
            _progressController.value = newP;
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant VinylTurntableView old) {
    super.didUpdateWidget(old);

    // ── 재생/정지 전환: 착지 & 들림 애니메이션
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _tonearmController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
        );
      } else {
        _tonearmController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInCubic,
        );
      }
    }

    // ── 시크바 점프: prop으로 큰 변화가 오면 즉시 동기화
    if (!_isScrubbing) {
      _scrubProgress = widget.progress;
      final double diff = (widget.progress - _progressController.value).abs();
      if (diff > 0.02) {
        _lastStreamProgress = widget.progress;
        _progressController.animateTo(
          widget.progress,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _mediaStatusSub?.cancel();
    _tonearmController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  double _angleFromCenter(Offset pos, Offset center) =>
      math.atan2(pos.dy - center.dy, pos.dx - center.dx);

  @override
  Widget build(BuildContext context) {
    final double boxW = widget.size;
    final double lpSize = boxW * 0.62;
    final double boxH = boxW * 0.72; // 하단 컨트롤 패널 없으므로 더 콤팩트

    // LP 중심 (박스 내 절대 좌표)
    final double lpCX = boxW * 0.41;
    final double lpCY = boxH * 0.50;

    return SizedBox(
      width: boxW,
      height: boxH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ① 글래스모피즘 플린스 (배경) — 정적이므로 RepaintBoundary로 격리
          RepaintBoundary(child: _buildGlassPlinth(boxW, boxH)),

          // ② 플래터 (금속 원판) — 정적이므로 RepaintBoundary로 격리
          Positioned(
            left: lpCX - lpSize * 0.54,
            top: lpCY - lpSize * 0.54,
            child: RepaintBoundary(child: _buildPlatter(lpSize)),
          ),

          // ③ LP 디스크 — 회전 애니메이션만 이 레이어에 격리
          Positioned(
            left: lpCX - lpSize / 2,
            top: lpCY - lpSize / 2,
            child: RepaintBoundary(
            child: GestureDetector(
              onPanStart: (d) {
                _isScrubbing = true;
                _progressController.stop();
                _scrubStartAngle = _angleFromCenter(
                    d.localPosition, Offset(lpSize / 2, lpSize / 2));
                _scrubProgress = _progressController.value;
                HapticFeedback.selectionClick();
              },
              onPanUpdate: (d) {
                final a = _angleFromCenter(
                    d.localPosition, Offset(lpSize / 2, lpSize / 2));
                double delta = a - _scrubStartAngle;
                if (delta > math.pi) delta -= 2 * math.pi;
                if (delta < -math.pi) delta += 2 * math.pi;
                setState(() {
                  _scrubProgress =
                      (_scrubProgress + delta / (2 * math.pi) * 0.05)
                          .clamp(0.0, 1.0);
                });
                _scrubStartAngle = a;
                // Haptic throttle: 80ms 이내 중복 진동 방지
                final now = DateTime.now();
                if (_lastHaptic == null ||
                    now.difference(_lastHaptic!) >
                        const Duration(milliseconds: 80)) {
                  HapticFeedback.selectionClick();
                  _lastHaptic = now;
                }
              },
              onPanEnd: (_) {
                final double seekTarget = _scrubProgress;
                _lastStreamProgress = seekTarget;
                _progressController.animateTo(
                  seekTarget,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
                _isScrubbing = false;
                widget.onSeek(seekTarget);
                HapticFeedback.mediumImpact();
              },
              child: VinylDisk(
                controller: widget.lpController,
                size: lpSize,
                albumArtBytes: widget.albumArtBytes,
                title: widget.title,
                artist: widget.artist,
              ),
            ),
            ), // RepaintBoundary (LP 디스크)
          ),

          // ④ 황금 스핀들 캡 — 정적, RepaintBoundary로 격리
          Positioned(
            left: lpCX - 6,
            top: lpCY - 6,
            child: RepaintBoundary(
              child: IgnorePointer(
                child: Container(
                  width: 12, height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD4AF37),
                    boxShadow: [
                      BoxShadow(color: Colors.black45, blurRadius: 4, spreadRadius: 1)
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ⑤ 톤암 (바늘)
          // lpController 제거: LP 회전(60fps)마다 톤암이 리빌드되는 문제 해결
          // RepaintBoundary로 톤암 레이어를 LP 디스크 레이어와 완전 분리
          Positioned(
            right: boxW * 0.06,
            top: lpCY - lpSize * 0.12,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_tonearmController, _progressController]),
                builder: (context, _) {
                  final double tonearmProgress = _isScrubbing
                      ? _scrubProgress
                      : (widget.isPlaying ? _progressController.value : 0.0);
                  return _TonearmWidget(
                    tonearmController: _tonearmController,
                    progress: tonearmProgress,
                    lpRadius: lpSize / 2,
                    accentColor: widget.accentColor,
                    onTap: widget.onPlayPause,
                  );
                },
              ),
            ),
          ),

          // ⑥ 스크러빙 오버레이
          if (_isScrubbing)
            Positioned(
              left: lpCX - 40,
              top: lpCY - 18,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _fmtProgress(_scrubProgress),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtProgress(double p) {
    final s = (p * 100).round();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ── 글래스모피즘 플린스 (월넛 대신 반투명 유리)
  Widget _buildGlassPlinth(double w, double h) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(w * 0.05),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: w, height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(w * 0.05),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          // 상단 하이라이트 줄
          child: Column(
            children: [
              Container(
                height: 1,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(w * 0.05)),
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.4),
                    Colors.transparent,
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 플래터 (LP 받침 금속 원판)
  Widget _buildPlatter(double lpSize) {
    final ps = lpSize * 1.08;
    return Container(
      width: ps, height: ps,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF4A4A52), Color(0xFF2D2D34), Color(0xFF1A1A20)],
          stops: [0.3, 0.8, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 20, offset: const Offset(0, 6), spreadRadius: 2,
          ),
        ],
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(5, (i) => Container(
          width: ps * (0.95 - i * 0.14),
          height: ps * (0.95 - i * 0.14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.03), width: 0.5),
          ),
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 톤암 위젯
//
// tonearmController:
//   0.0 = 대기 위치 (LP 오른쪽 바깥으로 젖혀진 상태) ← 정지 시
//   1.0 = 재생 위치 (LP 표면 착지)               ← 재생 시
//
// progress: 0.0 = LP 외곽 그루브 / 1.0 = LP 중심 그루브
// ─────────────────────────────────────────────────────────────────────────────
class _TonearmWidget extends StatelessWidget {
  // lpController 제거: LP 회전과 톤암은 독립적인 레이어 — 불필요한 60fps 리빌드 차단
  final AnimationController tonearmController;
  final double progress;
  final double lpRadius;
  final Color accentColor;
  final VoidCallback onTap;

  const _TonearmWidget({
    required this.tonearmController,
    required this.progress,
    required this.lpRadius,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tonearmController,
      builder: (context, _) {
        // ── 각도 정의 (단위: radians)
        //
        // 레이아웃: 피벗(오른쪽) — LP 중심(왼쪽)
        // Transform(alignment: Alignment.topCenter).rotateZ 기준:
        //   암의 기본방향 = 아래(+Y)
        //   양수(+) = 시계방향  → 암이 오른쪽으로 기울어짐 (LP 바깥, 대기)
        //   음수(-) = 반시계   → 암이 왼쪽으로 기울어짐  (LP 방향, 재생)
        //
        // 재생 시: restAngle(양수) → playAngle(음수) = 시계방향 회전으로 LP 위에 착지 ✓
        // 정지 시: playAngle(음수) → restAngle(양수) = 반시계방향 회전으로 LP 바깥으로 들림 ✓
        const double restAngle = -0.15;      // 대기: LP에 더 가깝게
        const double playStartAngle = 0.65;  // 재생 시작: 이동 각도 줄임
        const double playEndAngle = 0.90;    // 재생 끝: LP 내곽 방향

        // tonearmController.value 의미:
        //   0.0 → restAngle (대기/정지)
        //   1.0 → playAngle (재생)
        final double landFactor = tonearmController.value; // 0.0~1.0

        // 재생 중 진행도에 따라 바늘 각도 계산
        final double playAngle =
            playStartAngle + (playEndAngle - playStartAngle) * progress;

        // 최종 각도: restAngle ↔ playAngle 사이를 landFactor로 lerp
        // landFactor=0 → restAngle (정지, 오른쪽 바깥)
        // landFactor=1 → playAngle (재생, LP 위)
        final double finalAngle =
            restAngle + (playAngle - restAngle) * landFactor;

        // 피벗→LP 외곽까지 실제 거리에 맞춘 암 길이
        final double armLen = lpRadius * 1.1;

        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: lpRadius * 0.82,
            height: armLen + 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // 암 본체
                Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()..rotateZ(finalAngle),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 19),

                      // 암 바 (크롬 느낌)
                      Container(
                        width: 6, height: armLen * 0.63,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(colors: [
                            Color(0xFFD4D4DC),
                            Color(0xFF808088),
                            Color(0xFFD4D4DC),
                          ]),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6, offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),

                      // 헤드쉘 조인트 꺾임
                      // 암이 음수 각도(왼쪽=LP 방향)로 내려올 때
                      // 헤드쉘은 LP 중심을 향해 시계방향(+)으로 꺾여야 함
                      Transform.rotate(
                        angle: 0.22,
                        child: Container(
                          width: 14, height: armLen * 0.09,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(colors: [
                              Color(0xFFC0C0C8), Color(0xFF707078)
                            ]),
                          ),
                        ),
                      ),

                      // 헤드쉘 (LP 중심 방향으로 시계방향 꺾임)
                      Transform.rotate(
                        angle: 0.28,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22, height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C24),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 8, offset: const Offset(2, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (_) => Container(
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    width: 12, height: 1,
                                    color: Colors.white.withValues(alpha: 0.1),
                                  )),
                                ),
                              ),
                            ),
                            // 스타일러스 바늘
                            Container(
                              width: 2, height: 7,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                            // 다이아몬드 포인트
                            Container(
                              width: 4, height: 4,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.65),
                                    blurRadius: 6, spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 피벗(회전축) — 암 위에 그려서 겹치는 부분 가림
                _buildPivot(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPivot() {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF5A5A62), Color(0xFF2A2A32)]),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 10, spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              accentColor.withValues(alpha: 0.9),
              accentColor.withValues(alpha: 0.3),
            ]),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.45),
                blurRadius: 6, spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}