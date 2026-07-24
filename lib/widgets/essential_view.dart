import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/lyric_model.dart';
import 'fluid/fluid_kit.dart';
import '../theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
// 변경점 (v4) — 하단 플레이어 자유 배치
//   • 하단 정보 바를 자유롭게 드래그 + 모서리로 리사이즈 가능하게 변경
//   • prev/play/next 버튼 추가
//   • 크게 리사이즈하면 정사각형 앨범아트를 끌어와 빈 공간을 채우는 확장 레이아웃으로 전환
//   • 위치/크기는 SharedPreferences에 저장되어 다음 실행에도 유지됨
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
  final VoidCallback? onTogglePlay;
  final VoidCallback? onSkipNext;
  final VoidCallback? onSkipPrevious;

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
    this.onTogglePlay,
    this.onSkipNext,
    this.onSkipPrevious,
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

  // ── (v4) 커스텀 타이틀 / 포커스 모드 / 하단 플레이어 자유 배치
  String? _customTitle; // null이면 기본 "AESTHETIC" 표시
  bool _focusMode = false; // true면 배경+하단플레이어+가사 외엔 다 숨김
  Offset _footerOffset = Offset.zero; // 기본 위치 대비 드래그 이동량
  double _footerWidthDelta = 0.0; // 기본 너비 대비 리사이즈 증감량
  double _footerHeightDelta = 0.0; // 기본 높이 대비 리사이즈 증감량
  static const String _kCustomTitleKey = 'essential_custom_title';
  static const String _kFocusModeKey = 'essential_focus_mode';
  static const String _kFooterDxKey = 'essential_footer_dx';
  static const String _kFooterDyKey = 'essential_footer_dy';
  static const String _kFooterWKey = 'essential_footer_w_delta';
  static const String _kFooterHKey = 'essential_footer_h_delta';

  Future<void> _loadFooterPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _customTitle = prefs.getString(_kCustomTitleKey);
      _focusMode = prefs.getBool(_kFocusModeKey) ?? false;
      _footerOffset = Offset(
        prefs.getDouble(_kFooterDxKey) ?? 0.0,
        prefs.getDouble(_kFooterDyKey) ?? 0.0,
      );
      _footerWidthDelta = prefs.getDouble(_kFooterWKey) ?? 0.0;
      _footerHeightDelta = prefs.getDouble(_kFooterHKey) ?? 0.0;
    });
  }

  Future<void> _saveFooterTransform() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFooterDxKey, _footerOffset.dx);
    await prefs.setDouble(_kFooterDyKey, _footerOffset.dy);
    await prefs.setDouble(_kFooterWKey, _footerWidthDelta);
    await prefs.setDouble(_kFooterHKey, _footerHeightDelta);
  }

  Future<void> _saveCustomTitle(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_kCustomTitleKey);
    } else {
      await prefs.setString(_kCustomTitleKey, value.trim());
    }
  }

  Future<void> _saveFocusMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFocusModeKey, value);
  }

  Future<void> _renameTitle() async {
    final controller = TextEditingController(text: _customTitle ?? 'AESTHETIC');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B20).withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GRadius.mediumCard),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        title: const Text(
          'Change Title',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: Colors.white, letterSpacing: 4),
          decoration: InputDecoration(
            hintText: 'AESTHETIC',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''), // 빈 문자열 = 기본값 복원
            child: Text('Default', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Save', style: TextStyle(color: widget.accentColor)),
          ),
        ],
      ),
    );
    if (result == null) return; // 취소
    final newTitle = result.trim().isEmpty ? null : result.trim().toUpperCase();
    if (!mounted) return;
    setState(() => _customTitle = newTitle);
    _saveCustomTitle(newTitle);
  }

  @override
  void initState() {
    super.initState();

    _loadFooterPrefs();

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

    // ── (v4) 하단 플레이어 자유 배치 — 기본 위치/크기에 드래그·리사이즈 증감량 적용
    final double footerBaseLeft = mq.padding.left + 28;
    final double footerBaseRight = mq.padding.right + 28;
    final double footerBaseWidth = screenW - footerBaseLeft - footerBaseRight;
    const double footerBaseHeight = 76.0;
    final double footerBaseTop =
        screenH - (mq.padding.bottom + 32.0) - footerBaseHeight;

    final double footerWidth =
        (footerBaseWidth + _footerWidthDelta).clamp(180.0, screenW - 20.0);
    final double footerHeight =
        (footerBaseHeight + _footerHeightDelta).clamp(64.0, screenH * 0.7);
    final double footerLeft = (footerBaseLeft + _footerOffset.dx)
        .clamp(0.0, math.max(0.0, screenW - footerWidth));
    final double footerTop = (footerBaseTop + _footerOffset.dy)
        .clamp(mq.padding.top, math.max(mq.padding.top, screenH - mq.padding.bottom - footerHeight));

    return SizedBox.expand(
      child: FadeTransition(
        opacity: _enterFade,
        child: SlideTransition(
          position: _enterSlide,
          child: Stack(
            children: [
              // ── 앨범아트 블러 배경 (스펙: brightness -8%, saturation -8%, contrast +3%)
              if (widget.albumArtBytes != null)
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    child: SizedBox.expand(
                      key: ValueKey(widget.albumArtBytes.hashCode),
                      child: ColorFiltered(
                        // 계산된 고정 컬러 그레이딩 행렬 (brightness*contrast 스케일 +
                        // saturation 블렌드 + contrast translate). 입력값이 고정이라
                        // 매 프레임 재계산 없이 상수로 둠 — 성능에 영향 없음.
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.8946, 0.0445, 0.0086, 0, -3.84,
                          0.0227, 0.9163, 0.0086, 0, -3.84,
                          0.0227, 0.0445, 0.8806, 0, -3.84,
                          0, 0, 0, 1, 0,
                        ]),
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
                ),
              // ── 소프트 비네트 (스펙: opacity 8% 미만, 가장자리만 은은하게)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.0,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.07),
                        ],
                        stops: const [0.6, 1.0],
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

              // ── (v4) 좌/우 가장자리 탭 — 오른쪽: 다음 곡, 왼쪽: 이전 곡
              // 다른 컨트롤(버튼, 하단 플레이어 등)보다 먼저 쌓아서, 겹치는 영역은
              // 나중에 그려지는 위젯이 우선권을 가져 설정/버튼 탭이 씹히지 않음
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 64,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onSkipPrevious,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 64,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onSkipNext,
                ),
              ),

              // ── 앰비언트 halo (FFT 뒤편, 아주 은은하게 숨쉬는 accent 톤)
              if (!_focusMode)
                Positioned(
                  left: ringCx - specW * 0.6,
                  top: ringCy - specW * 0.6,
                  width: specW * 1.2,
                  height: specW * 1.2,
                  child: RepaintBoundary(
                    child: _AccentHalo(accentColor: widget.accentColor),
                  ),
                ),

              // ── 비트 링 + 파티클 레이어
              if (!_focusMode)
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

              // ── AESTHETIC 레이블 (탭하면 이름 변경 가능)
              if (!_focusMode)
                Positioned(
                  top: labelTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _renameTitle,
                      child: _EssentialLabel(
                        text: _customTitle ?? 'AESTHETIC',
                        textColor: widget.textColor,
                        accentColor: widget.accentColor,
                      ),
                    ),
                  ),
                ),

              // ── FFT 스펙트럼 (LYRICS 모드 또는 포커스 모드에서는 숨김)
              Positioned(
                top: specTop,
                left: specLeft,
                width: specW,
                height: specH,
                child: AnimatedOpacity(
                  opacity: (_specMode == _SpectrumMode.lyrics || _focusMode) ? 0.0 : 1.0,
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

              // ── 가사 한 줄 오버레이 (LYRICS 모드 또는 포커스 모드에서 표시)
              Positioned(
                top: specTop,
                left: specLeft - 16,
                width: specW + 32,
                height: specH,
                child: AnimatedOpacity(
                  opacity: (_specMode == _SpectrumMode.lyrics || _focusMode) ? 1.0 : 0.0,
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

              // ── 주파수 힌트 레이블 (SUB / MID / HI) — LYRICS/포커스 모드에서 숨김
              if (!_focusMode)
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

              // ── 내부 모드 토글 (AUTO ↔ FREQ ↔ LYRICS) — 포커스 모드에서 숨김
              // portrait: GLASNYL 아래 중앙 / landscape: 스펙트럼 위 우측 (원래 위치)
              if (!_focusMode)
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

              // ── 하단 곡 정보 — 자유 드래그 + 모서리 리사이즈
              Positioned(
                left: footerLeft,
                top: footerTop,
                width: footerWidth,
                height: footerHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onPanUpdate: (d) {
                        setState(() => _footerOffset += d.delta);
                      },
                      onPanEnd: (_) => _saveFooterTransform(),
                      child: _EssentialFooter(
                        title: widget.title,
                        artist: widget.artist,
                        albumName: widget.albumName,
                        isPlaying: widget.isPlaying,
                        accentColor: widget.accentColor,
                        albumArtBytes: widget.albumArtBytes,
                        width: footerWidth,
                        height: footerHeight,
                        onTogglePlay: widget.onTogglePlay,
                        onSkipNext: widget.onSkipNext,
                        onSkipPrevious: widget.onSkipPrevious,
                      ),
                    ),
                    // 리사이즈 손잡이 (우하단 모서리)
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          setState(() {
                            _footerWidthDelta += d.delta.dx;
                            _footerHeightDelta += d.delta.dy;
                          });
                        },
                        onPanEnd: (_) => _saveFooterTransform(),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.accentColor.withValues(alpha: 0.85),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.open_in_full_rounded,
                            size: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── (v4) 포커스 모드 토글 — 항상 표시(포커스 중에도 꺼야 하니까)
              // 상단(설정 버튼과 겹침) 대신 우하단, 하단 플레이어 바로 위에 배치.
              // footerTop을 기준으로 붙여서 하단 플레이어를 드래그/리사이즈 해도
              // 항상 그 위쪽에 떠 있고, 상단 세이프존 아래로는 내려가지 않도록 clamp.
              Positioned(
                top: (footerTop - 44).clamp(
                  mq.padding.top + 12,
                  screenH - mq.padding.bottom - 44,
                ),
                right: mq.padding.right + 16,
                child: _AestheticPressScale(
                  onTap: () {
                    setState(() => _focusMode = !_focusMode);
                    _saveFocusMode(_focusMode);
                    // 포커스 모드 진입/해제 시 가사가 밀리는 문제 방지 → 재싱크
                    widget.onLyricsActivated?.call();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Icon(
                      _focusMode
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 17,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
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
    return _AestheticPressScale(
      onTap: onToggle,
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
// _AccentHalo — FFT 뒤편의 거의 안 보이는 숨쉬는 accent glow
// (스펙: 9초 주기, scale 98%↔102%, opacity 4~5% — 의식적으로 알아채긴 힘들지만
// 분위기는 채워주는 정도. 성능: 단일 AnimationController + Transform.scale만
// 사용해 리레이아웃 없이 리페인트만 발생)
// ──────────────────────────────────────────────────────────────────────────────
class _AccentHalo extends StatefulWidget {
  final Color accentColor;
  const _AccentHalo({required this.accentColor});

  @override
  State<_AccentHalo> createState() => _AccentHaloState();
}

class _AccentHaloState extends State<_AccentHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final double t = Curves.easeInOut.transform(_ctrl.value);
          final double scale = 0.98 + 0.04 * t; // 98% ↔ 102%
          return Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.accentColor.withValues(alpha: 0.045),
                    widget.accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _AestheticPressScale — AESTHETIC 모드 전용 버튼 마이크로 인터랙션
// (스펙: press 1.00→0.96 90ms / release 180ms, 바운스·스프링 없음)
// ──────────────────────────────────────────────────────────────────────────────
class _AestheticPressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _AestheticPressScale({required this.child, this.onTap});

  @override
  State<_AestheticPressScale> createState() => _AestheticPressScaleState();
}

class _AestheticPressScaleState extends State<_AestheticPressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90), // press
    reverseDuration: const Duration(milliseconds: 180), // release
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          // 바운스/스프링 없이 선형 보간만 사용
          final double scale = 1.0 - (_ctrl.value * 0.04);
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _EssentialLabel
// ──────────────────────────────────────────────────────────────────────────────
class _EssentialLabel extends StatefulWidget {
  final Color textColor;
  final Color accentColor;
  final String text;
  const _EssentialLabel({
    required this.textColor,
    required this.accentColor,
    this.text = 'AESTHETIC',
  });

  @override
  State<_EssentialLabel> createState() => _EssentialLabelState();
}

class _EssentialLabelState extends State<_EssentialLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    // 스펙: 계속 반짝이는 게 아니라 "화면 열릴 때 / 곡 바뀔 때"만 250ms fade.
    // 항상 도는 AnimationController 대신 1회성 forward만 사용 — 불필요한
    // 리빌드가 없어져 성능(배터리)에도 도움.
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _EssentialLabel old) {
    super.didUpdateWidget(old);
    // 곡이 바뀌면(accentColor 변경) 짧게 다시 fade-in
    if (old.accentColor != widget.accentColor) {
      _glow.forward(from: 0);
    }
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
        // 정지된 은은한 값 — 더 이상 무한 반복으로 숨쉬지 않고, 페이드인 후 고정
        final double g = 0.30 * Curves.easeOut.transform(_glow.value);
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
              widget.text,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 20.0,
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
  final Uint8List? albumArtBytes;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onSkipNext;
  final VoidCallback? onSkipPrevious;
  final double width;
  final double height;

  const _EssentialFooter({
    required this.title,
    required this.artist,
    this.albumName,
    required this.isPlaying,
    required this.accentColor,
    this.albumArtBytes,
    this.onTogglePlay,
    this.onSkipNext,
    this.onSkipPrevious,
    required this.width,
    required this.height,
  });

  @override
  State<_EssentialFooter> createState() => _EssentialFooterState();
}

class _EssentialFooterState extends State<_EssentialFooter> {
  @override
  Widget build(BuildContext context) {
    // 스펙: 크게 리사이즈하면(세로 110 초과) 빈 공간에 정사각형 앨범아트를 끌어와 채움
    final bool expanded = widget.height > 110;

    return ClipRRect(
      borderRadius: BorderRadius.circular(GRadius.mediumCard),
      child: BackdropFilter(
        // 스펙: 글래스 강도 축소 (blur 18 → 6)
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: widget.width,
          height: widget.height,
          // 스펙: 높이 약 10% 축소 (vertical padding 14 → 12)
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(GRadius.mediumCard),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: expanded ? _buildExpanded(context) : _buildCompact(context),
        ),
      ),
    );
  }

  // ── 컴팩트 레이아웃 (기본 크기) — prev/play/next + 곡 정보
  Widget _buildCompact(BuildContext context) {
    return Row(
      children: [
        _transportButtons(iconSize: 18, playSize: 34),
        const SizedBox(width: 12),
        // 구분선
        Container(
          width: 0.6,
          height: 29,
          color: Colors.white.withValues(alpha: 0.12),
          margin: const EdgeInsets.only(right: 14),
        ),
        Expanded(child: _infoColumn()),
      ],
    );
  }

  // ── 확장 레이아웃 (세로로 크게 리사이즈했을 때) — 정사각형 앨범아트 + 여유로운 구성
  Widget _buildExpanded(BuildContext context) {
    final double artSize = (widget.height - 24).clamp(48.0, 240.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(GRadius.mediumCard * 0.7),
          child: widget.albumArtBytes != null
              ? Image.memory(
                  widget.albumArtBytes!,
                  width: artSize,
                  height: artSize,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : Container(
                  width: artSize,
                  height: artSize,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: Icon(Icons.music_note_rounded,
                      color: Colors.white.withValues(alpha: 0.3), size: artSize * 0.4),
                ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoColumn(titleSize: 18, artistSize: 12),
              const SizedBox(height: 14),
              _transportButtons(iconSize: 20, playSize: 40),
            ],
          ),
        ),
      ],
    );
  }

  // ── 곡 정보 컬럼 (제목/아티스트/앨범) — 두 레이아웃에서 공용
  Widget _infoColumn({double titleSize = 16, double artistSize = 11}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
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
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: artistSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.albumName != null && widget.albumName!.isNotEmpty) ...[
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
                    color: widget.accentColor.withValues(alpha: 0.50),
                    fontSize: artistSize,
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
    );
  }

  // ── prev / play / next 버튼 — 스펙: accent color는 play/progress/선택상태/prev-next에만
  Widget _transportButtons({required double iconSize, required double playSize}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AestheticPressScale(
          onTap: widget.onSkipPrevious,
          child: Icon(
            Icons.skip_previous_rounded,
            color: widget.accentColor.withValues(alpha: 0.80),
            size: iconSize,
          ),
        ),
        SizedBox(width: iconSize * 0.5),
        _AestheticPressScale(
          onTap: widget.onTogglePlay,
          child: Container(
            width: playSize,
            height: playSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black.withValues(alpha: 0.85),
              size: playSize * 0.55,
            ),
          ),
        ),
        SizedBox(width: iconSize * 0.5),
        _AestheticPressScale(
          onTap: widget.onSkipNext,
          child: Icon(
            Icons.skip_next_rounded,
            color: widget.accentColor.withValues(alpha: 0.80),
            size: iconSize,
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
    return _AestheticPressScale(
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
          // Fluid AI glow: 활성 상태일 때만 은은하게 빛남
          boxShadow: isEssentialMode
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 14,
                    spreadRadius: 0.5,
                  ),
                ]
              : [],
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

      // 저음 대역 외부 글로우 (스펙: radius 5dp, opacity 10% 미만 — 네온 아님)
      if (i < 12 && v > 0.45) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            barRect.inflate(1.5),
            Radius.circular(rx + 1.5),
          ),
          Paint()
            ..color = accentColor.withValues(alpha: (0.09 * v).clamp(0.0, 0.09))
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
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