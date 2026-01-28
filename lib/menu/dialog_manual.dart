import 'dart:ui';
import 'package:flutter/material.dart';

void showManualDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (context) => const ManualDialog(),
  );
}

class ManualDialog extends StatelessWidget {
  const ManualDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Dialog(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header ---
              Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: Color(0xFFD1C4E9), size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    "SYSTEM PROTOCOL",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.3)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 24),

              // --- Manual List ---
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildManualItem(
                        Icons.album_rounded,
                        "HIFI ACOUSTIC ENGINE",
                        "Tap the center vinyl to toggle the playback state. The rotation speed is hardware-accelerated and synchronized with the core audio stream.",
                      ),
                      _buildManualItem(
                        Icons.lock_clock_rounded,
                        "NEURAL SCREEN LOCK",
                        "Activate safety mode via the lock icon to prevent unintentional input. To restore access, perform a sustained 'Long Press' on the overlay.",
                      ),
                      _buildManualItem(
                        Icons.layers_outlined,
                        "DYNAMIC INTERFACE EDIT",
                        "Enter 'Edit Mode' from the primary menu to reconfigure UI modules. Drag and drop elements to calibrate your personalized acoustic workspace.",
                      ),
                      _buildManualItem(
                        Icons.analytics_outlined,
                        "PERFORMANCE MONITOR",
                        "Real-time frame monitoring is active. High-latency spikes (>300ms) trigger auto-optimization protocols to ensure a seamless experience.",
                      ),
                    ],
                  ),
                ),
              ),

              // --- Footer ---
              const SizedBox(height: 20),
              Column(
                children: [
                  Text(
                    "METEOR OPERATING SYSTEM",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "METEOR v1.0.7-RELEASE / STABLE",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.15),
                      fontSize: 8,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Icon(icon, color: const Color(0xFFD1C4E9), size: 18),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11.5,
                    height: 1.6,
                    fontFamily: 'monospace', // 기계적인 느낌을 주기 위해 모노스페이스 권장
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}