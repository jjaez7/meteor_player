import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'models/player_config.dart';
import 'utils/layout_engine.dart';
import 'widgets/editable_element.dart';
import 'widgets/vinyl_component.dart';
import 'widgets/player_app_bar.dart';
import 'menu/menu_main.dart';
import 'color_manager.dart';
import 'main.dart';
import 'widgets/player_elements.dart';
import 'widgets/player_text_info.dart';
import 'widgets/needle_component.dart';
import 'logic/music_controller.dart';
import 'logic/player_logic.dart';
import 'widgets/surreal_player_view.dart';
import 'widgets/classic_vinyl_view.dart';

class VinylPlayerScreen extends StatefulWidget {
  const VinylPlayerScreen({super.key});
  @override
  State<VinylPlayerScreen> createState() => _VinylPlayerScreenState();
}

class _VinylPlayerScreenState extends State<VinylPlayerScreen>
    with TickerProviderStateMixin {
  bool _isMinimalMode = false;
  bool _isSurrealMode = false;
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
  final GlobalKey _titleKey = GlobalKey();

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
  @override
  void initState() {
    super.initState();

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
      _fetchInitialStatus();
    });
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
      // 🚀 [수정] 제목이 같더라도 아티스트가 'UNKNOWN'인 상태라면 업데이트를 허용합니다.
      // 이렇게 해야 앱 시작 시 누락되었던 정보를 다시 받아올 수 있습니다.
      if (_currentTitle == event.title && _currentArtist != "UNKNOWN") {
        return;
      }

      Uint8List? art = event.largeIcon ?? event.appIcon;
      Map<String, Color>? colors;
      if (art != null) {
        colors = await MusicColorLogic.extractThemeColors(art);
      }

      if (!mounted) return;

      setState(() {
        _currentTitle = event.title!;
        // 🚀 [수정] content가 없을 경우 "Unknown"을 명시적으로 넣어줍니다.
        _currentArtist = (event.content ?? "Unknown").toUpperCase();
        if (art != null) _albumArtBytes = art;
        _isPlaying = true; 

        if (colors != null) {
          _bgColor = colors['bg']!;
          _playBtnColor = colors['btn']!;
          _barColor = colors['bar']!;
          _textColor = colors['text']!;
          _artistColor = colors['artist']!;
        }
      });

      _lpController.repeat(); 
      _needleController.forward();
    }
  });

  const EventChannel('com.meteor.player/media_status')
      .receiveBroadcastStream()
      .listen((status) {
    _handleMediaStatusUpdate(status);
  });
}

  // 미디어 상태 업데이트 로직도 별도 함수로 빼면 더 깨끗합니다.
void _handleMediaStatusUpdate(dynamic data) {
  if (data == null || !mounted) return;

  bool isPlayingNow = false;

  try {
    if (data is Map) {
      isPlayingNow = data['isPlaying'] ?? false;
    } else if (data is String) {
      isPlayingNow = (data == 'playing');
    } else if (data is bool) {
      isPlayingNow = data;
    }
  } catch (e) {
    debugPrint("Media status parsing error: $e");
  }

  // 🚀 [핵심 수정] 현재 앱 상태와 들어온 상태가 다를 때만 실행
  // 이 조건이 있어야 다음 곡으로 넘길 때 발생하는 '잠깐의 멈춤 신호'를 무시합니다.
  if (_isPlaying != isPlayingNow) {
    setState(() {
      _isPlaying = isPlayingNow;
    });

    if (_isPlaying) {
      // [재생 상태]
      _lpController.repeat();
      _needleController.forward();
      HapticFeedback.lightImpact();
    } else {
      // [정지 상태]
      _needleController.reverse();
      
      Future.delayed(const Duration(milliseconds: 300), () {
        // 지연 시간 후에도 여전히 정지 상태일 때만 LP를 멈춤
        if (mounted && !_isPlaying) {
          _lpController.stop();
        }
      });
      HapticFeedback.mediumImpact();
    }
  }
}

  Future<void> _fetchInitialStatus() async {
    try {
      const platform = MethodChannel('com.meteor.player/media_control');
      final dynamic result = await platform.invokeMethod('getCurrentStatus');

      if (result != null && mounted) {
        final data = Map<String, dynamic>.from(result);
        setState(() {
          _currentTitle = data['title'] ?? "Ready to Play";
          _currentArtist = (data['artist'] ?? "METEOR PLAYER").toUpperCase();
          _isPlaying = data['isPlaying'] ?? false;
          if (data['albumArt'] != null)
            _albumArtBytes = data['albumArt'] as Uint8List;
        });

        // 초기 상태가 재생 중이면 즉시 애니메이션 시작
        if (_isPlaying) {
          _lpController.repeat();
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
                    child: AnimatedOpacity(
                      duration: const Duration(seconds: 1),
                      opacity: 0.2, // 배경색에 따라 0.1 ~ 0.3 사이 조절
                      child: Image.memory(
                        _albumArtBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true, // 이미지 교체 시 깜빡임 방지
                        // 🚀 화질 개선 핵심 설정
                        filterQuality: _isMinimalMode
                            ? FilterQuality.high
                            : FilterQuality.low,
                        isAntiAlias: true,
                        // LP 모드일 땐 작게 캐싱해서 메모리를 아끼고, 앨범 모드일 땐 원본 화질 유지
                        cacheWidth: _isMinimalMode ? null : 400,
                        cacheHeight: _isMinimalMode ? null : 400,
                      ),
                    ),
                  ),
                // 배경을 흐리게 만드는 필터
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ColorFilter.mode(
                      _bgColor.withOpacity(0.5),
                      BlendMode.srcOver,
                    ),
                    child: Container(color: Colors.transparent),
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
                        ClassicVinylView(
                          isMinimalMode: _isMinimalMode,
                          size: config.lpSize,
                          albumArtBytes: _albumArtBytes,
                          title: _currentTitle,
                          artist: _currentArtist,
                          lpController: _lpController,
                          onToggleMode: () =>
                              setState(() => _isMinimalMode = !_isMinimalMode),
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
                          NeedleWidget(
                            controller: _needleController,
                            needleSize: config.needleSize,
                            bgColor: _bgColor,
                            accentColor: _playBtnColor,
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
  Widget _buildProgressBarStream(double barWidth) {
    return SizedBox(
      key: _progressKey,
      width: barWidth,
      child: StreamBuilder(
        stream: const EventChannel(
          'com.meteor.player/media_status',
        ).receiveBroadcastStream(),
        builder: (context, snapshot) {
          double factor = 0.0;
          if (snapshot.hasData && snapshot.data != null) {
            try {
              final data = Map<String, dynamic>.from(snapshot.data);
              final int pos = data['position'] ?? 0;
              final int dur = data['duration'] ?? 1;
              factor = (pos / dur).clamp(0.0, 1.0);
            } catch (e) {}
          }

          return ProgressBarWidget(
            width: barWidth,
            factor: factor,
            bgColor: _bgColor,
            barColor: _barColor,
            onSeek: PlayerLogic.seekTo, // 외부 로직 연결
          );
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
