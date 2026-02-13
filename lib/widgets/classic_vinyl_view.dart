import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_design/services/lyrics_service.dart';
import 'vinyl_component.dart';
import 'dart:ui';
import '../models/lyric_model.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
//import '../models/lyric_model.dart'; // LyricLine 모델 경로 확인

class ClassicVinylView extends StatelessWidget {
  final bool isMinimalMode;
  final bool isLyricsMode;
  final double size;
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;
  final AnimationController lpController;
  final bool isPlaying;
  final VoidCallback onToggleMode;
  final VoidCallback onShowLyrics;
  final VoidCallback onCloseLyrics;

  final List<dynamic> lyrics;
  final Duration currentPosition;

  final LyricStatus lyricStatus;

  const ClassicVinylView({
    super.key,
    required this.isMinimalMode,
    required this.isLyricsMode,
    required this.size,
    this.albumArtBytes,
    required this.title,
    required this.artist,
    required this.lpController,
    required this.onToggleMode,
    required this.onShowLyrics,
    required this.onCloseLyrics,
    required this.isPlaying,
    required this.lyrics,
    required this.currentPosition,
    required this.lyricStatus,
  });

  @override
  Widget build(BuildContext context) {

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: isLyricsMode
          ? _buildLyricsCard()
          : (isMinimalMode ? _buildMinimalArt() : _buildVinylDisk()),
    );
  }

  Widget _buildVinylDisk() {
    return GestureDetector(
      key: const ValueKey('vinyl_disk'),
      onTap: onShowLyrics,
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        onToggleMode();
      },
      child: RepaintBoundary(
        child: RotationTransition(
          turns: lpController,
          child: VinylDisk(
            controller: lpController,
            size: size,
            albumArtBytes: albumArtBytes,
            title: title,
            artist: artist,
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalArt() {
    final double responsiveRadius = size * 0.12;

    return GestureDetector(
      key: const ValueKey('minimal_art'),
      onTap: onShowLyrics,
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        onToggleMode();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(responsiveRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(responsiveRadius),
          child: albumArtBytes != null
              ? Image.memory(
                  albumArtBytes!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: (size * 2).toInt(),
                  cacheHeight: (size * 2).toInt(),
                  gaplessPlayback: true,
                  isAntiAlias: false,
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.music_note, size: 100),
                ),
        ),
      ),
    );
  }

  // --- 🚀 자동 스크롤 기능이 포함된 가사 카드 빌더 ---
  Widget _buildLyricsCard() {
    return Center(
      // 부모 레이아웃 안에서 중앙을 잡습니다.
      key: const ValueKey('lyrics_card'),
      child: SizedBox(
        width: size, // 미니멀 모드와 동일한 너비
        height: size, // 미니멀 모드와 동일한 높이
        child: _LyricsAutoScroller(
          key: ValueKey(title),
          lyrics: lyrics,
          currentPosition: currentPosition,
          size: size,
          onClose: onCloseLyrics,
          lyricStatus: lyricStatus,
          isPlaying: isPlaying,
        ),
      ),
    );
  }
}

// 🚀 내부에서만 사용하는 가사 스크롤 전용 위젯 (성능 최적화용)
class _LyricsAutoScroller extends StatefulWidget {
  final List<dynamic> lyrics;
  final Duration currentPosition;
  final double size;
  final VoidCallback onClose;
  final LyricStatus lyricStatus;
final bool isPlaying;

  const _LyricsAutoScroller({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    required this.size,
    required this.onClose,
    required this.lyricStatus,
    required this.isPlaying,
  });

  @override
  State<_LyricsAutoScroller> createState() => _LyricsAutoScrollerState();
}

class _LyricsAutoScrollerState extends State<_LyricsAutoScroller> 
    with SingleTickerProviderStateMixin {
  late FixedExtentScrollController _scrollController;
  int _lastIndex = -1;
  bool _isUserInteracting = false;
  Timer? _debounceTimer;

  late Ticker _ticker;
  Duration _internalOffset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _lastIndex = _calculateCurrentIndex();
    _scrollController = FixedExtentScrollController(
      initialItem: _lastIndex >= 0 ? _lastIndex : 0,
    );

    _ticker = createTicker((elapsed) {
      if (mounted) {
        setState(() {
          _internalOffset = elapsed; 
        });
        // 🚀 Ticker에서 매 프레임 감시하므로 '뒷북' 스크롤이 사라집니다.
        _checkAndScroll();
      }
    });
    
    if (widget.isPlaying) _ticker.start();
  }

  void _checkAndScroll() {
    if (_isUserInteracting || !_scrollController.hasClients) return;

    int currentIndex = _calculateCurrentIndex();
    if (currentIndex != _lastIndex && currentIndex >= 0) {
      _lastIndex = currentIndex;
      
      // 🚀 반응 속도 최적화: 400ms, easeOutCubic
      _scrollController.animateToItem(
        currentIndex,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
      );
    }
  }

  // _LyricsAutoScrollerState 클래스 내부
void _forceResetInteraction() {
  _debounceTimer?.cancel(); // 3초 타이머 취소
  if (_isUserInteracting) {
    setState(() {
      _isUserInteracting = false; // 즉시 자동 스크롤 모드로 복귀
    });
  }
}

// classic_vinyl_view.dart 내부 _LyricsAutoScrollerState 클래스 수정

// classic_vinyl_view.dart 내의 _LyricsAutoScrollerState 클래스 수정
// classic_vinyl_view.dart 내 _LyricsAutoScrollerState 클래스 수정

@override
void didUpdateWidget(covariant _LyricsAutoScroller oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  // 1. 재생 상태 변경 처리 (기존 유지)
  if (widget.isPlaying != oldWidget.isPlaying) {
    if (widget.isPlaying) {
      if (!_ticker.isTicking) _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  // 🚀 2. 핵심: 외부/내부 어디서든 시간이 바뀌었을 때 감지
  if (widget.currentPosition != oldWidget.currentPosition) {
    
    // [판단 기준] 
    // - 시간이 거꾸로 갔을 때 (이전 곡/처음으로)
    // - 시간 차이가 1.5초 이상 크게 났을 때 (시스템 진행바 조작)
    // - 현재 시간이 거의 0초일 때
    bool isExternalSeek = 
        widget.currentPosition < oldWidget.currentPosition || 
        (widget.currentPosition - oldWidget.currentPosition).abs().inMilliseconds > 1500 ||
        widget.currentPosition.inMilliseconds < 200;

    if (isExternalSeek) {
      // 💡 여기서 핵심! 외부에서 조작해도 3초 대기를 풀어야 합니다.
      _debounceTimer?.cancel();
      
      // setState를 직접 부르지 않아도 didUpdateWidget은 이미 리빌드 중이므로 
      // 변수 값만 즉시 바꿔주면 됩니다.
      _isUserInteracting = false; 

      // Ticker 보정값 리셋
      if (_ticker.isTicking) {
        _ticker.stop();
        _ticker.start();
      }
      _internalOffset = Duration.zero;
      
      int newIndex = _calculateCurrentIndex();
      _lastIndex = newIndex;

      // 즉시 스크롤 이동
      if (_scrollController.hasClients) {
        _scrollController.jumpToItem(newIndex >= 0 ? newIndex : 0);
      }
      
      debugPrint("📢 외부/내부 시스템 조작 감지: 가사 동기화 및 고정 해제");
    }
  }

  // 3. 곡 변경 시 처리 (기존 유지)
  if (widget.lyrics != oldWidget.lyrics) {
    _lastIndex = -1;
    _internalOffset = Duration.zero;
    if (_scrollController.hasClients) _scrollController.jumpToItem(0);
  }
}

  int _calculateCurrentIndex() {
    if (widget.lyrics.isEmpty) return -1;

    // 🚀 보정값을 150ms -> 300ms로 높여서 '미리' 준비하게 합니다.
    // 음악 재생 라이브러리의 딜레이에 따라 이 값을 200~400 사이로 조절해 보세요.
    final int currentMs = widget.currentPosition.inMilliseconds + 
                          _internalOffset.inMilliseconds + 400; 
    
    int foundIndex = 0;
    for (int i = 0; i < widget.lyrics.length; i++) {
      final item = widget.lyrics[i];
      if (item is! LyricLine) continue;

      if (item.time.inMilliseconds <= currentMs) {
        foundIndex = i;
      } else {
        break; 
      }
    }
    return foundIndex;
  }

  void _onUserInteraction() {
    if (_isUserInteracting) {
      _debounceTimer?.cancel(); // 이미 조작 중이면 타이머만 리셋
    } else {
      setState(() => _isUserInteracting = true);
    }
    
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isUserInteracting = false);
        _lastIndex = -1; // 복귀 시 즉시 다시 그리도록 초기화
        _checkAndScroll();
      }
    });
  }


  @override
  void dispose() {
    _ticker.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentIndex() {
    int currentIndex = _calculateCurrentIndex();
    if (currentIndex >= 0 && _scrollController.hasClients && !_isUserInteracting) {
      _scrollController.animateToItem(
        currentIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // 상태 메시지 헬퍼 (기존 유지)
  String _getStatusMessage(LyricStatus status) {
    switch (status) {
      case LyricStatus.noLyrics:
        return "No lyrics found for this track";
      case LyricStatus.networkError:
        return "Network connection unstable\nPlease check your Wi-Fi";
      case LyricStatus.timeout:
        return "Connection timed out\nPlease try again";
      case LyricStatus.loading:
        return "Fetching lyrics...";
      default:
        return "Unable to load lyrics";
    }
  }

  IconData _getStatusIcon(LyricStatus status) {
    switch (status) {
      case LyricStatus.noLyrics:
        return Icons.search_off_rounded;
      case LyricStatus.networkError:
        return Icons.wifi_off_rounded;
      case LyricStatus.timeout:
        return Icons.timer_off_outlined;
      case LyricStatus.loading:
        return Icons.sync;
      default:
        return Icons.error_outline_rounded;
    }
  }

@override
  Widget build(BuildContext context) {
    int currentIndex = _calculateCurrentIndex();
    final double responsiveRadius = widget.size * 0.12;

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(responsiveRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 50,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(responsiveRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: widget.lyrics.isEmpty
                        ? _buildEmptyContent() // 가사 없을 때 화면 (하단에 정의)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final double width = constraints.maxWidth;
                              final double responsiveBaseSize = (width * 0.05).clamp(16.0, 20.0);
                              final double responsiveCurrentSize = (width * 0.065).clamp(20.0, 28.0);

                              // 🚀 중요: NotificationListener를 추가해야 스크롤 상태를 감지합니다.
                              return NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification is ScrollStartNotification) {
                                    _onUserInteraction(); // 사용자가 만지면 자동 스크롤 일시 정지
                                  }
                                  return false;
                                },
                                child: ListWheelScrollView.useDelegate(
                                  controller: _scrollController,
                                  itemExtent: responsiveCurrentSize * 5.0,
                                  physics: const FixedExtentScrollPhysics(),
                                  clipBehavior: Clip.hardEdge,
                                  diameterRatio: 2.0,
                                  perspective: 0.002,
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: widget.lyrics.length,
                                    builder: (context, index) {
                                      final isCurrent = index == currentIndex;
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 30),
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 300),
                                            style: TextStyle(
                                              color: isCurrent
                                                  ? Colors.white
                                                  : Colors.white.withValues(alpha: 0.25),
                                              fontSize: isCurrent
                                                  ? responsiveCurrentSize
                                                  : responsiveBaseSize,
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              height: 1.3,
                                              letterSpacing: -0.5,
                                            ),
                                            child: Text(
                                              widget.lyrics[index].text,
                                              textAlign: TextAlign.center,
                                              softWrap: true,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // 하단 출처 표기 (생략 가능)
                  if (widget.lyrics.isNotEmpty)
                    _buildSourceTag(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 가사 없을 때 화면 별도 추출
  Widget _buildEmptyContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.lyricStatus == LyricStatus.loading
              ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
              : Icon(_getStatusIcon(widget.lyricStatus), color: Colors.white.withValues(alpha: 0.4), size: 40),
          const SizedBox(height: 12),
          Text(_getStatusMessage(widget.lyricStatus), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSourceTag() {
    return Positioned(bottom: 8, left: 0, right: 0, child: Text("Lyrics provided by LRCLIB", textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9, letterSpacing: 0.5, fontWeight: FontWeight.w300)));
  }
}
