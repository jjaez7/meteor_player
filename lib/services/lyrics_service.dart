import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/lyric_model.dart'; // 모델 경로에 맞게 확인해주세요.

/// 가사 로딩 상태 정의
enum LyricStatus { loading, success, noLyrics, networkError, timeout }

/// 가사 데이터와 상태를 함께 담는 결과 객체
class LyricResult {
  final List<LyricLine> lyrics;
  final LyricStatus status;

  LyricResult(this.lyrics, this.status);
}

class LyricsService {
  /// 가사 데이터를 가져오는 메인 함수
  static Future<LyricResult> getLyrics(String title, String artist) async {
    // 1. 서비스 진입 로그
    debugPrint("🔍 [LyricsService] Raw Request: $title / $artist");

    // 2. 검색어 강화 정제 로직
    String cleanTitle = title;

    // 괄호()나 대괄호[] 안에 '특정 키워드'가 포함된 경우만 해당 괄호 덩어리 삭제
    // 키워드: official, video, mv, audio, music, edit, prod, feat, ft, version, lyrics 등
    final junkPattern = RegExp(
      r'[\(\[][^\]\)]*(?:official|video|mv|audio|music|edit|prod|feat|ft|version|lyrics|radio|piano)[^\]\)]*[\)\]]', 
      caseSensitive: false
    );
    cleanTitle = cleanTitle.replaceAll(junkPattern, '').trim();

    // 만약 "Title - Artist" 형태로 들어오는 경우 대시(-) 뒤를 제거 (필요시)
    if (cleanTitle.contains(' - ')) {
      cleanTitle = cleanTitle.split(' - ')[0].trim();
    }

    // 아티스트 정제
    final cleanArtist = (artist == "Unknown" || artist == "알 수 없는 아티스트") ? "" : artist;

    debugPrint("✨ [LyricsService] Cleaned: '$cleanTitle' by '$cleanArtist'");

    final url = Uri.parse(
      'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(cleanArtist)}&track_name=${Uri.encodeComponent(cleanTitle)}'
    );

    try {
      debugPrint("🌐 [LyricsService] API 호출: $url");
      
      // 타임아웃을 10초로 설정
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      // 3. 응답 코드에 따른 분기 처리
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        
        // 싱크 가사 우선, 없으면 일반 가사 사용
        final String? lrcContent = data['syncedLyrics'] ?? data['plainLyrics'];
        
        if (lrcContent != null && lrcContent.isNotEmpty) {
          final parsed = parseLrc(lrcContent);
          debugPrint("✅ [LyricsService] 가사 파싱 성공: ${parsed.length}줄 불러옴");
          return LyricResult(parsed, LyricStatus.success);
        } else {
          debugPrint("⚠️ [LyricsService] 서버 응답은 성공했으나 가사 본문이 비어있음");
          return LyricResult([], LyricStatus.noLyrics);
        }
      } 
      else if (response.statusCode == 404) {
        debugPrint("❌ [LyricsService] 404 Error: 서버에 가사 데이터가 존재하지 않음");
        return LyricResult([], LyricStatus.noLyrics);
      } 
      else {
        debugPrint("⚠️ [LyricsService] 서버 에러 발생: HTTP ${response.statusCode}");
        return LyricResult([], LyricStatus.networkError);
      }
    } 
    on TimeoutException {
      debugPrint("🚨 [LyricsService] 네트워크 타임아웃 발생 (10초 초과)");
      return LyricResult([], LyricStatus.timeout);
    } 
    on http.ClientException catch (e) {
      debugPrint("🚨 [LyricsService] 클라이언트 네트워크 오류 (와이파이/데이터 연결 확인): $e");
      return LyricResult([], LyricStatus.networkError);
    } 
    catch (e) {
      debugPrint("🚨 [LyricsService] 알 수 없는 심각한 오류 발생: $e");
      return LyricResult([], LyricStatus.networkError);
    }
  }

  /// LRC 포맷 가사 파싱 함수
  static List<LyricLine> parseLrc(String lrc) {
    final List<LyricLine> lyrics = [];
    // [00:00.00] 또는 [00:00.000] 패턴 매칭
    final RegExp regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (var line in lrc.split('\n')) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final msMatch = match.group(3)!;
        final milliseconds = int.parse(msMatch);
        
        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          // 2자리(00)면 10을 곱하고, 3자리(000)면 그대로 사용
          milliseconds: milliseconds * (msMatch.length == 2 ? 10 : 1),
        );
        
        final text = line.replaceFirst(regExp, '').trim();
        if (text.isNotEmpty) {
          lyrics.add(LyricLine(duration, text));
        }
      }
    }
    // 시간 순서대로 정렬
    lyrics.sort((a, b) => a.time.compareTo(b.time));
    return lyrics;
  }
}