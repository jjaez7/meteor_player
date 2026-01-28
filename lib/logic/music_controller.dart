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
  if (packageName.isEmpty) return false;
  
  final String p = packageName.toLowerCase();

  // 1. 확실한 메이저 앱 리스트 (기존 유지 및 보강)
  final knownMusicPkgs = {
    'com.google.android.apps.youtube.music',
    'com.spotify.music', // 스포티파이 패키지명 수정
    'com.melon.android',
    'com.kt.music.genie',
    'com.nhn.android.music', // VIBE
    'com.apple.android.music',
    'com.flo.music', // FLO 추가
    'com.kakao.music',
    'com.bugs.android.music', // 벅스 추가
  };

  if (knownMusicPkgs.contains(p)) return true;

  // 2. 패키지명 내 핵심 키워드 검사
  // 대부분의 플레이어는 패키지명에 아래 단어 중 하나를 포함합니다.
  final musicKeywords = [
    'music',
    'player',
    'audio',
    'sound',
    'media',
    'radio',
    'stream',
    'vinyl',
    'mp3',
    'melon',
    'genie',
    'spotify',
  ];

  // 3. 예외 처리 (음악 키워드는 있지만 음악 앱이 아닌 것들)
  // 시스템 알림이나 설정 등이 걸리는 것을 방지합니다.
  final exclusionList = [
    'android.system',
    'com.android.settings',
    'com.android.systemui',
    'com.google.android.googlequicksearchbox', // 구글 검색/어시스턴트
  ];

  if (exclusionList.any((excluded) => p.contains(excluded))) return false;

  // 4. 최종 키워드 매칭 여부 반환
  return musicKeywords.any((keyword) => p.contains(keyword));
}
}