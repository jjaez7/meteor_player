import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart'; // 번역 패키지 추가
import '../models/lyric_model.dart';

/// 가사 로딩 상태 정의
enum LyricStatus { loading, success, noLyrics, networkError, timeout }

/// 가사 데이터와 상태를 함께 담는 결과 객체
class LyricResult {
  final List<LyricLine> lyrics;
  final LyricStatus status;

  LyricResult(this.lyrics, this.status);
}

class LyricsService {
  static final _translator = GoogleTranslator();

  /// 🔍 한국어 아티스트명을 영문으로 매핑 (글로벌 DB 대응)
  static const Map<String, String> _artistMapping = {
    '아이유': 'IU',
    '지드래곤': 'G-DRAGON',
    '방탄소년단': 'BTS',
    '태연': 'Taeyeon',
    '볼빨간사춘기': 'Bol4',
    '로제': 'ROSÉ',
    '지수': 'JISOO',
    '제니': 'JENNIE',
    '리사': 'LISA',
  };

  /// 🚀 메인 관문: 다단계 통합 검색 로직
  static Future<LyricResult> getLyrics(String title, String artist) async {
    debugPrint("--------------------------------------------------");
    
    // 0. 초기 정제: 아티스트명에서 괄호 제거 (지드래곤 (G-DRAGON) -> 지드래곤)
    String searchArtist = _getPureArtist(artist);
    String searchTitle = title.trim();

    debugPrint("🔍 [LyricsService] 가사 검색 시작: $searchTitle / $searchArtist");

    // [1차 시도] 정제된 원본 데이터로 검색
    debugPrint("👉 [1차 시도] 기본 검색 중...");
    LyricResult result = await _executeFetch(searchTitle, searchArtist);
    if (result.status == LyricStatus.success) return result;

    // [2차 시도] 아티스트명 영문 매핑 (지드래곤 -> G-DRAGON)
    String mappedArtist = _artistMapping[searchArtist] ?? searchArtist;
    if (mappedArtist != searchArtist) {
      debugPrint("🔄 [2차 시도] 아티스트 매핑 검색: $searchTitle / $mappedArtist");
      result = await _executeFetch(searchTitle, mappedArtist);
      if (result.status == LyricStatus.success) return result;
    }

    // [3차 시도] 제목 괄호 완전 제거 (에잇 (Prod...) -> 에잇)
    String superCleanTitle = _getSuperCleanTitle(searchTitle);
    if (superCleanTitle != searchTitle) {
      debugPrint("🔄 [3차 시도] 제목 괄호 제거 검색: $superCleanTitle / $mappedArtist");
      result = await _executeFetch(superCleanTitle, mappedArtist);
      if (result.status == LyricStatus.success) return result;
    }

    // [4차 시도] 수동 영문 매핑 검색 (에잇 -> eight)
    if (_isKorean(superCleanTitle)) {
      String manualRoman = _manualRomanize(superCleanTitle);
      if (manualRoman != superCleanTitle) {
        debugPrint("🔄 [4차 시도] 수동 영문 변환 검색: $manualRoman / $mappedArtist");
        result = await _executeFetch(manualRoman, mappedArtist);
        if (result.status == LyricStatus.success) return result;
      }
    }

    // 🔥 [5차 시도] 실시간 구글 번역 검색 (가장 강력한 수단)
    if (_isKorean(superCleanTitle) || _isKorean(mappedArtist)) {
      try {
        debugPrint("🌐 [5차 시도] 실시간 구글 번역 중...");
        var transTitle = await _translator.translate(superCleanTitle, to: 'en');
        var transArtist = await _translator.translate(mappedArtist, to: 'en');

        debugPrint("✨ 번역 결과: ${transTitle.text} / ${transArtist.text}");
        result = await _executeFetch(transTitle.text, transArtist.text);
        if (result.status == LyricStatus.success) return result;
      } catch (e) {
        debugPrint("🚨 번역 에러: $e");
      }
    }

    debugPrint("❌ [LyricsService] 모든 시도 실패");
    debugPrint("--------------------------------------------------");
    return result;
  }

  /// 🌐 실제 API 호출 로직
  /// 🌐 실제 API 호출 로직 수정
  static Future<LyricResult> _executeFetch(String title, String artist) async {
    final cleanArtist = (artist == "Unknown" || artist == "알 수 없는 아티스트" || artist == "") ? "" : artist;
    final url = Uri.parse(
      'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(cleanArtist)}&track_name=${Uri.encodeComponent(title)}'
    );

    try {
      debugPrint("🌐 [API 호출] $url");
      // 🚀 타임아웃을 7초에서 12초 정도로 늘려줍니다.
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final String? lrcContent = data['syncedLyrics'] ?? data['plainLyrics'];
        
        if (lrcContent != null && lrcContent.isNotEmpty) {
          final parsed = parseLrc(lrcContent);
          debugPrint("✅ [성공] 가사 로드 완료 (${parsed.length}줄)");
          return LyricResult(parsed, LyricStatus.success);
        }
      } 
      // 404 등 가사가 없는 경우
      return LyricResult([], LyricStatus.noLyrics);
    } on TimeoutException catch (_) {
      // 🚀 타임아웃 에러를 명확히 구분해서 던집니다.
      debugPrint("🚨 [타임아웃] 서버 응답 지연");
      return LyricResult([], LyricStatus.timeout);
    } catch (e) {
      debugPrint("🚨 [에러] $e");
      return LyricResult([], LyricStatus.networkError);
    }
  }

  /// 아티스트명 정제 (괄호 제거)
  static String _getPureArtist(String artist) {
    String pure = artist.split('(')[0].split('[')[0].trim();
    return (pure == "Unknown" || pure == "알 수 없는 아티스트") ? "" : pure;
  }

  /// 제목 정제 (괄호 제거)
  static String _getSuperCleanTitle(String title) {
    return title.split('(')[0].split('[')[0].trim();
  }

  /// 한국어 포함 여부 체크
  static bool _isKorean(String text) {
    return RegExp(r'[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]').hasMatch(text);
  }

  /// 주요 한국어 곡명 수동 매핑
  static String _manualRomanize(String title) {
    final map = {
      '에잇': 'eight',
      '밤편지': 'Through the Night',
      '삐삐': 'BBIBBI',
      '팔레트': 'Palette',
      '좋은 날': 'Good Day',
      '라일락': 'LILAC',
      '어제처럼': 'Like Yesterday',
    };
    return map[title] ?? title;
  }

  /// 📄 LRC 포맷 가사 파싱 함수
  static List<LyricLine> parseLrc(String lrc) {
    final List<LyricLine> lyrics = [];
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
          milliseconds: milliseconds * (msMatch.length == 2 ? 10 : 1),
        );
        
        final text = line.replaceFirst(regExp, '').trim();
        if (text.isNotEmpty) {
          lyrics.add(LyricLine(duration, text));
        }
      }
    }
    lyrics.sort((a, b) => a.time.compareTo(b.time));
    return lyrics;
  }
}