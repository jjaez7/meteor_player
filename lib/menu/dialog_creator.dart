import 'package:flutter/material.dart';

void showCreatorDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final bool isLandscape = size.width > size.height;
  const Color accentColor = Color(0xFF8E7AB5);
  const Color bgShadowColor = Color(0xFFEFEEEE);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: bgShadowColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: isLandscape ? size.width * 0.6 : size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  // [수정] withOpacity -> withValues
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "METEOR PLAYER",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "REDHOOK PROJECT",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D2D2D),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 30),

              isLandscape
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildCreatorCard(
                            "Jaewon Jo",
                            "Main Dev",
                            accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCreatorCard(
                            "MinChan Kim",
                            "UI/UX Design",
                            accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCreatorCard(
                            "Myeongwan Jeung",
                            "Special Thanks To",
                            accentColor,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildCreatorRow(
                          "Jaewon Jo",
                          "Main Developer",
                          accentColor,
                        ),
                        const SizedBox(height: 16),
                        _buildCreatorRow(
                          "MinChan Kim",
                          "UI/UX Design",
                          accentColor,
                        ),
                        const SizedBox(height: 16),
                        _buildCreatorRow(
                          "Myeongwan Jeung",
                          "Special Thanks To",
                          accentColor,
                        ),
                      ],
                    ),

              const SizedBox(height: 40),

              const Text(
                "\"So that your day can be sentimental\"",
                textAlign: TextAlign.center,
                // [수정] Colors.black80 에러 해결
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xCC000000), // black with 0.8 opacity
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enjoy it with the Meteor Player",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 30),

              _buildCloseButton(context, accentColor),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildCreatorRow(String name, String role, Color accent) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: _neomorphDecoration(),
    child: Row(
      children: [
        CircleAvatar(
          radius: 20,
          // [수정] withValues 적용
          backgroundColor: accent.withValues(alpha: 0.1),
          child: Icon(Icons.star_rounded, size: 22, color: accent),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              role,
              style: TextStyle(
                fontSize: 12,
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildCreatorCard(String name, String role, Color accent) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
    decoration: _neomorphDecoration(),
    child: Column(
      children: [
        CircleAvatar(
          radius: 22,
          // [수정] withValues 적용
          backgroundColor: accent.withValues(alpha: 0.1),
          child: Icon(Icons.star_rounded, size: 24, color: accent),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          role,
          style: TextStyle(
            fontSize: 10,
            color: accent,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget _buildCloseButton(BuildContext context, Color accent) {
  return InkWell(
    onTap: () => Navigator.pop(context),
    borderRadius: BorderRadius.circular(15),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: _neomorphDecoration(isPressed: true),
      child: Text(
        "CLOSE",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: accent,
        ),
      ),
    ),
  );
}

BoxDecoration _neomorphDecoration({bool isPressed = false}) {
  return BoxDecoration(
    color: const Color(0xFFEFEEEE),
    borderRadius: BorderRadius.circular(20),
    boxShadow: isPressed
        ? [
            // [수정] withValues 적용
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              offset: const Offset(2, 2),
              blurRadius: 4,
              spreadRadius: -1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(-2, -2),
              blurRadius: 4,
              spreadRadius: -1,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-6, -6),
              blurRadius: 12,
            ),
          ],
  );
}
