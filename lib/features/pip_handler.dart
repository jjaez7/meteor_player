import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PipHandler {
  // 진입 및 제어용 채널
  static const _controlChannel = MethodChannel('com.meteor.player/media_control');
  // PiP 상태 및 버튼 액션 수신용 채널
  static const _statusChannel = MethodChannel('com.meteor.player/pip_status');

  /// 🚀 PiP 시스템 버튼 클릭 리스너 등록
  /// [onToggle], [onNext], [onPrev]는 각각 재생/정지, 다음곡, 이전곡 함수를 전달받습니다.
static void listenToActions({
  required VoidCallback onToggle,
  required VoidCallback onNext,
  required VoidCallback onPrev,
  Function(bool)? onPipModeChanged,
}) {
  _statusChannel.setMethodCallHandler((call) async {
    // 디버깅을 위해 모든 호출 로그 출력
    debugPrint("📥 PiP Channel Method: ${call.method}, Args: ${call.arguments}");

    switch (call.method) {
      case "onPipAction":
        // toString()으로 받고 공백 제거(trim)를 추가해 혹시 모를 오작동 방지
        final action = call.arguments?.toString().trim();
        
        if (action == "TOGGLE") {
          onToggle();
        } else if (action == "NEXT") {
          onNext();
        } else if (action == "PREV") {
          onPrev();
        }
        break;
        
      case "onPipModeChanged":
        if (call.arguments is bool) {
          onPipModeChanged?.call(call.arguments as bool);
        }
        break;
    }
  });
}

  /// 안드로이드 시스템 PiP 모드로 즉시 전환
  static Future<void> enterPipMode() async {
    try {
      await _controlChannel.invokeMethod('enterPip');
      debugPrint("🚀 시스템 PiP 진입 성공");
    } on PlatformException catch (e) {
      debugPrint("❌ 시스템 PiP 진입 실패: ${e.message}");
    }
  }
}