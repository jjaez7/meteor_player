import 'package:flutter/material.dart';

void showLayoutDialog({
  required BuildContext context,
  required bool isEditMode,
  required Function(bool) onEditModeChanged,
  required Color bgColor,
  required Color textColor,
  required Color playBtnColor,
  required VoidCallback onResetLayout, // 레이아웃 위치만 초기화하는 함수
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) => Container(),
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: Curves.easeOutBack.transform(anim1.value),
        child: Opacity(
          opacity: anim1.value,
          child: AlertDialog(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            title: Text(
              "LAYOUT EDIT",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: textColor,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // 편집 모드 스위치
                _buildLayoutTile(
                  "Enable Edit Mode",
                  bgColor,
                  textColor,
                  Switch(
                    value: isEditMode,
                    activeThumbColor: playBtnColor,
                    activeTrackColor: playBtnColor.withValues(alpha: 0.3),
                    onChanged: (v) {
                      onEditModeChanged(v);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // 위치 초기화 버튼
                _buildLayoutTile(
                  "Reset Positions",
                  bgColor,
                  textColor,
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      onResetLayout();
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "In edit mode, you can drag components\nto customize your own player layout.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 24),
                // 닫기 버튼
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: _neoDecoration(bgColor),
                    child: Text(
                      "CLOSE",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildLayoutTile(
  String title,
  Color bgColor,
  Color textColor,
  Widget trailing,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: _neoDecoration(bgColor),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        trailing,
      ],
    ),
  );
}

BoxDecoration _neoDecoration(Color bgColor) {
  return BoxDecoration(
    color: bgColor,
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        offset: const Offset(4, 4),
        blurRadius: 8,
      ),
      const BoxShadow(
        color: Colors.white,
        offset: Offset(-4, -4),
        blurRadius: 8,
      ),
    ],
  );
}
