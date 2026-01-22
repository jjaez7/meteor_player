import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math' as math;

/// --- [1] 고급스러운 LP판 위젯 ---
class VinylDisk extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;

  const VinylDisk({
    super.key,
    required this.controller,
    required this.size,
    this.albumArtBytes,
    this.title = "",
    this.artist = "",
  });

  @override
  Widget build(BuildContext context) {
    final Widget albumArt = ClipOval(
      child: albumArtBytes != null
          ? Image.memory(
              albumArtBytes!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium, // 고품질보다 medium이 성능에 유리함
              isAntiAlias: false,
              gaplessPlayback: true,
            )
          : Container(
              color: Colors.grey[800],
              child: const Icon(
                Icons.music_note,
                color: Colors.white24,
                size: 50,
              ),
            ),
    );

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 회전하는 레이어
          RotationTransition(
            turns: controller,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // LP 본체
                Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF2C2C2C), Color(0xFF000000)],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                
                // LP판 동심원 홈
                Opacity(
                  opacity: 0.1,
                  child: Container(
                    width: size * 0.9,
                    height: size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 0.5),
                    ),
                  ),
                ),

                // 중앙 라벨 각인 (RepaintBoundary 필수)
                IgnorePointer(
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: size * 0.45,
                      height: size * 0.45,
                      child: CustomPaint(
                        painter: CircularTextPainter(
                          text: "${title.toUpperCase()}  •  ${artist.toUpperCase()}  ",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: size * 0.025,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 중앙 앨범 아트
                Container(
                  width: size * 0.38,
                  height: size * 0.38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF121212),
                  ),
                  child: RepaintBoundary(child: albumArt),
                ),
              ],
            ),
          ),

          // 2. 고정 레이어: 반사광
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  center: Alignment.center,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // 3. 중앙 스핀들
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// --- [2] 정교한 턴테이블 바늘 위젯 ---
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
    return RepaintBoundary( // 👈 바늘 전체를 캐싱하여 GPU 연산 최적화
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final double rotationAngle = 0.3 - (controller.value * 0.25);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 1. 바늘 회전축 (Shadow 연산이 많으므로 고정 위젯으로 분리하는 것이 좋음)
              const _NeedlePivot(),

              // 2. 바늘 암(Arm) & 헤드쉘
              Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateZ(rotationAngle)
                  ..rotateX(controller.value * 0.15),
                child: SizedBox(
                  height: height,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: height * 0.7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey[400]!, Colors.grey[300]!],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(5, 10),
                              blurRadius: 10,
                            ),
                          ],
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

// 바늘 회전축 분리 (리빌드 시 영향 최소화)
class _NeedlePivot extends StatelessWidget {
  const _NeedlePivot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEEE),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

class CircularTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final TextPainter _textPainter = TextPainter(textDirection: TextDirection.ltr); // 👈 밖으로 추출

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
      _textPainter.paint(canvas, Offset(-_textPainter.width / 2, -_textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CircularTextPainter oldDelegate) {
    // 👈 텍스트나 스타일이 바뀔 때만 다시 그리도록 명시
    return oldDelegate.text != text || oldDelegate.style != style;
  }
}