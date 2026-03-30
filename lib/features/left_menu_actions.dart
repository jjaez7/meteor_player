import 'package:flutter/material.dart';
import 'pip_handler.dart';

class LeftMenuActions {
  static void handleLeftMenuClick({
    required BuildContext context,
    required String value,
    required VoidCallback onLockEnabled,
    required VoidCallback onConcertModeToggled,
    VoidCallback? onShareCard, // ← 추가
  }) {
    if (value == "pip") {
      PipHandler.enterPipMode();
      if (Navigator.canPop(context)) Navigator.pop(context);
    }

    else if (value == "lock") {
      onLockEnabled();
      if (Navigator.canPop(context)) Navigator.pop(context);
    }

    else if (value == "concert") {
      onConcertModeToggled();
      if (Navigator.canPop(context)) Navigator.pop(context);
    }

    // 📸 공유 카드
    else if (value == "share") {
  if (Navigator.canPop(context)) Navigator.pop(context);
  // 메뉴 닫힘 애니메이션 완료 후 다이얼로그 열기
  Future.delayed(const Duration(milliseconds: 200), () {
    onShareCard?.call();
  });
}
  }
}