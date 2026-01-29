import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';

void showTermsDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final bool isLandscape = size.width > size.height;
  const Color accentColor = Color(0xFFD1C4E9); // 소프트 퍼플 포인트

  showDialog(
    context: context,
    barrierDismissible: false, // 출시용: 동의 전까지 닫기 방지
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.all(isLandscape ? 16 : 24),
        content: SizedBox(
          width: isLandscape ? size.width * 0.85 : size.width * 0.9,
          child: SingleChildScrollView(
            child: isLandscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 좌측 영역: 로고 및 동의 버튼
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeaderIcon(),
                            const SizedBox(height: 16),
                            const Text(
                              "TERMS OF\nSERVICE",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildAgreeButton(context, accentColor),
                            const SizedBox(height: 8),
                            _buildViewFullPolicyButton(),
                            const SizedBox(height: 16),

                            Opacity(
                              opacity: 0.4, // 시선을 분산시키지 않도록 연하게 처리
                              child: Column(
                                children: [
                                  Text(
                                    "© 2026 REDHOOK PROJECT. ALL RIGHTS RESERVED.",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "METEOR OS ENGINE v$appVersion",
                                    style: TextStyle(
                                      color: accentColor, // 포인트 컬러 사용
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // 우측 영역: 약관 본문
                      Expanded(
                        flex: 3,
                        child: _buildTermsScrollArea(size, isLandscape),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeaderIcon(),
                      const SizedBox(height: 16),
                      const Text(
                        "TERMS OF SERVICE",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTermsScrollArea(size, isLandscape),
                      const SizedBox(height: 12),
                      _buildViewFullPolicyButton(),
                      const SizedBox(height: 12),
                      _buildAgreeButton(context, accentColor),
                      const SizedBox(height: 16), // 버튼과의 간격

                      Opacity(
                        opacity: 0.4, // 시선을 분산시키지 않도록 연하게 처리
                        child: Column(
                          children: [
                            Text(
                              "© 2026 REDHOOK PROJECT. ALL RIGHTS RESERVED.",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "METEOR OS ENGINE v$appVersion",
                              style: TextStyle(
                                color: accentColor, // 포인트 컬러 사용
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

// 상단 보안 아이콘 헤더
Widget _buildHeaderIcon() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: const Icon(Icons.security_rounded, color: Colors.white, size: 28),
  );
}

// 전체 약관 보기 텍스트 버튼
Widget _buildViewFullPolicyButton() {
  return TextButton(
    onPressed: () async {
      final Uri url = Uri.parse('https://gist.github.com/jjaez7/77747922246eb6f6715f169ab55ec674');
    try {
    await launchUrl(
      url,
      mode: LaunchMode.externalApplication, // 외부 브라우저 강제 호출
    );
  } catch (e) {
    debugPrint('Could not launch $url: $e');
  }
    },
    style: TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(vertical: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      "View Full Privacy Policy",
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 11,
        decoration: TextDecoration.underline, // 링크 느낌 강조
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}

// 출시용 약관 본문 스크롤 영역
Widget _buildTermsScrollArea(Size size, bool isLandscape) {
  return ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: isLandscape ? size.height * 0.6 : size.height * 0.45,
    ),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // [소프트 레이어] 가독성을 위해 배경을 조금 더 어둡게 누름
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TermsSection(
              title: "1. Service Overview",
              content:
                  "METEOR PLAYER is a local media player tool. It does not provide, host, or distribute any digital content. Users are solely responsible for the media files on their device.",
            ),
            _TermsSection(
              title: "2. Data Privacy (No Collection)",
              content:
                  "We do not collect, store, or transmit any personal data, media metadata, or usage statistics to external servers. All processing occurs strictly on your local device.",
            ),
            _TermsSection(
              title: "3. Media Access Permissions",
              content:
                  "This app requires access to your device's media library to function. These permissions are used exclusively to index and play your audio files within the interface.",
            ),
            _TermsSection(
              title: "4. User Responsibility",
              content:
                  "Users must comply with local and international copyright laws. Unauthorized playback of copyrighted material is strictly prohibited and is the user's sole legal responsibility.",
            ),
            _TermsSection(
              title: "5. Limitation of Liability",
              content:
                  "METEOR PLAYER is provided 'AS IS'. The developers (Redhook Project) are not liable for any data loss, device damage, or legal issues arising from the use of this app.",
            ),
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1C4E9),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD1C4E9).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 빛나는 글래스 스타일의 동의 버튼
Widget _buildAgreeButton(BuildContext context, Color accent) {
  return GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.4),
            accent.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Text(
        "I AGREE & START",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Colors.white,
        ),
      ),
    ),
  );
}
