import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/lyric_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EssentialView  —  GLASNYL AESTHETIC 모드  (v2)
//
// 변경점 (v2)
//   • 내부 토글 — AUTO(시뮬) ↔ FREQ(주파수 바) 전환 가능, 반투명 pill 형태
//   • FFT shouldRepaint 버그 수정 — 리스트 내용 비교로 변경
//   • 비트 펄스 링 — 저음 에너지 기반 accentColor 원형 파동
//   • 파티클 시스템 — 비트 피크마다 미세 입자 방출
//   • 주파수 힌트 텍스트 — 하단 SUB / MID / HI 레이블
//   • 스펙트럼 미러 모드 — 위아래 반전 대칭으로 더 꽉 찬 느낌
//
// 변경점 (v3) — 가사 넘김 수정
//   • _LyricsLineView: positionNotifier listener 단독 방식 → Ticker 보완 추가
//   • LP 모드(_LandscapeLyricsScroller)와 동일하게 basePosition + 경과시간 추정
//   • positionNotifier는 싱크 기준점 갱신 용도로만 사용
//
// ══════════════════════════════════════════════════════════════════════════════

// ── 내부 뷰 모드
enum _SpectrumMode { auto, freq, lyrics }

class EssentialView extends StatefulWidget {
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;
  final String? albumName;
  final bool isPlaying;
  final Color accentColor;
  final Color textColor;
  final List<LyricLine> lyrics;
  final ValueNotifier<Duration> positionNotifier;
  final bool isLyricsLoading; // 가사 로딩 중 여부

  const EssentialView({
    super.key,
    required this.albumArtBytes,
    required this.title,
    required this.artist,
    this.albumName,
    required this.isPlaying,
    required this.accentColor,
    required this.textColor,
    this.lyrics = const [],
    required this.positionNotifier,
    this.isLyricsLoading = false,
  });

  @override
  State<EssentialView> createState() => _EssentialViewState();
}

