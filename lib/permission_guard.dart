import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

class PermissionGuard extends StatefulWidget {
  final Widget child;

  const PermissionGuard({super.key, required this.child});

  @override
  State<PermissionGuard> createState() => _PermissionGuardState();
}

class _PermissionGuardState extends State<PermissionGuard> with WidgetsBindingObserver {
  bool _isPermissionGranted = true;
  
  // 🎨 Neumorphic Base Color
  final Color _baseColor = const Color(0xFF1E1F23); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check on app launch
    _checkPermission(isInitial: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permission when user returns to the app from settings
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission({bool isInitial = false}) async {
    try {
      final bool status = await NotificationListenerService.isPermissionGranted();
      
      if (_isPermissionGranted != status) {
        setState(() => _isPermissionGranted = status);
        
        // Show welcome toast when permission is newly granted
        if (status) {
          _showWelcomeToast();
        }
      } else if (isInitial && status) {
        // If permission is already granted on launch, show toast after a short delay
        Future.delayed(const Duration(seconds: 1), () => _showWelcomeToast());
      }
    } catch (e) {
      debugPrint("Access Sync Error: $e");
    }
  }

  // ✨ Neumorphic Welcome Toast
  void _showWelcomeToast() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: _baseColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "WELCOME, BETA TESTER",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      "Thank you for joining Meteor Player.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _baseColor,
      body: Stack(
        children: [
          // Background content (Vinyl Player)
          widget.child,

          // Permission Overlay Layer
          if (!_isPermissionGranted)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: _baseColor.withValues(alpha: 0.98),
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- Neumorphic Icon Shield ---
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _baseColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          offset: const Offset(12, 12),
                          blurRadius: 24,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.04),
                          offset: const Offset(-12, -12),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.settings_input_component_rounded,
                      color: Colors.white60,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 60),
                  const Text(
                    "CORE ACCESS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "To enable high-fidelity vinyl synchronization,\nNotification Access is required.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 80),
                  // --- Neumorphic Button ---
                  GestureDetector(
                    onTap: () async {
                      await NotificationListenerService.requestPermission();
                    },
                    child: Container(
                      width: double.infinity,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _baseColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            offset: const Offset(8, 8),
                            blurRadius: 16,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.05),
                            offset: const Offset(-8, -8),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "GRANT SYSTEM ACCESS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
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