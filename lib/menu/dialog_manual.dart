import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/glass_material.dart';
import '../theme/design_tokens.dart';

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
    return GlassPopupShell(
        maxWidth: 440,
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
                        "HIFI VINYL INTERACTION",
                        "• Single Tap: Toggle synchronized lyrics mode.\n• Double Tap: Switch view to high-resolution album artwork.\n• Long Press: Execute system cache cleaning and metadata refresh.",
                      ),
                      _buildManualItem(
                        Icons.linear_scale_rounded,
                        "TIMELINE NAVIGATION",
                        "The dynamic progress bar supports manual seeking. Slide to calibrate the playback position and instantly synchronize lyrics to the target timestamp.",
                      ),
                      _buildManualItem(
                        Icons.settings_input_component_rounded,
                        "LEFT ACCESS PANEL",
                        "Use the top-left drop-down menu to trigger Picture-in-Picture (PiP) mode for multitasking or activate the Neural Screen Lock to prevent accidental touch input.",
                      ),
                      _buildManualItem(
                        Icons.palette_outlined,
                        "RIGHT CONTROL PANEL",
                        "Access the top-right menu to modify the core interface. Customize theme colors and toggle Edit Mode to reconfigure UI module layouts and positions.",
                      ),
                      _buildManualItem(
                        Icons.layers_outlined,
                        "DYNAMIC INTERFACE EDIT",
                        "Enter Edit Mode to transform the workspace. Drag modules to reposition them and use the resize handle to calibrate your personalized acoustic environment.",
                      ),
                      _buildManualItem(
                        Icons.analytics_outlined,
                        "STABILITY MONITOR",
                        "Hardware-accelerated rendering is active. High-latency spikes (>300ms) trigger auto-optimization protocols to ensure a 60FPS glassmorphism experience.",
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
                    "GLASNYL OPERATING SYSTEM",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "GLASNYL v$appVersion-RELEASE / STABLE",
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
                    fontSize: 11,
                    height: 1.5,
                    fontFamily: 'monospace',
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