import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'vinyl_component.dart';

class ClassicVinylView extends StatelessWidget {
  final bool isMinimalMode;
  final double size;
  final Uint8List? albumArtBytes;
  final String title;
  final String artist;
  final AnimationController lpController;
  final VoidCallback onToggleMode;

  const ClassicVinylView({
    super.key,
    required this.isMinimalMode,
    required this.size,
    this.albumArtBytes,
    required this.title,
    required this.artist,
    required this.lpController,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation,
          child: child,
        ),
      ),
      // 🚀 핵심: 모드 전환 시 위젯을 완전히 새로 그리지 않도록 키 관리
      child: isMinimalMode ? _buildMinimalArt() : _buildVinylDisk(),
    );
  }

  // --- 1. LP판 빌더 (렉 최적화) ---
Widget _buildVinylDisk() {
    return GestureDetector(
      key: const ValueKey('vinyl_disk'),
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        onToggleMode();
      },
      child: RepaintBoundary(
        // 🚀 RotationTransition이 애니메이션을 처리하여 렉을 방지합니다.
        child: RotationTransition(
          turns: lpController,
          child: VinylDisk(
            // 🚀 에러 해결: VinylDisk가 요구하는 controller를 전달합니다.
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

  // --- 2. 미니멀 모드 빌더 (고화질 최적화) ---
  Widget _buildMinimalArt() {
    final double responsiveRadius = size * 0.12;
    
    return GestureDetector(
      key: const ValueKey('minimal_art'),
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
                  // 🚀 [화질 개선 핵심]
                  // 1. FilterQuality를 high로 설정하여 업스케일링 시 깨짐 방지
                  filterQuality: FilterQuality.medium, 
                  // 2. 캐시 사이즈를 null로 두어 원본 해상도 그대로 사용
                cacheWidth: (size * 2).toInt(), 
                cacheHeight: (size * 2).toInt(),
                  // 3. 이미지 전환 시 부드럽게 유지
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
}