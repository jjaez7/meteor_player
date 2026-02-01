//import 'package:flutter/material.dart';

class LyricLine {
  final Duration time;
  final String text;

  LyricLine(this.time, this.text);
}

List<LyricLine> parseLrc(String lrc) {
  final List<LyricLine> lyrics = [];
  // 정규식: [00:00.00] 또는 [00:00.000] 형태 추출
  final RegExp regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

  for (var line in lrc.split('\n')) {
    final match = regExp.firstMatch(line);
    if (match != null) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final msString = match.group(3)!;
      final milliseconds = int.parse(msString);
      
      final duration = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds * (msString.length == 2 ? 10 : 1),
      );
      
      final text = line.replaceFirst(regExp, '').trim();
      if (text.isNotEmpty) {
        lyrics.add(LyricLine(duration, text));
      }
    }
  }
  return lyrics;
}