class _EssentialViewState extends State<EssentialView>
    with TickerProviderStateMixin {
  // ── 내부 모드 토글
  _SpectrumMode _specMode = _SpectrumMode.auto;

  // ── 네이티브 FFT
  static const EventChannel _fftChannel =
      EventChannel('com.glasnyl.app/fft_data');
  StreamSubscription? _fftSub;
  bool _useSimulation = false;

  // ── 입장 애니메이션
  late final AnimationController _enterController;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  // ── 시뮬 Ticker
  Ticker? _simTicker;

  // ── 스펙트럼 데이터
  static const int _bandCount = 64;
  static const int _nativeBands = 32;
  final List<double> _bands = List.filled(_bandCount, 0.0);

  // ── FREQ 모드 개별 밴드 독립 상태
  final List<double> _bandPhase = List.filled(_bandCount, 0.0);
  final List<double> _bandSpeed = List.filled(_bandCount, 0.0);
  final List<double> _bandDecay = List.filled(_bandCount, 0.0);

  // ── 시뮬 내부 상태
  final _rand = math.Random();
  final List<double> _envelope = List.filled(_bandCount, 0.0);
  final List<double> _target = List.filled(_bandCount, 0.0);
  double _beatPulse = 0.0;
  double _beatEnergy = 0.0;
  late final List<double> _phaseOffset;
  late final List<double> _phaseSpeed;
  double _elapsedSeconds = 0.0;
  DateTime _lastTick = DateTime.now();

  // ── 비트 펄스 링
  final List<_BeatRing> _beatRings = [];

  // ── 파티클
  final List<_Particle> _particles = [];
  double _lastBeatPulse = 0.0;

  // repaint notifier
  final ValueNotifier<int> _repaintTick = ValueNotifier(0);

  // ── 토글 애니메이션 컨트롤러
  late final AnimationController _toggleAnim;

  @override
  void initState() {
    super.initState();

    _phaseOffset =
        List.generate(_bandCount, (_) => _rand.nextDouble() * math.pi * 2);
    _phaseSpeed = List.generate(_bandCount, (i) {
      final t = i / (_bandCount - 1);
      return 0.8 + t * 1.6 + _rand.nextDouble() * 0.6;
    });

    // FREQ 모드 독립 밴드 초기화
    for (int i = 0; i < _bandCount; i++) {
      _bandPhase[i] = _rand.nextDouble() * math.pi * 2;
      _bandSpeed[i] = 1.5 + _rand.nextDouble() * 4.0;
      _bandDecay[i] = 0.55 + _rand.nextDouble() * 0.30;
    }

    // 입장 애니메이션
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _enterFade =
        CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _enterController, curve: Curves.easeOut));
    _enterController.forward();

    // 토글 애니메이션
    _toggleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _startFftStream();
  }

  Timer? _fftTimeoutTimer;

  void _startFftStream() {
    try {
      _fftSub = _fftChannel.receiveBroadcastStream().listen(
        (data) {
          if (!mounted) return;
          if (data is List && data.isNotEmpty) {
            if (_specMode == _SpectrumMode.freq) {
              if (_useSimulation) {
                _simTicker?.stop();
                _useSimulation = false;
              }
              _fftTimeoutTimer?.cancel();
              _fftTimeoutTimer = Timer(const Duration(milliseconds: 600), () {
                if (mounted && !_useSimulation) _startSimulation();
              });
              final incoming = List<double>.generate(
                _nativeBands,
                (i) => i < data.length
                    ? (data[i] as num).toDouble().clamp(0.0, 1.0)
                    : 0.0,
              );

              final now = DateTime.now();
              final dt = now.difference(_lastTick).inMicroseconds / 1e6;
              _lastTick = now;

              for (int i = 0; i < _bandCount; i++) {
                final int srcIdx =
                    (i * _nativeBands / _bandCount).round().clamp(0, _nativeBands - 1);
                double rawV = incoming[srcIdx];

                final double bandT = i / (_bandCount - 1);
                final double exponent = 2.2 - bandT * 1.0;
                rawV = math.pow(rawV, exponent).toDouble().clamp(0.0, 1.0);

                final double gain = 0.60 + bandT * 0.28;
                rawV = (rawV * gain).clamp(0.0, 0.78);

                _bandPhase[i] += _bandSpeed[i] * dt;
                final double indep = 0.5 + 0.5 * math.sin(_bandPhase[i]);
                final double blend = (1.0 - rawV / 0.78).clamp(0.0, 1.0);
                double v = rawV + indep * blend * 0.10;

                if (bandT > 0.5) {
                  v += (bandT - 0.5) * 0.06 * _rand.nextDouble();
                }

                v = v.clamp(0.0, 0.82);

                if (v > _bands[i]) {
                  _bands[i] = v;
                } else {
                  _bands[i] = (_bands[i] * _bandDecay[i] +
                               v * (1.0 - _bandDecay[i]))
                      .clamp(0.0, 0.82);
                }
              }
              _repaintTick.value++;
            }
          }
        },
        onError: (_) => _startSimulation(),
      );
    } catch (_) {
      _startSimulation();
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && !_useSimulation && _bands.every((v) => v == 0.0)) {
        _startSimulation();
      }
    });
  }

  void _startSimulation() {
    if (!mounted || _useSimulation) return;
    _useSimulation = true;
    _lastTick = DateTime.now();
    _simTicker = createTicker((_) {
      if (!mounted) return;
      final now = DateTime.now();
      final dt = now.difference(_lastTick).inMicroseconds / 1e6;
      _lastTick = now;
      _elapsedSeconds += dt;
      _simulateTick(dt);
      _updateBeatsAndParticles(dt);
      _repaintTick.value++;
    });
    _simTicker!.start();
  }

  void _simulateTick(double dt) {
    final bool playing = widget.isPlaying;

    if (!playing) {
      for (int i = 0; i < _bandCount; i++) {
        _bands[i] = (_bands[i] * (1.0 - dt * 4.5)).clamp(0.0, 1.0);
      }
      _beatPulse = (_beatPulse * (1.0 - dt * 6.0)).clamp(0.0, 1.0);
      return;
    }

    double bassBurst = 0.0;
    for (int i = 0; i < 4; i++) {
      bassBurst +=
          (0.5 + 0.5 * math.sin(_elapsedSeconds * 1.8 + i * 0.9)) *
              (0.6 + _rand.nextDouble() * 0.4);
    }
    _beatEnergy = _beatEnergy * 0.85 + (bassBurst / 4.0) * 0.15;

    if (_beatEnergy > 0.62 && _beatPulse < 0.3) {
      _beatPulse = 0.55 + _rand.nextDouble() * 0.45;
    }
    _beatPulse = (_beatPulse * (1.0 - dt * 7.0)).clamp(0.0, 1.0);

    for (int i = 0; i < _bandCount; i++) {
      final double t = i / (_bandCount - 1);
      final double phase =
          _elapsedSeconds * _phaseSpeed[i] + _phaseOffset[i];

      double energy;
      if (i < 12) {
        energy = 0.55 + 0.45 * math.sin(phase * 1.1);
        energy += _beatPulse * (1.0 - t) * 0.6;
        energy *= 0.75 + _rand.nextDouble() * 0.25;
      } else if (i < 36) {
        final w1 = 0.5 + 0.5 * math.sin(phase * 0.9);
        final w2 = 0.5 + 0.5 * math.cos(phase * 1.3 + 1.2);
        energy = w1 * 0.6 + w2 * 0.4;
        energy *= 0.45 + _rand.nextDouble() * 0.35;
      } else {
        energy = 0.08 + 0.22 * math.pow(math.sin(phase * 1.7).abs(), 1.5);
        energy *= 0.6 + _rand.nextDouble() * 0.4;
      }

      _target[i] = energy.clamp(0.0, 1.0);
      final double diff = _target[i] - _envelope[i];
      final double rate = diff > 0 ? 12.0 : 5.5;
      _envelope[i] =
          (_envelope[i] + diff * rate * dt).clamp(0.0, 1.0);
      _bands[i] = _envelope[i];
    }
  }

  // ── 비트 링 + 파티클 업데이트
  void _updateBeatsAndParticles(double dt) {
    if (!widget.isPlaying ||
        _specMode == _SpectrumMode.auto ||
        _specMode == _SpectrumMode.lyrics) {
      _beatRings.clear();
      _particles.clear();
      return;
    }

    if (_beatPulse > 0.65 && _lastBeatPulse <= 0.40) {
      _beatRings.add(_BeatRing(
        radius: 0.0,
        alpha: 0.55 + _rand.nextDouble() * 0.25,
        speed: 80.0 + _rand.nextDouble() * 40.0,
      ));
      final int count = 6 + _rand.nextInt(8);
      for (int i = 0; i < count; i++) {
        final angle = _rand.nextDouble() * math.pi * 2;
        final speed = 30.0 + _rand.nextDouble() * 70.0;
        _particles.add(_Particle(
          x: 0.0,
          y: 0.0,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          alpha: 0.6 + _rand.nextDouble() * 0.3,
          life: 0.6 + _rand.nextDouble() * 0.4,
          radius: 1.5 + _rand.nextDouble() * 2.5,
        ));
      }
    }
    _lastBeatPulse = _beatPulse;

    for (final ring in _beatRings) {
      ring.radius += ring.speed * dt;
      ring.alpha -= dt * 1.2;
    }
    _beatRings.removeWhere((r) => r.alpha <= 0.0);

    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 30 * dt;
      p.life -= dt * 1.0;
      p.alpha = (p.life * 0.9).clamp(0.0, 1.0);
    }
    _particles.removeWhere((p) => p.life <= 0.0);
  }

  void _onToggleMode() {
    HapticFeedback.selectionClick();
    final nextMode = switch (_specMode) {
      _SpectrumMode.auto   => _SpectrumMode.freq,
      _SpectrumMode.freq   => _SpectrumMode.lyrics,
      _SpectrumMode.lyrics => _SpectrumMode.auto,
    };

    setState(() {
      _specMode = nextMode;
    });

    if (nextMode == _SpectrumMode.auto || nextMode == _SpectrumMode.lyrics) {
      if (!_useSimulation) _startSimulation();
    } else {
      _simTicker?.stop();
      _useSimulation = false;
      _fftTimeoutTimer?.cancel();
      _fftTimeoutTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && !_useSimulation) _startSimulation();
      });
    }
  }

  @override
  void didUpdateWidget(EssentialView old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title) {
      for (int i = 0; i < _bandCount; i++) {
        _bands[i] = 0.0;
        _envelope[i] = 0.0;
        _target[i] = 0.0;
      }
      _beatPulse = 0.0;
      _beatEnergy = 0.0;
      _beatRings.clear();
      _particles.clear();
      _repaintTick.value++;
    }
  }

  @override
  void dispose() {
    _fftSub?.cancel();
    _fftTimeoutTimer?.cancel();
    _simTicker?.dispose();
    _enterController.dispose();
    _toggleAnim.dispose();
    _repaintTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double topPad = mq.padding.top + 60.0;
    final double screenH = mq.size.height;
    final double screenW = mq.size.width;
    final bool isLandscape = screenW > screenH;

    final double labelTop = isLandscape
        ? topPad + (screenH - topPad) * 0.14
        : topPad + (screenH - topPad) * 0.26;

    final double specW = screenW * 0.80;
    final double specLeft = (screenW - specW) / 2;

    final double specH = isLandscape
        ? (screenH * 0.34).clamp(90.0, 220.0)
        : (screenH * 0.25).clamp(110.0, 220.0);

    final double specTop = labelTop + 68.0 + 14.0;

    final double ringCx = screenW / 2;
    final double ringCy = specTop + specH / 2;

    return SizedBox.expand(
      child: FadeTransition(
        opacity: _enterFade,
        child: SlideTransition(
          position: _enterSlide,
          child: Stack(
            children: [
              // ── 비트 링 + 파티클 레이어
              Positioned.fill(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _repaintTick,
                    builder: (_, _, _) => CustomPaint(
                      painter: _BeatEffectPainter(
                        rings: List.of(_beatRings),
                        particles: List.of(_particles),
                        cx: ringCx,
                        cy: ringCy,
                        accentColor: widget.accentColor,
                      ),
                    ),
                  ),
                ),
              ),

              // ── AESTHETIC 레이블
              Positioned(
                top: labelTop,
                left: 0,
                right: 0,
                child: Center(
                  child: _EssentialLabel(textColor: widget.textColor),
                ),
              ),

              // ── FFT 스펙트럼 (LYRICS 모드에서는 숨김)
              Positioned(
                top: specTop,
                left: specLeft,
                width: specW,
                height: specH,
                child: AnimatedOpacity(
                  opacity: _specMode == _SpectrumMode.lyrics ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _repaintTick,
                      builder: (_, _, _) => CustomPaint(
                        painter: _SpectrumPainter(
                          bands: List<double>.from(_bands),
                          accentColor: widget.accentColor,
                          isPlaying: widget.isPlaying,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 가사 한 줄 오버레이 (LYRICS 모드)
              Positioned(
                top: specTop,
                left: specLeft - 16,
                width: specW + 32,
                height: specH,
                child: AnimatedOpacity(
                  opacity: _specMode == _SpectrumMode.lyrics ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _LyricsLineView(
                    key: ValueKey('${widget.title}_${widget.lyrics.length}'),
                    lyrics: widget.lyrics,
                    positionNotifier: widget.positionNotifier,
                    accentColor: widget.accentColor,
                    height: specH,
                    isLyricsLoading: widget.isLyricsLoading,
                    isPlaying: widget.isPlaying,
                  ),
                ),
              ),

              // ── 주파수 힌트 레이블 (SUB / MID / HI) — LYRICS 모드에서 숨김
              Positioned(
                top: specTop + specH + 8,
                left: specLeft,
                width: specW,
                child: AnimatedOpacity(
                  opacity: _specMode == _SpectrumMode.lyrics ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: _FreqLabels(accentColor: widget.accentColor),
                ),
              ),

              // ── 내부 모드 토글 (AUTO ↔ FREQ ↔ LYRICS) — 스펙트럼 위 우측
              Positioned(
                top: specTop - 28,
                right: specLeft,
                child: _InternalModeToggle(
                  mode: _specMode,
                  accentColor: widget.accentColor,
                  onToggle: _onToggleMode,
                ),
              ),

              // ── 하단 곡 정보
              Positioned(
                bottom: mq.padding.bottom + 32.0,
                left: mq.padding.left + 28,
                right: mq.padding.right + 28,
                child: _EssentialFooter(
                  title: widget.title,
                  artist: widget.artist,
                  albumName: widget.albumName,
                  isPlaying: widget.isPlaying,
                  accentColor: widget.accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _InternalModeToggle  —  AUTO ↔ FREQ ↔ LYRICS 3-way 토글
// ──────────────────────────────────────────────────────────────────────────────
class _InternalModeToggle extends StatelessWidget {
  final _SpectrumMode mode;
  final Color accentColor;
  final VoidCallback onToggle;

  const _InternalModeToggle({
    required this.mode,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: mode != _SpectrumMode.auto
              ? accentColor.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: mode != _SpectrumMode.auto
                ? accentColor.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleLabel(
              text: 'AUTO',
              active: mode == _SpectrumMode.auto,
              accentColor: accentColor,
            ),
            _ToggleDivider(),
            _ToggleLabel(
              text: 'FREQ',
              active: mode == _SpectrumMode.freq,
              accentColor: accentColor,
            ),
            _ToggleDivider(),
            _ToggleLabel(
              text: 'LRC',
              active: mode == _SpectrumMode.lyrics,
              accentColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleLabel extends StatelessWidget {
  final String text;
  final bool active;
  final Color accentColor;
  const _ToggleLabel({
    required this.text,
    required this.active,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: active
            ? accentColor.withValues(alpha: 0.90)
            : Colors.white.withValues(alpha: 0.18),
      ),
      child: Text(text),
    );
  }
}

class _ToggleDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _FreqLabels  —  SUB / MID / HI 힌트
// ──────────────────────────────────────────────────────────────────────────────
class _FreqLabels extends StatelessWidget {
  final Color accentColor;
  const _FreqLabels({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 7.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
    );
    return Row(
      children: [
        Text('SUB',
            style: style.copyWith(
                color: accentColor.withValues(alpha: 0.40))),
        const Spacer(),
        Text('MID',
            style: style.copyWith(
                color: Colors.white.withValues(alpha: 0.22))),
        const Spacer(),
        Text('HI',
            style: style.copyWith(
                color: Colors.white.withValues(alpha: 0.16))),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 비트 링 모델
// ──────────────────────────────────────────────────────────────────────────────
class _BeatRing {
  double radius;
  double alpha;
  final double speed;
  _BeatRing({required this.radius, required this.alpha, required this.speed});
}

// ──────────────────────────────────────────────────────────────────────────────
// 파티클 모델
// ──────────────────────────────────────────────────────────────────────────────
class _Particle {
  double x, y, vx, vy, alpha, life, radius;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.alpha,
    required this.life,
    required this.radius,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// _BeatEffectPainter  —  링 + 파티클
// ──────────────────────────────────────────────────────────────────────────────
class _BeatEffectPainter extends CustomPainter {
  final List<_BeatRing> rings;
  final List<_Particle> particles;
  final double cx, cy;
  final Color accentColor;

  const _BeatEffectPainter({
    required this.rings,
    required this.particles,
    required this.cx,
    required this.cy,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ring in rings) {
      final paint = Paint()
        ..color = accentColor.withValues(alpha: ring.alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(cx, cy), ring.radius, paint);
    }

    for (final p in particles) {
      final paint = Paint()
        ..color = accentColor.withValues(alpha: p.alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(Offset(cx + p.x, cy + p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BeatEffectPainter old) => true;
}

// ──────────────────────────────────────────────────────────────────────────────
// _EssentialLabel
// ──────────────────────────────────────────────────────────────────────────────
class _EssentialLabel extends StatelessWidget {
  final Color textColor;
  const _EssentialLabel({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 0.8,
          color: Colors.white.withValues(alpha: 0.22),
          margin: const EdgeInsets.only(bottom: 10),
        ),
        Text(
          'AESTHETIC',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 10.0,
            color: Colors.white.withValues(alpha: 0.82),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 20,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'GLASNYL',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 5.5,
            color: Colors.white.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _EssentialFooter
// ──────────────────────────────────────────────────────────────────────────────
class _EssentialFooter extends StatelessWidget {
  final String title;
  final String artist;
  final String? albumName;
  final bool isPlaying;
  final Color accentColor;

  const _EssentialFooter({
    required this.title,
    required this.artist,
    this.albumName,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: isPlaying ? 6 : 4,
          height: isPlaying ? 6 : 4,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPlaying
                ? accentColor.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.25),
            boxShadow: isPlaying
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.55),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                artist,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (albumName != null && albumName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.album_rounded,
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        albumName!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// EssentialToggleButton  —  AppBar에 삽입할 토글 버튼 (변경 없음)
// ──────────────────────────────────────────────────────────────────────────────
class EssentialToggleButton extends StatelessWidget {
  final bool isEssentialMode;
  final VoidCallback onToggle;
  final Color accentColor;

  const EssentialToggleButton({
    super.key,
    required this.isEssentialMode,
    required this.onToggle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isEssentialMode
              ? accentColor.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEssentialMode
                ? accentColor.withValues(alpha: 0.50)
                : Colors.white.withValues(alpha: 0.14),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.equalizer_rounded,
              size: 13,
              color: isEssentialMode
                  ? accentColor
                  : Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 4),
            Text(
              'AESTHETIC',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isEssentialMode
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _LyricsLineView  —  현재 재생 위치 기준 가사 한 줄 표시
//
// LP 모드(_LyricsAutoScroller)와 동일한 방식:
//   • _basePosition + _elapsedSinceSync 로 정밀 위치 추정
//   • positionNotifier listener: 싱크 기준점 갱신 + drift/seek 감지만 담당
//   • Ticker: 25ms 쓰로틀로 _checkAndUpdate 호출 (setState 유일 진입점)
//   • build()에서 positionNotifier.value 직접 읽지 않음 (가사창 중복 방지)
// ──────────────────────────────────────────────────────────────────────────────
class _LyricsLineView extends StatefulWidget {
  final List<LyricLine> lyrics;
  final ValueNotifier<Duration> positionNotifier;
  final Color accentColor;
  final double height;
  final bool isLyricsLoading;
  final bool isPlaying;

  const _LyricsLineView({
    super.key,
    required this.lyrics,
    required this.positionNotifier,
    required this.accentColor,
    required this.height,
    this.isLyricsLoading = false,
    required this.isPlaying,
  });

  @override
  State<_LyricsLineView> createState() => _LyricsLineViewState();
}

class _LyricsLineViewState extends State<_LyricsLineView>
    with TickerProviderStateMixin {
  int _currentIndex = -1;
  String _displayText = '';
  String _prevText = '';
  String _nextText = '';

  // ── 인트로 구간 표시용 (build에서 positionNotifier 직접 읽기 제거)
  bool _isIntro = false;

  // ── 글로우 pulse 애니메이션
  AnimationController? _glowController;

  // ── LP 모드와 동일한 고정밀 동기화 변수
  Ticker? _positionTicker;
  Duration _basePosition = Duration.zero;
  Duration _elapsedSinceSync = Duration.zero;
  Duration _prevNotifiedPos = Duration.zero;
  Duration _lastTickerCheck = Duration.zero;
  static const Duration _throttleInterval = Duration(milliseconds: 25);
  static const Duration _seekThreshold = Duration(milliseconds: 300);
  static const Duration _driftThreshold = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _basePosition = widget.positionNotifier.value;
    _prevNotifiedPos = _basePosition;

    widget.positionNotifier.addListener(_onPositionSync);

    _positionTicker = createTicker((elapsed) {
      if (!mounted) return;
      if (elapsed - _lastTickerCheck < _throttleInterval) return;
      _lastTickerCheck = elapsed;
      _elapsedSinceSync = elapsed;

      if (!widget.isPlaying) return;

      // LP 모드와 동일: basePosition + ticker elapsed + 50ms 선행
      final estimatedPos = _basePosition +
          _elapsedSinceSync +
          const Duration(milliseconds: 50);
      _checkAndUpdate(estimatedPos);
    });

    if (widget.isPlaying) _positionTicker!.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAndUpdate(widget.positionNotifier.value);
    });
  }

  /// positionNotifier 변경 시: 싱크 기준점 갱신 + drift/seek 감지
  /// setState 없음 — Ticker가 다음 틱에서 반영
  void _onPositionSync() {
    if (!mounted) return;
    final Duration current = widget.positionNotifier.value;

    final bool isSeeked =
        (current - _prevNotifiedPos).abs() > _seekThreshold ||
        current < _prevNotifiedPos;

    if (isSeeked) {
      // seek: 즉시 동기화 + ticker 리셋
      _basePosition = current;
      _elapsedSinceSync = Duration.zero;
      _lastTickerCheck = Duration.zero;
      if (_positionTicker?.isTicking ?? false) {
        _positionTicker!.stop();
        _positionTicker!.start();
      }
    } else {
      // 일반 업데이트: drift 감지
      final estimatedNow = _basePosition + _elapsedSinceSync;
      final drift = (current - estimatedNow).abs();
      if (drift > _driftThreshold) {
        _basePosition = current;
        _elapsedSinceSync = Duration.zero;
        _lastTickerCheck = Duration.zero;
        if (_positionTicker?.isTicking ?? false) {
          _positionTicker!.stop();
          _positionTicker!.start();
        }
      }
    }

    _prevNotifiedPos = current;
  }

  /// Ticker에서만 호출 — 추정 위치로 가사 인덱스 계산 후 필요 시 setState
  void _checkAndUpdate(Duration pos) {
    final List<LyricLine> lines = widget.lyrics;

    // 인트로 판단 (가사 없거나 첫 가사 전)
    final bool isIntroNow = lines.isNotEmpty && pos < lines.first.time;

    if (lines.isEmpty) {
      if (_isIntro || _currentIndex != -1) {
        if (mounted) setState(() { _isIntro = false; _currentIndex = -1; _displayText = ''; _prevText = ''; _nextText = ''; });
      }
      return;
    }

    int lo = 0, hi = lines.length - 1, idx = -1;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      if (lines[mid].time <= pos) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    if (idx == _currentIndex && isIntroNow == _isIntro) return;
    if (!mounted) return;
    setState(() {
      _currentIndex = idx;
      _isIntro = isIntroNow;
      _displayText = idx >= 0 ? lines[idx].text : '';
      _prevText    = idx > 0 ? lines[idx - 1].text : '';
      _nextText    = (idx >= 0 && idx + 1 < lines.length)
          ? lines[idx + 1].text
          : '';
    });
  }

  @override
  void didUpdateWidget(_LyricsLineView old) {
    super.didUpdateWidget(old);

    // positionNotifier 교체
    if (old.positionNotifier != widget.positionNotifier) {
      old.positionNotifier.removeListener(_onPositionSync);
      _basePosition = widget.positionNotifier.value;
      _prevNotifiedPos = _basePosition;
      _elapsedSinceSync = Duration.zero;
      widget.positionNotifier.addListener(_onPositionSync);
    }

    // isPlaying 변경 시 Ticker 제어 (LP 모드와 동일)
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _basePosition = widget.positionNotifier.value;
        _prevNotifiedPos = _basePosition;
        _elapsedSinceSync = Duration.zero;
        _lastTickerCheck = Duration.zero;
        if (!(_positionTicker?.isTicking ?? false)) {
          _positionTicker?.start();
        }
      } else {
        _positionTicker?.stop();
        _basePosition = widget.positionNotifier.value;
        _prevNotifiedPos = _basePosition;
        _elapsedSinceSync = Duration.zero;
      }
    }

    // 가사 목록 교체
    final lyricsChanged = old.lyrics.length != widget.lyrics.length ||
        (widget.lyrics.isNotEmpty &&
            old.lyrics.isNotEmpty &&
            old.lyrics.first.text != widget.lyrics.first.text) ||
        widget.lyrics.isEmpty;
    if (lyricsChanged) {
      _currentIndex = -1;
      _isIntro = false;
      _displayText = '';
      _prevText = '';
      _nextText = '';
      _basePosition = widget.positionNotifier.value;
      _prevNotifiedPos = _basePosition;
      _elapsedSinceSync = Duration.zero;
      _lastTickerCheck = Duration.zero;
      if (_positionTicker?.isTicking ?? false) {
        _positionTicker!.stop();
        _positionTicker!.start();
      }
    }
  }

  @override
  void dispose() {
    widget.positionNotifier.removeListener(_onPositionSync);
    _positionTicker?.dispose();
    _glowController?.dispose();
    _glowController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLyrics = widget.lyrics.isNotEmpty;
    final AnimationController? ctrl = _glowController;

    // 로딩 중이면 스피너 표시
    if (widget.isLyricsLoading) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: widget.accentColor.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }

    // ── build()에서 positionNotifier.value 직접 읽지 않음
    // 모든 상태는 Ticker → _checkAndUpdate → setState 경로로만 갱신됨
    final String currentText;
    final bool isActive;
    if (!hasLyrics) {
      currentText = '';
      isActive = false;
    } else if (_isIntro) {
      // 인트로 구간: 첫 가사를 dim하게 미리 표시 (_isIntro는 Ticker가 관리)
      currentText = widget.lyrics.first.text;
      isActive = false;
    } else if (_displayText.isNotEmpty) {
      currentText = _displayText;
      isActive = true;
    } else {
      currentText = '';
      isActive = false;
    }

    return SizedBox(
      height: widget.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── 이전 가사 (dim)
          if (hasLyrics && _prevText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _prevText,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.18),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                  height: 1.3,
                ),
              ),
            ),

          // ── 현재 가사 (메인, 글로우 pulse)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: ctrl != null
                ? AnimatedBuilder(
                    key: ValueKey(currentText),
                    animation: ctrl,
                    builder: (_, __) {
                      final double g =
                          isActive ? 0.40 + ctrl.value * 0.30 : 0.0;
                      return _LyricText(
                        text: currentText,
                        isActive: isActive,
                        glowAlpha: g,
                        accentColor: widget.accentColor,
                      );
                    },
                  )
                : _LyricText(
                    key: ValueKey(currentText),
                    text: currentText,
                    isActive: isActive,
                    glowAlpha: isActive ? 0.55 : 0.0,
                    accentColor: widget.accentColor,
                  ),
          ),

          // ── 다음 가사 예고 (dim)
          if (hasLyrics && _nextText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _nextText,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.14),
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.2,
                  height: 1.3,
                ),
              ),
            ),

          // ── 장식 라인
          if (hasLyrics && isActive && ctrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) => Container(
                  width: 28 + ctrl.value * 12,
                  height: 1.0,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        widget.accentColor
                            .withValues(alpha: 0.30 + ctrl.value * 0.25),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 가사 텍스트 위젯 — 글로우 파라미터 분리
class _LyricText extends StatelessWidget {
  final String text;
  final bool isActive;
  final double glowAlpha;
  final Color accentColor;

  const _LyricText({
    super.key,
    required this.text,
    required this.isActive,
    required this.glowAlpha,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isActive
              ? Colors.white.withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.20),
          fontSize: isActive ? 19 : 15,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w300,
          letterSpacing: isActive ? -0.4 : 0.2,
          height: 1.35,
          shadows: glowAlpha > 0
              ? [
                  Shadow(
                    color: accentColor.withValues(alpha: glowAlpha),
                    blurRadius: 22,
                  ),
                  Shadow(
                    color: accentColor.withValues(alpha: glowAlpha * 0.5),
                    blurRadius: 48,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}


class _SpectrumPainter extends CustomPainter {
  final List<double> bands;
  final Color accentColor;
  final bool isPlaying;

  const _SpectrumPainter({
    required this.bands,
    required this.accentColor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final int count = bands.length;
    const double gapFraction = 0.32;
    final double slot = size.width / count;
    final double barW = slot * (1.0 - gapFraction);
    final double gap = slot * gapFraction;
    final double maxH = size.height * 0.92;
    const double minH = 2.5;
    final double cy = size.height / 2;
    final double rx = (barW / 2).clamp(0.5, 5.0);

    final Rect fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final double fadeH = size.height * 0.18;
    final Paint fadeMaskPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        [0.0, fadeH / size.height, 1.0 - fadeH / size.height, 1.0],
      )
      ..blendMode = BlendMode.dstIn;

    canvas.saveLayer(fullRect, Paint());

    for (int i = 0; i < count; i++) {
      final double v = bands[i].clamp(0.0, 1.0);
      final double barH = (maxH * v).clamp(minH, maxH);
      final double x = gap / 2 + i * slot;
      final double t =
          count > 1 ? i / (count - 1).toDouble() : 0.0;

      final Color barColor = Color.lerp(
        accentColor.withValues(alpha: 0.90),
        Colors.white.withValues(alpha: 0.50),
        t,
      )!;

      // 메인 바 (위아래 대칭 mirror)
      canvas.drawRRect(
        RRect.fromLTRBR(
          x, cy - barH / 2, x + barW, cy + barH / 2,
          Radius.circular(rx),
        ),
        Paint()
          ..color = barColor
          ..style = PaintingStyle.fill,
      );

      // 상단 하이라이트
      if (v > 0.10) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            x, cy - barH / 2, x + barW, cy - barH / 2 + 2.2,
            Radius.circular(rx),
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.30 * v)
            ..style = PaintingStyle.fill,
        );
      }

      // 저음 대역 글로우
      if (i < 10 && v > 0.55) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            x - 1, cy - barH / 2 - 1,
            x + barW + 1, cy + barH / 2 + 1,
            Radius.circular(rx + 1),
          ),
          Paint()
            ..color = accentColor.withValues(alpha: 0.18 * v)
            ..style = PaintingStyle.fill
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 3.0),
        );
      }
    }

    // 위아래 페이드
    canvas.drawRect(fullRect, fadeMaskPaint);

    // 좌우 비네트
    final double vigW = size.width * 0.22;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, vigW, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(vigW, 0),
          [Colors.black.withValues(alpha: 0.45), Colors.transparent],
        )
        ..blendMode = BlendMode.dstOut,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - vigW, 0, vigW, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width - vigW, 0),
          Offset(size.width, 0),
          [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
        )
        ..blendMode = BlendMode.dstOut,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) {
    if (old.accentColor != accentColor || old.isPlaying != isPlaying) {
      return true;
    }
    if (old.bands.length != bands.length) return true;
    for (int i = 0; i < bands.length; i++) {
      if ((old.bands[i] - bands[i]).abs() > 0.001) return true;
    }
    return false;
  }
}