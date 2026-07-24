import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math' as math;

/// --- [1] 글래스모피즘 LP판 위젯 (최적화 버전) ---
class VinylDisk extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;
  final Color accentColor;

  const VinylDisk({
    super.key,
    required this.controller,
    required this.size,
    this.albumArtBytes,
    this.title = "",
    this.artist = "",
    this.accentColor = const Color(0xFFB1A1D0),
  });

  @override
  Widget build(BuildContext context) {
    final Widget albumArt = ClipOval(
      child: albumArtBytes != null
          ? Image.memory(
              albumArtBytes!,
              fit: BoxFit.cover,
              filterQuality:
                  FilterQuality.low, // 👈 성능을 위해 회전 중에는 low/medium 추천
              gaplessPlayback: true,
            )
          : Container(
              color: const Color(0xFF2D2D44),
              child: const Icon(
                Icons.music_note,
                color: Colors.white10,
                size: 50,
              ),
            ),
    );

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 회전하는 베이스 (Gradient 위주)
          RotationTransition(
            turns: controller,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 디스크 본체: 블러 대신 깊이감 있는 그라데이션
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF35354A).withValues(alpha: 0.4),
                        const Color(0xFF0A0A0F).withValues(alpha: 0.9),
                      ],
                      stops: const [0.2, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                ),

                // 동심원 홈 (Opacity 조절로 소프트 레이어 구현)
                ...List.generate(
                  20,
                  (index) => Container(
                    width: size * (0.97 - (index * 0.032)),
                    height: size * (0.97 - (index * 0.032)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: index % 4 == 0 ? 0.05 : 0.02,
                        ), // 👈 밀도감
                        width: 0.5,
                      ),
                    ),
                  ),
                ),

                // 중앙 라벨 (텍스트)
                IgnorePointer(
                  child: SizedBox(
                    width: size * 0.45,
                    height: size * 0.45,
                    child: CustomPaint(
                      painter: CircularTextPainter(
                        text:
                            "${title.toUpperCase()}  •  ${artist.toUpperCase()}  ",
                        style: TextStyle(
                          color: const Color(0xFFFFE082).withValues(alpha: 0.4),
                          fontSize: size * 0.022,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // 앨범 아트
                Container(
                  width: size * 0.38,
                  height: size * 0.38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                  child: albumArt,
                ),
              ],
            ),
          ),

          // 2. 고정 반사광 + 림 라이팅 + 디스크 하이라이트 (전부 정적 레이어 —
          // 회전 애니메이션과 분리되어 있어 60fps 리빌드에 추가 비용 없음)
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 소프트 스페큘러 하이라이트: 두 개의 뭉툭한 피크 대신
                // 하나의 부드러운 하이라이트로 정리 ("never exaggerate")
                gradient: SweepGradient(
                  startAngle: 0,
                  endAngle: 2 * math.pi,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.07),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.62, 0.72, 0.82, 1.0],
                ),
              ),
            ),
          ),
          // 림 라이팅: 곡의 accentColor로 가장자리를 아주 얇게 밝힘
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.16),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.10),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
            ),
          ),
          // 디스크 하이라이트: 좌상단에서 빛이 스치는 듯한 아주 옅은 타원 반사
          Positioned(
            top: size * 0.10,
            left: size * 0.16,
            child: IgnorePointer(
              child: Container(
                width: size * 0.30,
                height: size * 0.16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.16),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. 중앙 핀
          /*Container(
            width: 10, // 8에서 조금 키워도 좋습니다.
            height: 10,
            decoration: BoxDecoration(
              // color: Colors.white, 대신 아래 그라데이션 적용
              gradient: RadialGradient(
                colors: [const Color(0xFFFFD54F), const Color(0xFF795548)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),*/
        ],
      ),
    );
  }
}

/// --- [2] 턴테이블 바늘 (블러 제거 최적화 버전) ---
class VinylNeedle extends StatelessWidget {
  final AnimationController controller;
  final double height;

  const VinylNeedle({
    super.key,
    required this.controller,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final double rotationAngle = 0.3 - (controller.value * 0.25);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              const _GlassNeedlePivot(),
              Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()..rotateZ(rotationAngle),
                child: SizedBox(
                  height: height,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 바늘 암 (반투명 라인)
                      Container(
                        width: 5,
                        height: height * 0.7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            // 👈 실버 크롬 느낌
                            colors: [Colors.grey[400]!, Colors.grey[700]!],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 헤드쉘 (블러 대신 반투명 컬러 레이어링)
                      Container(
                        width: 24,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: const BorderRadius.only(
                            // 👈 비대칭 디자인
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(12),
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Center(
                          child: Column(
                            // 🚀 기계적인 슬릿 효과
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              3,
                              (_) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                width: 12,
                                height: 1,
                                color: Colors.white10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassNeedlePivot extends StatelessWidget {
  const _GlassNeedlePivot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D34), // 👈 투명한 화이트보다 묵직한 다크 그레이
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45, // 👈 보라색 그림자보다 리얼한 검정 그림자
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class CircularTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
  ); // 👈 밖으로 추출

  CircularTextPainter({required this.text, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final double center = size.width / 2;

    double startAngle = -math.pi / 2;
    double sweepAngle = 2 * math.pi;
    double angleStep = sweepAngle / text.length;

    for (int i = 0; i < text.length; i++) {
      _textPainter.text = TextSpan(text: text[i], style: style);
      _textPainter.layout(); // 여전히 layout은 필요하지만 RepaintBoundary가 다시 호출을 막아줌

      final double charAngle = startAngle + (i * angleStep);
      final double x = center + radius * 0.95 * math.cos(charAngle);
      final double y = center + radius * 0.95 * math.sin(charAngle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(charAngle + math.pi / 2);
      _textPainter.paint(
        canvas,
        Offset(-_textPainter.width / 2, -_textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CircularTextPainter oldDelegate) {
    // 👈 텍스트나 스타일이 바뀔 때만 다시 그리도록 명시
    return oldDelegate.text != text || oldDelegate.style != style;
  }
}