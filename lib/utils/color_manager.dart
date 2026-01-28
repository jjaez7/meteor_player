import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorManager {
  // 저장된 색상 불러오기
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    // 모든 테마 관련 키값을 삭제합니다.
    await prefs.remove('bg');
    await prefs.remove('lp');
    await prefs.remove('text');
    await prefs.remove('artist');
    await prefs.remove('bar');
    await prefs.remove('btn');
    debugPrint("저장된 모든 색상 데이터가 삭제되었습니다.");
  }

  // 개별 색상 저장
  static Future<void> saveColor(String target, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${target}_color', color.toARGB32());
  }

  // 설정 초기화
  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
