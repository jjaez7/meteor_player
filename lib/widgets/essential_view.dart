import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
// [player_screen.dart 적용 — 변경 없음]
//   EssentialView(
//     albumArtBytes: _albumArtBytes,
//     title: _currentTitle,
//     artist: _currentArtist,
//     albumName: _currentAlbumName,
//     isPlaying: _isPlaying,
//     accentColor: _playBtnColor,
//     textColor: _textColor,
//   ),
// ══════════════════════════════════════════════════════════════════════════════

// ── 내부 뷰 모드
enum _SpectrumMode { auto, freq }

class EssentialView extends StatefulWidget {
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;
  final String? albumName;
  final bool isPlaying;
  final Color accentColor;
  final Color textColor;

  const EssentialView({
    super.key,
    required this.albumArtBytes,
    required this.title,
    required this.artist,
    this.albumName,
    required this.isPlaying,
    required this.accentColor,
    required this.textColor,
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
            // AUTO 모드에서는 시뮬을 건드리지 않음
            // FREQ 모드일 때만 시뮬 중단 및 타임아웃 타이머 갱신
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
              for (int i = 0; i < _bandCount; i++) {
                // 선형 매핑: _nativeBands(32) → _bandCount(64) 균등 분배
                final double pos = i / (_bandCount - 1) * (_nativeBands - 1);
                final int lo = pos.floor().clamp(0, _nativeBands - 1);
                final int hi = (lo + 1).clamp(0, _nativeBands - 1);
                final double t = pos - lo;
                double v = incoming[lo] * (1 - t) + incoming[hi] * t;

                // 노이즈 플로어: 고주파일수록 최소 움직임 보장
                // i=0 → 0.0, i=63 → 0.08 (눈에 띄는 최소 진동)
                final double bandT = i / (_bandCount - 1);
                final double noiseFloor = bandT * 0.08 * (0.5 + _rand.nextDouble());
                v = (v + noiseFloor).clamp(0.0, 1.0);

                // 감쇠: 전 대역 균일 (빠른 반응)
                const double decay = 0.70;
                if (v > _bands[i]) {
                  _bands[i] = v;
                } else {
                  _bands[i] = (_bands[i] * decay + v * (1.0 - decay)).clamp(0.0, 1.0);
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
    // AUTO 모드에서는 파티클/링 비활성화
    if (!widget.isPlaying || _specMode == _SpectrumMode.auto) {
      _beatRings.clear();
      _particles.clear();
      return;
    }

    // 비트 링 발생 (beatPulse 급등 감지)
    if (_beatPulse > 0.65 && _lastBeatPulse <= 0.40) {
      _beatRings.add(_BeatRing(
        radius: 0.0,
        alpha: 0.55 + _rand.nextDouble() * 0.25,
        speed: 80.0 + _rand.nextDouble() * 40.0,
      ));
      // 파티클 방출
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

    // 비트 링 업데이트
    for (final ring in _beatRings) {
      ring.radius += ring.speed * dt;
      ring.alpha -= dt * 1.2;
    }
    _beatRings.removeWhere((r) => r.alpha <= 0.0);

    // 파티클 업데이트
    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 30 * dt; // 약한 중력
      p.life -= dt * 1.0;
      p.alpha = (p.life * 0.9).clamp(0.0, 1.0);
    }
    _particles.removeWhere((p) => p.life <= 0.0);
  }

  void _onToggleMode() {
    HapticFeedback.selectionClick();
    // 먼저 다음 상태를 변수에 저장 (setState는 비동기이므로 블록 밖에서 읽으면 이전 값)
    final nextMode = _specMode == _SpectrumMode.auto
        ? _SpectrumMode.freq
        : _SpectrumMode.auto;

    setState(() {
      _specMode = nextMode;
    });

    if (nextMode == _SpectrumMode.auto) {
      // AUTO로 전환 → 시뮬 시작 (FFT 스트림은 계속 수신하되 무시됨)
      if (!_useSimulation) _startSimulation();
    } else {
      // FREQ로 전환 → 시뮬 중단, FFT 데이터 대기
      _simTicker?.stop();
      _useSimulation = false;
      // 데이터가 안 오면 시뮬 폴백 타이머 재시작
      _fftTimeoutTimer?.cancel();
      _fftTimeoutTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && !_useSimulation) _startSimulation();
      });
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
        ? (screenH * 0.34).clamp(70.0, 200.0)
        : (screenH * 0.22).clamp(80.0, 200.0);

    final double specTop = labelTop + 68.0 + 14.0;

    // 비트 링 중심 = 스펙트럼 세로 중앙
    final double ringCx = screenW / 2;
    final double ringCy = specTop + specH / 2;

    // ❌ Positioned.fill 제거 — 부모가 Stack 직계가 아니면 ParentDataWidget 에러 발생
    // player_screen.dart에서 AnimatedOpacity > IgnorePointer 안에 들어가므로
    // SizedBox.expand + Stack으로 대체
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
                    builder: (_, __, ___) => CustomPaint(
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

              // ── FFT 스펙트럼
              Positioned(
                top: specTop,
                left: specLeft,
                width: specW,
                height: specH,
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _repaintTick,
                    builder: (_, __, ___) => CustomPaint(
                      painter: _SpectrumPainter(
                        // 리스트 복사로 shouldRepaint 정상 동작
                        bands: List<double>.from(_bands),
                        accentColor: widget.accentColor,
                        isPlaying: widget.isPlaying,
                      ),
                    ),
                  ),
                ),
              ),

              // ── 주파수 힌트 레이블 (SUB / MID / HI)
              Positioned(
                top: specTop + specH + 8,
                left: specLeft,
                width: specW,
                child: _FreqLabels(accentColor: widget.accentColor),
              ),

              // ── 내부 모드 토글 (AUTO ↔ FREQ) — 스펙트럼 위 우측
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
// _InternalModeToggle  —  AUTO ↔ FREQ 토글 (잘 안 보이는 pill 스타일)
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
    final bool isFreq = mode == _SpectrumMode.freq;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isFreq
              ? accentColor.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFreq
                ? accentColor.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AUTO 레이블
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: !isFreq
                    ? Colors.white.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.18),
              ),
              child: const Text('AUTO'),
            ),
            // 구분선
            Container(
              width: 0.5,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            // FREQ 레이블
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: isFreq
                    ? accentColor.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.18),
              ),
              child: const Text('FREQ'),
            ),
          ],
        ),
      ),
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
    // 비트 링
    for (final ring in rings) {
      final paint = Paint()
        ..color = accentColor.withValues(alpha: ring.alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(cx, cy), ring.radius, paint);
    }

    // 파티클
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
// _SpectrumPainter  —  FFT 버그 수정 + 미러 강화
// ──────────────────────────────────────────────────────────────────────────────
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
    // ✅ 버그 수정: 리스트 참조가 아닌 내용 비교
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