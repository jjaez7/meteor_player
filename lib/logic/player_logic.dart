import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../color_manager.dart';
import '../utils/layout_engine.dart';
import '../main.dart'; // audioHandler 접근을 위해 필요

class PlayerLogic {
  // --- [1] 테마 및 색상 관련 로직 ---

  /// 공장 초기화 로직 (절대 리셋)
  static Future<Map<String, Color>> handleAbsoluteColorReset() async {
    final defaultColors = {
      'bg': const Color(0xFFE1E0E5),
      'lp': const Color(0xFF2A292E),
      'text': const Color(0xFF333335),
      'artist': const Color(0xFF8F7AB3),
      'bar': const Color(0xFFB1A1D0),
      'btn': const Color(0xFF735DA5),
    };

    // 저장소 저장
    for (var entry in defaultColors.entries) {
      await ColorManager.saveColor(entry.key, entry.value);
    }
    return defaultColors;
  }

  /// 색상 개별 업데이트 및 저장
  static Future<void> updateColor(String target, Color newColor) async {
    await ColorManager.saveColor(target, newColor);
  }

  // --- [2] 레이아웃 관련 로직 ---

  /// 레이아웃 리셋 로직
  static Future<void> resetLayout() async {
    await LayoutEngine.clearSavedLayout();
    debugPrint("✅ 레이아웃 저장소 초기화 완료");
  }

  // --- [3] 음악 제어 로직 ---

  /// 재생/일시정지 토글
  static void togglePlay({
    required bool isPlaying,
    required VoidCallback onToggle,
  }) {
    if (isPlaying) {
      audioHandler.pause();
    } else {
      audioHandler.play();
    }
    onToggle(); // UI 상태 업데이트를 위한 콜백 호출
  }

  /// 다음 곡 재생
  static void skipNext() {
    audioHandler.skipToNext();
  }

  /// 이전 곡 재생
  static void skipPrevious() {
    audioHandler.skipToPrevious();
  }

  /// 특정 위치로 재생 지점 이동 (Seek)
  /// relativePos: 0.0 ~ 1.0 사이의 비율
  static Future<void> seekTo(double relativePos) async {
    try {
      const platform = MethodChannel('com.glasnyl.app/media_control');
      // 비율(0.0~1.0)을 네이티브로 직접 쏩니다.
      await platform.invokeMethod('seek', {'position': relativePos.clamp(0.0, 1.0)});
    } catch (e) {
      debugPrint("❌ Seek 오류: $e");
    }
  }
}