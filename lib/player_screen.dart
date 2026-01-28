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
//import 'main.dart';
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

class VinylPlayerScreen extends StatefulWidget {
  const VinylPlayerScreen({super.key});
  @override
  State<VinylPlayerScreen> createState() => _VinylPlayerScreenState();
}

class _VinylPlayerScreenState extends State<VinylPlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isMinimalMode = false;
  bool _isPipMode = false;

  bool _isScreenLocked = false;
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

  // 클래스 상단 변수 선언부
  final GlobalKey _progressKey = GlobalKey();
  //final GlobalKey _titleKey = GlobalKey();

  late AnimationController _lpController, _needleController;
  bool isEditMode = false, _isPlaying = false;
  PlayerConfig? _portraitConfig, _landscapeConfig;

  String _currentTitle = "Ready to Play";
  String _currentArtist = "METEOR PLAYER";
  Uint8List? _albumArtBytes;

  // 기본 테마 색상 설정
  Color _bgColor = const Color(0xFFE1E0E5);
  Color _lpColor = const Color(0xFF2A292E);
  Color _textColor = const Color(0xFF333335);
  Color _artistColor = const Color(0xFF8F7AB3);
  Color _barColor = const Color(0xFFB1A1D0);
  Color _playBtnColor = const Color(0xFF735DA5);

  static const _pipChannel = MethodChannel('com.meteor.player/pip_status');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == "onPipModeChanged") {
        bool isInPip = call.arguments;
        if (mounted) {
          setState(() {
            _isPipMode = isInPip;
            // PiP 모드 진입 시 편집 모드는 자동으로 끔
            if (isInPip) isEditMode = false;
          });
        }
      }
    });

    // 1. 애니메이션 컨트롤러 초기화 (addListener는 계속 삭제된 상태 유지)
    _lpController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

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
  }

  @override
  void dispose() {
    // 🚀 관찰자를 반드시 해제해야 메모리 누수가 없습니다.
    WidgetsBinding.instance.removeObserver(this);
    _lpController.dispose();
    _needleController.dispose();
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
        if (_currentTitle == event.title &&
            _currentArtist != "UNKNOWN" &&
            _currentArtist != "Unknown") {
          return;
        }

        //Uint8List? art = event.largeIcon ?? event.appIcon;

        if (!mounted) return;

        // 1. [즉시 업데이트] 이미지와 텍스트부터 먼저 바꿉니다 (callback 제거)
        setState(() {
          _currentTitle = event.title!;
          _currentArtist = (event.content ?? "Unknown").toUpperCase();
          /*if (art != null) {
            _albumArtBytes = art;
          }*/
          _isPlaying = true;
        });

        await _fetchInitialStatus();

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
      'com.meteor.player/media_status',
    ).receiveBroadcastStream().listen((status) {
      _handleMediaStatusUpdate(status);
    });
  }

  // 미디어 상태 업데이트 로직도 별도 함수로 빼면 더 깨끗합니다.
  void _handleMediaStatusUpdate(dynamic data) {
    if (data == null || !mounted) return;

    bool incomingPlayingState = _isPlaying;

    try {
      if (data is Map) {
        incomingPlayingState = data['isPlaying'] ?? _isPlaying;
      } else if (data is String) {
        incomingPlayingState = (data == 'playing');
      } else if (data is bool) {
        incomingPlayingState = data;
      }
    } catch (e) {
      debugPrint("Media status parsing error: $e");
    }

    // 🚀 [핵심 수정]
    // 다른 앱에서 멈췄을 때(false가 들어왔을 때) 확실히 멈추도록 강제 제어합니다.
    if (_isPlaying != incomingPlayingState) {
      setState(() {
        _isPlaying = incomingPlayingState;
      });

      if (_isPlaying) {
        // 재생 상태로 변함 -> 바늘 내리고 LP 돌리기
        if (!_lpController.isAnimating) {
          _lpController.repeat();
        }
        _needleController.forward();
        HapticFeedback.lightImpact();
      } else {
        // 정지 상태로 변함 -> 바늘 올리고 LP 멈추기
        _needleController.reverse();

        // 바늘이 올라가는 애니메이션 시간(약 200~300ms) 동안은 LP가 돌다가 멈추는 게 자연스러움
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isPlaying) {
            _lpController.stop(); // 👈 여기서 확실히 멈춤
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
      const platform = MethodChannel('com.meteor.player/media_control');
      final dynamic result = await platform.invokeMethod('getCurrentStatus');

      if (result != null && mounted) {
        final data = Map<String, dynamic>.from(result);
        final Uint8List? artData = data['albumArt'] as Uint8List?;

        // 🚀 [개선 1] 재귀 호출 대신 가벼운 텍스트 먼저 렌더링
        // 앨범 아트가 없어도 제목/가수 정보는 먼저 띄워야 검은 화면을 탈출합니다.
        setState(() {
          _currentTitle = data['title'] ?? "Ready to Play";
          _currentArtist = (data['artist'] ?? "METEOR PLAYER").toUpperCase();
          _isPlaying = data['isPlaying'] ?? false;
        });

        // 🚀 [개선 2] 애니메이션 실행 시점을 최적화
        if (_isPlaying) {
          // 즉시 실행하되 UI가 끊기지 않도록 컨트롤
          if (!_lpController.isAnimating) _lpController.repeat();
          _needleController.forward();
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
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isFlipCover = size.height < 500 && size.width > size.height;

    return OrientationBuilder(
      builder: (context, orientation) {
        final bool isSpecialMode = _isPipMode || isFlipCover;
        final isPortrait = orientation == Orientation.portrait;

        final config = LayoutEngine.calculate(size, orientation, isSpecialMode);

        final bool isLandscape = orientation == Orientation.landscape && !_isPipMode;

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
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            color: _bgColor,
            child: Stack(
              children: [
                if (_albumArtBytes != null)
                  Positioned.fill(
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

                // 블러 레이어 (이 부분은 동일하되, sigma 수치만 확인하세요)
                // 배경을 흐리게 만들고 가독성을 높이는 필터 레이어
                Positioned.fill(
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
                          _isMinimalMode
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
                          child: ClassicVinylView(
                            isMinimalMode: _isMinimalMode,
                            size: config.lpSize,
                            albumArtBytes: _albumArtBytes,
                            title: _currentTitle,
                            artist: _currentArtist,
                            lpController: _lpController,
                            onToggleMode: () => setState(
                              () => _isMinimalMode = !_isMinimalMode,
                            ),
                          ),
                        ),
                      ),

                      // --- 바늘 (LP 모드일 때만 표시) ---
                      if (!_isMinimalMode)
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
                      _buildEdit(
                        config.playButtonsPos,
                        config.playButtonsWidth,
                        100,
                        (d) => config.playButtonsPos += d,
                        (s) => config.playButtonsWidth =
                            (config.playButtonsWidth + s).clamp(200.0, 500.0),
                        PlayButtonsWidget(
                          isPlaying: _isPlaying,
                          onTogglePlay: () {
                            // 1. Logic 클래스를 통해 네이티브에 재생/일시정지 명령 전달
                            PlayerLogic.togglePlay(
                              isPlaying: _isPlaying,
                              onToggle: () {
                                // 2. 네이티브 명령이 성공적으로 전달되면 UI와 애니메이션을 즉시 업데이트
                                if (mounted) {
                                  setState(() {
                                    _isPlaying = !_isPlaying; // 현재 상태 반전

                                    if (_isPlaying) {
                                      // 재생 시작 시: LP 무한 회전, 바늘 내리기
                                      _lpController.repeat();
                                      _needleController.forward();
                                    } else {
                                      // 정지 시: LP 정지, 바늘 올리기
                                      _lpController.stop();
                                      _needleController.reverse();
                                    }
                                  });
                                }
                              },
                            );
                          },
                          onNext: PlayerLogic.skipNext,
                          onPrevious: PlayerLogic.skipPrevious,
                          width: config.playButtonsWidth,
                          bgColor: _bgColor,
                          textColor: _textColor,
                          activeColor: _barColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // [2] 상단 앱바 레이어
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: RepaintBoundary(
                    child: SafeArea(
                      child: PlayerAppBar(
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
      // 🚀 핵심: 복잡한 StreamBuilder 로직은 이제 StreamProgressBar 파일 안에 들어있습니다.
      child: StreamProgressBar(
        barWidth: barWidth,
        bgColor: _bgColor,
        barColor: _barColor,
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
