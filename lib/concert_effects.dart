// ════════════════════════════════════════════════════════════════════════════
// concert_effects.dart  —  GLASNYL 콘서트 효과 (풀 이머시브 콘서트 모드)
// ════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 공통 유틸
// ─────────────────────────────────────────────────────────────────────────────
double _lerp(double a, double b, double t) => a + (b - a) * t;

// ═════════════════════════════════════════════════════════════════════════════
// 1.  레이저 빔
// ═════════════════════════════════════════════════════════════════════════════
class ConcertLaserBeams extends StatefulWidget {
  final bool isPlaying;
  final Color accentColor;

  const ConcertLaserBeams({
    super.key,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<ConcertLaserBeams> createState() => _ConcertLaserBeamsState();
}

class _ConcertLaserBeamsState extends State<ConcertLaserBeams>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    // ✅ 재생 중일 때만 시작
    if (widget.isPlaying) _ctrl.repeat();
  }

  // ✅ 재생/정지 상태 변화 시 Ticker 직접 제어
  @override
  void didUpdateWidget(covariant ConcertLaserBeams old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.isPlaying ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1200),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _LaserPainter(
              t: _ctrl.value,
              accent: widget.accentColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _LaserPainter extends CustomPainter {
  final double t;
  final Color accent;

  static const _lasers = [
    [0.30,  0.55, 1.0,  0.0, 1.5],
    [0.50,  0.70, 0.73, 1.0, 2.0],
    [0.70,  0.45, 1.18, 2.0, 1.5],
    [0.20,  0.35, 0.60, 3.0, 1.2],
    [0.80,  0.40, 0.88, 1.0, 1.2],
  ];

  _LaserPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final colors = [
      accent,
      const Color(0xFFFF2D55),
      const Color(0xFF00E5FF),
      const Color(0xFFFFD60A),
    ];

    for (int i = 0; i < _lasers.length; i++) {
      final l = _lasers[i];
      final originX = w * (l[0] as double);
      final amp     = l[1] as double;
      final speed   = l[2] as double;
      final cIdx    = (l[3] as double).toInt();
      final lWidth  = l[4] as double;

      final angle = math.pi / 2 +
          math.sin((t * speed + i * 0.7) * 2 * math.pi) * amp;

      final origin = Offset(originX, 0);
      final end = Offset(
        originX + math.cos(angle) * h * 1.8,
        math.sin(angle) * h * 1.8,
      );

      final color = colors[cIdx % colors.length];

      final beamPaint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = lWidth
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawLine(origin, end, beamPaint);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..strokeWidth = lWidth * 8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawLine(origin, end, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_LaserPainter old) => old.t != t || old.accent != accent;
}


// ═════════════════════════════════════════════════════════════════════════════
// 2.  관중석 라이터/폰 불빛
// ═════════════════════════════════════════════════════════════════════════════
class ConcertAudienceLights extends StatefulWidget {
  final bool isPlaying;
  final Color accentColor;

  const ConcertAudienceLights({
    super.key,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<ConcertAudienceLights> createState() =>
      _ConcertAudienceLightsState();
}

class _ConcertAudienceLightsState extends State<ConcertAudienceLights>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_LightDot> _dots;
  static const _count = 220;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _dots = List.generate(_count, (i) => _LightDot(
      x:       rng.nextDouble(),
      yBase:   rng.nextDouble() * 0.28 + 0.72,
      phase:   rng.nextDouble() * 2 * math.pi,
      speed:   rng.nextDouble() * 0.8 + 0.3,
      swayAmp: rng.nextDouble() * 0.012 + 0.003,
      size:    rng.nextDouble() * 2.8 + 1.2,
      bright:  rng.nextDouble() * 0.5 + 0.5,
      isGold:  rng.nextDouble() > 0.55,
    ));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    // ✅ 재생 중일 때만 시작
    if (widget.isPlaying) _ctrl.repeat();
  }

  // ✅ 재생/정지 상태 변화 시 Ticker 직접 제어
  @override
  void didUpdateWidget(covariant ConcertAudienceLights old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.isPlaying ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1500),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _AudiencePainter(
              t: _ctrl.value,
              dots: _dots,
              accent: widget.accentColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _LightDot {
  final double x, yBase, phase, speed, swayAmp, size, bright;
  final bool isGold;
  const _LightDot({
    required this.x, required this.yBase, required this.phase,
    required this.speed, required this.swayAmp, required this.size,
    required this.bright, required this.isGold,
  });
}

class _AudiencePainter extends CustomPainter {
  final double t;
  final List<_LightDot> dots;
  final Color accent;

  _AudiencePainter({required this.t, required this.dots, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withValues(alpha: 0.55),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, h * 0.68, w, h * 0.32));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.68, w, h * 0.32), bgPaint);

    for (final d in dots) {
      final angle = (t * d.speed + d.phase);
      final swayY = math.sin(angle * 2 * math.pi) * 0.008;
      final swayX = math.cos(angle * 2 * math.pi * 0.7) * d.swayAmp;

      final px = (d.x + swayX).clamp(0.0, 1.0) * w;
      final py = (d.yBase + swayY).clamp(0.0, 1.0) * h;

      final flicker = (math.sin(angle * 2 * math.pi * 1.3) * 0.3 + 0.7) * d.bright;

      final color = d.isGold
          ? Color.lerp(const Color(0xFFFFD700), const Color(0xFFFFFFFF), 0.3)!
          : Color.lerp(accent, Colors.white, 0.4)!;

      final glowPaint = Paint()
        ..color = color.withValues(alpha: flicker * 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d.size * 3);
      canvas.drawCircle(Offset(px, py), d.size * 3, glowPaint);

      final dotPaint = Paint()
        ..color = color.withValues(alpha: (flicker * 0.92).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), d.size, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_AudiencePainter old) => old.t != t;
}


// ═════════════════════════════════════════════════════════════════════════════
// 3.  스트로브 플래시
// ═════════════════════════════════════════════════════════════════════════════
class ConcertStrobeFlash extends StatefulWidget {
  const ConcertStrobeFlash({super.key});

  @override
  State<ConcertStrobeFlash> createState() => ConcertStrobeFlashState();
}

class ConcertStrobeFlashState extends State<ConcertStrobeFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.55), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.55, end: 0.18), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: 0.40), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.40, end: 0.0),  weight: 55),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // 외부에서 호출 — 트리거 이벤트이므로 isPlaying 상관없이 항상 발동
  void flash() => _ctrl.forward(from: 0.0);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => _anim.value == 0.0
            ? const SizedBox.shrink()
            : Container(color: Colors.white.withValues(alpha: _anim.value)),
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════════
// 4.  파티클 폭발
// ═════════════════════════════════════════════════════════════════════════════
class ConcertParticleBurst extends StatefulWidget {
  const ConcertParticleBurst({super.key});

