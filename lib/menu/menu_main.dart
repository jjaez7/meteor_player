import 'package:flutter/material.dart';
import 'dialog_creator.dart';
import 'dialog_terms.dart';
import 'dialog_settings.dart';
import 'dialog_manual.dart';

// [수정] 뉴모픽 감성을 담은 팝업 아이템 빌더
PopupMenuItem<String> buildPopupItem(
  String title,
  IconData icon,
  String value,
) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        // 아이콘 색상을 포인트 보라색으로 통일하여 세련미를 더함
        Icon(icon, color: const Color(0xFF735DA5), size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF333335), // 텍스트도 플레이어 테마와 통일
          ),
        ),
      ],
    ),
  );
}

// 메인 메뉴 클릭 핸들러 (기존 로직 유지하며 정확히 연결)
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
  required VoidCallback onResetColors, // 하나만 남기고 유지
  required VoidCallback onResetLayout, // 레이아웃 리셋 추가
}) {
  switch (value) {
    case "manual":
      showManualDialog(context);
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
    case "edit_mode": // 편집 모드 토글 로직 추가
      onEditModeChanged(!isEditMode);
      break;
  }
}
