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
    return Center(
      // 부모 레이아웃 안에서 중앙을 잡습니다.
      key: const ValueKey('lyrics_card'),
      child: SizedBox(
        width: size, // 미니멀 모드와 동일한 너비
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
    // 🚀 1. 반응형 폰트 사이즈 계산
    final screenSize = MediaQuery.of(context).size;
    // 화면 너비에 따라 폰트 크기 결정 (최소 18, 최대 28)
    final double responsiveBaseSize = (screenSize.width * 0.05).clamp(
      18.0,
      24.0,
    );
    final double responsiveCurrentSize = (screenSize.width * 0.07).clamp(
      22.0,
      30.0,
    );

    debugPrint("🕒 Position: ${widget.currentPosition} | Index: $_lastIndex");
    final double responsiveRadius = widget.size * 0.12;

    // 🚀 1. 실시간 인덱스 계산
    int currentIndex =
        widget.lyrics.indexWhere((line) => line.time > widget.currentPosition) -
        1;
    if (currentIndex < 0 &&
        widget.lyrics.isNotEmpty &&
        widget.currentPosition >= widget.lyrics.last.time) {
      currentIndex = widget.lyrics.length - 1;
    }

    // 🚀 2. 인덱스 변경 시 자동 스크롤 애니메이션 실행
    if (currentIndex != _lastIndex && currentIndex >= 0) {
      _lastIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateToItem(
            currentIndex,
            duration: const Duration(milliseconds: 400), // 조금 더 부드럽게 400ms
            curve: Curves.easeOutQuart, // 자연스러운 감속
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
                // 🚀 자연스러운 유리 느낌을 위한 그라데이션
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                // 🚀 테두리 선 제거 효과
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
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
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // 🚀 기기 너비에 따른 반응형 폰트 사이즈 계산
                              final double width = constraints.maxWidth;
                              final double responsiveBaseSize = (width * 0.05)
                                  .clamp(16.0, 20.0);
                              final double responsiveCurrentSize =
                                  (width * 0.065).clamp(20.0, 28.0);

                              return ListWheelScrollView.useDelegate(
                                controller: _scrollController,
                                // 🚀 줄바꿈(2줄)을 고려하여 아이템 높이를 넉넉하게 설정
                                itemExtent: responsiveCurrentSize * 3.0,
                                physics: const NeverScrollableScrollPhysics(),
                                diameterRatio: 2.0, // 굴곡을 완만하게 하여 줄바꿈 시 왜곡 방지
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: widget.lyrics.length,
                                  builder: (context, index) {
                                    final isCurrent = index == currentIndex;

                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 30,
                                        ),
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          style: TextStyle(
                                            color: isCurrent
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.25,
                                                  ),
                                            fontSize: isCurrent
                                                ? responsiveCurrentSize
                                                : responsiveBaseSize,
                                            fontWeight: isCurrent
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            height: 1.3, // 줄 간격 확보
                                            letterSpacing: -0.5,
                                          ),
                                          // 🚀 FittedBox를 제거하여 글자 크기를 고정하고 줄바꿈 허용
                                          child: Text(
                                            widget.lyrics[index].text,
                                            textAlign: TextAlign.center,
                                            softWrap: true,
                                            maxLines: 3, // 최대 2줄까지 허용
                                            overflow: TextOverflow
                                                .ellipsis, // 넘치면 ... 처리
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),

                  // 하단 출처 표기 (은은하게 고정)
                  if (widget.lyrics.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Text(
                        "Lyrics provided by LRCLIB",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
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
