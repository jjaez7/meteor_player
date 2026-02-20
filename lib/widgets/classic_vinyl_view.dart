import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glasnyl/services/lyrics_service.dart';
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
  late Ticker _ticker;
  
  int _lastIndex = -1;
  bool _isUserInteracting = false;
  Timer? _debounceTimer;

  // 🚀 핵심: 마지막으로 성공적으로 업데이트된 인덱스를 저장하여 역행을 물리적으로 차단
  int _maxIndexReached = -1;

  // 고정밀 동기화 변수
  Duration _basePosition = Duration.zero; 
  Duration _elapsedSinceSync = Duration.zero;

  @override
  void initState() {
    super.initState();
    _basePosition = widget.currentPosition;
    _lastIndex = _calculateCurrentIndex(_basePosition);
    _maxIndexReached = _lastIndex;
    _scrollController = FixedExtentScrollController(
      initialItem: _lastIndex >= 0 ? _lastIndex : 0,
    );

    _ticker = createTicker((elapsed) {
      if (!mounted || !widget.isPlaying || _isUserInteracting) return;

      setState(() {
        _elapsedSinceSync = elapsed; 
      });
      _checkAndScroll();
    });
    
    if (widget.isPlaying) _ticker.start();
  }

  void _checkAndScroll() {
    if (_isUserInteracting || !_scrollController.hasClients) return;

    // 🚀 선행 보정: 소리보다 300ms 먼저 가사를 준비 (체감 성능 향상)
    final precisePos = _basePosition + _elapsedSinceSync + const Duration(milliseconds: 300);
    int currentIndex = _calculateCurrentIndex(precisePos);
    
    if (currentIndex != -1 && currentIndex != _lastIndex) {
      // 🚀 [해결책] 위로 튀기 방지 로직
      // 현재 계산된 인덱스가 지금까지 도달한 최대 인덱스보다 클 때만 전진합니다.
      // 이렇게 하면 시스템의 느린 신호 때문에 시간이 '뒤로' 가도 스크롤은 버팁니다.
      if (currentIndex > _maxIndexReached) {
        _maxIndexReached = currentIndex;
        _lastIndex = currentIndex;
        
        _scrollController.animateToItem(
          currentIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutQuart,
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant _LyricsAutoScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 1. 재생 상태 변경
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _basePosition = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
        if (!_ticker.isTicking) _ticker.start();
      } else {
        _ticker.stop();
      }
    }

    // 2. 🚀 시스템 신호와의 정밀 동기화 (Drift Detection)
    if (widget.currentPosition != oldWidget.currentPosition) {
      final estimatedNow = _basePosition + _elapsedSinceSync;
      final drift = (widget.currentPosition - estimatedNow).abs();

      // [판단] 사용자가 진행바를 옮겼거나(Seek), 곡이 바뀌었을 때만 강제 재동기화
      // 1.2초 미만의 미세한 오차는 시스템 신호가 '느린 것'이므로 무시하여 튀는 현상 방지
      bool isSeek = (widget.currentPosition - oldWidget.currentPosition).abs().inMilliseconds > 1200 ||
                    widget.currentPosition < oldWidget.currentPosition;

      if (isSeek || drift > const Duration(milliseconds: 1500)) {
        _basePosition = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
        
        if (_ticker.isTicking) {
          _ticker.stop();
          _ticker.start();
        }
        
        int newIndex = _calculateCurrentIndex(widget.currentPosition);
        _lastIndex = newIndex;
        _maxIndexReached = newIndex; // 최대 도달 지점 리셋 (Seek 대응)

        if (_scrollController.hasClients) {
          _scrollController.jumpToItem(newIndex >= 0 ? newIndex : 0);
        }
      }
    }

    // 3. 새 노래 시작 시
    if (widget.lyrics != oldWidget.lyrics) {
      _basePosition = widget.currentPosition;
      _elapsedSinceSync = Duration.zero;
      _lastIndex = -1;
      _maxIndexReached = -1;
      if (_scrollController.hasClients) _scrollController.jumpToItem(0);
    }
  }

  int _calculateCurrentIndex(Duration pos) {
    if (widget.lyrics.isEmpty) return -1;
    int foundIndex = 0;
    for (int i = 0; i < widget.lyrics.length; i++) {
      final item = widget.lyrics[i];
      if (item is! LyricLine) continue;
      if (item.time <= pos) {
        foundIndex = i;
      } else {
        break; 
      }
    }
    return foundIndex;
  }

  void _onUserInteraction() {
    if (_isUserInteracting) {
      _debounceTimer?.cancel();
    } else {
      setState(() => _isUserInteracting = true);
    }
    
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isUserInteracting = false);
        // 조작 종료 후 현재 시점으로 리싱크
        _basePosition = widget.currentPosition;
        _elapsedSinceSync = Duration.zero;
        _maxIndexReached = _calculateCurrentIndex(_basePosition);
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
  int currentIndex = _lastIndex;
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
        child: Stack(
          children: [
            // 🚀 레이어 1: 배경 블러 및 그라데이션 (RepaintBoundary로 격리)
            // 가사가 움직여도 이 무거운 블러 연산은 다시 수행되지 않습니다.
            Positioned.fill(
              child: RepaintBoundary(
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
                  ),
                ),
              ),
            ),

            // 🚀 레이어 2: 가사 리스트 (RepaintBoundary로 격리)
            // 가사가 스크롤될 때 "가사 레이어"만 다시 그리도록 제한합니다.
            Positioned.fill(
              child: RepaintBoundary(
                child: widget.lyrics.isEmpty
                    ? _buildEmptyContent()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final double width = constraints.maxWidth;
                          final double responsiveBaseSize =
                              (width * 0.05).clamp(16.0, 20.0);
                          final double responsiveCurrentSize =
                              (width * 0.065).clamp(20.0, 28.0);

                          return NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification) {
                                _onUserInteraction();
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30),
                                      child: AnimatedDefaultTextStyle(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        style: TextStyle(
                                          color: isCurrent
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.25),
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
            ),

            // 레이어 3: 하단 출처 표기 (텍스트 위젯)
            if (widget.lyrics.isNotEmpty) _buildSourceTag(),
          ],
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
