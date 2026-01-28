import 'package:flutter/material.dart';
import 'pip_handler.dart';

class LeftMenuActions {
  static void handleLeftMenuClick(BuildContext context, String value) {
    if (value == "pip") {
      // 이제 context 없이 바로 시스템 PiP를 호출합니다.
      PipHandler.enterPipMode(); 
      
      // 메뉴 창이 열려있다면 닫아주는 센스 (선택 사항)
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }
}