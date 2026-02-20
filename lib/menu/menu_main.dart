import 'package:flutter/material.dart';
import 'dialog_creator.dart';
import 'dialog_terms.dart';
import 'dialog_settings.dart';
import 'dialog_manual.dart';
import 'dialog_pass.dart'; // 🚀 추가

// ... buildPopupItem 함수는 동일 ...

void handleMenuClick({
  required BuildContext context,
  required String value,
  required bool isEditMode,
  required Function(bool) onEditModeChanged,
  required Color bgColor,
  required Color lpColor,
  required Color textColor,
  required Color artistColor,
  required Color barColor,
  required Color playBtnColor,
  required Function(Color, String) onColorChanged,
  required VoidCallback onResetColors,
  required VoidCallback onResetLayout,
  required VoidCallback onPassUpdated, // 🚀 프리패스 갱신용 콜백 추가
}) {
  switch (value) {
    case "pass": // 🚀 패스 관리 추가
      showPassDialog(context, onPassUpdated);
      break;
    case "manual":
      showManualDialog(context);
      break;
    case "creator":
      showCreatorDialog(context);
      break;
    case "terms":
      showTermsDialog(context);
      break;
    case "settings":
      showSettingsDialog(
        context: context,
        bgColor: bgColor,
        lpColor: lpColor,
        textColor: textColor,
        artistColor: artistColor,
        barColor: barColor,
        playBtnColor: playBtnColor,
        onColorChanged: onColorChanged,
        onResetColors: onResetColors,
      );
      break;
    case "edit_mode":
      onEditModeChanged(!isEditMode);
      break;
  }
}