import 'package:flutter/material.dart';
import 'pip_handler.dart';

class LeftMenuActions {
  static void handleLeftMenuClick({
    required BuildContext context,
    required String value,
    required VoidCallback onLockEnabled, // 잠금 활성화를 위한 콜백 추가
  }) {
    if (value == "pip") {
      PipHandler.enterPipMode();
      if (Navigator.canPop(context)) Navigator.pop(context);
    } 
    
    // 🚀 화면 잠금 액션 추가
    else if (value == "lock") {
      onLockEnabled(); // 메인 화면의 _isScreenLocked를 true로 바꿈
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }
}