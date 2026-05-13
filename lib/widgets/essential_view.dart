import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EssentialView  —  GLASNYL ESSENTIAL 모드
//
// 디자인
//   • 배경은 기존 플레이어 배경 그대로 유지 (별도 오버레이 없음)
//   • "ESSENTIAL" 레이블 — 화면 세로 중상단에 크게 중앙 배치
//   • FFT 스펙트럼 — 레이블 바로 아래, 글자 너비보다 살짝 넓게
//   • EssentialMiniInfo — 우측 상단 앨범아트 + 트랙 정보
//   • AppBar용 EssentialToggleButton
//
// [시뮬레이션]
//   네이티브 FFT 채널(com.glasnyl.app/fft_data)이 없을 때
//   단일 Ticker 루프가 저/중/고음 대역별 에너지를 독립적으로 움직여
//   음악 느낌을 최대한 살립니다. 실제 데이터가 오면 자동 전환됩니다.
//
// [player_screen.dart 적용]
//   if (_isEssentialMode && !_isPipMode && !_isScreenLocked) ...[
//     EssentialView(
//       albumArtBytes: _albumArtBytes,
//       title: _currentTitle,
//       artist: _currentArtist,
//       isPlaying: _isPlaying,
//       accentColor: _playBtnColor,
//       textColor: _textColor,
//     ),
//     EssentialMiniInfo(
//       albumArtBytes: _albumArtBytes,
//       title: _currentTitle,
//       artist: _currentArtist,
//       accentColor: _playBtnColor,
//     ),
//   ],
// ══════════════════════════════════════════════════════════════════════════════

class EssentialView extends StatefulWidget {
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;
  final bool isPlaying;
  final Color accentColor;
  final Color textColor;

  const EssentialView({
    super.key,
    required this.albumArtBytes,
    required this.title,
    required this.artist,
    required this.isPlaying,
    required this.accentColor,
    required this.textColor,
  });

  @override
  State<EssentialView> createState() => _EssentialViewState();
}

class _EssentialViewState extends State<EssentialView>
    with TickerProviderStateMixin {
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

  // repaint notifier (setState 없이 CustomPaint만 갱신)
  final ValueNotifier<int> _repaintTick = ValueNotifier(0);

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

    _startFftStream();
  }

  // ── 네이티브 FFT 연결 시도
  void _startFftStream() {
    try {
      _fftSub = _fftChannel.receiveBroadcastStream().listen(
        (data) {
          if (!mounted) return;
          if (data is List && data.isNotEmpty) {
            _useSimulation = false;
            final len = math.min(data.length, _bandCount);
            for (int i = 0; i < len; i++) {
              _bands[i] = (data[i] as num).toDouble().clamp(0.0, 1.0);
            }
            _repaintTick.value++;
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

  // ── 시뮬레이션 시작
  void _startSimulation() {
    if (!mounted || _useSimulation) return;
    _useSimulation = true;
    _lastTick = DateTime.now();
    _simTicker = createTicker((_) {
      if (!mounted) return;
      final now = DateTime.now();
      final dt =
          now.difference(_lastTick).inMicroseconds / 1e6;
      _lastTick = now;
      _elapsedSeconds += dt;
      _simulateTick(dt);
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

    // 비트 에너지 (저음 4대역)
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
        // 저음: 묵직하게
        energy = 0.55 + 0.45 * math.sin(phase * 1.1);
        energy += _beatPulse * (1.0 - t) * 0.6;
        energy *= 0.75 + _rand.nextDouble() * 0.25;
      } else if (i < 36) {
        // 중음: 보컬/기타
        final w1 = 0.5 + 0.5 * math.sin(phase * 0.9);
        final w2 = 0.5 + 0.5 * math.cos(phase * 1.3 + 1.2);
        energy = w1 * 0.6 + w2 * 0.4;
        energy *= 0.45 + _rand.nextDouble() * 0.35;
      } else {
        // 고음: 낮고 섬세하게
        energy =
            0.08 + 0.22 * math.pow(math.sin(phase * 1.7).abs(), 1.5);
        energy *= 0.6 + _rand.nextDouble() * 0.4;
      }

      _target[i] = energy.clamp(0.0, 1.0);

      // 어택 빠르게, 릴리즈 느리게
      final double diff = _target[i] - _envelope[i];
      final double rate = diff > 0 ? 12.0 : 5.5;
      _envelope[i] =
          (_envelope[i] + diff * rate * dt).clamp(0.0, 1.0);
      _bands[i] = _envelope[i];
    }
  }

  @override
  void dispose() {
    _fftSub?.cancel();
    _simTicker?.dispose();
    _enterController.dispose();
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

    // ESSENTIAL 레이블 위치
    final double labelTop = isLandscape
        ? topPad + (screenH - topPad) * 0.14
        : topPad + (screenH - topPad) * 0.26;

    // 스펙트럼 너비 (레이블보다 살짝 넓게)
    final double specW = screenW * 0.80;
    final double specLeft = (screenW - specW) / 2;

    // 스펙트럼 높이
    final double specH = isLandscape
        ? (screenH * 0.34).clamp(70.0, 200.0)
        : (screenH * 0.22).clamp(80.0, 200.0);

    // 레이블 고도 약 68px (텍스트 + 서브 + 라인 + padding)
    final double specTop = labelTop + 68.0 + 14.0;

    return Positioned.fill(
      child: FadeTransition(
        opacity: _enterFade,
        child: SlideTransition(
          position: _enterSlide,
          child: Stack(
            children: [
              // ── ESSENTIAL 레이블 (중앙 크게)
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
                        bands: List.of(_bands),
                        accentColor: widget.accentColor,
                        isPlaying: widget.isPlaying,
                      ),
                    ),
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
        // 상단 장식 라인
        Container(
          width: 36,
          height: 0.8,
          color: Colors.white.withValues(alpha: 0.22),
          margin: const EdgeInsets.only(bottom: 10),
        ),
        // 메인 레이블
        Text(
          'ESSENTIAL',
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
        // 서브 레이블
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
  final bool isPlaying;
  final Color accentColor;

  const _EssentialFooter({
    required this.title,
    required this.artist,
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
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// EssentialMiniInfo  —  우측 상단 미니 앨범아트 + 트랙 정보
// ──────────────────────────────────────────────────────────────────────────────
class EssentialMiniInfo extends StatelessWidget {
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;
  final Color accentColor;

  const EssentialMiniInfo({
    super.key,
    required this.albumArtBytes,
    required this.title,
    required this.artist,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.of(context).padding.top + 54.0;
    final double rightPad = MediaQuery.of(context).padding.right + 16.0;

    return Positioned(
      top: topPad,
      right: rightPad,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 190),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: albumArtBytes != null
                          ? Image.memory(
                              albumArtBytes!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                            )
                          : Container(
                              color: Colors.white.withValues(alpha: 0.10),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: accentColor,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artist,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// EssentialToggleButton  —  AppBar에 삽입할 토글 버튼
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              'ESSENTIAL',
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
// _SpectrumPainter
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

      // 저음 대역 글로우 (비트감 강조)
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
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.bands != bands ||
      old.accentColor != accentColor ||
      old.isPlaying != isPlaying;
}