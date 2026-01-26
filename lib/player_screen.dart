import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'models/player_config.dart';
import 'utils/layout_engine.dart';
import 'widgets/editable_element.dart';
//import 'widgets/vinyl_component.dart';
import 'widgets/player_app_bar.dart';
import 'menu/menu_main.dart';
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

class VinylPlayerScreen extends StatefulWidget {
  const VinylPlayerScreen({super.key});
  @override
  State<VinylPlayerScreen> createState() => _VinylPlayerScreenState();
}

class _VinylPlayerScreenState extends State<VinylPlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isMinimalMode = false;
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

      _portraitConfig = LayoutEngine.calculate(size, Orientation.portrait);
      _landscapeConfig = LayoutEngine.calculate(size, Orientation.landscape);
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ..addListener(() => setState(() {})) 가 반드시 포함되어야 합니다.
    _lpController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    ); // ..addListener 부분 삭제

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    ); // ..addListener 부분 삭제

    _loadSavedColors();
    _listenToMusic();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
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

        if (artData == null || artData.isEmpty) {
          // 200ms 후에 재시도 (재귀 호출 방지를 위해 딱 한 번만 실행되도록 설계하는 것이 좋음)
          Future.delayed(
            const Duration(milliseconds: 200),
            () => _fetchInitialStatus(),
          );
        }

        // 1. 텍스트 정보 및 재생 상태 즉시 업데이트
        setState(() {
          _currentTitle = data['title'] ?? "Ready to Play";
          // 네이티브에서 넘어온 artist 정보를 대문자로 변환하여 저장
          _currentArtist = (data['artist'] ?? "METEOR PLAYER").toUpperCase();
          _isPlaying = data['isPlaying'] ?? false;

          // 앨범 아트 데이터가 유효한 경우에만 바이트 데이터 저장
          if (artData != null && artData.isNotEmpty) {
            _albumArtBytes = artData;
          }
        });

        // 2. [추가] 첫 곡 색상 추출 로직
        // 이미지가 존재하고 데이터가 충분할 때만 테마 색상을 추출합니다.
        if (artData != null && artData.length > 500) {
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

        // 3. 초기 상태가 재생 중이면 애니메이션 즉시 가동
        if (_isPlaying) {
          if (!_lpController.isAnimating) _lpController.repeat();
          _needleController.forward();
        }
      }
    } catch (e) {
      debugPrint("초기 정보를 가져올 수 없습니다: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final size = MediaQuery.of(context).size;
        final isPortrait = orientation == Orientation.portrait;

        // 1. 레이아웃 설정 로드 및 계산
        if (isPortrait) {
          _portraitConfig ??= LayoutEngine.calculate(size, orientation);
        } else {
          _landscapeConfig ??= LayoutEngine.calculate(size, orientation);
        }

        final config = isPortrait ? _portraitConfig! : _landscapeConfig!;

        // 2. 텍스트 정렬을 위한 위치 계산
        // 세로: 화면 85% 영역의 중앙 / 가로: LayoutEngine에서 정의한 오른쪽 좌표
        final double leftPadding = size.width * 0.08;
        final double safeLeftDx = (size.width * 0.85 / 2) + leftPadding;
        final double finalContentDx = isPortrait
            ? safeLeftDx
            : config.titlePos.dx;
        final double finalContentWidth = isPortrait
            ? size.width * 0.85
            : config.progressBarWidth;

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
                            cacheWidth: 600, // 너무 작으면 화질이 깨지니 600 정도로 상향
                            cacheHeight: 1200, // 세로형 폰에 맞게 조절
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
                            sigmaX: 20,
                            sigmaY: 20,
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
                  child: SafeArea(
                    child: PlayerAppBar(
                      orientation: orientation,
                      textColor: _textColor,
                      isEditMode: isEditMode,
                      onResetLayout: _handleResetLayout,
                      menuButton: PopupMenuButton<String>(
                        color: _bgColor,
                        elevation: 8, // 입체감 복구
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            22,
                          ), // 더 둥글게 디자인 복구
                        ),
                        icon: Icon(
                          Icons.more_vert,
                          color: _textColor,
                          size: 28,
                        ),
                        onSelected: (val) => handleMenuClick(
                          context: context,
                          value: val,
                          isEditMode: isEditMode,
                          onEditModeChanged: (v) =>
                              setState(() => isEditMode = v),
                          bgColor: _bgColor,
                          lpColor: _lpColor,
                          textColor: _textColor,
                          artistColor: _artistColor,
                          barColor: _barColor,
                          playBtnColor: _playBtnColor,
                          onColorChanged: _handleColorChange,
                          onResetColors: _handleAbsoluteColorReset,
                          onResetLayout: _handleResetLayout,
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: "settings",
                            child: _buildMenuItem(
                              Icons.palette_outlined,
                              "Theme Settings",
                            ),
                          ),
                          PopupMenuItem(
                            value: "edit_mode",
                            child: _buildMenuItem(
                              isEditMode
                                  ? Icons.check_circle_rounded
                                  : Icons.dashboard_customize_outlined,
                              isEditMode ? "Finish Layout" : "Edit Layout",
                            ),
                          ),
                          const PopupMenuDivider(height: 1), // 구분선 디자인
                          PopupMenuItem(
                            value: "creator",
                            child: _buildMenuItem(
                              Icons.account_circle_outlined,
                              "Creator Info",
                            ),
                          ),
                          PopupMenuItem(
                            value: "terms",
                            child: _buildMenuItem(
                              Icons.article_outlined,
                              "Terms of Service",
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

  // _buildEdit 함수 아래에 추가하세요
  Widget _buildMenuItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _textColor.withValues(alpha: 0.8), size: 22),
        const SizedBox(width: 14), // 아이콘과 글자 사이 간격 복구
        Text(
          label,
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
