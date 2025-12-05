import 'package:flutter/material.dart';
import 'package:ixes.app/screens/voice_call/voice_call_room_screen.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/voice_call_provider.dart';


class VoiceCallingScreen extends StatefulWidget {
  const VoiceCallingScreen({Key? key}) : super(key: key);

  @override
  State<VoiceCallingScreen> createState() => _VoiceCallingScreenState();
}

class _VoiceCallingScreenState extends State<VoiceCallingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _setupListener();
  }

  void _setupListener() {
    final provider = context.read<VoiceCallProvider>();
    provider.addListener(_handleCallStateChange);
  }

  void _handleCallStateChange() {
    if (!mounted || _isNavigating) return;

    final provider = context.read<VoiceCallProvider>();

    if (provider.callState == VoiceCallState.connected) {
      // Navigate to voice room
      _isNavigating = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VoiceRoomScreen()),
      );
    } else if (provider.callState == VoiceCallState.ended) {
      _isNavigating = true;
      Navigator.pop(context);

      if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    try {
      context.read<VoiceCallProvider>().removeListener(_handleCallStateChange);
    } catch (e) {
      debugPrint('Error removing listener: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isNavigating) {
          context.read<VoiceCallProvider>().endVoiceCall();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Consumer<VoiceCallProvider>(
          builder: (context, provider, child) {
            return SafeArea(
              child: Column(
                children: [
                  const Spacer(),

                  // Animated Avatar
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 140 + (_pulseController.value * 20),
                        height: 140 + (_pulseController.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue[400]!,
                              Colors.purple[400]!,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 70,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),

                  // Receiver Name
                  Text(
                    provider.currentReceiverName ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status with animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(0),
                      const SizedBox(width: 4),
                      _buildDot(1),
                      const SizedBox(width: 4),
                      _buildDot(2),
                      const SizedBox(width: 12),
                      const Text(
                        'Calling',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Call Type Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone,
                          color: Colors.blue[300],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Voice Call',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mute button (disabled during calling)
                      _buildControlButton(
                        icon: Icons.mic_off,
                        color: Colors.white.withOpacity(0.2),
                        onPressed: null, // Disabled
                      ),
                      const SizedBox(width: 40),

                      // End Call Button
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 25,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (!_isNavigating) {
                              _isNavigating = true;
                              provider.endVoiceCall();
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(
                            Icons.call_end,
                            size: 35,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),

                      // Speaker button (disabled during calling)
                      _buildControlButton(
                        icon: Icons.volume_up,
                        color: Colors.white.withOpacity(0.2),
                        onPressed: null, // Disabled
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final delay = index * 0.3;
        final value = (_pulseController.value + delay) % 1.0;
        final opacity = 0.3 + (value * 0.7);

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}