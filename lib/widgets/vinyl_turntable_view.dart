import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:typed_data';
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

  bool _isScrubbing = false;
  double _scrubStartAngle = 0.0;
  double _scrubProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scrubProgress = widget.progress;
    // 초기 상태: 재생 중이면 착지(1.0), 정지면 대기(0.0)
    _tonearmController.value = widget.isPlaying ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant VinylTurntableView old) {
    super.didUpdateWidget(old);

    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        // 재생 시작 → LP 위로 착지 (0.0 → 1.0)
        _tonearmController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
        );
      } else {
        // 정지 → LP 바깥으로 올라감 (1.0 → 0.0)
        _tonearmController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInCubic,
        );
      }
    }

    if (!_isScrubbing) {
      _scrubProgress = widget.progress;
    }
  }

  @override
  void dispose() {
    _tonearmController.dispose();
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
    final double lpCX = boxW * 0.34;
    final double lpCY = boxH * 0.50;

    return SizedBox(
      width: boxW,
      height: boxH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ① 글래스모피즘 플린스 (배경)
          _buildGlassPlinth(boxW, boxH),

          // ② 플래터 (금속 원판)
          Positioned(
            left: lpCX - lpSize * 0.54,
            top: lpCY - lpSize * 0.54,
            child: _buildPlatter(lpSize),
          ),

          // ③ LP 디스크
          Positioned(
            left: lpCX - lpSize / 2,
            top: lpCY - lpSize / 2,
            child: GestureDetector(
              onPanStart: (d) {
                _isScrubbing = true;
                _scrubStartAngle = _angleFromCenter(
                    d.localPosition, Offset(lpSize / 2, lpSize / 2));
                _scrubProgress = widget.progress;
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
                HapticFeedback.selectionClick();
              },
              onPanEnd: (_) {
                _isScrubbing = false;
                widget.onSeek(_scrubProgress);
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
          ),

          // ④ 황금 스핀들 캡
          Positioned(
            left: lpCX - 6,
            top: lpCY - 6,
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

          // ⑤ 톤암 (바늘)
          Positioned(
            right: boxW * 0.02,
            top: lpCY - lpSize * 0.12,
            child: _TonearmWidget(
              lpController: widget.lpController,
              tonearmController: _tonearmController,
              progress: widget.isPlaying
                  ? (_isScrubbing ? _scrubProgress : widget.progress)
                  : 0.0,
              lpRadius: lpSize / 2,
              accentColor: widget.accentColor,
              onTap: widget.onPlayPause,
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
  final AnimationController lpController;
  final AnimationController tonearmController;
  final double progress;
  final double lpRadius;
  final Color accentColor;
  final VoidCallback onTap;

  const _TonearmWidget({
    required this.lpController,
    required this.tonearmController,
    required this.progress,
    required this.lpRadius,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([tonearmController, lpController]),
      builder: (context, _) {
        // ── 각도 정의 (단위: radians)
        // restAngle     = 대기 위치 각도 (LP 바깥쪽, 오른쪽으로 많이 젖혀짐)
        // playStartAngle = 재생 시작 각도 (LP 외곽 그루브 위)
        // playEndAngle  = 재생 끝 각도   (LP 중심 그루브 위)
        const double restAngle = 0.74;      // ~42° — 대기(정지) 시 바깥 위치
        const double playStartAngle = 0.27; // ~15° — 재생 시작 (LP 외곽)
        const double playEndAngle = 0.04;   // ~2°  — 재생 끝   (LP 중심)

        // tonearmController.value 의미:
        //   0.0 → restAngle (대기/정지)
        //   1.0 → playAngle (재생)
        final double landFactor = tonearmController.value; // 0.0~1.0

        // 재생 중 진행도에 따라 바늘 각도 계산
        final double playAngle =
            playStartAngle + (playEndAngle - playStartAngle) * progress;

        // 최종 각도: restAngle ↔ playAngle 사이를 landFactor로 lerp
        // landFactor=0 → restAngle (정지, 바깥)
        // landFactor=1 → playAngle (재생, LP 위)
        final double finalAngle =
            restAngle + (playAngle - restAngle) * landFactor;

        final double armLen = lpRadius * 1.32;

        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: lpRadius * 0.82,
            height: armLen + 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // 피벗(회전축)
                _buildPivot(),

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
                      Transform.rotate(
                        angle: -0.22,
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

                      // 헤드쉘
                      Transform.rotate(
                        angle: -0.28,
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