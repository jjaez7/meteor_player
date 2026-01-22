import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:typed_data';

class SurrealPlayerView extends StatelessWidget {
  final String title;
  final String artist;
  final Uint8List? albumArt;
  final bool isPlaying;
  final Color themeColor;
  final Color textColor;

  const SurrealPlayerView({
    super.key,
    required this.title,
    required this.artist,
    this.albumArt,
    required this.isPlaying,
    required this.themeColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. 배경 오로라 효과 (몽환적인 분위기)
        _buildAuroraBackground(size),

        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 2. 부유하는 앨범 아트 (Glassmorphism + Glow)
            _buildFloatingArt(size),
            
            const SizedBox(height: 50),

            // 3. 감성 타이포그래피
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              artist,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 14,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 40),

            // 4. 이퀄라이저 바 (MZ 감성 커스텀)
            _buildVisualizer(),
          ],
        ),
      ],
    );
  }

  Widget _buildAuroraBackground(Size size) {
    return Container(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: _blurCircle(size.width * 0.8, themeColor.withValues(alpha: 0.3)),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: _blurCircle(size.width * 0.6, themeColor.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildFloatingArt(Size size) {
    return Container(
      width: size.height * 0.35,
      height: size.height * 0.35,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: 5,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: albumArt != null
            ? Image.memory(albumArt!, fit: BoxFit.cover)
            : Container(color: Colors.grey[800]),
      ),
    );
  }

  Widget _buildVisualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(15, (index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: isPlaying ? 150 + (index * 30) : 500),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 3,
          height: isPlaying ? (10 + (index % 4 * 20.0)) : 4,
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}