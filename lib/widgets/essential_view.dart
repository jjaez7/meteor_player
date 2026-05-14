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
// 변경점 (v3) — 가사 싱크 전면 재작성
//   • _LyricsLineView → _AestheticLyricsScroller 로 교체
//   • LP 모드(_LyricsAutoScroller)와 완전히 동일한 싱크 로직 사용
//   • 디자인만 aesthetic (prev/current/next 3줄 + 글로우 pulse) 유지
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
  final VoidCallback? onLyricsActivated; // LRC 토글 시 시계 3번 탭과 동일 횬고

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
    this.onLyricsActivated,
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
      // ㌐파티클 제거 (issue 6)
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

    if (nextMode == _SpectrumMode.lyrics) {
      // LRC 토글 시 시계 3탭 횬고 효과
      widget.onLyricsActivated?.call();
      if (!_useSimulation) _startSimulation();
    } else if (nextMode == _SpectrumMode.auto) {
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
        : topPad + (screenH - topPad) * 0.22;

    final double specW = screenW * 0.80;
    final double specLeft = (screenW - specW) / 2;

    final double specH = isLandscape
        ? (screenH * 0.34).clamp(90.0, 220.0)
        : (screenH * 0.25).clamp(110.0, 220.0);

    // portrait: label(68) + gap(16) + toggle(24) + gap(12) = specTop
    // landscape: original position (label + 68 + 14), toggle at specTop-28
    final double specTop = isLandscape
        ? labelTop + 68.0 + 14.0
        : labelTop + 68.0 + 16.0 + 24.0 + 12.0;
    final double toggleTop = labelTop + 68.0 + 16.0; // portrait only

    final double ringCx = screenW / 2;
    final double ringCy = specTop + specH / 2;

    return SizedBox.expand(
      child: FadeTransition(
        opacity: _enterFade,
        child: SlideTransition(
          position: _enterSlide,
          child: Stack(
            children: [
              // ── 앨범아트 블러 배경
              if (widget.albumArtBytes != null)
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    child: SizedBox.expand(
                      key: ValueKey(widget.albumArtBytes.hashCode),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                        child: Image.memory(
                          widget.albumArtBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
              // ── 위에 어두운 오버레이 (가독성 확보)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.70),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

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
                  child: _EssentialLabel(
                    textColor: widget.textColor,
                    accentColor: widget.accentColor,
                  ),
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

              // ── 내부 모드 토글 (AUTO ↔ FREQ ↔ LYRICS)
              // portrait: GLASNYL 아래 중앙 / landscape: 스펙트럼 위 우측 (원래 위치)
              if (isLandscape)
                Positioned(
                  top: specTop - 28,
                  right: specLeft,
                  child: _InternalModeToggle(
                    mode: _specMode,
                    accentColor: widget.accentColor,
                    onToggle: _onToggleMode,
                  ),
                )
              else
                Positioned(
                  top: toggleTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _InternalModeToggle(
                      mode: _specMode,
                      accentColor: widget.accentColor,
                      onToggle: _onToggleMode,
                    ),
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
class _EssentialLabel extends StatefulWidget {
  final Color textColor;
  final Color accentColor;
  const _EssentialLabel({required this.textColor, required this.accentColor});

  @override
  State<_EssentialLabel> createState() => _EssentialLabelState();
}

class _EssentialLabelState extends State<_EssentialLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) {
        final double g = 0.18 + _glow.value * 0.28;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 가는 라인 — accent 컬러로
            Container(
              width: 48,
              height: 0.8,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    widget.accentColor.withValues(alpha: 0.70),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Text(
              'AESTHETIC',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 10.0,
                color: Colors.white.withValues(alpha: 0.92),
                shadows: [
                  Shadow(
                    color: widget.accentColor.withValues(alpha: g),
                    blurRadius: 28,
                  ),
                  Shadow(
                    color: widget.accentColor.withValues(alpha: g * 0.55),
                    blurRadius: 56,
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 0.5,
                  color: widget.accentColor.withValues(alpha: 0.35),
                  margin: const EdgeInsets.only(right: 6),
                ),
                Text(
                  'GLASNYL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5.5,
                    color: widget.accentColor.withValues(alpha: 0.45),
                  ),
                ),
                Container(
                  width: 16,
                  height: 0.5,
                  color: widget.accentColor.withValues(alpha: 0.35),
                  margin: const EdgeInsets.only(left: 6),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _EssentialFooter
// ──────────────────────────────────────────────────────────────────────────────
class _EssentialFooter extends StatefulWidget {
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
  State<_EssentialFooter> createState() => _EssentialFooterState();
}

class _EssentialFooterState extends State<_EssentialFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playAnim;

  @override
  void initState() {
    super.initState();
    _playAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) _playAnim.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_EssentialFooter old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _playAnim.repeat(reverse: true);
      } else {
        _playAnim.stop();
        _playAnim.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _playAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              // 재생 인디케이터 — 3개 바 애니메이션
              AnimatedBuilder(
                animation: _playAnim,
                builder: (_, __) {
                  return SizedBox(
                    width: 14,
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(3, (i) {
                        final double phase = (i / 2.0);
                        final double v = widget.isPlaying
                            ? (0.35 + 0.65 * ((math.sin(
                                    (_playAnim.value + phase) * math.pi) +
                                1) /
                                2))
                            : 0.20;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          width: 3,
                          height: (20 * v).clamp(3.0, 20.0),
                          decoration: BoxDecoration(
                            color: widget.isPlaying
                                ? widget.accentColor.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              // 구분선
              Container(
                width: 0.6,
                height: 32,
                color: Colors.white.withValues(alpha: 0.12),
                margin: const EdgeInsets.only(right: 14),
              ),
              // 곡 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.artist,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.albumName != null &&
                            widget.albumName!.isNotEmpty) ...[
                          Container(
                            width: 3,
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              widget.albumName!,
                              style: TextStyle(
                                color: widget.accentColor.withValues(alpha: 0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.4,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
// _LyricsLineView  —  LP 모드(_LyricsAutoScroller)와 동일한 싱크 로직
//                     디자인만 aesthetic 스타일로 변경
// ──────────────────────────────────────────────────────────────────────────────
// ── _LyricsLineView: LP 모드(_LyricsAutoScroller)와 완전히 동일한 싱크 로직
// StatefulWidget wrapper — positionNotifier → currentPosition으로 변환해서 넘김
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

class _LyricsLineViewState extends State<_LyricsLineView> {
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.positionNotifier.value;
    widget.positionNotifier.addListener(_onPositionChanged);
  }

  void _onPositionChanged() {
    if (!mounted) return;
    setState(() {
      _currentPosition = widget.positionNotifier.value;
    });
  }

  @override
  void didUpdateWidget(_LyricsLineView old) {
    super.didUpdateWidget(old);
    if (old.positionNotifier != widget.positionNotifier) {
      old.positionNotifier.removeListener(_onPositionChanged);
      _currentPosition = widget.positionNotifier.value;
      widget.positionNotifier.addListener(_onPositionChanged);
    }
  }

  @override
  void dispose() {
    widget.positionNotifier.removeListener(_onPositionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AestheticLyricsScroller(
      key: ValueKey('${widget.lyrics.length}_${widget.lyrics.isNotEmpty ? widget.lyrics.first.text : ''}'),
      lyrics: widget.lyrics,
      currentPosition: _currentPosition,
      height: widget.height,
      accentColor: widget.accentColor,
      isLyricsLoading: widget.isLyricsLoading,
      isPlaying: widget.isPlaying,
    );
  }
}

// ── _AestheticLyricsScroller: LP의 _LyricsAutoScroller 로직 그대로,
//    디자인만 aesthetic (prev/current/next 3줄 + 글로우 pulse)
class _AestheticLyricsScroller extends StatefulWidget {
  final List<LyricLine> lyrics;
  final Duration currentPosition;
  final double height;
  final Color accentColor;
  final bool isLyricsLoading;
  final bool isPlaying;

  const _AestheticLyricsScroller({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    required this.height,
    required this.accentColor,
    this.isLyricsLoading = false,
    required this.isPlaying,
  });

  @override
  State<_AestheticLyricsScroller> createState() => _AestheticLyricsScrollerState();
}

class _AestheticLyricsScrollerState extends State<_AestheticLyricsScroller>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late Ticker _ticker;

  int _lastIndex = -1;
  int _maxIndexReached = -1;

  // LP 모드와 완전히 동일한 동기화 변수
  Duration _basePosition = Duration.zero;
  Duration _elapsedSinceSync = Duration.zero;
  Duration _lastTickerCheck = Duration.zero;
  static const Duration _throttleInterval = Duration(milliseconds: 25);

  // 글로우 pulse
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _basePosition = widget.currentPosition;
    _lastIndex = _calculateCurrentIndex(_basePosition);
    _maxIndexReached = _lastIndex;

    _ticker = createTicker((elapsed) {
      if (!mounted || !widget.isPlaying) return;
      if (elapsed - _lastTickerCheck < _throttleInterval) return;
      _lastTickerCheck = elapsed;
      _elapsedSinceSync = elapsed;
      _checkAndUpdate();
    });

    if (widget.isPlaying) _ticker.start();
  }

  void _checkAndUpdate() {
    final precisePos = _basePosition +
        _elapsedSinceSync +
        const Duration(milliseconds: 50);
    final int newIndex = _calculateCurrentIndex(precisePos);

    if (newIndex != -1 && newIndex != _lastIndex) {
      _lastIndex = newIndex;
      if (newIndex > _maxIndexReached) _maxIndexReached = newIndex;
      if (mounted) setState(() {});
    }
  }

  int _calculateCurrentIndex(Duration pos) {
    if (widget.lyrics.isEmpty) return -1;

    int lo = 0, hi = widget.lyrics.length - 1, index = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (widget.lyrics[mid].time <= pos) {
        index = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    // 자연 재생 중에는 절대 이전 가사로 돌아가지 않음 (LP와 동일)
    if (index < _maxIndexReached && _maxIndexReached != -1) {
      return _maxIndexReached;
    }
    return index;
  }

  @override
  void didUpdateWidget(_AestheticLyricsScroller old) {
    super.didUpdateWidget(old);

    // 재생 상태 변경
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _basePosition = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
        _lastTickerCheck = Duration.zero;
        if (!_ticker.isTicking) _ticker.start();
      } else {
        _ticker.stop();
        _basePosition = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
      }
    }

    // 위치 변경 시 drift/seek 감지 (LP와 완전히 동일)
    if (widget.currentPosition != old.currentPosition) {
      final estimatedNow = _basePosition + _elapsedSinceSync;
      final drift = (widget.currentPosition - estimatedNow).abs();
      final bool isSeek =
          (widget.currentPosition - old.currentPosition).abs().inMilliseconds > 300 ||
          widget.currentPosition < old.currentPosition;

      if (isSeek || drift > const Duration(milliseconds: 500)) {
        _basePosition = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
        _lastTickerCheck = Duration.zero;

        if (_ticker.isTicking) {
          _ticker.stop();
          _ticker.start();
        }

        final int newIndex = _calculateCurrentIndex(widget.currentPosition);
        _lastIndex = newIndex;
        _maxIndexReached = newIndex;
        if (mounted) setState(() {});
      }
    }

    // 가사 목록 교체
    if (widget.lyrics != old.lyrics) {
      _basePosition = widget.currentPosition;
      _elapsedSinceSync = Duration.zero;
      _lastIndex = -1;
      _maxIndexReached = -1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // App resumed -> resync lyrics position (issues 4, 5)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _basePosition = widget.currentPosition;
      _elapsedSinceSync = Duration.zero;
      _lastTickerCheck = Duration.zero;
      final int newIdx = _calculateCurrentIndex(_basePosition);
      _lastIndex = newIdx;
      _maxIndexReached = newIdx;
      if (widget.isPlaying && !_ticker.isTicking) _ticker.start();
      if (mounted) setState(() {});
    }
    if (state == AppLifecycleState.paused) {
      if (_ticker.isTicking) _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩
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

    final bool hasLyrics = widget.lyrics.isNotEmpty;
    final int idx = _lastIndex;

    // 인트로 구간 판단 — positionNotifier.value 직접 읽지 않고
    // didUpdateWidget으로 받은 currentPosition 사용
    final bool isIntro = hasLyrics && widget.currentPosition < widget.lyrics.first.time;

    final String currentText = idx >= 0
        ? widget.lyrics[idx].text
        : (isIntro ? widget.lyrics.first.text : '');
    final bool isActive = idx >= 0 && !isIntro;

    return SizedBox(
      height: widget.height,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          child: AnimatedBuilder(
            key: ValueKey(currentText),
            animation: _glowController,
            builder: (_, __) {
              final double g = isActive ? 0.45 + _glowController.value * 0.30 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  currentText,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.22),
                    fontSize: isActive ? 26 : 18,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w300,
                    letterSpacing: isActive ? -0.5 : 0.2,
                    height: 1.3,
                    shadows: g > 0
                        ? [
                            Shadow(
                              color: widget.accentColor.withValues(alpha: g),
                              blurRadius: 28,
                            ),
                            Shadow(
                              color: widget.accentColor.withValues(alpha: g * 0.5),
                              blurRadius: 56,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
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
    final double maxH = size.height * 0.88;
    const double minH = 2.5;
    final double cy = size.height / 2;
    final double rx = (barW / 2).clamp(0.5, 5.0);

    final Rect fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final double fadeH = size.height * 0.16;
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

    // 반사 레이어용 saveLayer (아래쪽 절반만 희미하게)
    for (int i = 0; i < count; i++) {
      final double v = bands[i].clamp(0.0, 1.0);
      final double barH = (maxH * v).clamp(minH, maxH);
      final double x = gap / 2 + i * slot;
      final double t = count > 1 ? i / (count - 1).toDouble() : 0.0;

      // 메인 바 — 그라디언트 (accent → white)
      final Rect barRect = Rect.fromLTRB(x, cy - barH / 2, x + barW, cy + barH / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, Radius.circular(rx)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, cy - barH / 2),
            Offset(x, cy + barH / 2),
            [
              Color.lerp(accentColor, Colors.white, 0.25 + t * 0.35)!
                  .withValues(alpha: 0.92),
              accentColor.withValues(alpha: 0.55 - t * 0.20),
              Color.lerp(accentColor, Colors.white, 0.25 + t * 0.35)!
                  .withValues(alpha: 0.92),
            ],
            [0.0, 0.5, 1.0],
          )
          ..style = PaintingStyle.fill,
      );

      // 상단 캡 글로우
      if (v > 0.08) {
        final double capY = cy - barH / 2;
        canvas.drawRRect(
          RRect.fromLTRBR(x, capY, x + barW, capY + 2.5, Radius.circular(rx)),
          Paint()
            ..color = Colors.white.withValues(alpha: (0.55 * v).clamp(0.0, 0.55))
            ..style = PaintingStyle.fill,
        );
      }

      // 저음 대역 외부 글로우
      if (i < 12 && v > 0.45) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            barRect.inflate(1.5),
            Radius.circular(rx + 1.5),
          ),
          Paint()
            ..color = accentColor.withValues(alpha: 0.22 * v)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
        );
      }

      // 반사 (아래쪽, 50% 투명도 + 짧게)
      final double reflH = barH * 0.30;
      final double reflTop = cy + barH / 2 + 2;
      if (reflH > 1.5) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            x, reflTop, x + barW, reflTop + reflH,
            Radius.circular(rx),
          ),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x, reflTop),
              Offset(x, reflTop + reflH),
              [
                accentColor.withValues(alpha: 0.18 * v),
                Colors.transparent,
              ],
            )
            ..style = PaintingStyle.fill,
        );
      }
    }

    // 위아래 페이드
    canvas.drawRect(fullRect, fadeMaskPaint);

    // 좌우 비네트
    final double vigW = size.width * 0.18;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, vigW, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(vigW, 0),
          [Colors.black.withValues(alpha: 0.50), Colors.transparent],
        )
        ..blendMode = BlendMode.dstOut,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - vigW, 0, vigW, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width - vigW, 0),
          Offset(size.width, 0),
          [Colors.transparent, Colors.black.withValues(alpha: 0.50)],
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