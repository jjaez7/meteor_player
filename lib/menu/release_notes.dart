import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────
// 출시노트 데이터 (버전 올릴 때마다 맨 위에 추가)
// ─────────────────────────────────────

class ReleaseNote {
  final String version;
  final String date;
  final List<ReleaseNoteItem> items;

  const ReleaseNote({
    required this.version,
    required this.date,
    required this.items,
  });
}

enum NoteType { feature, fix, improvement }

class ReleaseNoteItem {
  final NoteType type;
  final String text;

  const ReleaseNoteItem(this.type, this.text);
}

// ★ 여기에 버전 올릴 때마다 맨 위에 추가하세요
const List<ReleaseNote> kReleaseNotes = [
  ReleaseNote(
    version: "0.0.2",
    date: "2026-04-08",
    items: [
      ReleaseNoteItem(NoteType.feature, "GLASNYL launch note has been released."),
    ],
  ),
  ReleaseNote(
    version: "0.0.1",
    date: "2026-04-01",
    items: [
      ReleaseNoteItem(NoteType.feature, "GLASNYL 2.0 released"),
    ],
  ),
];

// ─────────────────────────────────────
// 자동 표시 (업데이트 후 첫 실행 시)
// ─────────────────────────────────────

const String _lastSeenVersionKey = "release_notes_last_seen_version";

Future<void> showReleaseNotesIfUpdated(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  final currentVersion = info.version;

  final prefs = await SharedPreferences.getInstance();
  final lastSeen = prefs.getString(_lastSeenVersionKey) ?? "";

  if (lastSeen != currentVersion) {
    await prefs.setString(_lastSeenVersionKey, currentVersion);
    if (context.mounted) {
      showReleaseNotesDialog(context);
    }
  }
}

// ─────────────────────────────────────
// 수동 표시 (설정/정보 화면에서 호출)
// ─────────────────────────────────────

void showReleaseNotesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _ReleaseNotesDialog(),
  );
}

// ─────────────────────────────────────
// 다이얼로그 UI
// ─────────────────────────────────────

class _ReleaseNotesDialog extends StatelessWidget {
  const _ReleaseNotesDialog();

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFFD1C4E9);
    final size = MediaQuery.of(context).size;
    final bool isLandscape = size.width > size.height;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: isLandscape ? size.width * 0.65 : size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      "GLASNYL",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "업데이트 노트",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 노트 리스트 (스크롤)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: isLandscape ? size.height * 0.5 : size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: kReleaseNotes.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 28,
                  ),
                  itemBuilder: (context, index) {
                    final note = kReleaseNotes[index];
                    return _buildNoteSection(note, accentColor);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 닫기 버튼
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.3),
                        accentColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    "CLOSE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteSection(ReleaseNote note, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 버전 + 날짜
        Row(
          children: [
            Text(
              "v${note.version}",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: accentColor,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              note.date,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 항목들
        ...note.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeBadge(item.type),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildTypeBadge(NoteType type) {
    final (label, color) = switch (type) {
      NoteType.feature    => ("NEW",  const Color(0xFF81C784)),
      NoteType.fix        => ("FIX",  const Color(0xFFE57373)),
      NoteType.improvement => ("UPD", const Color(0xFF64B5F6)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}