import 'package:flutter/material.dart';

void showTermsDialog(BuildContext context) {
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
      title: Column(
        children: [
          Icon(Icons.gavel_rounded, color: accentColor, size: 28),
          const SizedBox(height: 10),
          const Text(
            "TERMS & CONDITIONS",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isLandscape ? size.width * 0.6 : size.width * 0.9,
        height: size.height * 0.55,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgShadowColor,
                  borderRadius: BorderRadius.circular(20),
                  // [수정] 오목한 느낌(Inset)의 그림자 효과로 텍스트 집중도 향상
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(3, 3),
                      blurRadius: 5,
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      offset: Offset(-3, -3),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TermsSection(
                        title: "1. Acceptance of Terms",
                        content:
                            "By accessing METEOR PLAYER, you agree to comply with these terms. This application is a personal project intended for media playback only.",
                      ),
                      _TermsSection(
                        title: "2. Personal Information & Privacy",
                        content:
                            "We do not collect any personal data. METEOR PLAYER operates offline for local file playback. All settings and playlists are stored exclusively on your device's local storage.",
                      ),
                      _TermsSection(
                        title: "3. Media Content & Copyright",
                        content:
                            "METEOR PLAYER does not provide any music content. All audio files played are the responsibility of the user. You must own the rights to the files you play.",
                      ),
                      _TermsSection(
                        title: "4. Storage Access",
                        content:
                            "To provide music playback services, this app requires access to your device's storage. This permission is used solely to read and play your local audio files.",
                      ),
                      _TermsSection(
                        title: "5. Disclaimer of Liability",
                        content:
                            "Redhook Project is not responsible for any copyright infringement by users or damages resulting from the use of the app. It is provided 'as-is' without warranties.",
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            _buildCloseButton(context, accentColor),
          ],
        ),
      ),
    ),
  );
}

class _TermsSection extends StatelessWidget {
  final String title, content;
  const _TermsSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀 부분
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF8E7AB5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              // [해결] 타이틀도 길어질 수 있으므로 Expanded 처리
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 내용 부분
          Padding(
            padding: const EdgeInsets.only(left: 12), // 인디케이터 바 너비만큼 들여쓰기
            child: Row(
              children: [
                // [핵심 해결] Expanded로 감싸서 19px 오버플로우 방지
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.6,
                    ),
                    softWrap: true, // 자동 줄바꿈 활성화
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildCloseButton(BuildContext context, Color accent) {
  return GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEEE),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        "I AGREE",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: accent,
        ),
      ),
    ),
  );
}
