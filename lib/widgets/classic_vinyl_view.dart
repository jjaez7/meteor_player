import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_design/services/lyrics_service.dart';
import 'vinyl_component.dart';
import 'dart:ui';
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
    if (isPlaying) {
      if (!lpController.isAnimating) lpController.repeat();
    } else {
      lpController.stop();
    }

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
    return Center( // 부모 레이아웃 안에서 중앙을 잡습니다.
      key: const ValueKey('lyrics_card'),
      child: SizedBox(
        width: size,  // 미니멀 모드와 동일한 너비
        height: size, // 미니멀 모드와 동일한 높이
        child: _LyricsAutoScroller(
          lyrics: lyrics,
          currentPosition: currentPosition,
          size: size,
          onClose: onCloseLyrics,
          lyricStatus: lyricStatus,
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

  const _LyricsAutoScroller({
    required this.lyrics,
    required this.currentPosition,
    required this.size,
    required this.onClose,
    required this.lyricStatus,
  });

  @override
  State<_LyricsAutoScroller> createState() => _LyricsAutoScrollerState();
}

class _LyricsAutoScrollerState extends State<_LyricsAutoScroller> {
  late FixedExtentScrollController _scrollController;
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
    final double responsiveRadius = widget.size * 0.12;

    // 현재 인덱스 계산
    int currentIndex = widget.lyrics.indexWhere((line) => line.time > widget.currentPosition) - 1;
    if (currentIndex < 0 && widget.lyrics.isNotEmpty && widget.currentPosition >= widget.lyrics.last.time) {
      currentIndex = widget.lyrics.length - 1;
    }

    // 인덱스 변경 시 자동 스크롤 실행
    if (currentIndex != _lastIndex && currentIndex >= 0) {
      _lastIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateToItem(
            currentIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }

   return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(responsiveRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 25,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(responsiveRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              // 🚀 Stack을 사용하여 가사와 출처 표기를 겹칩니다.
              child: Stack(
                children: [
                  // 1. 메인 가사 영역
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: widget.lyrics.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(widget.lyricStatus),
                                    color: Colors.white.withValues(alpha: 0.4),
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _getStatusMessage(widget.lyricStatus),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListWheelScrollView.useDelegate(
                              controller: _scrollController,
                              itemExtent: 45,
                              physics: const FixedExtentScrollPhysics(),
                              diameterRatio: 1.2,
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: widget.lyrics.length,
                                builder: (context, index) {
                                  final isCurrent = index == currentIndex;
                                  return Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 300),
                                      style: TextStyle(
                                        color: isCurrent
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.3),
                                        fontSize: isCurrent ? 18 : 14,
                                        fontWeight: isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      child: Text(
                                        widget.lyrics[index].text,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ),

                  // 2. 🚀 하단 출처 표기 (가사가 있을 때만 노출)
                  if (widget.lyrics.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Text(
                        "Lyrics provided by LRCLIB",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 9,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w300,
                        ),
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