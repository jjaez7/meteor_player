import 'package:flutter/material.dart';

class PlayerConfig {
  // final을 제거하여 변수 값을 수정할 수 있게 변경합니다.
  Offset lpPos, needlePos, titlePos, artistPos, progressBarPos, playButtonsPos;
  double lpSize,
      needleSize,
      titleSize,
      artistSize,
      progressBarWidth,
      playButtonsWidth;

  PlayerConfig({
    required this.lpPos,
    required this.needlePos,
    required this.titlePos,
    required this.artistPos,
    required this.progressBarPos,
    required this.playButtonsPos,
    required this.lpSize,
    required this.needleSize,
    required this.titleSize,
    required this.artistSize,
    required this.progressBarWidth,
    required this.playButtonsWidth,
  });
}
