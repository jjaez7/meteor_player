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
              filterQuality: FilterQuality.low, // 👈 성능을 위해 회전 중에는 low/medium 추천
              gaplessPlayback: true,
            )
          : Container(
              color: const Color(0xFF2D2D44),
              child: const Icon(Icons.music_note, color: Colors.white10, size: 50),
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
                        const Color(0xFF35354A).withOpacity(0.4),
                        const Color(0xFF0A0A0F).withOpacity(0.9),
                      ],
                      stops: const [0.2, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.5,
                    ),
                  ),
                ),

                // 동심원 홈 (Opacity 조절로 소프트 레이어 구현)
                ...List.generate(3, (index) => Container(
                  width: size * (0.95 - (index * 0.2)),
                  height: size * (0.95 - (index * 0.2)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
                  ),
                )),

                // 중앙 라벨 (텍스트)
                IgnorePointer(
                  child: SizedBox(
                    width: size * 0.45,
                    height: size * 0.45,
                    child: CustomPaint(
                      painter: CircularTextPainter(
                        text: "${title.toUpperCase()}  •  ${artist.toUpperCase()}  ",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: size * 0.024,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.5,
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
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                  ),
                  child: albumArt,
                ),
              ],
            ),
          ),

          // 2. 고정 반사광 (회전 연산 제외 - 성능 이점)
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
          
          // 3. 중앙 핀
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFFD1C4E9).withOpacity(0.5), blurRadius: 8),
              ],
            ),
          ),
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
                        width: 4,
                        height: height * 0.75,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 헤드쉘 (블러 대신 반투명 컬러 레이어링)
                      Container(
                        width: 20,
                        height: 35,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A4A).withOpacity(0.8), // 👈 고정색으로 처리
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Center(
                          child: Container(width: 2, height: 12, color: Colors.white24),
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
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD1C4E9).withValues(alpha: 0.1),
            blurRadius: 20,
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