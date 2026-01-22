// lib/color_manager.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorManager {
  // 저장된 색상 불러오기
  static Future<Map<String, Color>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'bg': Color(prefs.getInt('bg_color') ?? 0xFFE1E0E5), // 요청값 #E1E0E5
      'lp': Color(prefs.getInt('lp_color') ?? 0xFF2A292E), // 요청값 #2A292E
      'text': Color(prefs.getInt('text_color') ?? 0xFF333335), // 요청값 #333335
      'artist': Color(
        prefs.getInt('artist_color') ?? 0xFF8F7AB3,
      ), // 요청값 #8F7AB3
      'bar': Color(prefs.getInt('bar_color') ?? 0xFFB1A1D0), // 요청값 #B1A1D0
      'btn': Color(prefs.getInt('btn_color') ?? 0xFF735DA5),
    };
  }

  // 개별 색상 저장
  static Future<void> saveColor(String target, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${target}_color', color.value);
  }

  // 설정 초기화
  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
