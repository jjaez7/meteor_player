import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'release_notes.dart';
import '../theme/design_tokens.dart';

// 무제한 활성화 비밀 코드 (원하는 값으로 변경하세요)
const String _secretCode = "ZNLABS2025";
const String _lifetimeKey = "is_lifetime_pro";

void showCreatorDialog(BuildContext context, {VoidCallback? onUnlocked}) {
  final size = MediaQuery.of(context).size;
  final bool isLandscape = size.width > size.height;

  const Color accentColor = Color(0xFFD1C4E9);

  final List<String> betaTesters = [
    "Jaewon Jo", "Myungwan Jeong", "Jonghyun Yang", "Siwon Park",
    "Sieun Park", "Hayoon Kim", "Junho Lee", "Simhyeok Lee",
    "Lucas Bennett", "Sofia Marchetti", "Ethan Clarke", "Yuki Tanaka"
  ];

  showDialog(
    context: context,
    builder: (context) => _CreatorDialog(
      isLandscape: isLandscape,
      size: size,
      accentColor: accentColor,
      betaTesters: betaTesters,
      onUnlocked: onUnlocked,
    ),
  );
}

class _CreatorDialog extends StatefulWidget {
  final bool isLandscape;
  final Size size;
  final Color accentColor;
  final List<String> betaTesters;
  final VoidCallback? onUnlocked;

  const _CreatorDialog({
    required this.isLandscape,
    required this.size,
    required this.accentColor,
    required this.betaTesters,
    this.onUnlocked,
  });

  @override
  State<_CreatorDialog> createState() => _CreatorDialogState();
}

class _CreatorDialogState extends State<_CreatorDialog> {
  int _tapCount = 0;
  final TextEditingController _codeController = TextEditingController();
  bool _showCodeInput = false;
  bool _isUnlocked = false;
  String _errorMsg = "";

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onBadgeTap() {
    setState(() {
      _tapCount++;
      if (_tapCount >= 7) {
        _tapCount = 0;
        _showCodeInput = true;
        _errorMsg = "";
        _codeController.clear();
      }
    });
  }

  Future<void> _submitCode() async {
    if (_codeController.text.trim().toUpperCase() == _secretCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lifetimeKey, true);
      setState(() {
        _isUnlocked = true;
        _showCodeInput = false;
        _errorMsg = "";
      });
      widget.onUnlocked?.call();
    } else {
      setState(() {
        _errorMsg = "Invalid code.";
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GRadius.popup),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: widget.isLandscape ? widget.size.width * 0.7 : widget.size.width * 0.85,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 상단 로고 배지 (7번 탭 트리거)
                GestureDetector(
                  onTap: _onBadgeTap,
                  child: _buildGlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Text(
                      "GLASNYL",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "ZN LABS",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 30),

                // 잠금 해제 성공 배지
                if (_isUnlocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.all_inclusive, color: Colors.amber, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "UNLIMITED UNLOCKED",
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 비밀 코드 입력창
                if (_showCodeInput) ...[
                  _buildGlassContainer(
                    child: Column(
                      children: [
                        const Text(
                          "ENTER CODE",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                          decoration: InputDecoration(
                            hintText: "••••••••••",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.5)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: widget.accentColor),
                            ),
                          ),
                        ),
                        if (_errorMsg.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMsg,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _showCodeInput = false;
                                  _errorMsg = "";
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Text(
                                    "CANCEL",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: _submitCode,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        widget.accentColor.withValues(alpha: 0.4),
                                        widget.accentColor.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: widget.accentColor.withValues(alpha: 0.5)),
                                  ),
                                  child: const Text(
                                    "CONFIRM",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 2. 제작자 카드 섹션
                widget.isLandscape
                    ? Row(
                        children: [
                          Expanded(child: _buildCreatorCard("Jaewon Jo", "Main Dev", widget.accentColor)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCreatorCard("Minchan Kim", "Special Thanks", widget.accentColor)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCreatorCard("Myungwan Jeong", "Special Thanks", widget.accentColor)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildCreatorRow("Jaewon Jo", "Main Developer", widget.accentColor),
                          const SizedBox(height: 12),
                          _buildCreatorRow("Minchan Kim", "Special Thanks To", widget.accentColor),
                          const SizedBox(height: 12),
                          _buildCreatorRow("Myungwan Jeong", "Special Thanks To", widget.accentColor),
                        ],
                      ),

                const SizedBox(height: 35),

                // 베타 테스터 섹션
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white24, endIndent: 10)),
                    Text(
                      "BETA TESTERS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: widget.accentColor.withValues(alpha: 0.8),
                        letterSpacing: 2,
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.white24, indent: 10)),
                  ],
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: widget.betaTesters.map((name) => _buildTesterChip(name)).toList(),
                ),

                const SizedBox(height: 40),
                Text(
                  "\"Music, Visualized.\"",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),

                // SNS 링크 버튼
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildSnsButton(
                      icon: FontAwesomeIcons.instagram,
                      label: "@znlabs_official",
                      url: "https://instagram.com/znlabs_official",
                      accentColor: widget.accentColor,
                      onTap: _launchUrl,
                    ),
                    _buildSnsButton(
                      icon: FontAwesomeIcons.github,
                      label: "jjaez7",
                      url: "https://github.com/jjaez7",
                      accentColor: widget.accentColor,
                      onTap: _launchUrl,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 업데이트 노트 버튼
                GestureDetector(
                  onTap: () => showReleaseNotesDialog(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(GRadius.mediumCard),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 14, color: Colors.white54),
                        const SizedBox(width: 7),
                        const Text(
                          "UPDATE NOTES",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white54,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 닫기 버튼
                _buildGlassButton(context, "CLOSE", widget.accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────
// 공통 글래스모피즘 위젯
// ─────────────────────────────────────

Widget _buildGlassContainer({required Widget child, EdgeInsets? padding, double borderRadius = GRadius.mediumCard}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
    ),
    child: child,
  );
}

Widget _buildCreatorCard(String name, String role, Color accent) {
  return _buildGlassContainer(
    child: Column(
      children: [
        Icon(Icons.auto_awesome, size: 24, color: accent),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(role, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ],
    ),
  );
}

Widget _buildCreatorRow(String name, String role, Color accent) {
  return _buildGlassContainer(
    child: Row(
      children: [
        Icon(Icons.auto_awesome, size: 20, color: accent),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
            Text(role, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    ),
  );
}

Widget _buildTesterChip(String name) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Text(
      name,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70),
    ),
  );
}

Widget _buildSnsButton({
  required FaIconData icon,
  required String label,
  required String url,
  required Color accentColor,
  required Future<void> Function(String) onTap,
}) {
  return GestureDetector(
    onTap: () => onTap(url),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 13, color: accentColor),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildGlassButton(BuildContext context, String label, Color accent) {
  return GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(GRadius.mediumCard),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
      ),
    ),
  );
}