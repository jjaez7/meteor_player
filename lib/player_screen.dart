import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show compute;
import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models/player_config.dart';
import 'utils/layout_engine.dart';
import 'widgets/editable_element.dart';
import 'widgets/player_app_bar.dart';
import 'color_manager.dart';
import 'main.dart';
import 'widgets/player_elements.dart';
import 'widgets/player_text_info.dart';
import 'logic/music_controller.dart';
import 'logic/player_logic.dart';
import 'widgets/classic_vinyl_view.dart';
import 'widgets/stream_progress_bar.dart';
import 'widgets/vinyl_turntable_view.dart';
import 'features/screen_lock.dart';
import 'services/lyrics_service.dart';
import 'models/lyric_model.dart';
import 'services/ad_service.dart';
import 'menu/dialog_pass.dart';

Timer? _accessCheckTimer;
bool _isPassDialogShowing = false;

class VinylPlayerScreen extends StatefulWidget {
  const VinylPlayerScreen({super.key});
  @override
  State<VinylPlayerScreen> createState() => _VinylPlayerScreenState();
}

class _VinylPlayerScreenState extends State<VinylPlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── 모드 상태
  bool _isMinimalMode = false;
  bool _showLyrics = false;
  bool _isPipMode = false;
  bool _isScreenLocked = false;

  // ── 가로 모드 하단 패널 토글 (볼륨 ↔ 가사), 기본: 볼륨
  bool _landscapeShowLyrics = false;
  int _clockTapCount = 0;
  Timer? _clockTapTimer;

  // ── 세로 모드 상단 패널 토글 (턴테이블 ↔ 가사), 기본: 턴테이블
  bool _portraitShowLyrics = false;
  int _portraitClockTapCount = 0;
  Timer? _portraitClockTapTimer;

  // ── 볼륨 (ValueNotifier — setState 없이 볼륨 패널만 rebuild)
  final ValueNotifier<double> _volumeNotifier = ValueNotifier(0.8);

  // ── 재생 상태
  bool isEditMode = false;
  bool _isPlaying = false;
  Duration? _totalDuration;
  int _durationRetryCount = 0;
  static const int _maxDurationRetry = 3;

  // ── 컨트롤러
  late AnimationController _lpController;
  late AnimationController _needleController; // 가사/미니멀 모드용

  // ── 레이아웃 (가로 모드 / PiP 용)
  PlayerConfig? _portraitConfig, _landscapeConfig;

  // ── 곡 정보
  String _currentTitle = "Ready to Play";
  String _currentArtist = "Artist NAME";
  Uint8List? _albumArtBytes;
  DateTime? _lastSyncTime;

  // ── 사전 블러 처리된 배경 이미지 (BackdropFilter 대체 — 곡 전환 시 1회만 계산)
  Uint8List? _blurredBgBytes;

  // ── 가사
  List<dynamic> _lyrics = [];
  LyricStatus _currentStatus = LyricStatus.loading;
  String _lastFetchedSongId = "";
  int _lastRequestToken = 0;

  // ── 재생 위치 (ValueNotifier: setState 없이 가사 & 진행률 동기화)
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);

  // ── 턴테이블 progress 분배 (media_status 단일 구독 → 여기서 분배)
  final StreamController<double> _turntableProgressCtrl =
      StreamController<double>.broadcast();

  // ── 색상 (앨범 아트에서 추출, 저장값 로드)
  Color _bgColor = const Color(0xFFE1E0E5);
  Color _lpColor = const Color(0xFF2A292E);
  Color _textColor = const Color(0xFF333335);
  Color _artistColor = const Color(0xFF8F7AB3);
  Color _barColor = const Color(0xFFB1A1D0);
  Color _playBtnColor = const Color(0xFF735DA5);

  // ── 채널
  static const _pipChannel = MethodChannel('com.glasnyl.app/pip_status');
  static const _volumeChannel = EventChannel('com.glasnyl.app/volume_events');
  final GlobalKey _progressKey = GlobalKey();

  // ── 스트림 구독 (dispose에서 반드시 cancel)
  StreamSubscription? _mediaStatusSub;
  StreamSubscription? _notificationSub;
  StreamSubscription? _volumeSub;

  // ── 접근 가드 캐시 (isFullAccess 결과를 30초간 재사용 → CPU wake-up 감소)
  bool? _cachedAccessResult;
  DateTime? _lastAccessCheck;

  // ──────────────────────────────────────────────────────────────────────
  // initState
  // ──────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    _startAccessGuardian();
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // PiP 채널
    _pipChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "onPipModeChanged":
          if (mounted) {
            setState(() {
              _isPipMode = call.arguments as bool;
              if (_isPipMode) isEditMode = false;
            });
          }
          break;
        case "onPipAction":
          final action = call.arguments.toString().trim();
          if (action == "TOGGLE") _handleInternalToggle();
          else if (action == "NEXT") PlayerLogic.skipNext();
          else if (action == "PREV") PlayerLogic.skipPrevious();
          break;
      }
    });

    WakelockPlus.enable();

    // 애니메이션 컨트롤러
    _lpController = AnimationController(
      vsync: this, duration: const Duration(seconds: 20));
    _needleController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));

    // 재생 위치
    audioHandler.position.listen((pos) {
      if (mounted) _positionNotifier.value = pos;
    });

    // 곡 변경
    audioHandler.mediaItem.listen((item) {
      if (item != null && mounted && _currentTitle != item.title) {
        _positionNotifier.value = Duration.zero;
        setState(() {
          _currentTitle = item.title;
          _currentArtist = (item.artist ?? "Unknown").toUpperCase();
          _lyrics = [];
          _lastFetchedSongId = "";
          _currentStatus = LyricStatus.loading;
        });
        _updateLyrics(item);
      }
    });

    // 재생 상태
    audioHandler.playbackState.listen((state) {
      if (!mounted) return;
      if (state.playing) {
        if (_needleController.status != AnimationStatus.forward &&
            _needleController.value < 1.0) {
          _needleController.forward();
        }
        if (!_lpController.isAnimating) _lpController.repeat();
      } else {
        if (_needleController.status != AnimationStatus.reverse &&
            _needleController.value > 0.0) {
          _needleController.reverse();
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !audioHandler.playbackState.value.playing) {
            _lpController.stop();
          }
        });
      }
    });

    _loadSavedColors();
    _loadInitialVolume();

    // 기기 볼륨 버튼 실시간 감지 (하드웨어 버튼 → _volumeNotifier 즉시 반영)
    _volumeSub = _volumeChannel.receiveBroadcastStream().listen((dynamic value) {
      if (mounted && value != null) {
        _volumeNotifier.value =
            (value as num).toDouble().clamp(0.0, 1.0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToMusic();
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) _fetchInitialStatus();
      });
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // dispose
  // ──────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _accessCheckTimer?.cancel();
    _clockTapTimer?.cancel();
    _portraitClockTapTimer?.cancel();
    _mediaStatusSub?.cancel();
    _notificationSub?.cancel();
    _volumeSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _lpController.dispose();
    _needleController.dispose();
    _positionNotifier.dispose();
    _volumeNotifier.dispose();
    _turntableProgressCtrl.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _durationRetryCount = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _fetchInitialStatus();
        });
        // 가사 패널이 열려있으면 포지션도 즉시 동기화
        if (_landscapeShowLyrics || _portraitShowLyrics) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _syncLyricsPosition();
          });
        }
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // 접근 가드 (광고/패스)
  // ──────────────────────────────────────────────────────────────────────
  void _startAccessGuardian() {
    _accessCheckTimer?.cancel();
    _accessCheckTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
      if (_isPassDialogShowing || isEditMode || _isPipMode) return;

      final now = DateTime.now();
      bool isFullAccess;
      if (_cachedAccessResult != null &&
          _lastAccessCheck != null &&
          now.difference(_lastAccessCheck!) < const Duration(seconds: 30)) {
        isFullAccess = _cachedAccessResult!;
      } else {
        isFullAccess = await AdService.isFullAccess();
        _cachedAccessResult = isFullAccess;
        _lastAccessCheck = now;
      }

      if (!isFullAccess && mounted) {
        _isPassDialogShowing = true;
        showPassDialog(context, () {
          if (mounted) {
            _cachedAccessResult = null;
            setState(() => _isPassDialogShowing = false);
            _fetchInitialStatus();
          }
        });
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // 재생 토글
  // ──────────────────────────────────────────────────────────────────────
  void _handleInternalToggle() {
    PlayerLogic.togglePlay(
      isPlaying: _isPlaying,
      onToggle: () {
        if (mounted) {
          setState(() {
            _isPlaying = !_isPlaying;
            if (_isPlaying) {
              _lpController.repeat();
              _needleController.forward();
            } else {
              _lpController.stop();
              _needleController.reverse();
            }
          });
          HapticFeedback.lightImpact();
        }
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // 탐색
  // ──────────────────────────────────────────────────────────────────────
  void _handleSeek(Duration targetTime) {
    audioHandler.seek(targetTime);
    _positionNotifier.value = targetTime;
    if (_lyrics.isNotEmpty) {
      int idx = _lyrics.lastIndexWhere((l) => l.time <= targetTime);
      if (idx != -1)
        debugPrint("🎯 탐색 동기화: $idx (${targetTime.inMilliseconds}ms)");
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // 가사
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _updateLyrics(dynamic item) async {
    _positionNotifier.value = Duration.zero;
    final int token = ++_lastRequestToken;

    String title = item is Map
        ? (item['title'] ?? "Unknown")
        : (item.title ?? "Unknown");
    String artist = item is Map
        ? (item['artist'] ?? "Unknown")
        : (item.artist ?? "Unknown");
    final String id = "${title}_$artist";

    if (_lastFetchedSongId == id && _lyrics.isNotEmpty) return;
    _lastFetchedSongId = id;

    if (mounted) {
      setState(() {
        _lyrics = [];
        _currentStatus = LyricStatus.loading;
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (token != _lastRequestToken) return;

    try {
      final result = await LyricsService.getLyrics(title, artist);
      if (mounted && token == _lastRequestToken) {
        setState(() {
          _lyrics = result.lyrics;
          _currentStatus = result.status;
        });
      }
    } catch (e) {
      if (mounted && token == _lastRequestToken && _lyrics.isEmpty) {
        setState(() {
          _currentStatus = (e is TimeoutException)
              ? LyricStatus.timeout
              : LyricStatus.networkError;
        });
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // 수동 새로고침 (LP 롱프레스)
  // ──────────────────────────────────────────────────────────────────────
  void _handleManualRefresh() async {
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!) < const Duration(seconds: 10)) {
      await HapticFeedback.selectionClick();
      return;
    }
    _lastSyncTime = now;
    await HapticFeedback.heavyImpact();
    permissionGuardKey.currentState?.showTopStatusAlarm(isSyncing: true);
    try {
      await audioHandler.refreshMetadata();
      await _fetchInitialStatus();
    } catch (e) {
      debugPrint("Sync Error: $e");
      _lastSyncTime = null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // 볼륨 로드
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _loadInitialVolume() async {
    final v = await PlayerLogic.getVolume();
    if (mounted) _volumeNotifier.value = v;
  }

  // ──────────────────────────────────────────────────────────────────────
  // 색상 로드 / 변경
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _loadSavedColors() async {
    final saved = await ColorManager.loadSettings();
    setState(() {
      _bgColor = saved['bg']!;
      _lpColor = saved['lp']!;
      _textColor = saved['text']!;
      _artistColor = saved['artist']!;
      _barColor = saved['bar']!;
      _playBtnColor = saved['btn']!;
    });
  }

  void _handleColorChange(Color newColor, String target) {
    setState(() {
      switch (target) {
        case 'bg': _bgColor = newColor; break;
        case 'lp': _lpColor = newColor; break;
        case 'text': _textColor = newColor; break;
        case 'artist': _artistColor = newColor; break;
        case 'bar': _barColor = newColor; break;
        case 'btn': _playBtnColor = newColor; break;
      }
    });
    PlayerLogic.updateColor(target, newColor);
  }

  Future<void> _handleAbsoluteColorReset() async {
    final c = await PlayerLogic.handleAbsoluteColorReset();
    setState(() {
      _bgColor = c['bg']!;
      _lpColor = c['lp']!;
      _textColor = c['text']!;
      _artistColor = c['artist']!;
      _barColor = c['bar']!;
      _playBtnColor = c['btn']!;
    });
  }

  void _handleResetLayout() async {
    await PlayerLogic.resetLayout();
    if (!mounted) return;
    setState(() {
      final size = MediaQuery.of(context).size;
      _portraitConfig = LayoutEngine.calculate(size, Orientation.portrait, false);
      _landscapeConfig = LayoutEngine.calculate(size, Orientation.landscape, false);
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // 음악 리스너
  // ──────────────────────────────────────────────────────────────────────
  void _listenToMusic() async {
    bool isGranted = await NotificationListenerService.isPermissionGranted();
    if (!isGranted) return;

    if (_notificationSub != null) return;

    _notificationSub = NotificationListenerService.notificationsStream.listen((event) async {
      if (event.hasRemoved == true || event.title == null) return;
      if (!MusicColorLogic.isMusicApp(event.packageName ?? "")) return;
      if (_currentTitle == event.title || !mounted) return;

      _positionNotifier.value = Duration.zero;
      setState(() {
        _currentTitle = event.title!;
        _currentArtist = (event.content ?? "Unknown").toUpperCase();
        _lyrics = [];
        _lastFetchedSongId = "";
        _isPlaying = true;
        _currentStatus = LyricStatus.loading;
      });

      // Android MediaMetadata가 곡 전환 직후 바로 준비되지 않을 수 있어 딜레이 추가
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      await _fetchInitialStatus();
      _updateLyrics({'title': event.title, 'artist': event.content});
      if (mounted) setState(() => _isPlaying = true);

      // 앨범아트를 못 받았으면 800ms 간격으로 최대 3번 재시도
      if (_albumArtBytes == null || _albumArtBytes!.isEmpty) {
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          try {
            const platform = MethodChannel('com.glasnyl.app/media_control');
            final dynamic artResult = await platform.invokeMethod('getAlbumArt');
            final Uint8List? artData = artResult != null
                ? Uint8List.fromList(List<int>.from(artResult))
                : null;
            if (artData != null && artData.isNotEmpty) {
              setState(() => _albumArtBytes = artData);
              _preBlurAlbumArt(artData);
              MusicColorLogic.extractThemeColors(artData).then((colors) {
                if (mounted && colors != null) {
                  setState(() {
                    _bgColor = colors['bg']!;
                    _playBtnColor = colors['btn']!;
                    _barColor = colors['bar']!;
                    _textColor = colors['text']!;
                    _artistColor = colors['artist']!;
                  });
                }
              });
              break; // 성공하면 재시도 중단
            }
          } catch (e) {
            debugPrint('앨범아트 재시도 ${i + 1}회 실패: $e');
          }
        }
      }

      _lpController.repeat();
      _needleController.forward();
    });

    _mediaStatusSub?.cancel();
    _mediaStatusSub = const EventChannel('com.glasnyl.app/media_status')
        .receiveBroadcastStream()
        .listen((status) {
      if (status is Map && status['position'] != null) {
        final int pos = status['position'];
        final int dur = (status['duration'] as num?)?.toInt() ?? 0;
        final diff = (pos - _positionNotifier.value.inMilliseconds).abs();
        if (diff > 200) {
          _positionNotifier.value = Duration(milliseconds: pos);
        }
        if (dur > 0 && !_turntableProgressCtrl.isClosed) {
          _turntableProgressCtrl.add((pos / dur).clamp(0.0, 1.0));
        }
      }
    }, onError: (e) {
      debugPrint('media_status stream error (ignored): $e');
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // 초기 상태 가져오기
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _fetchInitialStatus() async {
    try {
      const platform = MethodChannel('com.glasnyl.app/media_control');
      final dynamic result = await platform.invokeMethod('getCurrentStatus');

      if (result != null && mounted) {
        final data = Map<String, dynamic>.from(result);
        final dynamic artResult = await platform.invokeMethod('getAlbumArt');
        final Uint8List? artData = artResult != null ? Uint8List.fromList(List<int>.from(artResult)) : null;

        setState(() {
          _currentTitle = data['title'] ?? "Ready to Play";
          _currentArtist = (data['artist'] ?? "GLASNYL").toUpperCase();
          _isPlaying = data['isPlaying'] ?? false;

          if (data['duration'] != null) {
            final int durMs = (data['duration'] as num).toInt();
            if (durMs > 0) {
              _totalDuration = Duration(milliseconds: durMs);
              _durationRetryCount = 0;
            } else if (_durationRetryCount < _maxDurationRetry) {
              _durationRetryCount++;
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) _fetchInitialStatus();
              });
            } else {
              _durationRetryCount = 0;
            }
          }
        });

        if (_isPlaying) {
          if (!_lpController.isAnimating) _lpController.repeat();
          _needleController.animateTo(1.0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut);
        } else {
          _lpController.stop();
          _needleController.animateTo(0.0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut);
        }

        if (artData != null && artData.isNotEmpty) {
          setState(() => _albumArtBytes = artData);
          _preBlurAlbumArt(artData);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && artData.length > 500) {
              MusicColorLogic.extractThemeColors(artData).then((colors) {
                if (mounted) {
                  setState(() {
                    _bgColor = colors['bg']!;
                    _playBtnColor = colors['btn']!;
                    _barColor = colors['bar']!;
                    _textColor = colors['text']!;
                    _artistColor = colors['artist']!;
                  });
                }
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint("초기 정보를 가져올 수 없습니다: $e");
    }
    _updateLyrics({'title': _currentTitle, 'artist': _currentArtist});
  }

  // ──────────────────────────────────────────────────────────────────────
  // 배경 블러 사전 계산
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _preBlurAlbumArt(Uint8List bytes) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    try {
      final rawCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 300,
      );
      final frame = await rawCodec.getNextFrame();
      final srcImage = frame.image;
      final int w = srcImage.width;
      final int h = srcImage.height;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8);
      canvas.drawImage(srcImage, ui.Offset.zero, paint);
      srcImage.dispose();

      final blurred = await recorder
          .endRecording()
          .toImage(w, h);
      final byteData = await blurred.toByteData(
          format: ui.ImageByteFormat.png);
      blurred.dispose();

      if (mounted && byteData != null) {
        setState(() {
          _blurredBgBytes = byteData.buffer.asUint8List();
        });
      }
    } catch (e) {
      debugPrint('블러 사전처리 실패: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final size = MediaQuery.of(context).size;
        final bool isFlipCover = size.width > size.height && size.width < 600;
        final bool isSpecialMode = _isPipMode || isFlipCover;
        final bool isPortrait = orientation == Orientation.portrait;
        final config = LayoutEngine.calculate(size, orientation, isSpecialMode);

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            color: _bgColor,
            child: Stack(
              children: [
                if (_blurredBgBytes != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          layoutBuilder: (child, prev) =>
                              Stack(children: [...prev, if (child != null) child]),
                          child: SizedBox.expand(
                            key: ValueKey(
                                '${_currentTitle}_${_blurredBgBytes.hashCode}'),
                            child: Image.memory(
                              _blurredBgBytes!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.low,
                              opacity: const AlwaysStoppedAnimation(0.9),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: Stack(
                        children: [
                          if (_blurredBgBytes == null)
                            Container(color: _bgColor.withValues(alpha: 0.80)),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            color: _bgColor.withValues(alpha: 0.30),
                          ),
                          Container(color: Colors.black.withValues(alpha: 0.25)),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.05),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                                stops: const [0.0, 0.40, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (isPortrait && !isSpecialMode)
                  _buildPortraitFullLayout(size, config)
                else if (!isPortrait && !isSpecialMode)
                  _buildLandscapeFullLayout(size, config)
                else if (_isPipMode)
                  _buildPipLayout(size)
                else if (isFlipCover)
                  _buildFlipCoverLayout(size)
                else
                  _buildLegacyLayout(size, config, isPortrait, isSpecialMode),

                if (!_isPipMode)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: RepaintBoundary(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: (MediaQuery.of(context).padding.top - 8.0).clamp(0.0, double.infinity),
                          left: MediaQuery.of(context).padding.left,
                          right: MediaQuery.of(context).padding.right,
                        ),
                        child: PlayerAppBar(
                          onPassUpdated: () => setState(() {}),
                          isPip: _isPipMode,
                          orientation: orientation,
                          textColor: _textColor,
                          bgColor: _bgColor,
                          isEditMode: isEditMode,
                          onResetLayout: _handleResetLayout,
                          lpColor: _lpColor,
                          artistColor: _artistColor,
                          barColor: _barColor,
                          playBtnColor: _playBtnColor,
                          onColorChanged: _handleColorChange,
                          onResetColors: _handleAbsoluteColorReset,
                          onEditModeChanged: (v) =>
                              setState(() => isEditMode = v),
                          onLockToggle: () =>
                              setState(() => _isScreenLocked = true),
                        ),
                      ),
                    ),
                  ),

                if (_isScreenLocked)
                  Positioned.fill(
                    child: ScreenLockOverlay(
                      onUnlock: () => setState(() => _isScreenLocked = false),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 가로 모드 전체화면 통합 레이아웃
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildLandscapeFullLayout(Size size, PlayerConfig config) {
    final EdgeInsets sysPad = MediaQuery.of(context).padding;
    final double topPad  = sysPad.top    + 48.0;
    final double botPad  = sysPad.bottom +  8.0;
    // 카메라(left) · 네비게이션 바(right) 인셋을 콘텐츠 여백에 추가
    // → 배경 블러는 Positioned.fill이라 영향 없음, 콘텐츠만 안전 영역 안으로
    final double hPadLeft  = size.width * 0.018 + sysPad.left;
    final double hPadRight = size.width * 0.018 + sysPad.right;
    final double hPad      = size.width * 0.018; // Row 내부 gap 등 중립 간격용
    final double available = (size.height - topPad - botPad).clamp(0.0, double.infinity);

    // LP + 패널 너비는 좌우 인셋을 제외한 실제 사용 가능 너비 기준으로 계산
    final double usableW = (size.width - hPadLeft - hPadRight).clamp(0.0, double.infinity);
    final double panelW  = usableW * 0.35;
    final double lpW     = (usableW - panelW - hPad).clamp(0.0, double.infinity);

    final double turntableSizeByW = lpW;
    final double turntableSizeByH = available > 0 ? available / 0.72 : lpW;
    final double turntableSize = (turntableSizeByW < turntableSizeByH
        ? turntableSizeByW
        : turntableSizeByH).clamp(0.0, double.infinity);

    final double lpH = turntableSize * 0.72;
    final double volumePanelH = (available - lpH).clamp(0.0, double.infinity);

    final double titleFs   = (panelW * 0.13).clamp(7.0, 36.0);
    final double artistFs  = (panelW * 0.075).clamp(5.0, 22.0);
    final double itemGap   = (available * 0.025).clamp(0.0, 18.0);
    final double bigGap    = (available * 0.045).clamp(0.0, 28.0);
    final double vPad      = (available * 0.04).clamp(0.0, 20.0);
    final double hInnerPad = (panelW * 0.07).clamp(10.0, 28.0);
    final double innerW    = (panelW - hInnerPad * 2).clamp(1.0, double.infinity);

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.only(top: topPad, bottom: botPad, left: hPadLeft, right: hPadRight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: _handleManualRefresh,
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _positionNotifier,
                      builder: (context, realTimePos, _) {
                        if (_isMinimalMode || _showLyrics) {
                          return RepaintBoundary(
                            child: ClassicVinylView(
                              lyricStatus: _currentStatus,
                              lyrics: _lyrics,
                              currentPosition: realTimePos,
                              isMinimalMode: _isMinimalMode,
                              isLyricsMode: _showLyrics,
                              size: turntableSize,
                              albumArtBytes: _albumArtBytes,
                              title: _currentTitle,
                              artist: _currentArtist,
                              lpController: _lpController,
                              isPlaying: _isPlaying,
                              onToggleMode: () =>
                                  setState(() => _isMinimalMode = !_isMinimalMode),
                              onShowLyrics: () {
                                setState(() => _showLyrics = true);
                                Future(() async {
                                  if (_lyrics.isEmpty &&
                                      _currentStatus != LyricStatus.loading) {
                                    await _updateLyrics({
                                      'title': _currentTitle,
                                      'artist': _currentArtist,
                                    });
                                  }
                                  try {
                                    const p = MethodChannel('com.glasnyl.app/media_control');
                                    final r = await p.invokeMethod('getCurrentStatus');
                                    if (r?['position'] != null) {
                                      _positionNotifier.value = Duration(
                                          milliseconds: (r['position'] as num).toInt());
                                    }
                                  } catch (_) {}
                                });
                              },
                              onCloseLyrics: () =>
                                  setState(() => _showLyrics = false),
                            ),
                          );
                        }

                        final double progress = (_totalDuration != null &&
                                _totalDuration!.inMilliseconds > 0)
                            ? (realTimePos.inMilliseconds /
                                    _totalDuration!.inMilliseconds)
                                .clamp(0.0, 1.0)
                            : 0.0;

                        return RepaintBoundary(
                          child: VinylTurntableView(
                            lpController: _lpController,
                            size: turntableSize,
                            albumArtBytes: _albumArtBytes,
                            title: _currentTitle,
                            artist: _currentArtist,
                            isPlaying: _isPlaying,
                            progress: progress,
                            progressStream: _turntableProgressCtrl.stream,
                            accentColor: _playBtnColor,
                            bgColor: _bgColor,
                            onPlayPause: _handleInternalToggle,
                            onNext: () {
                              HapticFeedback.lightImpact();
                              PlayerLogic.skipNext();
                            },
                            onPrevious: () {
                              HapticFeedback.lightImpact();
                              PlayerLogic.skipPrevious();
                            },
                            onSeek: (ratio) {
                              final dur = _totalDuration ??
                                  audioHandler.mediaItem.value?.duration;
                              if (dur != null && dur.inMilliseconds > 0) {
                                final target = Duration(
                                    milliseconds:
                                        (dur.inMilliseconds * ratio).round());
                                _handleSeek(target);
                                PlayerLogic.seekTo(ratio);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  if (volumePanelH > 24) ...[
                    SizedBox(height: hPad),
                    Expanded(
                      child: _landscapeShowLyrics
                          ? _buildLandscapeLyricsPanel(lpW, (volumePanelH - hPad).clamp(1.0, double.infinity))
                          : _buildVolumePanel(lpW, (volumePanelH - hPad).clamp(1.0, double.infinity)),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(width: hPad),

            Expanded(
              flex: 35,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double clockH = (panelW * 0.14).clamp(16.0, 28.0) + 20.0;
                  final bool showLandscapeClock = constraints.maxHeight > clockH + 290;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildGlassInfoPanel(
                          Size(panelW, available),
                          available,
                          verticalPad: vPad,
                          isLandscape: true,
                          titleFontSize: titleFs,
                          artistFontSize: artistFs,
                          itemGap: itemGap,
                          bigGap: bigGap,
                          hInnerPad: hInnerPad,
                          innerW: innerW,
                        ),
                      ),
                      if (showLandscapeClock) ...[
                        SizedBox(height: hPad),
                        _buildClockPanel(panelW),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleClockTap() {
    _clockTapTimer?.cancel();
    _clockTapCount++;
    if (_clockTapCount >= 5) {
      _clockTapCount = 0;
      HapticFeedback.mediumImpact();
      final bool turningOn = !_landscapeShowLyrics;
      setState(() => _landscapeShowLyrics = turningOn);
      if (turningOn) _syncLyricsPosition();
    } else {
      _clockTapTimer = Timer(const Duration(milliseconds: 1000), () {
        _clockTapCount = 0;
      });
    }
  }

  Future<void> _syncLyricsPosition() async {
    try {
      const p = MethodChannel('com.glasnyl.app/media_control');
      final r = await p.invokeMethod('getCurrentStatus');
      if (r?['position'] != null && mounted) {
        _positionNotifier.value =
            Duration(milliseconds: (r['position'] as num).toInt());
      }
    } catch (_) {}
  }

  Widget _buildClockPanel(double w) {
    final double hPadInner = (w * 0.07).clamp(10.0, 22.0);
    final double timeFontSize = (w * 0.14).clamp(16.0, 28.0);
    final double iconSize = timeFontSize * 0.8;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _handleClockTap,
        child: StreamBuilder<DateTime>(
          stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
          initialData: DateTime.now(),
          builder: (context, snapshot) {
            final now = snapshot.data ?? DateTime.now();
            final String timeText =
                '${now.hour.toString().padLeft(2, '0')}:'
                '${now.minute.toString().padLeft(2, '0')}';

            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(
                      color: _landscapeShowLyrics
                          ? _barColor.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.18),
                      width: _landscapeShowLyrics ? 1.4 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: hPadInner,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        _landscapeShowLyrics
                            ? Icons.lyrics_rounded
                            : Icons.access_time_rounded,
                        color: _barColor,
                        size: iconSize,
                      ),
                      Text(
                        timeText,
                        style: TextStyle(
                          color: _textColor.withValues(alpha: 0.90),
                          fontSize: timeFontSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeLyricsPanel(double w, double h) {
    final double radius = 20.0;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: w,
            height: h.clamp(1.0, double.infinity),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ValueListenableBuilder<Duration>(
              valueListenable: _positionNotifier,
              builder: (context, currentPos, _) {
                return _LandscapeLyricsScroller(
                  key: ValueKey(_currentTitle),
                  lyrics: _lyrics,
                  currentPosition: currentPos,
                  lyricStatus: _currentStatus,
                  isPlaying: _isPlaying,
                  size: h.clamp(1.0, double.infinity),
                  barColor: _barColor,
                  textColor: _textColor,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumePanel(double w, double h) {
    final double safeH   = h.clamp(1.0, double.infinity);
    final double thumbR  = (safeH * 0.18).clamp(5.0, 12.0);
    final double trackH  = thumbR;
    final double sliderH = thumbR * 2 + 8;

    final double iconSize = (safeH * 0.22).clamp(12.0, 20.0);
    final double labelFs  = (safeH * 0.14).clamp(9.0, 13.0);
    final double labelRowH = iconSize;
    final double gapAfterLabel = 6.0;

    final double contentWithLabel = labelRowH + gapAfterLabel + sliderH;
    final double vPad = ((safeH - sliderH) / 2).clamp(0.0, 12.0);
    final bool showLabel = vPad * 2 + contentWithLabel <= safeH;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: w,
            height: safeH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ValueListenableBuilder<double>(
              valueListenable: _volumeNotifier,
              builder: (context, volume, _) => ClipRect(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (w * 0.07).clamp(8.0, 22.0),
                    vertical: vPad,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showLabel) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              volume < 0.05
                                  ? Icons.volume_off_rounded
                                  : volume < 0.5
                                      ? Icons.volume_down_rounded
                                      : Icons.volume_up_rounded,
                              color: _barColor,
                              size: iconSize,
                            ),
                            Text(
                              '${(volume * 100).round()}%',
                              style: TextStyle(
                                color: _textColor.withValues(alpha: 0.65),
                                fontSize: labelFs,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      _GlassVolumeSlider(
                        value: volume,
                        trackHeight: trackH,
                        thumbRadius: thumbR,
                        activeColor: _barColor,
                        thumbColor: _playBtnColor,
                        bgColor: _bgColor,
                        onChanged: (v) async {
                          _volumeNotifier.value = v;
                          await PlayerLogic.setVolume(v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 세로 모드 전체화면 통합 레이아웃
  // ══════════════════════════════════════════════════════════════════════
  void _handlePortraitClockTap() {
    _portraitClockTapTimer?.cancel();
    _portraitClockTapCount++;
    if (_portraitClockTapCount >= 5) {
      _portraitClockTapCount = 0;
      HapticFeedback.mediumImpact();
      final bool turningOn = !_portraitShowLyrics;
      setState(() => _portraitShowLyrics = turningOn);
      if (turningOn) _syncLyricsPosition();
    } else {
      _portraitClockTapTimer = Timer(const Duration(milliseconds: 1000), () {
        _portraitClockTapCount = 0;
      });
    }
  }

  Widget _buildPortraitLyricsPanel(double w, double h) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: w,
            height: h.clamp(1.0, double.infinity),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ValueListenableBuilder<Duration>(
              valueListenable: _positionNotifier,
              builder: (context, currentPos, _) => _LandscapeLyricsScroller(
                key: ValueKey('portrait_lyrics_$_currentTitle'),
                lyrics: _lyrics,
                currentPosition: currentPos,
                lyricStatus: _currentStatus,
                isPlaying: _isPlaying,
                size: h.clamp(1.0, double.infinity),
                barColor: _barColor,
                textColor: _textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitClockPanel(double w) {
    final double hPadInner = (w * 0.05).clamp(10.0, 22.0);
    final double timeFontSize = (w * 0.065).clamp(16.0, 26.0);
    final double iconSize = timeFontSize * 0.8;

    return RepaintBoundary(
      child: GestureDetector(
      onTap: _handlePortraitClockTap,
      child: StreamBuilder<DateTime>(
        stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
        initialData: DateTime.now(),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final String timeText =
              '${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')}';
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: _portraitShowLyrics
                        ? _barColor.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.18),
                    width: _portraitShowLyrics ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                    horizontal: hPadInner, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      _portraitShowLyrics
                          ? Icons.lyrics_rounded
                          : Icons.access_time_rounded,
                      color: _barColor,
                      size: iconSize,
                    ),
                    Text(
                      timeText,
                      style: TextStyle(
                        color: _textColor.withValues(alpha: 0.90),
                        fontSize: timeFontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildPortraitFullLayout(Size size, PlayerConfig config) {
    final EdgeInsets sysPad = MediaQuery.of(context).padding;
    final double topPad  = sysPad.top    + 52.0;
    final double botPad  = sysPad.bottom + 12.0;
    final double available = (size.height - topPad - botPad).clamp(0.0, double.infinity);
    // 세로 모드는 보통 left/right 인셋이 0이지만, 폴더블 등 예외 기기를 위해 반영
    final double hPad = size.width * 0.04 + (sysPad.left + sysPad.right) / 2;

    final double gap         = hPad * 0.5;

    final bool showPortraitClock = available >= 450.0;
    final double clockPanelH = showPortraitClock
        ? (available * 0.07).clamp(0.0, 64.0)
        : 0.0;
    final double clockGap = showPortraitClock ? gap : 0.0;
    final double remaining   = (available - clockPanelH - gap - clockGap).clamp(0.0, double.infinity);
    final double turntableH  = remaining * 0.585;
    final double panelH      = remaining * 0.415;
    final double panelContentH = (panelH - 8.0).clamp(1.0, double.infinity);
    final double turntableSize = turntableH > 0
        ? (size.width * 0.97).clamp(0.0, turntableH / 0.72)
        : 0.0;

    return Positioned.fill(
      child: Column(
        children: [
          SizedBox(height: topPad),

          SizedBox(
            height: turntableH,
            child: _portraitShowLyrics
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: _buildPortraitLyricsPanel(
                        size.width - hPad * 2, turntableH),
                  )
                : Center(
                    child: GestureDetector(
                      onLongPress: _handleManualRefresh,
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: _positionNotifier,
                        builder: (context, realTimePos, _) {
                          if (_isMinimalMode || _showLyrics) {
                            final double lpSz = turntableH * 0.92;
                            return RepaintBoundary(
                              child: ClassicVinylView(
                                lyricStatus: _currentStatus,
                                lyrics: _lyrics,
                                currentPosition: realTimePos,
                                isMinimalMode: _isMinimalMode,
                                isLyricsMode: _showLyrics,
                                size: lpSz,
                                albumArtBytes: _albumArtBytes,
                                title: _currentTitle,
                                artist: _currentArtist,
                                lpController: _lpController,
                                isPlaying: _isPlaying,
                                onToggleMode: () => setState(
                                    () => _isMinimalMode = !_isMinimalMode),
                                onShowLyrics: () {
                                  setState(() => _showLyrics = true);
                                  Future(() async {
                                    if (_lyrics.isEmpty &&
                                        _currentStatus != LyricStatus.loading) {
                                      await _updateLyrics({
                                        'title': _currentTitle,
                                        'artist': _currentArtist,
                                      });
                                    }
                                    try {
                                      const p = MethodChannel(
                                          'com.glasnyl.app/media_control');
                                      final r =
                                          await p.invokeMethod('getCurrentStatus');
                                      if (r?['position'] != null) {
                                        _positionNotifier.value = Duration(
                                            milliseconds:
                                                (r['position'] as num).toInt());
                                      }
                                    } catch (_) {}
                                  });
                                },
                                onCloseLyrics: () =>
                                    setState(() => _showLyrics = false),
                              ),
                            );
                          }

                          final double progress = (_totalDuration != null &&
                                  _totalDuration!.inMilliseconds > 0)
                              ? (realTimePos.inMilliseconds /
                                      _totalDuration!.inMilliseconds)
                                  .clamp(0.0, 1.0)
                              : 0.0;

                          return RepaintBoundary(
                            child: VinylTurntableView(
                              lpController: _lpController,
                              size: turntableSize,
                              albumArtBytes: _albumArtBytes,
                              title: _currentTitle,
                              artist: _currentArtist,
                              isPlaying: _isPlaying,
                              progress: progress,
                              progressStream: _turntableProgressCtrl.stream,
                              accentColor: _playBtnColor,
                              bgColor: _bgColor,
                              onPlayPause: _handleInternalToggle,
                              onNext: () {
                                HapticFeedback.lightImpact();
                                PlayerLogic.skipNext();
                              },
                              onPrevious: () {
                                HapticFeedback.lightImpact();
                                PlayerLogic.skipPrevious();
                              },
                              onSeek: (ratio) {
                                final dur = _totalDuration ??
                                    audioHandler.mediaItem.value?.duration;
                                if (dur != null && dur.inMilliseconds > 0) {
                                  final target = Duration(
                                      milliseconds:
                                          (dur.inMilliseconds * ratio).round());
                                  _handleSeek(target);
                                  PlayerLogic.seekTo(ratio);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),

          SizedBox(height: gap),

          SizedBox(
            height: panelH,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
              child: _buildGlassInfoPanel(size, panelContentH),
            ),
          ),

          if (showPortraitClock) ...[
            SizedBox(height: clockGap),
            SizedBox(
              height: clockPanelH,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: _buildPortraitClockPanel(size.width - hPad * 2),
              ),
            ),
          ],

          SizedBox(height: botPad),
        ],
      ),
    );
  }

  Widget _buildGlassInfoPanel(
    Size size,
    double panelH, {
    double? verticalPad,
    bool isLandscape = false,
    double? titleFontSize,
    double? artistFontSize,
    double? itemGap,
    double? bigGap,
    double? hInnerPad,
    double? innerW,
  }) {
    final double safeH = panelH.clamp(1.0, double.infinity);

    final double sidePad = hInnerPad ?? size.width * 0.06;
    final double iW = (innerW ?? (size.width - sidePad * 2 - size.width * 0.08)).clamp(1.0, double.infinity);
    final double vPad = (verticalPad ?? (safeH * 0.05)).clamp(0.0, 16.0);

    final double titleFs  = titleFontSize  ?? (safeH * 0.10).clamp(7.0, 28.0);
    final double artistFs = artistFontSize ?? (safeH * 0.065).clamp(5.0, 16.0);

    final double gap1 = (itemGap ?? (safeH * 0.03)).clamp(2.0, 8.0);
    final double gap2 = (bigGap  ?? (safeH * 0.05)).clamp(4.0, 14.0);
    final double gap3 = (safeH * 0.04).clamp(3.0, 12.0);

    final double sideBtnSz = (safeH * 0.13).clamp(36.0, 54.0);
    final double mainBtnSz = (safeH * 0.20).clamp(50.0, 78.0);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
          height: safeH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.09),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sidePad,
              vertical: vPad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: iW,
                  child: MarqueeTitleWidget(
                    key: Key(_currentTitle),
                    title: _currentTitle,
                    fontSize: titleFs,
                    textColor: _textColor,
                    width: iW,
                  ),
                ),

                SizedBox(height: gap1),

                ArtistTextWidget(
                  artist: _currentArtist,
                  fontSize: artistFs,
                  color: _artistColor.withValues(alpha: 0.85),
                ),

                SizedBox(height: gap2),

                SizedBox(
                  key: _progressKey,
                  width: iW,
                  child: StreamProgressBar(
                    barWidth: iW.clamp(1.0, double.infinity),
                    bgColor: _bgColor,
                    barColor: _barColor,
                    onSeek: (ratio) {
                      PlayerLogic.seekTo(ratio);
                      final dur = _totalDuration ??
                          audioHandler.mediaItem.value?.duration;
                      if (dur != null && dur.inMilliseconds > 0) {
                        _positionNotifier.value = Duration(
                            milliseconds:
                                (dur.inMilliseconds * ratio).toInt());
                      }
                    },
                  ),
                ),

                SizedBox(height: gap3),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildScaledSideBtn(
                      icon: Icons.skip_previous_rounded,
                      size: sideBtnSz,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        PlayerLogic.skipPrevious();
                      },
                    ),
                    _buildScaledMainBtn(
                      isPlaying: _isPlaying,
                      size: mainBtnSz,
                      activeColor: _barColor,
                      onTap: () {
                        PlayerLogic.togglePlay(
                          isPlaying: _isPlaying,
                          onToggle: () {
                            if (mounted) {
                              setState(() {
                                _isPlaying = !_isPlaying;
                                if (_isPlaying) {
                                  _lpController.repeat();
                                  _needleController.forward();
                                } else {
                                  _lpController.stop();
                                  _needleController.reverse();
                                }
                              });
                            }
                          },
                        );
                      },
                    ),
                    _buildScaledSideBtn(
                      icon: Icons.skip_next_rounded,
                      size: sideBtnSz,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        PlayerLogic.skipNext();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildScaledSideBtn({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Icon(icon, size: size * 0.52, color: Colors.white.withValues(alpha: 0.9)),
      ),
    );
  }

  Widget _buildScaledMainBtn({
    required bool isPlaying,
    required double size,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlaying
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.30),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            if (isPlaying)
              BoxShadow(
                color: activeColor.withValues(alpha: 0.30),
                blurRadius: 25,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: size * 0.52,
            color: isPlaying ? activeColor : Colors.white,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // PiP 전용 레이아웃
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildPipLayout(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double lpAreaH  = h * 0.62;
    final double infoH    = h * 0.38;

    final double lpSize   = (lpAreaH * 0.85).clamp(0.0, double.infinity);
    final double titleFs  = (infoH * 0.38).clamp(9.0, 14.0);
    final double artistFs = (infoH * 0.26).clamp(7.0, 11.0);

    return Positioned.fill(
      child: Column(
        children: [
          SizedBox(
            height: lpAreaH,
            child: Center(
              child: StreamBuilder<double>(
                stream: _turntableProgressCtrl.stream,
                builder: (context, snapshot) {
                  double progress = 0.0;
                  if (snapshot.hasData) {
                    progress = snapshot.data!;
                  } else {
                    final pos = _positionNotifier.value;
                    if (_totalDuration != null && _totalDuration!.inMilliseconds > 0) {
                      progress = (pos.inMilliseconds / _totalDuration!.inMilliseconds).clamp(0.0, 1.0);
                    }
                  }
                  return AnimatedBuilder(
                    animation: _lpController,
                    builder: (context, _) {
                      return SizedBox(
                        width: lpSize,
                        height: lpSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: lpSize,
                              height: lpSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _lpColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            RotationTransition(
                              turns: _lpController,
                              child: Container(
                                width: lpSize * 0.55,
                                height: lpSize * 0.55,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _bgColor,
                                  image: _albumArtBytes != null
                                      ? DecorationImage(
                                          image: MemoryImage(_albumArtBytes!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            Container(
                              width: lpSize * 0.07,
                              height: lpSize * 0.07,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFD4AF37),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: lpSize * 0.92,
                              height: lpSize * 0.92,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: lpSize * 0.022,
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _barColor.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          SizedBox(
            height: infoH,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _currentTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFs,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: infoH * 0.08),
                  Text(
                    _currentArtist,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: artistFs,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 갤럭시 플립 커버스크린 전용 레이아웃  ← FIXED
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildFlipCoverLayout(Size size) {
    final double w = size.width;
    final double h = size.height;

    final EdgeInsets safePad = MediaQuery.of(context).padding;
    final double safeH = (h - safePad.top - safePad.bottom).clamp(1.0, double.infinity);
    final double safeW = (w - safePad.left - safePad.right).clamp(1.0, double.infinity);

    final double hPad = safeW * 0.05;
    final double vGap = safeH * 0.02;

    // ── FIX 1: Compute raw section heights ──────────────────────────────
    // Each section has a desired height; we then scale all of them down
    // proportionally if their sum (+ gaps) exceeds safeH, preventing overflow.
    final double rawHeaderH  = (safeH * 0.13).clamp(28.0, 46.0);
    final double rawArtH     = (safeH * 0.42).clamp(60.0, 200.0);
    final double rawInfoH    = (safeH * 0.20).clamp(36.0, 80.0);
    final double rawControlH = (safeH * 0.19).clamp(32.0, 64.0);
    final double totalGaps   = vGap * 3;

    final double rawTotal = rawHeaderH + rawArtH + rawInfoH + rawControlH + totalGaps;

    // Scale factor: if rawTotal > safeH shrink sections proportionally.
    // Gaps are NOT scaled — only section heights.
    final double sectionBudget = (safeH - totalGaps).clamp(1.0, double.infinity);
    final double rawSections   = rawHeaderH + rawArtH + rawInfoH + rawControlH;
    final double scale         = rawTotal > safeH
        ? sectionBudget / rawSections
        : 1.0;

    final double headerH  = rawHeaderH  * scale;
    final double artH     = rawArtH     * scale;
    final double infoH    = rawInfoH    * scale;
    final double controlH = rawControlH * scale;
    // ────────────────────────────────────────────────────────────────────

    final double artSize   = (artH * 0.92).clamp(50.0, 180.0);

    final double titleFs   = (infoH * 0.34).clamp(9.0, 15.0);
    final double artistFs  = (infoH * 0.22).clamp(7.0, 11.0);
    final double btnSize   = (controlH * 0.55).clamp(18.0, 36.0);
    final double mainBtnSz = (controlH * 0.75).clamp(26.0, 48.0);

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.only(
          top: safePad.top,
          bottom: safePad.bottom,
          left: safePad.left,
          right: safePad.right,
        ),
        // ── FIX 2: Wrap Column in ClipRect so any residual pixel rounding
        // overflow is silently clipped rather than triggering a RenderFlex error.
        child: ClipRect(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── ① 상단 헤더: 시간 + 날짜 ─────────────────────────────
              SizedBox(
                height: headerH,
                child: StreamBuilder<DateTime>(
                  stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                  initialData: DateTime.now(),
                  builder: (context, snap) {
                    final now = snap.data ?? DateTime.now();
                    final String hm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                    final List<String> weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
                    final String date = '${weekdays[now.weekday - 1]}  ${now.month}.${now.day.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'GLASNYL',
                            style: TextStyle(
                              color: _textColor.withValues(alpha: 0.55),
                              fontSize: (headerH * 0.28).clamp(7.0, 11.0),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            date,
                            style: TextStyle(
                              color: _textColor.withValues(alpha: 0.55),
                              fontSize: (headerH * 0.28).clamp(7.0, 11.0),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(width: hPad * 0.6),
                          Text(
                            hm,
                            style: TextStyle(
                              color: _textColor.withValues(alpha: 0.90),
                              fontSize: (headerH * 0.42).clamp(10.0, 16.0),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: vGap),

              // ── ② 앨범 아트 (원형 LP + 프로그레스 링) ────────────────
              SizedBox(
                height: artH,
                child: Center(
                  child: GestureDetector(
                    onLongPress: _handleManualRefresh,
                    child: AnimatedBuilder(
                      animation: _lpController,
                      builder: (context, _) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: _positionNotifier,
                          builder: (context, pos, _) {
                            final double prog = (_totalDuration != null &&
                                    _totalDuration!.inMilliseconds > 0)
                                ? (pos.inMilliseconds / _totalDuration!.inMilliseconds).clamp(0.0, 1.0)
                                : 0.0;
                            return SizedBox(
                              width: artSize,
                              height: artSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: artSize,
                                    height: artSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _lpColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  RotationTransition(
                                    turns: _lpController,
                                    child: Container(
                                      width: artSize * 0.56,
                                      height: artSize * 0.56,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _bgColor,
                                        image: _albumArtBytes != null
                                            ? DecorationImage(
                                                image: MemoryImage(_albumArtBytes!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: artSize * 0.08,
                                    height: artSize * 0.08,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFD4AF37),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black45, blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: artSize * 0.93,
                                    height: artSize * 0.93,
                                    child: CircularProgressIndicator(
                                      value: prog,
                                      strokeWidth: artSize * 0.025,
                                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _barColor.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              SizedBox(height: vGap),

              // ── ③ 제목 + 가수 + 프로그레스바 ─────────────────────────
              // FIX 3: Replaced LayoutBuilder + nested Column with a simpler
              // structure that does NOT use LayoutBuilder inside a bounded
              // SizedBox — this was causing the MultiChildLayoutDelegate crash
              // when Flutter tried to lay out StreamProgressBar in a context
              // where the parent constraints were being recalculated.
              SizedBox(
                height: infoH,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: _buildFlipCoverInfoSection(
                    infoH: infoH,
                    titleFs: titleFs,
                    artistFs: artistFs,
                    safeW: safeW,
                    hPad: hPad,
                  ),
                ),
              ),

              SizedBox(height: vGap),

              // ── ④ 컨트롤 버튼 + 볼륨 ─────────────────────────────────
              SizedBox(
                height: controlH,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          PlayerLogic.skipPrevious();
                        },
                        child: Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: btnSize,
                        ),
                      ),
                      GestureDetector(
                        onTap: _handleInternalToggle,
                        child: Container(
                          width: mainBtnSz,
                          height: mainBtnSz,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _barColor.withValues(alpha: 0.25),
                            border: Border.all(
                              color: _barColor.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: mainBtnSz * 0.55,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          PlayerLogic.skipNext();
                        },
                        child: Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: btnSize,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: controlH * 0.45,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: hPad * 0.6),
                          child: ValueListenableBuilder<double>(
                            valueListenable: _volumeNotifier,
                            builder: (context, vol, _) => Row(
                              children: [
                                Icon(
                                  vol < 0.05
                                      ? Icons.volume_off_rounded
                                      : vol < 0.5
                                          ? Icons.volume_down_rounded
                                          : Icons.volume_up_rounded,
                                  color: _barColor,
                                  size: btnSize * 0.7,
                                ),
                                SizedBox(width: hPad * 0.4),
                                Expanded(
                                  child: _GlassVolumeSlider(
                                    value: vol,
                                    trackHeight: 5.0,
                                    thumbRadius: 7.0,
                                    activeColor: _barColor,
                                    thumbColor: _playBtnColor,
                                    bgColor: _bgColor,
                                    onChanged: (v) async {
                                      _volumeNotifier.value = v;
                                      await PlayerLogic.setVolume(v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FIX 3 helper: info section extracted to its own method ──────────
  // Previously this was an inline LayoutBuilder that read constraints.maxWidth
  // inside a StreamBuilder closure — a pattern that can produce degenerate
  // constraints when the parent Column is being reflowed.
  // Now the width is passed in explicitly, matching how every other section
  // in this file computes its dimensions.
  Widget _buildFlipCoverInfoSection({
    required double infoH,
    required double titleFs,
    required double artistFs,
    required double safeW,
    required double hPad,
  }) {
    // Bar width = safeW minus the symmetric hPad applied by the parent Padding.
    final double barW = (safeW - hPad * 2).clamp(1.0, double.infinity);

    // Recompute gaps without LayoutBuilder (same math, just explicit).
    const double progressBarH = 40.0;
    final double titleLineH   = titleFs * 1.3;
    final double artistLineH  = artistFs * 1.3;
    final double totalFixed   = titleLineH + artistLineH + progressBarH;
    final double remainH      = (infoH - totalFixed).clamp(0.0, double.infinity);
    final double gapA         = (remainH * 0.35).clamp(0.0, 6.0);
    final double gapB         = (remainH * 0.65).clamp(0.0, 10.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 제목
        SizedBox(
          height: titleLineH,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              _currentTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFs,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(height: gapA),
        // 가수
        SizedBox(
          height: artistLineH,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              _currentArtist,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: artistFs,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(height: gapB),
        // 프로그레스바 — explicit width, no LayoutBuilder needed
        SizedBox(
          height: progressBarH,
          width: barW,
          child: StreamProgressBar(
            barWidth: barW,
            bgColor: _bgColor,
            barColor: _barColor,
            onSeek: (ratio) {
              PlayerLogic.seekTo(ratio);
              final dur = _totalDuration ?? audioHandler.mediaItem.value?.duration;
              if (dur != null && dur.inMilliseconds > 0) {
                _positionNotifier.value = Duration(
                    milliseconds: (dur.inMilliseconds * ratio).toInt());
              }
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 기존 자유 배치 레이아웃
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildLegacyLayout(
    Size size, PlayerConfig config,
    bool isPortrait, bool isSpecialMode,
  ) {
    final double leftPadding = size.width * 0.08;
    final double safeLeftDx = (size.width * 0.85 / 2) + leftPadding;

    double finalContentDx = isSpecialMode
        ? config.titlePos.dx
        : isPortrait
            ? safeLeftDx
            : config.titlePos.dx;

    double finalContentWidth = isSpecialMode
        ? size.width * 0.6
        : isPortrait
            ? size.width * 0.85
            : config.progressBarWidth;

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildEdit(
            Offset(
              (_isMinimalMode || _showLyrics)
                  ? (isPortrait ? size.width / 2 : size.width * 0.25)
                  : config.lpPos.dx,
              config.lpPos.dy,
            ),
            (_isMinimalMode || _showLyrics)
                ? config.lpSize
                : config.lpSize * 1.35,
            (_isMinimalMode || _showLyrics)
                ? config.lpSize
                : config.lpSize * 1.05,
            (d) => config.lpPos += d,
            (s) => config.lpSize = (config.lpSize + s).clamp(150.0, 500.0),
            GestureDetector(
              onLongPress: _handleManualRefresh,
              child: ValueListenableBuilder<Duration>(
                valueListenable: _positionNotifier,
                builder: (context, realTimePos, _) {
                  if (_isMinimalMode || _showLyrics) {
                    return RepaintBoundary(
                      child: ClassicVinylView(
                        lyricStatus: _currentStatus,
                        lyrics: _lyrics,
                        currentPosition: realTimePos,
                        isMinimalMode: _isMinimalMode,
                        isLyricsMode: _showLyrics,
                        size: config.lpSize,
                        albumArtBytes: _albumArtBytes,
                        title: _currentTitle,
                        artist: _currentArtist,
                        lpController: _lpController,
                        isPlaying: _isPlaying,
                        onToggleMode: () =>
                            setState(() => _isMinimalMode = !_isMinimalMode),
                        onShowLyrics: () {
                          setState(() => _showLyrics = true);
                          Future(() async {
                            if (_lyrics.isEmpty &&
                                _currentStatus != LyricStatus.loading) {
                              await _updateLyrics({
                                'title': _currentTitle,
                                'artist': _currentArtist,
                              });
                            }
                            try {
                              const p =
                                  MethodChannel('com.glasnyl.app/media_control');
                              final r = await p.invokeMethod('getCurrentStatus');
                              if (r?['position'] != null) {
                                _positionNotifier.value = Duration(
                                    milliseconds:
                                        (r['position'] as num).toInt());
                              }
                            } catch (_) {}
                          });
                        },
                        onCloseLyrics: () =>
                            setState(() => _showLyrics = false),
                      ),
                    );
                  }

                  final double progress = (_totalDuration != null &&
                          _totalDuration!.inMilliseconds > 0)
                      ? (realTimePos.inMilliseconds /
                              _totalDuration!.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0;

                  return RepaintBoundary(
                    child: VinylTurntableView(
                      lpController: _lpController,
                      size: config.lpSize * 1.35,
                      albumArtBytes: _albumArtBytes,
                      title: _currentTitle,
                      artist: _currentArtist,
                      isPlaying: _isPlaying,
                      progress: progress,
                      progressStream: _turntableProgressCtrl.stream,
                      accentColor: _playBtnColor,
                      bgColor: _bgColor,
                      onPlayPause: _handleInternalToggle,
                      onNext: () {
                        HapticFeedback.lightImpact();
                        PlayerLogic.skipNext();
                      },
                      onPrevious: () {
                        HapticFeedback.lightImpact();
                        PlayerLogic.skipPrevious();
                      },
                      onSeek: (ratio) {
                        final dur = _totalDuration ??
                            audioHandler.mediaItem.value?.duration;
                        if (dur != null && dur.inMilliseconds > 0) {
                          final target = Duration(
                              milliseconds:
                                  (dur.inMilliseconds * ratio).round());
                          _handleSeek(target);
                          PlayerLogic.seekTo(ratio);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          _buildEdit(
            Offset(finalContentDx, config.titlePos.dy),
            finalContentWidth, config.titleSize * 1.5,
            (d) => config.titlePos += d,
            (s) => config.titleSize =
                (config.titleSize + s * 0.1).clamp(20.0, 80.0),
            ClipRect(
              child: SizedBox(
                width: finalContentWidth > 0 ? finalContentWidth : 200,
                child: Align(
                  alignment: isPortrait
                      ? Alignment.centerLeft
                      : Alignment.center,
                  child: MarqueeTitleWidget(
                    key: Key(_currentTitle),
                    title: _currentTitle,
                    fontSize: config.titleSize * 1.1,
                    textColor: _textColor,
                    width: finalContentWidth,
                    isPip: _isPipMode,
                  ),
                ),
              ),
            ),
          ),

          _buildEdit(
            Offset(finalContentDx, config.artistPos.dy),
            finalContentWidth, 40,
            (d) => config.artistPos += d,
            (s) => config.artistSize =
                (config.artistSize + s * 0.1).clamp(10.0, 40.0),
            Align(
              alignment:
                  isPortrait ? Alignment.centerLeft : Alignment.center,
              child: ArtistTextWidget(
                artist: _currentArtist,
                fontSize: config.artistSize,
                color: _artistColor.withValues(alpha: 0.8),
              ),
            ),
          ),

          _buildEdit(
            config.progressBarPos, config.progressBarWidth, 40,
            (d) => config.progressBarPos += d,
            (s) => config.progressBarWidth =
                (config.progressBarWidth + s).clamp(100.0, size.width),
            SizedBox(
              key: _progressKey,
              width: config.progressBarWidth.clamp(1.0, double.infinity),
              child: StreamProgressBar(
                barWidth: config.progressBarWidth.clamp(1.0, double.infinity),
                bgColor: _bgColor,
                barColor: _barColor,
                onSeek: (ratio) {
                  PlayerLogic.seekTo(ratio);
                  final dur = _totalDuration ??
                      audioHandler.mediaItem.value?.duration;
                  if (dur != null && dur.inMilliseconds > 0) {
                    _positionNotifier.value = Duration(
                        milliseconds:
                            (dur.inMilliseconds * ratio).toInt());
                  }
                },
              ),
            ),
          ),

          _buildEdit(
            config.prevButtonPos, 60, 60,
            (d) => config.prevButtonPos += d, (_) {},
            PlayButtonsWidget.buildSideBtn(
              icon: Icons.skip_previous_rounded,
              onTap: PlayerLogic.skipPrevious,
            ),
          ),

          _buildEdit(
            config.playButtonsPos, 90, 90,
            (d) => config.playButtonsPos += d, (_) {},
            PlayButtonsWidget.buildMainPlayBtn(
              isPlaying: _isPlaying,
              activeColor: _barColor,
              onTap: () {
                PlayerLogic.togglePlay(
                  isPlaying: _isPlaying,
                  onToggle: () {
                    if (mounted) {
                      setState(() {
                        _isPlaying = !_isPlaying;
                        if (_isPlaying) {
                          _lpController.repeat();
                          _needleController.forward();
                        } else {
                          _lpController.stop();
                          _needleController.reverse();
                        }
                      });
                    }
                  },
                );
              },
            ),
          ),

          _buildEdit(
            config.nextButtonPos, 60, 60,
            (d) => config.nextButtonPos += d, (_) {},
            PlayButtonsWidget.buildSideBtn(
              icon: Icons.skip_next_rounded,
              onTap: PlayerLogic.skipNext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEdit(
    Offset pos, double w, double h,
    Function(Offset) onDrag,
    Function(double) onResize,
    Widget child,
  ) {
    return Positioned(
      left: pos.dx - (w / 2),
      top: pos.dy - (h / 2),
      child: EditableElement(
        isEditMode: isEditMode,
        width: w, height: h,
        onDrag: (d) => setState(() => onDrag(d)),
        onResizeDelta: (s) => setState(() => onResize(s)),
        child: child,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 가로 모드 전용 가사 스크롤러
// ════════════════════════════════════════════════════════════════════════
class _LandscapeLyricsScroller extends StatefulWidget {
  final List<dynamic> lyrics;
  final Duration currentPosition;
  final LyricStatus lyricStatus;
  final bool isPlaying;
  final double size;
  final Color barColor;
  final Color textColor;

  const _LandscapeLyricsScroller({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    required this.lyricStatus,
    required this.isPlaying,
    required this.size,
    required this.barColor,
    required this.textColor,
  });

  @override
  State<_LandscapeLyricsScroller> createState() =>
      _LandscapeLyricsScrollerState();
}

class _LandscapeLyricsScrollerState extends State<_LandscapeLyricsScroller>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late ScrollController _scrollController;
  late Ticker _ticker;

  int _lastIndex = -1;
  int _maxIndexReached = -1;
  bool _isUserInteracting = false;
  Timer? _debounceTimer;

  Duration _basePosition = Duration.zero;
  Duration _elapsedSinceSync = Duration.zero;
  Duration _lastTickerCheck = Duration.zero;
  static const Duration _throttleInterval = Duration(milliseconds: 25);

  late final double _baseSize;
  late final double _currentSize;
  late final double _itemExtent;

  double _offsetForIndex(int index) => index * _itemExtent;

  @override
  void initState() {
    super.initState();
    _baseSize    = (widget.size * 0.055).clamp(11.0, 15.0);
    _currentSize = (widget.size * 0.075).clamp(14.0, 20.0);
    _itemExtent  = _currentSize * 2.8;

    _basePosition    = widget.currentPosition;
    _lastIndex       = _calculateCurrentIndex(_basePosition);
    _maxIndexReached = _lastIndex;

    final double initOffset = _lastIndex > 0
        ? _offsetForIndex(_lastIndex).clamp(0.0, double.infinity)
        : 0.0;
    _scrollController = ScrollController(initialScrollOffset: initOffset);
    WidgetsBinding.instance.addObserver(this);

    _ticker = createTicker((elapsed) {
      if (!mounted || !widget.isPlaying || _isUserInteracting) return;
      if (elapsed - _lastTickerCheck < _throttleInterval) return;
      _lastTickerCheck = elapsed;
      _elapsedSinceSync = elapsed;
      _checkAndScroll();
    });
    if (widget.isPlaying) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant _LandscapeLyricsScroller old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _basePosition     = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
        if (!_ticker.isTicking) _ticker.start();
      } else {
        _ticker.stop();
        _basePosition     = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
      }
    }
    if (widget.currentPosition != old.currentPosition) {
      final estimatedNow = _basePosition + _elapsedSinceSync;
      final bool isSeek =
          (widget.currentPosition - old.currentPosition).abs().inMilliseconds > 300 ||
          widget.currentPosition < old.currentPosition;
      if (isSeek || (widget.currentPosition - estimatedNow).abs() > const Duration(milliseconds: 500)) {
        _basePosition     = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
        _lastTickerCheck  = Duration.zero;
        if (_ticker.isTicking) { _ticker.stop(); _ticker.start(); }
        int newIdx = _calculateCurrentIndex(widget.currentPosition);
        _lastIndex       = newIdx;
        _maxIndexReached = newIdx;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _offsetForIndex(newIdx >= 0 ? newIdx : 0).clamp(0.0, double.infinity),
          );
        }
      }
    }
    if (widget.lyrics != old.lyrics) {
      _basePosition     = widget.currentPosition;
      _elapsedSinceSync = Duration.zero;
      _lastIndex       = -1;
      _maxIndexReached = -1;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _basePosition     = widget.currentPosition;
      _elapsedSinceSync = Duration.zero;
      int newIdx = _calculateCurrentIndex(_basePosition);
      _lastIndex       = newIdx;
      _maxIndexReached = newIdx;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _offsetForIndex(newIdx >= 0 ? newIdx : 0).clamp(0.0, double.infinity),
          );
        }
      });
      if (widget.isPlaying && !_ticker.isTicking) _ticker.start();
    }
    if (state == AppLifecycleState.paused) {
      if (_ticker.isTicking) _ticker.stop();
    }
  }

  void _checkAndScroll() {
    if (_isUserInteracting || !_scrollController.hasClients) return;
    final precisePos = _basePosition + _elapsedSinceSync + const Duration(milliseconds: 50);
    int currentIndex = _calculateCurrentIndex(precisePos);
    if (currentIndex != -1 && currentIndex != _lastIndex) {
      final skipped = currentIndex - _lastIndex;
      _lastIndex = currentIndex;
      if (currentIndex > _maxIndexReached) _maxIndexReached = currentIndex;
      if (mounted) setState(() {});
      final double maxScroll = _scrollController.position.maxScrollExtent;
      final double offset = _offsetForIndex(currentIndex).clamp(0.0, maxScroll);
      if (skipped >= 2) {
        _scrollController.jumpTo(offset);
      } else {
        _scrollController.animateTo(offset,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    }
  }

  int _calculateCurrentIndex(Duration pos) {
    if (widget.lyrics.isEmpty) return -1;
    int lo = 0, hi = widget.lyrics.length - 1, index = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final item = widget.lyrics[mid];
      if (item is LyricLine && item.time <= pos) {
        index = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (index < _maxIndexReached && _maxIndexReached != -1) return _maxIndexReached;
    return index;
  }

  void _onUserInteraction() {
    _isUserInteracting = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isUserInteracting = false);
        _basePosition     = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
        _maxIndexReached  = _calculateCurrentIndex(_basePosition);
        _checkAndScroll();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return Center(
        child: widget.lyricStatus == LyricStatus.loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
            : Text(
                widget.lyricStatus == LyricStatus.noLyrics
                    ? 'No lyrics found'
                    : 'Unable to load lyrics',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification && n.dragDetails != null) {
          _onUserInteraction();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: widget.size / 2 - _itemExtent / 2),
        itemCount: widget.lyrics.length,
        itemExtent: _itemExtent,
        itemBuilder: (context, index) {
          final isCurrent = index == _lastIndex;
          return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isCurrent
                      ? Colors.white.withValues(alpha: 1.0)
                      : Colors.white.withValues(alpha: 0.28),
                  fontSize: isCurrent ? _currentSize : _baseSize,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  height: 1.3,
                ),
                child: Text(
                  widget.lyrics[index].text ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 글래스모피즘 볼륨 슬라이더
// ════════════════════════════════════════════════════════════════════════
class _GlassVolumeSlider extends StatefulWidget {
  final double value;
  final double trackHeight;
  final double thumbRadius;
  final Color activeColor;
  final Color thumbColor;
  final Color bgColor;
  final ValueChanged<double> onChanged;

  const _GlassVolumeSlider({
    required this.value,
    required this.trackHeight,
    required this.thumbRadius,
    required this.activeColor,
    required this.thumbColor,
    required this.bgColor,
    required this.onChanged,
  });

  @override
  State<_GlassVolumeSlider> createState() => _GlassVolumeSliderState();
}

class _GlassVolumeSliderState extends State<_GlassVolumeSlider> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackW = constraints.maxWidth;
        final double th = widget.trackHeight;
        final double tr = widget.thumbRadius;
        final double totalH = tr * 2 + 8;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            setState(() => _dragging = true);
            _update(d.localPosition.dx, trackW, tr);
          },
          onPanUpdate: (d) => _update(d.localPosition.dx, trackW, tr),
          onPanEnd: (_) => setState(() => _dragging = false),
          onTapDown: (d) => _update(d.localPosition.dx, trackW, tr),
          child: SizedBox(
            width: trackW,
            height: totalH,
            child: CustomPaint(
              painter: _GlassTrackPainter(
                value: widget.value,
                trackHeight: th,
                thumbRadius: tr,
                activeColor: widget.activeColor,
                thumbColor: widget.thumbColor,
                bgColor: widget.bgColor,
                dragging: _dragging,
              ),
            ),
          ),
        );
      },
    );
  }

  void _update(double dx, double trackW, double tr) {
    final double ratio = ((dx - tr) / (trackW - tr * 2)).clamp(0.0, 1.0);
    widget.onChanged(ratio);
  }
}

class _GlassTrackPainter extends CustomPainter {
  final double value;
  final double trackHeight;
  final double thumbRadius;
  final Color activeColor;
  final Color thumbColor;
  final Color bgColor;
  final bool dragging;

  _GlassTrackPainter({
    required this.value,
    required this.trackHeight,
    required this.thumbRadius,
    required this.activeColor,
    required this.thumbColor,
    required this.bgColor,
    required this.dragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final double th = 5.0;
    final double tr = thumbRadius * 0.9;
    final double left = tr;
    final double right = size.width - tr;
    final double fillX = left + (right - left) * value;

    final Radius r = Radius.circular(th / 2);

    final Paint inactivePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final RRect inactiveRRect = RRect.fromLTRBR(
        left, cy - th / 2, right, cy + th / 2, r);
    canvas.drawRRect(inactiveRRect, inactivePaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(inactiveRRect, borderPaint);

    if (fillX > left) {
      final Paint activePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            activeColor.withValues(alpha: 0.3),
            activeColor.withValues(alpha: 0.7),
          ],
        ).createShader(Rect.fromLTRB(left, cy - th / 2, fillX, cy + th / 2))
        ..style = PaintingStyle.fill;

      final RRect activeRRect = RRect.fromLTRBR(
          left, cy - th / 2, fillX, cy + th / 2, r);
      canvas.drawRRect(activeRRect, activePaint);
    }

    final double glowR = dragging ? tr * 2.0 : tr * 1.5;
    final Paint glowPaint = Paint()
      ..color = activeColor.withValues(alpha: dragging ? 0.28 : 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(fillX, cy), glowR, glowPaint);

    final Paint thumbBodyPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final Paint thumbStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final Paint thumbPointPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(fillX, cy), tr * 0.85, thumbBodyPaint);
    canvas.drawCircle(Offset(fillX, cy), tr * 0.85, thumbStrokePaint);
    canvas.drawCircle(Offset(fillX, cy), tr * 0.3, thumbPointPaint);
  }

  @override
  bool shouldRepaint(_GlassTrackPainter old) =>
      old.value != value || old.dragging != dragging;
}