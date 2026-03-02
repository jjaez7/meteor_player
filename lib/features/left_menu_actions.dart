import 'package:flutter/material.dart';
import 'pip_handler.dart';

class LeftMenuActions {
  static void handleLeftMenuClick({
    required BuildContext context,
    required String value,
    required VoidCallback onLockEnabled,
    required VoidCallback onConcertModeToggled, // 콘서트 모드 토글 콜백 추가
  }) {
    if (value == "pip") {
      PipHandler.enterPipMode();
      if (Navigator.canPop(context)) Navigator.pop(context);
    }

    // 화면 잠금 액션
    else if (value == "lock") {
      onLockEnabled();
      if (Navigator.canPop(context)) Navigator.pop(context);
    }

    // 🎸 콘서트 모드 토글
    else if (value == "concert") {
      onConcertModeToggled();
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }
}