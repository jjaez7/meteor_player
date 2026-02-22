import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'models/player_config.dart';
import 'utils/layout_engine.dart';
import 'widgets/editable_element.dart';
//import 'widgets/vinyl_component.dart';
import 'widgets/player_app_bar.dart';
//import 'menu/menu_main.dart';
import 'color_manager.dart';
import 'main.dart';
import 'widgets/player_elements.dart';
import 'widgets/player_text_info.dart';
import 'widgets/needle_component.dart';
import 'logic/music_controller.dart';
import 'logic/player_logic.dart';
//import 'widgets/surreal_player_view.dart';
import 'widgets/classic_vinyl_view.dart';
import 'widgets/stream_progress_bar.dart';
import 'dart:ui';
import 'features/screen_lock.dart';
//import 'features/pip_handler.dart';
import 'services/lyrics_service.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
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
  bool _isMinimalMode = false;
  bool _showLyrics = false;
  bool _isPipMode = false;

  bool _isScreenLocked = false;
  Duration? _totalDuration;
  //bool _isSurrealMode = false;
  // 기존 20줄짜리 코드를 이렇게 줄입니다.
  Future<void> _handleAbsoluteColorReset() async {
    final newColors = await PlayerLogic.handleAbsoluteColorReset();
    setState(() {
      _bgColor = newColors['bg']!;
      _lpColor = newColors['lp']!;
      _textColor = newColors['text']!;
      _artistColor = newColors['artist']!;
      _barColor = newColors['bar']!;
      _playBtnColor = newColors['btn']!;
    });
  }

  void _handleResetLayout() async {
    await PlayerLogic.resetLayout();
    if (!mounted) return;

    setState(() {
      final size = MediaQuery.of(context).size;

      // 🚀 LayoutEngine.calculate에 세 번째 인자(isPip)로 false를 전달합니다.
      // 리셋은 보통 일반 모드에서 이루어지기 때문입니다.
      _portraitConfig = LayoutEngine.calculate(
        size,
        Orientation.portrait,
        false,
      );
      _landscapeConfig = LayoutEngine.calculate(
        size,
        Orientation.landscape,
        false,
      );
    });
  }

  void _handleSeek(Duration targetTime) {
    // 1. 시스템 오디오 핸들러에 탐색 명령 전달
    audioHandler.seek(targetTime);

    // 2. 현재 시간을 즉시 업데이트하여 UI 반응성 높임
    _positionNotifier.value = targetTime;

    // 3. 가사가 있다면, 변경된 시간에 맞는 가사 인덱스로 즉시 이동
    if (_lyrics.isNotEmpty) {
      int newIndex = _lyrics.lastIndexWhere((line) => line.time <= targetTime);
      if (newIndex != -1) {
        // 만약 가사 위젯에서 별도의 index 변수를 쓰고 있다면 여기서 setState를 해줍니다.
        // 현재 ClassicVinylView 내부에서 realTimePos를 직접 보고 있다면
        // notifier 업데이트만으로도 충분합니다.
        debugPrint(
          "🎯 수동 탐색 동기화: Index $newIndex (${targetTime.inMilliseconds}ms)",
        );
      }
    }
  }

  // 클래스 상단 변수 선언부
  final GlobalKey _progressKey = GlobalKey();
  //final GlobalKey _titleKey = GlobalKey();

  late AnimationController _lpController, _needleController;
  bool isEditMode = false, _isPlaying = false;
  PlayerConfig? _portraitConfig, _landscapeConfig;
  DateTime? _lastSyncTime;

  String _currentTitle = "Ready to Play";
  String _currentArtist = "Artist NAME";
  Uint8List? _albumArtBytes;

  List<dynamic> _lyrics = [];
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );

  // 기본 테마 색상 설정
  Color _bgColor = const Color(0xFFE1E0E5);
  Color _lpColor = const Color(0xFF2A292E);
  Color _textColor = const Color(0xFF333335);
  Color _artistColor = const Color(0xFF8F7AB3);
  Color _barColor = const Color(0xFFB1A1D0);
  Color _playBtnColor = const Color(0xFF735DA5);

  static const _pipChannel = MethodChannel('com.glasnyl.app/pip_status');

  @override
  void initState() {
    _startAccessGuardian();
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pipChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "onPipModeChanged":
          bool isInPip = call.arguments;
          if (mounted) {
            setState(() {
              _isPipMode = isInPip;
              if (isInPip) isEditMode = false;
            });
          }
          break;

        case "onPipAction":
          // 네이티브에서 invokeMethod("onPipAction", action)으로 보냈으므로
          // arguments는 Map이 아니라 문자열(String) 그 자체입니다.
          final String actionName = call.arguments.toString();
          debugPrint("📥 PiP 신호 수신: $actionName");

          // 문자열 비교 시 공백 제거 및 대문자 확인으로 더 확실하게 처리
          if (actionName.trim() == "TOGGLE") {
            debugPrint("✅ 재생 토글 실행");
            _handleInternalToggle();
          } else if (actionName.trim() == "NEXT") {
            debugPrint("✅ 다음 곡 실행");
            PlayerLogic.skipNext();
          } else if (actionName.trim() == "PREV") {
            debugPrint("✅ 이전 곡 실행");
            PlayerLogic.skipPrevious();
          }
          break;
      }
    });
    WakelockPlus.enable();

    // 1. 애니메이션 컨트롤러 초기화 (addListener는 계속 삭제된 상태 유지)
    _lpController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 1. 재생 위치 리스너
    audioHandler.position.listen((pos) {
      debugPrint("🕒 시계 심박동: ${pos.inMilliseconds}ms");
      if (mounted) _positionNotifier.value = pos; // setState 없이 값만 주입
    });

    // 2. 가사 로딩 및 곡 변경 리스너 (해결 핵심)
    audioHandler.mediaItem.listen((item) {
      if (item != null && mounted) {
        // 🚀 [중요] 곡 제목이 '실제로' 다를 때만 모든 데이터를 초기화합니다.
        // 이 조건이 없으면 가사 로딩 중에 제목 정보를 다시 받으면서 시계가 0으로 튕깁니다.
        if (_currentTitle != item.title) {
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
      }
    });

    audioHandler.playbackState.listen((state) {
      if (!mounted) return;

      if (state.playing) {
        // 재생 중 신호가 오면 바늘 내림
        if (_needleController.status != AnimationStatus.forward &&
            _needleController.value < 1.0) {
          _needleController.forward();
        }
        if (!_lpController.isAnimating) _lpController.repeat();
      } else {
        // 멈춤 신호가 오면 바늘 올림 (이게 해결 핵심!)
        if (_needleController.status != AnimationStatus.reverse &&
            _needleController.value > 0.0) {
          _needleController.reverse();
        }

        // LP는 바늘이 올라가기 시작한 뒤 약간 뒤에 멈춤
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !audioHandler.playbackState.value.playing) {
            _lpController.stop();
          }
        });
      }
    });

    // 2. 가벼운 데이터(색상) 먼저 로드
    _loadSavedColors();

    // 3. 🚀 핵심 수정: 화면이 뜬 뒤에 순차적으로 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A. 먼저 뮤직 리스너를 등록 (통신 통로 열기)
      _listenToMusic();

      // B. 무거운 이미지 데이터 호출은 조금 더 뒤로 미룸 (검은 화면 방지)
      // 500ms -> 1000ms로 늘려 UI가 완전히 안착할 시간을 줍니다.
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _fetchInitialStatus();
        }
      });
    });

    /*_setLowRefreshRate();*/
  }

  void _startAccessGuardian() {
    // 기존 타이머가 있다면 취소하여 중복 실행 방지
    _accessCheckTimer?.cancel();

    _accessCheckTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      // 1. 이미 다이얼로그가 떠 있거나, 편집 모드, 혹은 PiP 모드일 때는 체크 건너뜀
      if (_isPassDialogShowing || isEditMode || _isPipMode) return;

      // 2. 권한 체크 (initInstallTime은 main에서 한 번만 호출되므로 여기선 생략)
      bool hasAccess = await AdService.isFullAccess();

      // 3. 권한이 만료되었을 때만 팝업 실행
      if (!hasAccess && mounted) {
        _isPassDialogShowing = true;

        // 광고 팝업 실행
        showPassDialog(context, () {
          if (mounted) {
            setState(() {
              _isPassDialogShowing = false;
            });
            // 권한 획득 후 즉시 상태 갱신 (선택사항)
            _fetchInitialStatus();
          }
        });
      }
    });
  }

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

  LyricStatus _currentStatus = LyricStatus.loading;
  String _lastFetchedSongId = "";
  int _lastRequestToken = 0;

  Future<void> _updateLyrics(dynamic item) async {
    _positionNotifier.value = Duration.zero;

    // 1. 새로운 요청 토큰 생성
    final int currentToken = ++_lastRequestToken;

    String title = (item is Map)
        ? (item['title'] ?? "Unknown")
        : (item.title ?? "Unknown");
    String artist = (item is Map)
        ? (item['artist'] ?? "Unknown")
        : (item.artist ?? "Unknown");
    final String currentId = "${title}_$artist";

    // 중복 요청 방지 (ID와 데이터가 모두 동일할 때만 리턴)
    if (_lastFetchedSongId == currentId && _lyrics.isNotEmpty) return;
    _lastFetchedSongId = currentId;

    if (mounted) {
      setState(() {
        _lyrics = [];
        _currentStatus = LyricStatus.loading;
      });
    }

    // 사용자가 곡을 빠르게 넘길 때(Debounce)를 위한 대기
    await Future.delayed(const Duration(milliseconds: 500));
    if (currentToken != _lastRequestToken) return;

    try {
      // 🚀 LyricsService 실행 (내부에서 1차~5차 시도 수행)
      final result = await LyricsService.getLyrics(title, artist);

      // [검증] 응답이 왔을 때 내 토큰이 최신인가?
      if (mounted && currentToken == _lastRequestToken) {
        setState(() {
          _lyrics = result.lyrics;
          _currentStatus = result.status;
        });
        debugPrint("✅ 가사 최종 반영: $title (Token: $currentToken)");
      }
    } catch (e) {
      // 🚨 [가장 중요한 부분]
      // LyricsService가 내부 재시도 중 에러를 던지더라도,
      // 이미 가사가 들어온 상태(성공)라면 UI를 '네트워크 에러'로 덮어쓰지 않습니다.
      if (mounted && currentToken == _lastRequestToken) {
        if (_lyrics.isEmpty) {
          debugPrint("🚨 가사 로드 실패(최종): $e");
          setState(() {
            _currentStatus = (e is TimeoutException)
                ? LyricStatus.timeout
                : LyricStatus.networkError;
          });
        } else {
          debugPrint("💡 무시된 지연 에러: 이미 가사가 로드됨 ($title)");
        }
      }
    }
  }

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

  @override
  void dispose() {
    _accessCheckTimer?.cancel();
    // 🚀 관찰자를 반드시 해제해야 메모리 누수가 없습니다.
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _lpController.dispose();
    _needleController.dispose();
    _positionNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadSavedColors() async {
    final savedColors = await ColorManager.loadSettings();
    setState(() {
      _bgColor = savedColors['bg']!;
      _lpColor = savedColors['lp']!;
      _textColor = savedColors['text']!;
      _artistColor = savedColors['artist']!;
      _barColor = savedColors['bar']!;
      _playBtnColor = savedColors['btn']!;
    });
  }

  /*Future<void> _setLowRefreshRate() async {
    try {
      // 주사율 제어 패키지 임포트가 필요합니다: import 'package:flutter_displaymode/flutter_displaymode.dart';
      final List<DisplayMode> modes = await FlutterDisplayMode.supported;

      // 60Hz 모드 찾기
      final DisplayMode lowRefreshMode = modes.firstWhere(
        (m) => m.refreshRate.round() == 60,
        orElse: () => DisplayMode.auto,
      );

      await FlutterDisplayMode.setPreferredMode(lowRefreshMode);
      debugPrint("✅ 앱 전체 주사율 60Hz 고정 완료");
    } catch (e) {
      debugPrint("⚠️ 주사율 설정 실패 (지원하지 않는 기기일 수 있음): $e");
    }
  }*/

  void _handleColorChange(Color newColor, String target) {
    setState(() {
      // UI 업데이트 로직만 남김
      switch (target) {
        case 'bg':
          _bgColor = newColor;
          break;
        case 'lp':
          _lpColor = newColor;
          break;
        case 'text':
          _textColor = newColor;
          break;
        case 'artist':
          _artistColor = newColor;
          break;
        case 'bar':
          _barColor = newColor;
          break;
        case 'btn':
          _playBtnColor = newColor;
          break;
      }
    });
    PlayerLogic.updateColor(target, newColor); // 저장 로직은 외부로
  }

  void _listenToMusic() async {
    bool isGranted = await NotificationListenerService.isPermissionGranted();
    if (!isGranted) return;

    NotificationListenerService.notificationsStream.listen((event) async {
      if (event.hasRemoved == true || event.title == null) return;

      if (MusicColorLogic.isMusicApp(event.packageName ?? "")) {
        // 제목이 같고 아티스트가 유효하면 불필요한 리빌드 방지
        if (_currentTitle == event.title) {
          return;
        }

        if (!mounted) return;

        _positionNotifier.value = Duration.zero;

        // 1. [즉시 업데이트] 이미지와 텍스트부터 먼저 바꿉니다 (callback 제거)
        setState(() {
          _currentTitle = event.title!;
          _currentArtist = (event.content ?? "Unknown").toUpperCase();
          _lyrics = [];
          _lastFetchedSongId = "";
          _isPlaying = true;
          _currentStatus = LyricStatus.loading;
        });

        await _fetchInitialStatus();

        _updateLyrics({'title': event.title, 'artist': event.content});

        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }

        // 2. [비동기 업데이트] 색상 추출은 백그라운드에서 천천히 수행
        if (_albumArtBytes != null) {
          MusicColorLogic.extractThemeColors(_albumArtBytes!).then((colors) {
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
        }

        _lpController.repeat();
        _needleController.forward();
      }
    });

    const EventChannel(
      'com.glasnyl.app/media_status',
    ).receiveBroadcastStream().listen((status) {
      if (status is Map && status['position'] != null) {
        final int incomingPos = status['position'];

        // 현재 값과 200ms 이상 차이날 때만 업데이트 (UI 스레드 부하 감소)
        final diff = (incomingPos - _positionNotifier.value.inMilliseconds)
            .abs();
        if (diff > 200) {
          _positionNotifier.value = Duration(milliseconds: incomingPos);
        }
      }
    });
  }

  // 미디어 상태 업데이트 로직도 별도 함수로 빼면 더 깨끗합니다.
  void _handleMediaStatusUpdate(dynamic data) {
    if (data == null || !mounted) return;

    if (data is Map && data['position'] != null) {
      // 🚀 핵심 수정: 시스템이 주는 시간을 무조건 믿지 않습니다.
      int incomingPos = data['position'];

      if (_positionNotifier.value.inMilliseconds == 0 && incomingPos > 2000) {
        debugPrint("🚫 이전 곡의 잔상 시간($incomingPos) 무시함");
        return;
      }

      if (incomingPos < 500) {
        // 곡 초반(1초 미만) 신호는 곡이 바뀌었거나 되돌린 것이므로 즉시 리셋
        _positionNotifier.value = Duration(milliseconds: incomingPos);
      } else if (_isPlaying && incomingPos <= 0) {
        // 재생 중인데 갑자기 0이 들어오는 케이스만 무시
        debugPrint("🚫 재생 중 튀는 신호 차단");
      } else {
        final diff = (incomingPos - _positionNotifier.value.inMilliseconds)
            .abs();
        if (diff > 200) {
          _positionNotifier.value = Duration(milliseconds: incomingPos);
        }
      }
    }

    bool incomingPlayingState = _isPlaying;

    try {
      if (data is Map) {
        incomingPlayingState = data['isPlaying'] ?? false;
      } else if (data is String) {
        incomingPlayingState = (data == 'playing');
      } else if (data is bool) {
        incomingPlayingState = data;
      }
    } catch (e) {
      debugPrint("Media status parsing error: $e");
    }

    // 상태가 변했을 때만 처리
    if (_isPlaying != incomingPlayingState) {
      setState(() {
        _isPlaying = incomingPlayingState;
      });

      if (_isPlaying) {
        // [재생 시작]
        if (!_lpController.isAnimating) _lpController.repeat();
        _needleController.forward(); // 바늘 내리기 (0.0 -> 1.0)
        HapticFeedback.lightImpact();
      } else {
        // [정지 발생] 🚀 이 부분이 바늘 동작의 핵심입니다.

        // 1. 바늘 먼저 즉시 올리기
        _needleController.reverse(); // 바늘 올리기 (1.0 -> 0.0)

        // 2. 바늘이 완전히 올라가는 시간(약 500ms) 동안은 LP가 도는 게 자연스러움
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isPlaying) {
            _lpController.stop(); // LP 정지
          }
        });
        HapticFeedback.mediumImpact();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 유튜브 뮤직 등 다른 곳에서 조작하고 돌아왔을 때 즉시 상태 동기화
      _fetchInitialStatus();
    }
  }

  Future<void> _fetchInitialStatus() async {
    try {
      const platform = MethodChannel('com.glasnyl.app/media_control');
      final dynamic result = await platform.invokeMethod('getCurrentStatus');

      if (result != null && mounted) {
        final data = Map<String, dynamic>.from(result);
        final Uint8List? artData = data['albumArt'] as Uint8List?;

        // 🚀 [개선 1] 재귀 호출 대신 가벼운 텍스트 먼저 렌더링
        // 앨범 아트가 없어도 제목/가수 정보는 먼저 띄워야 검은 화면을 탈출합니다.
        setState(() {
          _currentTitle = data['title'] ?? "Ready to Play";
          _currentArtist = (data['artist'] ?? "GLASNYL").toUpperCase();
          _isPlaying = data['isPlaying'] ?? false;

          // 🚀 [수정] 전체 길이 동기화 로직 강화
          if (data['duration'] != null) {
            final int durMs = (data['duration'] as num).toInt();

            if (durMs > 0) {
              _totalDuration = Duration(milliseconds: durMs);
              debugPrint("⏳ 전체 길이 동기화 완료: $_totalDuration");
            } else {
              // ⚠️ 길이가 0이라면 시스템이 아직 정보를 준비 못한 것임
              debugPrint("⚠️ 전체 길이 정보가 0입니다. 1초 후 재시도합니다.");
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) _fetchInitialStatus(); // 1초 뒤 한 번 더 데이터 요청
              });
            }
          }
        });

        // 🚀 [개선 2] 애니메이션 실행 시점을 최적화
        if (_isPlaying) {
          if (!_lpController.isAnimating) _lpController.repeat();
          // value = 1.0; 대신 아래처럼 쓰면 슥~ 내려갑니다.
          _needleController.animateTo(
            1.0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          );
        } else {
          _lpController.stop();
          // 즉시 0.0으로 두지 않고 슥~ 올라가게 합니다.
          _needleController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          );
        }

        // 🚀 [개선 3] 무거운 데이터(이미지 및 색상 추출)는 비동기로 처리
        if (artData != null && artData.isNotEmpty) {
          // 이미지 저장 (이 작업도 setState를 한 번 더 타서 화면을 갱신합니다)
          setState(() {
            _albumArtBytes = artData;
          });

          // 🚀 [개선 4] 색상 추출은 Isolate나 아주 약간의 딜레이를 주어 UI 스레드를 방어
          // 앱이 켜지자마자 계산하면 렉이 걸리므로 300ms 정도 뒤에 여유롭게 수행
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
        } else {
          // 아예 데이터가 없는 경우에만 한 번만 더 시도 (무한 루프 방지)
          // 여기에 재시도 횟수 제한 변수를 두는 것을 추천합니다.
        }
      }
    } catch (e) {
      debugPrint("초기 정보를 가져올 수 없습니다: $e");
    }
    _updateLyrics({'title': _currentTitle, 'artist': _currentArtist});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isFlipCover = size.width > size.height && size.width < 600;

    return OrientationBuilder(
      builder: (context, orientation) {
        final bool isSpecialMode = _isPipMode || isFlipCover;
        final isPortrait = orientation == Orientation.portrait;

        final config = LayoutEngine.calculate(size, orientation, isSpecialMode);

        final bool isLandscape =
            orientation == Orientation.landscape && !_isPipMode;

        // 3. 기존 세로 모드용 계산식
        final double leftPadding = size.width * 0.08;
        final double safeLeftDx = (size.width * 0.85 / 2) + leftPadding;

        // 4. 상황별 좌표 결정
        double finalContentDx;
        if (isSpecialMode) {
          finalContentDx = config.titlePos.dx; // PiP 모드용 좌표 (LayoutEngine 설정값)
        } else if (isPortrait) {
          finalContentDx = safeLeftDx; // 세로 모드 고정 위치
        } else {
          finalContentDx = config.titlePos.dx; // 일반 가로 모드 좌표
        }

        // 5. 상황별 너비 결정
        double finalContentWidth;
        if (isSpecialMode) {
          finalContentWidth = size.width * 0.6; // PiP: 좁은 너비
        } else if (isPortrait) {
          finalContentWidth = size.width * 0.85; // 세로: 넓은 너비
        } else {
          finalContentWidth = config.progressBarWidth; // 가로 모드 전용 너비
        }

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
                if (_albumArtBytes != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          // 🚀 핵심: AnimatedSwitcher의 자식이 전체를 채우도록 설정
                          layoutBuilder:
                              (
                                Widget? currentChild,
                                List<Widget> previousChildren,
                              ) {
                                return Stack(
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                          child: SizedBox.expand(
                            // 🚀 이미지가 화면 전체로 늘어나도록 강제
                            key: ValueKey(
                              '${_currentTitle}_${_albumArtBytes.hashCode}',
                            ),
                            child: Image.memory(
                              _albumArtBytes!,
                              fit: BoxFit.cover, // 이제 이 설정이 화면 전체에 먹힙니다.
                              gaplessPlayback: true,
                              cacheWidth: 300, // 너무 작으면 화질이 깨지니 600 정도로 상향
                              cacheHeight: 600, // 세로형 폰에 맞게 조절
                              filterQuality: FilterQuality.low,
                              opacity: const AlwaysStoppedAnimation(
                                0.8,
                              ), // 0.2보다 훨씬 선명하게
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 블러 레이어 (이 부분은 동일하되, sigma 수치만 확인하세요)
                // 배경을 흐리게 만들고 가독성을 높이는 필터 레이어
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: Stack(
                        children: [
                          // [1] 블러 레이어: 배경 이미지의 색감만 남깁니다.
                          BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 15,
                              sigmaY: 15,
                            ), // 🚀 블러를 살짝 높여 몽환적으로
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              // 배경색을 덮되, 투명도를 조절해 앨범 아트의 생동감을 살립니다.
                              color: _bgColor.withValues(alpha: 0.4),
                            ),
                          ),

                          // [2] 소프트 레이어 (가장 중요): 글래스모피즘의 핵심 '어둠의 계층'
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  // 상단: 상단 바 아이콘들을 위해 아주 살짝만 어둡게
                                  Colors.black.withValues(alpha: 0.2),
                                  // 중간: 앨범 아트의 색이 가장 잘 투영되는 지점
                                  Colors.black.withValues(alpha: 0.1),
                                  // 하단: 🚀 텍스트 가독성을 위해 묵직하게 블랙 그라데이션
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // [1] 메인 콘텐츠 레이어
                Positioned.fill(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // --- LP판 & 앨범 표지 (이 부분만 전환됨) ---
                      // --- LP판 & 앨범 표지 전환 ---
                      // --- LP판 & 앨범 표지 전환부 ---
                      _buildEdit(
                        Offset(
                          (_isMinimalMode || _showLyrics)
                              ? (isPortrait
                                    ? size.width / 2
                                    : size.width * 0.25)
                              : config.lpPos.dx,
                          config.lpPos.dy,
                        ),
                        config.lpSize,
                        config.lpSize,
                        (d) => config.lpPos += d,
                        (s) => config.lpSize = (config.lpSize + s).clamp(
                          150.0,
                          600.0,
                        ),

                        // 외부 파일로 뺀 위젯 호출
                        RepaintBoundary(
                          child: GestureDetector(
                            onLongPress: _handleManualRefresh,
                            child: ValueListenableBuilder<Duration>(
                              valueListenable: _positionNotifier,
                              builder: (context, realTimePos, child) {
                                return ClassicVinylView(
                                  // 1. ValueKey를 제거하거나 고정 키를 사용하세요. (리빌드 최적화)
                                  // key: ValueKey('classic_vinyl'),
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

                                  onToggleMode: () => setState(
                                    () => _isMinimalMode = !_isMinimalMode,
                                  ),

                                  onShowLyrics: () {
                                    // 1. UI 전환을 최우선 실행 (가사창 먼저 보여주기)
                                    setState(() => _showLyrics = true);

                                    // 2. 가사 데이터 및 시간 동기화
                                    Future(() async {
                                      // 가사가 없으면 로딩
                                      if (_lyrics.isEmpty &&
                                          _currentStatus !=
                                              LyricStatus.loading) {
                                        await _updateLyrics({
                                          'title': _currentTitle,
                                          'artist': _currentArtist,
                                        });
                                      }

                                      try {
                                        const platform = MethodChannel(
                                          'com.glasnyl.app/media_control',
                                        );
                                        final dynamic result = await platform
                                            .invokeMethod('getCurrentStatus');

                                        if (result != null &&
                                            result['position'] != null) {
                                          // 🚀 안전한 타입 변환: 어떤 숫자 형태든 대응
                                          final int posMs =
                                              (result['position'] as num)
                                                  .toInt();

                                          // 🚀 즉시 갱신하여 가사 위젯이 현재 위치를 바로 잡게 함
                                          _positionNotifier.value = Duration(
                                            milliseconds: posMs,
                                          );

                                          debugPrint("🎯 동기화 완료: ${posMs}ms");
                                        }
                                      } catch (e) {
                                        debugPrint("⚠️ 시계 동기화 실패: $e");
                                      }
                                    });
                                  },

                                  onCloseLyrics: () =>
                                      setState(() => _showLyrics = false),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // --- 바늘 (LP 모드일 때만 표시) ---
                      if (!_isMinimalMode && !_showLyrics)
                        _buildEdit(
                          config.needlePos,
                          160,
                          config.needleSize * 2.0,
                          (d) => config.needlePos += d,
                          (s) => config.needleSize = (config.needleSize + s)
                              .clamp(100.0, 400.0),
                          // 🚀 최적화 핵심: RepaintBoundary가 바늘의 움직임을 별도 레이어로 분리합니다.
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _needleController,
                              builder: (context, child) {
                                return NeedleWidget(
                                  controller: _needleController,
                                  needleSize: config.needleSize,
                                  bgColor: _bgColor,
                                  accentColor: _playBtnColor,
                                );
                              },
                            ),
                          ),
                        ),

                      // --- 제목 (유지) ---
                      _buildEdit(
                        Offset(finalContentDx, config.titlePos.dy),
                        finalContentWidth,
                        config.titleSize * 1.5,
                        (d) => config.titlePos += d,
                        (s) => config.titleSize = (config.titleSize + s * 0.1)
                            .clamp(20.0, 80.0),
                        // ClipRect로 감싸서 넘치는 텍스트를 물리적으로 차단합니다.
                        ClipRect(
                          child: SizedBox(
                            // finalContentWidth가 0 이하일 경우 에러 방지
                            width: finalContentWidth > 0
                                ? finalContentWidth
                                : 200,
                            child: Align(
                              // 세로: 왼쪽 정렬, 가로: 중앙 정렬
                              alignment: isPortrait
                                  ? Alignment.centerLeft
                                  : Alignment.center,
                              child: MarqueeTitleWidget(
                                key: Key(_currentTitle), // 타이틀 변경 시 위젯 초기화
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

                      // --- 가수 (유지) ---
                      _buildEdit(
                        Offset(finalContentDx, config.artistPos.dy),
                        finalContentWidth,
                        40,
                        (d) => config.artistPos += d,
                        (s) => config.artistSize = (config.artistSize + s * 0.1)
                            .clamp(10.0, 40.0),
                        Align(
                          // 제목과 동일하게 정렬 방향 수정
                          alignment: isPortrait
                              ? Alignment.centerLeft
                              : Alignment.center,
                          child: ArtistTextWidget(
                            artist: _currentArtist,
                            fontSize: config.artistSize,
                            color: _artistColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),

                      // --- 프로그레스 바 (유지 및 에러 해결) ---
                      _buildEdit(
                        config.progressBarPos,
                        config.progressBarWidth,
                        40,
                        (d) => config.progressBarPos += d,
                        (s) => config.progressBarWidth =
                            (config.progressBarWidth + s).clamp(
                              100.0,
                              size.width,
                            ),
                        _buildProgressBarStream(config.progressBarWidth),
                      ),

                      // --- 재생 버튼 (유지) ---
                      // --- 1. 이전 곡 버튼 ---
                      _buildEdit(
                        config
                            .prevButtonPos, // config에 개별 위치 변수가 있다고 가정 (없으면 생성 필요)
                        60, // 버튼 크기에 맞춘 너비
                        60, // 버튼 크기에 맞춘 높이
                        (d) => config.prevButtonPos += d,
                        (s) => {}, // 개별 버튼은 크기 조절 제외하거나 필요시 추가
                        PlayButtonsWidget.buildSideBtn(
                          icon: Icons.skip_previous_rounded,
                          onTap: PlayerLogic.skipPrevious,
                        ),
                      ),

                      // --- 2. 재생/일시정지 버튼 (메인) ---
                      _buildEdit(
                        config.playButtonsPos,
                        90, // 메인 버튼 크기
                        90,
                        (d) => config.playButtonsPos += d,
                        (s) => {},
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

                      // --- 3. 다음 곡 버튼 ---
                      _buildEdit(
                        config.nextButtonPos, // config에 개별 위치 변수가 있다고 가정
                        60,
                        60,
                        (d) => config.nextButtonPos += d,
                        (s) => {},
                        PlayButtonsWidget.buildSideBtn(
                          icon: Icons.skip_next_rounded,
                          onTap: PlayerLogic.skipNext,
                        ),
                      ),
                    ],
                  ),
                ),

                // [2] 상단 앱바 레이어
                if (!_isPipMode)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: RepaintBoundary(
                      child: SafeArea(
                        child: PlayerAppBar(
                          onPassUpdated: () => setState(() {}),
                          isPip: _isPipMode,
                          orientation: orientation,
                          textColor: _textColor,
                          bgColor: _bgColor, // 메뉴 배경색
                          isEditMode: isEditMode,
                          onResetLayout: _handleResetLayout,
                          // 아래 항목들을 추가로 넘겨줘야 내부에서 메뉴가 작동합니다.
                          lpColor: _lpColor,
                          artistColor: _artistColor,
                          barColor: _barColor,
                          playBtnColor: _playBtnColor,
                          onColorChanged: _handleColorChange,
                          onResetColors: _handleAbsoluteColorReset,
                          onEditModeChanged: (v) =>
                              setState(() => isEditMode = v),
                          onLockToggle: () {
                            setState(() {
                              _isScreenLocked = true;
                            });
                          },
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

  // 2. 프로그레스 바 스트림 빌더 (하나만 남기기)
  // 2. 프로그레스 바 스트림 빌더
  Widget _buildProgressBarStream(double barWidth) {
    return SizedBox(
      key: _progressKey,
      width: barWidth,
      child: StreamProgressBar(
        barWidth: barWidth,
        bgColor: _bgColor,
        barColor: _barColor,
        onSeek: (ratio) {
  // 1. 오디오 탐색
  PlayerLogic.seekTo(ratio);

  // 2. duration을 _totalDuration 대신 audioHandler에서 직접 읽기 (null 방지)
  final duration = _totalDuration ?? audioHandler.mediaItem.value?.duration;
  if (duration != null && duration.inMilliseconds > 0) {
    final targetPosition = Duration(
      milliseconds: (duration.inMilliseconds * ratio).toInt(),
    );
    _positionNotifier.value = targetPosition; // setState 불필요, ValueNotifier가 자동 rebuild
    debugPrint("🎯 가사 수동 이동 및 화면 갱신: $targetPosition");
  }
},
      ),
    );
  }

  // --- 위젯 빌더 함수들 ---

  Widget _buildEdit(
    Offset pos,
    double w,
    double h,
    Function(Offset) onDrag,
    Function(double) onResize,
    Widget child,
  ) {
    // 1. Stack의 직계 자식이 되도록 여기서 Positioned를 선언합니다.
    return Positioned(
      // 중앙 좌표 계산 로직을 여기로 가져옵니다.
      left: pos.dx - (w / 2),
      top: pos.dy - (h / 2),
      child: EditableElement(
        isEditMode: isEditMode,
        // 2. [중요] 생성자에서 삭제한 position 파라미터는 더 이상 넣지 않습니다.
        width: w,
        height: h,
        onDrag: (d) => setState(() => onDrag(d)),
        onResizeDelta: (s) => setState(() => onResize(s)),
        child: child,
      ),
    );
  }
}
