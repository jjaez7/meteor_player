import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// 인스타 공유용 Now Playing 카드
/// vinyl_component.dart 의 VinylDisk 디자인 적용
class NowPlayingCard extends StatelessWidget {
  final GlobalKey cardKey;
  final String title;
  final String artist;
  final Uint8List? albumArtBytes;
  final Color bgColor;
  final Color accentColor;
  final Color textColor;

  const NowPlayingCard({
    super.key,
    required this.cardKey,
    required this.title,
    required this.artist,
    required this.albumArtBytes,
    required this.bgColor,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    const double cardW = 360;
    const double cardH = 640;
    const double vinylSize = 280;

    return RepaintBoundary(
      key: cardKey,
      child: SizedBox(
        width: cardW,
        height: cardH,
        child: Stack(
          children: [
            // ── 1. 블러 배경
            _Background(
              albumArtBytes: albumArtBytes,
              bgColor: bgColor,
              accentColor: accentColor,
              cardW: cardW,
              cardH: cardH,
            ),

            // ── 2. 상단 미묘한 노이즈 텍스처 효과 (그라디언트 레이어)
            Positioned.fill(
              child: CustomPaint(painter: _NoiseOverlayPainter()),
            ),

            // ── 3. LP 판 (중앙 약간 위, 살짝 기울어진 느낌)
            Positioned(
              left: cardW / 2 - vinylSize / 2,
              top: 90,
              child: _StaticVinylDisk(
                albumArtBytes: albumArtBytes,
                accentColor: accentColor,
                size: vinylSize,
                title: title,
                artist: artist,
              ),
            ),

            // ── 4. 하단 정보 영역
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomInfo(
                title: title,
                artist: artist,
                accentColor: accentColor,
                cardW: cardW,
              ),
            ),

            // ── 5. 좌상단 미니 워터마크 (앱 이름만, 심플하게)
            Positioned(
              top: 24,
              left: 24,
              child: Text(
                'GLASNYL',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 배경
// ════════════════════════════════════════════════════════════
class _Background extends StatelessWidget {
  final Uint8List? albumArtBytes;
  final Color bgColor;
  final Color accentColor;
  final double cardW;
  final double cardH;

  const _Background({
    required this.albumArtBytes,
    required this.bgColor,
    required this.accentColor,
    required this.cardW,
    required this.cardH,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 앨범아트 배경
        if (albumArtBytes != null)
          SizedBox(
            width: cardW,
            height: cardH,
            child: Image.memory(albumArtBytes!, fit: BoxFit.cover),
          )
        else
          Container(
            width: cardW,
            height: cardH,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(bgColor, Colors.black, 0.4)!,
                  Color.lerp(bgColor, accentColor, 0.15)!,
                  Color.lerp(bgColor, Colors.black, 0.6)!,
                ],
              ),
            ),
          ),

        // 강한 블러
        if (albumArtBytes != null)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),

        // 어두운 오버레이 — 상단 밝게, 하단 더 어둡게 (텍스트 가독성)
        Container(
          width: cardW,
          height: cardH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.30),
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0.80),
              ],
              stops: const [0.0, 0.40, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// 노이즈 오버레이 (필름 그레인 느낌)
// ════════════════════════════════════════════════════════════
class _NoiseOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 800; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble() * 0.03;
      paint.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════
// LP 판 — vinyl_component.dart VinylDisk 디자인 정적 버전
// (카드는 정지 이미지라 AnimationController 불필요)
// ════════════════════════════════════════════════════════════
class _StaticVinylDisk extends StatelessWidget {
  final Uint8List? albumArtBytes;
  final Color accentColor;
  final double size;
  final String title;
  final String artist;

  const _StaticVinylDisk({
    required this.albumArtBytes,
    required this.accentColor,
    required this.size,
    required this.title,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final Widget albumArt = ClipOval(
      child: albumArtBytes != null
          ? Image.memory(
              albumArtBytes!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            )
          : Container(
              color: const Color(0xFF2D2D44),
              child: Icon(
                Icons.music_note,
                color: Colors.white.withValues(alpha: 0.15),
                size: size * 0.18,
              ),
            ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── 디스크 본체
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF35354A).withValues(alpha: 0.5),
                  const Color(0xFF0A0A0F).withValues(alpha: 0.95),
                ],
                stops: const [0.2, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 60,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),

          // ── 동심원 홈 (vinyl_component 스타일 그대로)
          ...List.generate(
            22,
            (index) => Container(
              width: size * (0.97 - (index * 0.030)),
              height: size * (0.97 - (index * 0.030)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: index % 4 == 0 ? 0.055 : 0.022,
                  ),
                  width: 0.5,
                ),
              ),
            ),
          ),

          // ── 중앙 원형 텍스트 레이블
          IgnorePointer(
            child: SizedBox(
              width: size * 0.45,
              height: size * 0.45,
              child: CustomPaint(
                painter: _CircularTextPainter(
                  text: "${title.toUpperCase()}  •  ${artist.toUpperCase()}  ",
                  style: TextStyle(
                    color: const Color(0xFFFFE082).withValues(alpha: 0.35),
                    fontSize: size * 0.022,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ),

          // ── 앨범아트 중앙 원
          Container(
            width: size * 0.38,
            height: size * 0.38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: albumArt,
          ),

          // ── 고정 반사광 (vinyl_component SweepGradient 그대로)
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.05),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 하단 정보 패널 — 심플 & 클린
// ════════════════════════════════════════════════════════════
class _BottomInfo extends StatelessWidget {
  final String title;
  final String artist;
  final Color accentColor;
  final double cardW;

  const _BottomInfo({
    required this.title,
    required this.artist,
    required this.accentColor,
    required this.cardW,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 재생 중 인디케이터 (작고 심플)
              Row(
                children: [
                  _MiniEqBars(color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'NOW PLAYING',
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 제목
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.15,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 아티스트
              Text(
                artist.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                ),
              ),

              const SizedBox(height: 20),

              // 구분선
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.15),
              ),

              const SizedBox(height: 16),

              // 하단 행 — 좌: LP 아이콘 태그, 우: GLASNYL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LP 태그
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(GRadius.mediumCard),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.album_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 11,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Vinyl',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 워터마크
                  Text(
                    'GLASNYL',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.22),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 미니 EQ 바 (정적)
// ════════════════════════════════════════════════════════════
class _MiniEqBars extends StatelessWidget {
  final Color color;
  const _MiniEqBars({required this.color});

  @override
  Widget build(BuildContext context) {
    final heights = [5.0, 9.0, 6.0, 11.0, 7.0, 4.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights.map((h) {
        return Container(
          width: 2.5,
          height: h,
          margin: const EdgeInsets.only(right: 1.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 원형 텍스트 (vinyl_component CircularTextPainter 그대로)
// ════════════════════════════════════════════════════════════
class _CircularTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final TextPainter _tp = TextPainter(textDirection: TextDirection.ltr);

  _CircularTextPainter({required this.text, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final double center = size.width / 2;
    const double startAngle = -math.pi / 2;
    const double sweep = 2 * math.pi;
    final double step = sweep / text.length;

    for (int i = 0; i < text.length; i++) {
      _tp.text = TextSpan(text: text[i], style: style);
      _tp.layout();
      final double angle = startAngle + (i * step);
      final double x = center + radius * 0.95 * math.cos(angle);
      final double y = center + radius * 0.95 * math.sin(angle);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);
      _tp.paint(canvas, Offset(-_tp.width / 2, -_tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CircularTextPainter old) =>
      old.text != text || old.style != style;
}