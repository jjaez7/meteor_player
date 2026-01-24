import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class MusicColorLogic {
  // 앨범 아트에서 테마 색상들을 추출하는 순수 로직
  static Future<Map<String, Color>> extractThemeColors(
    Uint8List artBytes,
  ) async {
    final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
      MemoryImage(artBytes),
      maximumColorCount: 20,
    );

    // 1. 포인트 컬러 (재생 버튼용)
    Color accent =
        palette.vibrantColor?.color ??
        palette.lightVibrantColor?.color ??
        palette.dominantColor?.color ??
        const Color(0xFF735DA5);

    // 2. 보조 컬러 (진행바용)
    Color secondary =
        palette.mutedColor?.color ??
        palette.darkVibrantColor?.color ??
        accent.withValues(alpha: 0.7);

    // 3. 배경색 (파스텔톤)
    HSLColor hsl = HSLColor.fromColor(accent);
    Color bg = hsl.withSaturation(0.1).withLightness(0.92).toColor();

    // 4. 텍스트 컬러
    Color text = hsl.withLightness(0.2).withSaturation(0.3).toColor();
    if (text.computeLuminance() > 0.4) text = Colors.black87;

    return {
      'bg': bg,
      'btn': accent,
      'bar': secondary,
      'text': text,
      'artist': secondary.withValues(alpha: 0.8),
    };
  }

  // 음악 앱인지 확인하는 필터
  static bool isMusicApp(String packageName) {
    final pkgs = [
      'com.google.android.apps.youtube.music',
      'com.spotify.music',
      'com.melon.android',
      'com.kt.music.genie',
      'com.nhn.android.music',
      'com.apple.android.music',
    ];
    String p = packageName.toLowerCase();
    return pkgs.contains(p) || p.contains("music") || p.contains("player");
  }
}