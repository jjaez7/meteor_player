import 'package:flutter/services.dart'; // MethodChannel 사용을 위해 필요
import 'package:flutter/foundation.dart';

class PipHandler {
  // 메인 액티비티에서 설정한 채널명과 동일해야 합니다.
  static const _channel = MethodChannel('com.meteor.player/media_control');

  /// 안드로이드 시스템 PiP 모드로 즉시 전환
  static Future<void> enterPipMode() async {
    try {
      await _channel.invokeMethod('enterPip');
      debugPrint("🚀 시스템 PiP 진입 성공");
    } on PlatformException catch (e) {
      debugPrint("❌ 시스템 PiP 진입 실패: ${e.message}");
    }
  }
}