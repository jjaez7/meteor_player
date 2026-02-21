import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
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

  /// 🔍 한국어 아티스트명을 영문으로 매핑
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

  // ─────────────────────────────────────────────
  // 🚀 PUBLIC: 메인 관문
  // ─────────────────────────────────────────────

  static Future<LyricResult> getLyrics(String title, String artist) async {
    debugPrint("==================================================");
    debugPrint("🔍 [LyricsService] 검색 시작: $title / $artist");

    // ── 0. 입력값 정제 ──────────────────────────
    final cleanArtist = _cleanArtist(artist);
    final cleanTitle  = _cleanTitle(title);

    // 아티스트 영문 매핑 (지드래곤 → G-DRAGON)
    final mappedArtist = _artistMapping[cleanArtist] ?? cleanArtist;

    // feat. 제거한 제목 (보조 검색용)
    final noFeatTitle  = _removeFeat(cleanTitle);

    // 특수문자 제거한 제목 (!, ♥, ?, - 등 포함 곡 대비)
    final plainTitle   = _stripSpecialChars(noFeatTitle);

    // ── 1차: 정확한 매칭 (/api/get) ────────────
    debugPrint("👉 [1차] 정확한 매칭: $cleanTitle / $mappedArtist");
    var result = await _fetchExact(cleanTitle, mappedArtist);
    if (result.status == LyricStatus.success) return result;

    // ── 2차: feat. 제거 후 정확한 매칭 ─────────
    if (noFeatTitle != cleanTitle) {
      debugPrint("👉 [2차] feat 제거 후 정확 매칭: $noFeatTitle / $mappedArtist");
      result = await _fetchExact(noFeatTitle, mappedArtist);
      if (result.status == LyricStatus.success) return result;
    }

    // ── 3차: LRCLIB 퍼지 검색 (/api/search) ────
    // 제목+아티스트를 q 파라미터로 한 번에 전달 → 오타/표기 차이에 강함
    debugPrint("👉 [3차] 퍼지 검색: $noFeatTitle / $mappedArtist");
    result = await _fetchFuzzy(noFeatTitle, mappedArtist);
    if (result.status == LyricStatus.success) return result;

    // ── 4차: 제목만으로 퍼지 검색 (아티스트 불일치 대비) ──
    debugPrint("👉 [4차] 제목만 퍼지 검색: $noFeatTitle");
    result = await _fetchFuzzy(noFeatTitle, '');
    if (result.status == LyricStatus.success) return result;

    // ── 4.5차: 특수문자 제거 후 퍼지 검색 (!, ♥, ? 등이 제목에 포함된 경우)
    if (plainTitle != noFeatTitle) {
      debugPrint("👉 [4.5차] 특수문자 제거 퍼지: $plainTitle / $mappedArtist");
      result = await _fetchFuzzy(plainTitle, mappedArtist);
      if (result.status == LyricStatus.success) return result;
    }

    // ── 5차: 수동 로마자 매핑 ───────────────────
    final manualRoman = _manualRomanize(noFeatTitle);
    if (manualRoman != noFeatTitle) {
      debugPrint("👉 [5차] 수동 로마자: $manualRoman / $mappedArtist");
      result = await _fetchExact(manualRoman, mappedArtist);
      if (result.status == LyricStatus.success) return result;
    }

    // ── 6차: 구글 번역 (한국어일 때만) ─────────
    if (_isKorean(noFeatTitle) || _isKorean(mappedArtist)) {
      try {
        debugPrint("🌐 [6차] 구글 번역 검색...");
        final transTitle  = await _translator.translate(noFeatTitle, to: 'en');
        final transArtist = await _translator.translate(mappedArtist, to: 'en');
        debugPrint("✨ 번역: ${transTitle.text} / ${transArtist.text}");

        result = await _fetchExact(transTitle.text, transArtist.text);
        if (result.status == LyricStatus.success) return result;

        // 번역 후에도 퍼지 검색 한 번 더
        result = await _fetchFuzzy(transTitle.text, transArtist.text);
        if (result.status == LyricStatus.success) return result;
      } catch (e) {
        debugPrint("🚨 번역 에러: $e");
      }
    }

    debugPrint("❌ 모든 시도 실패");
    debugPrint("==================================================");
    return LyricResult([], LyricStatus.noLyrics);
  }

