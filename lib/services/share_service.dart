import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// 1단계: 위젯 캡처만 → PNG bytes 반환 (다이얼로그 닫기 전에 호출)
  static Future<Uint8List?> captureCard({
    required GlobalKey cardKey,
    required BuildContext context,
  }) async {
    try {
      final boundary = cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showError(context, "카드를 찾을 수 없어요.");
        return null;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("ShareService captureCard error: $e");
      return null;
    }
  }

  /// 2단계: bytes → 파일 저장 후 공유 시트 열기 (다이얼로그 닫은 후 호출)
  static Future<void> shareBytes({
    required Uint8List pngBytes,
    required BuildContext context,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/glasnyl_now_playing.png';
      await File(filePath).writeAsBytes(pngBytes);
      await SharePlus.instance.share(
  ShareParams(
    files: [XFile(filePath, mimeType: 'image/png')],
    text: 'GLASNYL로 듣는 중 🎵',
  ),
);
    } catch (e) {
      debugPrint("ShareService shareBytes error: $e");
      if (context.mounted) _showError(context, "공유 중 오류가 발생했어요.");
    }
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }
}