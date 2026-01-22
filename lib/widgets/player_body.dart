import 'package:flutter/material.dart';
import '../models/player_config.dart';
import 'vinyl_component.dart';

// UI 구성 요소만 담당하는 헬퍼 클래스 (또는 파일)
class PlayerViewComponents {
  static Widget buildLpDisk({
    required PlayerConfig config,
    required bool isPlaying,
    required AnimationController controller,
    required dynamic albumArtBytes,
    required Color barColor,
    required Color lpColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: barColor.withValues(alpha: 0.4),
            blurRadius: isPlaying ? 50 : 20,
            spreadRadius: isPlaying ? 10 : 0,
          ),
          BoxShadow(
            color: lpColor.withValues(alpha: 0.2),
            blurRadius: isPlaying ? 80 : 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: VinylDisk(
        controller: controller,
        size: config.lpSize,
        albumArtBytes: albumArtBytes,
      ),
    );
  }
}