<<<<<<< HEAD
  // ─────────────────────────────────────────────
  // 🌐 PRIVATE: API 호출
  // ─────────────────────────────────────────────

  /// /api/get — 제목+아티스트 정확 매칭
  static Future<LyricResult> _fetchExact(String title, String artist) async {
    final params = {
      'track_name': title,
      if (artist.isNotEmpty) 'artist_name': artist,
    };
    final url = Uri.https('lrclib.net', '/api/get', params);
    return _callApi(url);
  }

  /// /api/search — 퍼지(fuzzy) 검색
  /// q 파라미터 하나에 "제목 아티스트"를 합쳐서 넘기면 LRCLIB이 유사 결과를 순위로 반환
  static Future<LyricResult> _fetchFuzzy(String title, String artist) async {
    final q = [title, artist].where((s) => s.isNotEmpty).join(' ');
    final url = Uri.https('lrclib.net', '/api/search', {'q': q});

    try {
      debugPrint("🌐 [Fuzzy] $url");
=======
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
>>>>>>> ee3cf5301f7823a5386c09c5f8c42c31b6ca5536
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final List<dynamic> items = json.decode(utf8.decode(response.bodyBytes));

        // 결과 중 syncedLyrics(싱크 가사) 있는 것 우선, 없으면 plainLyrics
        for (final item in items) {
          final synced = item['syncedLyrics'] as String?;
          if (synced != null && synced.isNotEmpty) {
            final parsed = parseLrc(synced);
            if (parsed.isNotEmpty) {
              debugPrint("✅ [Fuzzy 성공] syncedLyrics (${parsed.length}줄)");
              return LyricResult(parsed, LyricStatus.success);
            }
          }
        }
<<<<<<< HEAD
        for (final item in items) {
          final plain = item['plainLyrics'] as String?;
          if (plain != null && plain.isNotEmpty) {
            final parsed = parseLrc(plain);
            if (parsed.isNotEmpty) {
              debugPrint("✅ [Fuzzy 성공] plainLyrics (${parsed.length}줄)");
              return LyricResult(parsed, LyricStatus.success);
            }
          }
        }
      }
      return LyricResult([], LyricStatus.noLyrics);
    } on TimeoutException {
      debugPrint("🚨 [Fuzzy 타임아웃]");
=======
      } 
      // 404 등 가사가 없는 경우
      return LyricResult([], LyricStatus.noLyrics);
    } on TimeoutException catch (_) {
      // 🚀 타임아웃 에러를 명확히 구분해서 던집니다.
      debugPrint("🚨 [타임아웃] 서버 응답 지연");
>>>>>>> ee3cf5301f7823a5386c09c5f8c42c31b6ca5536
      return LyricResult([], LyricStatus.timeout);
    } catch (e) {
      debugPrint("🚨 [Fuzzy 에러] $e");
      return LyricResult([], LyricStatus.networkError);
    }
  }

  /// 공통 단일 결과 API 호출
  static Future<LyricResult> _callApi(Uri url) async {
    try {
      debugPrint("🌐 [Exact] $url");
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final String? lrc = data['syncedLyrics'] ?? data['plainLyrics'];

        if (lrc != null && lrc.isNotEmpty) {
          final parsed = parseLrc(lrc);
          debugPrint("✅ [Exact 성공] (${parsed.length}줄)");
          return LyricResult(parsed, LyricStatus.success);
        }
      }
      return LyricResult([], LyricStatus.noLyrics);
    } on TimeoutException {
      debugPrint("🚨 [Exact 타임아웃]");
      return LyricResult([], LyricStatus.timeout);
    } catch (e) {
      debugPrint("🚨 [Exact 에러] $e");
      return LyricResult([], LyricStatus.networkError);
    }
  }

  // ─────────────────────────────────────────────
  // 🧹 PRIVATE: 문자열 정제
  // ─────────────────────────────────────────────

  /// 아티스트명 정제
  /// "지드래곤 (G-DRAGON)" → "지드래곤"
  static String _cleanArtist(String artist) {
    String s = artist.split('(')[0].split('[')[0].trim();
    if (s == "Unknown" || s == "알 수 없는 아티스트" || s.isEmpty) return '';
    return s;
  }

  /// 제목 정제
  /// "에잇 (Prod. SUGA) [MV Ver.]" → "에잇"
  /// 단, "(feat. ...)" 제거는 별도 처리해서 아티스트 정보를 살릴 수도 있음
  static String _cleanTitle(String title) {
    // 공통 노이즈 패턴 제거 (순서 중요)
    String s = title
        // Remaster / Deluxe / Live / Radio Edit 등 버전 태그
        .replaceAll(RegExp(r'\s*[\(\[\-]\s*(remaster(ed)?|deluxe|live|radio\s*edit|acoustic|demo|instrumental|mono|stereo|version|ver\.?)\s*[\)\]]?',
            caseSensitive: false), '')
        // 연도 태그: (2023), [2023 Remaster]
        .replaceAll(RegExp(r'\s*[\(\[]\s*\d{4}\s*[\)\]]'), '')
        // 괄호 안 내용 제거 (feat은 나중에 별도 처리)
        .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
        .trim();
    return s.isEmpty ? title.trim() : s;
  }

  /// feat. 아티스트 제거
  /// "에잇 (feat. BTS)" → "에잇"
  static String _removeFeat(String title) {
    return title
        .replaceAll(RegExp(r'\s*[\(\[]\s*feat\.?\s+[^\)\]]+[\)\]]',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*ft\.?\s+[^\(\[,]+',
            caseSensitive: false), '')
        .trim();
  }

  /// 특수문자 제거 (알파벳·숫자·한글·공백만 남김)
  /// "LOVE♥DIVE" → "LOVEDIVE", "What?!" → "What"
  static String _stripSpecialChars(String title) {
    return title
        .replaceAll(RegExp(r"[^\w\s가-힣]"), ' ')  // 특수문자 → 공백
        .replaceAll(RegExp(r'\s+'), ' ')             // 연속 공백 → 단일
        .trim();
  }

  /// 한국어 포함 여부
  static bool _isKorean(String text) =>
      RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]').hasMatch(text);

  /// 주요 한국어 곡명 수동 매핑
  static String _manualRomanize(String title) {
    const map = {
      '에잇': 'eight',
      '밤편지': 'Through the Night',
      '삐삐': 'BBIBBI',
      '팔레트': 'Palette',
      '좋은 날': 'Good Day',
      '라일락': 'LILAC',
      '어제처럼': 'Like Yesterday',
      '봄날': 'Spring Day',
      '피 땀 눈물': 'Blood Sweat & Tears',
      '작은 것들을 위한 시': 'Boy With Luv',
      '다이너마이트': 'Dynamite',
      '버터': 'Butter',
      '허': 'HER',
    };
    return map[title] ?? title;
  }

  // ─────────────────────────────────────────────
  // 📄 PUBLIC: LRC 파서 (기존 유지)
  // ─────────────────────────────────────────────

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