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

  // --- [3] 음악 제어 로직 (신규 추가) ---

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
  static Future<void> seekTo(double relativePos) async {
    try {
      HapticFeedback.lightImpact();

      // 현재 곡의 전체 길이를 확인하기 위해 네이티브 상태 요청
      const platform = MethodChannel('com.meteor.player/media_control');
      final dynamic result = await platform.invokeMethod('getCurrentStatus');

      if (result != null) {
        final data = Map<String, dynamic>.from(result);
        final int duration = data['duration'] ?? 0;

        if (duration > 0) {
          final int seekMs = (duration * relativePos).toInt();
          // 시스템 핸들러를 통해 실제 이동 명령 전송
          await audioHandler.seek(Duration(milliseconds: seekMs));
          debugPrint("🎯 Seek 명령 전송 완료: $seekMs ms");
        }
      }
    } catch (e) {
      debugPrint("❌ Seek 오류 발생: $e");
    }
  }
}