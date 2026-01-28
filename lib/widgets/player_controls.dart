import 'package:flutter/material.dart';

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final double width;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 재생바: 왼쪽 끝을 제목 시작선에 맞춤 (여백 조정)
          Padding(
            padding: const EdgeInsets.only(left: 48, right: 30, bottom: 35),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: 0.35,
                backgroundColor: Colors.black.withValues(alpha: 0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black87),
                minHeight: 5,
              ),
            ),
          ),

          // 2. 컨트롤 버튼: 다시 이전의 입체적인 디자인으로 복구
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSideButton(Icons.skip_previous_rounded),
              const SizedBox(width: 30),
              _buildMainPlayButton(),
              const SizedBox(width: 30),
              _buildSideButton(Icons.skip_next_rounded),
            ],
          ),
        ],
      ),
    );
  }

  // 기존의 메인 재생 버튼 디자인 (검은색 원형 + 그림자)
  Widget _buildMainPlayButton() {
    return GestureDetector(
      onTap: onTogglePlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEEEE), // 배경색과 통일
          shape: BoxShape.circle,
          boxShadow: isPlaying
              ? [
                  // 재생 중(눌린 느낌): Inner Shadow 효과 모방
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(4, 4),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: const Offset(-4, -4),
                    blurRadius: 10,
                  ),
                ]
              : [
                  // 정지 중(튀어나온 느낌): 전통적인 네오모피즘
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(8, 8),
                    blurRadius: 16,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: const Offset(-8, -8),
                    blurRadius: 16,
                  ),
                ],
        ),
        child: Center(
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: const Color(0xFF1A1A1A),
            size: 35,
          ),
        ),
      ),
    );
  }

  // 기존의 서브 버튼 디자인 (연한 회색 아이콘)
  Widget _buildSideButton(IconData icon) {
    return Icon(icon, size: 35, color: Colors.black.withValues(alpha: 0.6));
  }
}
