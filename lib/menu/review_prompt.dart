import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────
// 설정값
// ─────────────────────────────────────

const int _launchThreshold = 5;         // 몇 회 실행 후 표시
const String _launchCountKey  = "review_launch_count";
const String _reviewDoneKey   = "review_prompt_done";  // Don't show again 플래그

// ★ 본인 앱의 Google Play 패키지명으로 변경하세요
const String _packageName = "com.glasnyl.app";

// ─────────────────────────────────────
// 자동 표시 (앱 시작 시 호출)
// ─────────────────────────────────────

Future<void> showReviewPromptIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  // 이미 평가했거나 Don't show again 선택 시 종료
  if (prefs.getBool(_reviewDoneKey) ?? false) return;

  final count = (prefs.getInt(_launchCountKey) ?? 0) + 1;
  await prefs.setInt(_launchCountKey, count);

  if (count == _launchThreshold) {
    if (context.mounted) {
      showReviewDialog(context);
    }
  }
}

// ─────────────────────────────────────
// 수동 표시 (Creator Dialog 등에서 호출)
// ─────────────────────────────────────

void showReviewDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ReviewDialog(packageName: _packageName),
  );
}

// ─────────────────────────────────────
// 다이얼로그 UI
// ─────────────────────────────────────

class _ReviewDialog extends StatefulWidget {
  final String packageName;
  const _ReviewDialog({required this.packageName});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _starSelected = 0;
  int _starHovered = 0;

  static const Color _accentColor = Color(0xFFD1C4E9);

  Future<void> _onRate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewDoneKey, true);

    final uri = Uri.parse(
      "https://play.google.com/store/apps/details?id=${widget.packageName}",
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onLater() async {
    // Later → 카운트 초기화해서 5회 뒤 다시 표시
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_launchCountKey, 0);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onNever() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewDoneKey, true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: _accentColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 18),

            // 타이틀
            const Text(
              "Enjoying GLASNYL?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "A quick rating means the world\nto an indie developer :)",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // 별점 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < (_starHovered > 0 ? _starHovered : _starSelected);
                return GestureDetector(
                  onTap: () => setState(() => _starSelected = i + 1),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _starHovered = i + 1),
                    onExit: (_) => setState(() => _starHovered = 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 36,
                        color: filled ? const Color(0xFFFFD54F) : Colors.white24,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // 평가하기 버튼
            GestureDetector(
              onTap: _starSelected > 0 ? _onRate : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _starSelected > 0
                        ? [
                            _accentColor.withValues(alpha: 0.4),
                            _accentColor.withValues(alpha: 0.15),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.05),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _starSelected > 0
                        ? _accentColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  "Rate on Google Play",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    color: _starSelected > 0 ? Colors.white : Colors.white30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Later / Don't show again
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _onLater,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        "Later",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _onNever,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        "Don't show again",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}