  @override
  State<ConcertParticleBurst> createState() => ConcertParticleBurstState();
}

class ConcertParticleBurstState extends State<ConcertParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  List<_BurstParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _particles = []);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // 외부에서 호출 — 트리거 이벤트이므로 isPlaying 상관없이 항상 발동
  void burst({Color accentColor = Colors.white, Offset? origin}) {
    final rng = math.Random();
    const colors = [
      Color(0xFFFFD700),
      Color(0xFFFF2D55),
      Color(0xFF00E5FF),
      Color(0xFFFFFFFF),
    ];

    _particles = List.generate(65, (i) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = rng.nextDouble() * 0.7 + 0.2;
      final size  = rng.nextDouble() * 7 + 2.5;
      final spin  = (rng.nextDouble() - 0.5) * 8;
      final color = i % 5 == 0 ? accentColor : colors[rng.nextInt(colors.length)];
      final trail = rng.nextBool();
      return _BurstParticle(angle: angle, speed: speed, size: size,
          spin: spin, color: color, trail: trail, origin: origin);
    });
    _ctrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _BurstPainter(
          particles: _particles,
          t: _ctrl.value,
          screenSize: MediaQuery.of(context).size,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BurstParticle {
  final double angle, speed, size, spin;
  final Color color;
  final bool trail;
  final Offset? origin;
  const _BurstParticle({
    required this.angle, required this.speed, required this.size,
    required this.spin,  required this.color, required this.trail,
    this.origin,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_BurstParticle> particles;
  final double t;
  final Size screenSize;

  _BurstPainter({required this.particles, required this.t, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    final eased = 1.0 - math.pow(1.0 - t, 3.0) as double;
    final fade  = t < 0.65 ? 1.0 : (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0);

    for (final p in particles) {
      final origin = p.origin ?? Offset(size.width / 2, size.height * 0.40);
      final dist   = eased * p.speed * size.height * 0.62;
      final pos = Offset(
        origin.dx + math.cos(p.angle) * dist,
        origin.dy + math.sin(p.angle) * dist,
      );
      final alpha = (p.color.a / 255.0 * fade).clamp(0.0, 1.0);
      final currentSize = p.size * (1.0 - eased * 0.25);

      if (p.trail) {
        final prevDist = math.max(0.0, eased - 0.06) * p.speed * size.height * 0.62;
        final prevPos  = Offset(
          origin.dx + math.cos(p.angle) * prevDist,
          origin.dy + math.sin(p.angle) * prevDist,
        );
        canvas.drawLine(prevPos, pos, Paint()
          ..color = p.color.withValues(alpha: alpha * 0.5)
          ..strokeWidth = currentSize * 0.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 0.3));
      }

      canvas.drawCircle(pos, currentSize * 2.2, Paint()
        ..color = p.color.withValues(alpha: alpha * 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 2.5));
      canvas.drawCircle(pos, currentSize, Paint()
        ..color = p.color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}


// ═════════════════════════════════════════════════════════════════════════════
// 5. 무대 연기/헤이즈
// ═════════════════════════════════════════════════════════════════════════════
class ConcertSmokeHaze extends StatefulWidget {
  final bool isPlaying;
  final Color accentColor;

  const ConcertSmokeHaze({
    super.key,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<ConcertSmokeHaze> createState() => _ConcertSmokeHazeState();
}

class _ConcertSmokeHazeState extends State<ConcertSmokeHaze>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_SmokeParticle> _puffs;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(13);
    _puffs = List.generate(18, (i) => _SmokeParticle(
      xBase:    rng.nextDouble(),
      yBase:    0.60 + rng.nextDouble() * 0.38,
      phase:    rng.nextDouble() * 2 * math.pi,
      speed:    rng.nextDouble() * 0.18 + 0.06,
      size:     rng.nextDouble() * 0.12 + 0.08,
      opacity:  rng.nextDouble() * 0.18 + 0.06,
    ));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    // ✅ 재생 중일 때만 시작
    if (widget.isPlaying) _ctrl.repeat();
  }

  // ✅ 재생/정지 상태 변화 시 Ticker 직접 제어
  @override
  void didUpdateWidget(covariant ConcertSmokeHaze old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.isPlaying ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 2000),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _SmokePainter(
              t: _ctrl.value,
              puffs: _puffs,
              accent: widget.accentColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _SmokeParticle {
  final double xBase, yBase, phase, speed, size, opacity;
  const _SmokeParticle({
    required this.xBase, required this.yBase, required this.phase,
    required this.speed, required this.size, required this.opacity,
  });
}

class _SmokePainter extends CustomPainter {
  final double t;
  final List<_SmokeParticle> puffs;
  final Color accent;

  _SmokePainter({required this.t, required this.puffs, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in puffs) {
      final cycleT = (t * p.speed + p.phase / (2 * math.pi)) % 1.0;
      final riseY  = p.yBase - cycleT * 0.45;
      final driftX = p.xBase + math.sin(cycleT * 2 * math.pi + p.phase) * 0.06;
      final growFactor = 1.0 + cycleT * 2.5;
      final fadeFactor = (1.0 - cycleT * 1.4).clamp(0.0, 1.0);

      final px = driftX.clamp(0.0, 1.0) * size.width;
      final py = riseY.clamp(0.0, 1.0) * size.height;
      final r  = p.size * size.width * growFactor;

      final smokeColor = Color.lerp(
        Colors.white.withValues(alpha: p.opacity * fadeFactor),
        accent.withValues(alpha: p.opacity * fadeFactor * 0.3),
        0.25,
      )!;

      canvas.drawCircle(
        Offset(px, py), r,
        Paint()
          ..color = smokeColor
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) => old.t != t || old.accent != accent;
}


// ═════════════════════════════════════════════════════════════════════════════
// 6. 스포트라이트
// ═════════════════════════════════════════════════════════════════════════════
class ConcertSpotlights extends StatefulWidget {
  final bool isPlaying;
  final Color accentColor;

  const ConcertSpotlights({
    super.key,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<ConcertSpotlights> createState() => _ConcertSpotlightsState();
}

class _ConcertSpotlightsState extends State<ConcertSpotlights>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    // ✅ 재생 중일 때만 시작
    if (widget.isPlaying) _ctrl.repeat();
  }

  // ✅ 재생/정지 상태 변화 시 Ticker 직접 제어
  @override
  void didUpdateWidget(covariant ConcertSpotlights old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.isPlaying ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1500),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _SpotlightPainter(
              t: _ctrl.value,
              accent: widget.accentColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final double t;
  final Color accent;

  _SpotlightPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final spots = [
      (0.08,  1.0,  accent,                     0.10),
      (0.92,  0.73, const Color(0xFF00E5FF),     0.09),
      (0.50,  0.55, const Color(0xFFFFD700),     0.07),
      (0.18,  1.28, const Color(0xFFFF2D55),     0.08),
      (0.82,  0.90, accent,                      0.09),
    ];

    for (int i = 0; i < spots.length; i++) {
      final (oxR, speed, color, halfAngle) = spots[i];

      final ox = w * oxR;
      const oy = 0.0;

      final sweep = math.sin((t * speed + i * 0.8) * 2 * math.pi);
      final targetX = w * (0.35 + sweep * 0.30);
      final targetY = h * 0.70;

      final baseAngle = math.atan2(targetY - oy, targetX - ox);
      // ✅ dead code 제거: 미사용 변수 endX 삭제
      final coneLen = math.sqrt(
        math.pow(targetX - ox, 2) + math.pow(targetY - oy, 2)) * 1.3;

      final left  = Offset(
        ox + math.cos(baseAngle - halfAngle) * coneLen,
        oy + math.sin(baseAngle - halfAngle) * coneLen,
      );
      final right = Offset(
        ox + math.cos(baseAngle + halfAngle) * coneLen,
        oy + math.sin(baseAngle + halfAngle) * coneLen,
      );

      final path = Path()
        ..moveTo(ox, oy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();

      final shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.0,
        colors: [
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0.08),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(ox - coneLen, oy, coneLen * 2, coneLen));

      canvas.drawPath(path, Paint()..shader = shader..style = PaintingStyle.fill);

      canvas.drawLine(
        Offset(ox, oy),
        Offset(targetX, targetY),
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawCircle(
        Offset(ox, oy), 5,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.t != t || old.accent != accent;
}


// ═════════════════════════════════════════════════════════════════════════════
// 7. 색종이 비
// ═════════════════════════════════════════════════════════════════════════════
class ConcertConfettiRain extends StatefulWidget {
  final bool isPlaying;
  // ✅ 앱바 높이만큼 상단 여백을 받아서 색종이가 앱바를 침범하지 않도록
  final double topOffset;

  const ConcertConfettiRain({
    super.key,
    required this.isPlaying,
    this.topOffset = 60.0,
  });

  @override
  State<ConcertConfettiRain> createState() => _ConcertConfettiRainState();
}

class _ConcertConfettiRainState extends State<ConcertConfettiRain>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(99);
    _pieces = List.generate(60, (i) {
      const colors = [
        Color(0xFFFF2D55), Color(0xFFFFD700), Color(0xFF00E5FF),
        Color(0xFF34C759), Color(0xFFAF52DE), Color(0xFFFFFFFF),
        Color(0xFFFF9500),
      ];
      return _ConfettiPiece(
        x:       rng.nextDouble(),
        yOffset: rng.nextDouble(),
        speed:   rng.nextDouble() * 0.12 + 0.06,
        swayAmp: rng.nextDouble() * 0.04 + 0.01,
        swayFreq: rng.nextDouble() * 1.5 + 0.5,
        size:    rng.nextDouble() * 7 + 4,
        color:   colors[rng.nextInt(colors.length)],
        isRect:  rng.nextBool(),
        rotation: rng.nextDouble() * math.pi,
        rotSpeed: (rng.nextDouble() - 0.5) * 4,
      );
    });

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    // ✅ 재생 중일 때만 시작
    if (widget.isPlaying) _ctrl.repeat();
  }

  // ✅ 재생/정지 상태 변화 시 Ticker 직접 제어
  @override
  void didUpdateWidget(covariant ConcertConfettiRain old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.isPlaying ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1800),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _ConfettiPainter(
              t: _ctrl.value,
              pieces: _pieces,
              topOffset: widget.topOffset,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  final double x, yOffset, speed, swayAmp, swayFreq, size, rotation, rotSpeed;
  final Color color;
  final bool isRect;
  const _ConfettiPiece({
    required this.x, required this.yOffset, required this.speed,
    required this.swayAmp, required this.swayFreq, required this.size,
    required this.color, required this.isRect,
    required this.rotation, required this.rotSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<_ConfettiPiece> pieces;
  // ✅ 앱바 아래부터 색종이가 시작되도록 offset 적용
  final double topOffset;

  _ConfettiPainter({required this.t, required this.pieces, required this.topOffset});

  @override
  void paint(Canvas canvas, Size size) {
    // ✅ 앱바 영역(topOffset 이상)만 색종이가 그려지도록 클리핑
    canvas.clipRect(Rect.fromLTWH(0, topOffset, size.width, size.height - topOffset));

    final drawH = size.height - topOffset;

    for (final p in pieces) {
      final cycleT = (t * p.speed + p.yOffset) % 1.0;
      final py = topOffset + cycleT * drawH;
      final px = (p.x + math.sin(cycleT * p.swayFreq * 2 * math.pi) * p.swayAmp)
          .clamp(0.0, 1.0) * size.width;

      final edgeFade = (cycleT < 0.08)
          ? cycleT / 0.08
          : (cycleT > 0.90 ? (1.0 - cycleT) / 0.10 : 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: (edgeFade * 0.85).clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + t * p.rotSpeed);

      if (p.isRect) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.45),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.t != t || old.topOffset != topOffset;
}


// ═════════════════════════════════════════════════════════════════════════════
// 8. 무대 바닥 반사광 / 그리드
// ═════════════════════════════════════════════════════════════════════════════
class ConcertStageFloor extends StatefulWidget {
  final bool isPlaying;
  final Color accentColor;

  const ConcertStageFloor({
    super.key,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<ConcertStageFloor> createState() => _ConcertStageFloorState();
}

class _ConcertStageFloorState extends State<ConcertStageFloor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    // ✅ 재생 중일 때만 시작
    if (widget.isPlaying) _ctrl.repeat();
  }

  // ✅ 재생/정지 상태 변화 시 Ticker 직접 제어
  @override
  void didUpdateWidget(covariant ConcertStageFloor old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.isPlaying ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1500),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _StageFloorPainter(
              t: _ctrl.value,
              accent: widget.accentColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _StageFloorPainter extends CustomPainter {
  final double t;
  final Color accent;

  _StageFloorPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final floorY = h * 0.68;
    final floorH = h - floorY;

    canvas.drawRect(
      Rect.fromLTWH(0, floorY, w, floorH),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.65),
          ],
        ).createShader(Rect.fromLTWH(0, floorY, w, floorH)),
    );

    final vp = Offset(w / 2, floorY);

    for (int i = 1; i <= 5; i++) {
      final ratio = i / 6.0;
      final y = floorY + floorH * ratio;
      final fade = (1.0 - ratio * 0.8).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(0, y), Offset(w, y),
        Paint()
          ..color = accent.withValues(alpha: fade * 0.12)
          ..strokeWidth = 0.7,
      );
    }

    const numV = 9;
    for (int i = 0; i <= numV; i++) {
      final startX = w * (i / numV.toDouble());
      canvas.drawLine(
        Offset(startX, floorY + floorH),
        Offset(vp.dx, floorY),
        Paint()
          ..color = accent.withValues(alpha: 0.10)
          ..strokeWidth = 0.6,
      );
    }

    final pulse = (math.sin(t * 2 * math.pi) * 0.3 + 0.7);
    for (int i = 0; i < 3; i++) {
      final reflX = w * (0.2 + i * 0.3);
      final reflY = floorY + floorH * 0.15;
      final colors = [accent, const Color(0xFF00E5FF), const Color(0xFFFFD700)];

      canvas.drawCircle(
        Offset(reflX, reflY),
        w * 0.12,
        Paint()
          ..color = colors[i].withValues(alpha: pulse * 0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10),
      );
    }
  }

  @override
  bool shouldRepaint(_StageFloorPainter old) => old.t != t || old.accent != accent;
}


// ═════════════════════════════════════════════════════════════════════════════
// 9. 전체 콘서트 레이어 래퍼
// ═════════════════════════════════════════════════════════════════════════════
class ConcertLayer extends StatefulWidget {
  final bool isPlaying;
  final Color accentColor;

  const ConcertLayer({
    super.key,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<ConcertLayer> createState() => ConcertLayerState();
}

class ConcertLayerState extends State<ConcertLayer> {
  final _strobeKey = GlobalKey<ConcertStrobeFlashState>();
  final _burstKey  = GlobalKey<ConcertParticleBurstState>();

  /// 곡 전환 시 호출 — 스트로브 + 파티클 동시에 발동
  void onTrackChange({Color? accentColor}) {
    _strobeKey.currentState?.flash();
    Future.delayed(const Duration(milliseconds: 80), () {
      _burstKey.currentState?.burst(
        accentColor: accentColor ?? widget.accentColor,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 앱바 높이 + 상단 SafeArea를 색종이 topOffset으로 전달
    final double statusBarH = MediaQuery.of(context).padding.top;
    final double confettiTopOffset = statusBarH + 60.0; // 60 = 앱바 높이

    return Stack(
      children: [
        // 1. 무대 바닥 반사 (맨 아래)
        Positioned.fill(
          child: ConcertStageFloor(
            isPlaying: widget.isPlaying,
            accentColor: widget.accentColor,
          ),
        ),
        // 2. 스포트라이트 원뿔
        Positioned.fill(
          child: ConcertSpotlights(
            isPlaying: widget.isPlaying,
            accentColor: widget.accentColor,
          ),
        ),
        // 3. 레이저 빔
        Positioned.fill(
          child: ConcertLaserBeams(
            isPlaying: widget.isPlaying,
            accentColor: widget.accentColor,
          ),
        ),
        // 4. 연기/헤이즈
        Positioned.fill(
          child: ConcertSmokeHaze(
            isPlaying: widget.isPlaying,
            accentColor: widget.accentColor,
          ),
        ),
        // 5. 색종이 비 — ✅ topOffset으로 앱바 영역 제외
        Positioned.fill(
          child: ConcertConfettiRain(
            isPlaying: widget.isPlaying,
            topOffset: confettiTopOffset,
          ),
        ),
        // 6. 관중석 불빛
        Positioned.fill(
          child: ConcertAudienceLights(
            isPlaying: widget.isPlaying,
            accentColor: widget.accentColor,
          ),
        ),
        // 7. 스트로브 플래시 (트리거 이벤트)
        Positioned.fill(
          child: ConcertStrobeFlash(key: _strobeKey),
        ),
        // 8. 파티클 폭발 (트리거 이벤트, 맨 위)
        Positioned.fill(
          child: ConcertParticleBurst(key: _burstKey),
        ),
      ],
    );
  }
}