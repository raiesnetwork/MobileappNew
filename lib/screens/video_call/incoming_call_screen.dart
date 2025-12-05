import 'package:flutter/material.dart';
import 'package:ixes.app/screens/video_call/video_call.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/video_call_provider.dart';

class IncomingCallScreen extends StatefulWidget {
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  @override
  void initState() {
    super.initState();
    _setupCallEndListener();
  }

  void _setupCallEndListener() {
    final provider = context.read<VideoCallProvider>();
    provider.addListener(_handleCallStateChange);
  }

  void _handleCallStateChange() {
    if (!mounted) return;

    final provider = context.read<VideoCallProvider>();

    // If call ended while on incoming screen, close this screen
    if (provider.callState == CallState.ended) {
      Navigator.of(context).pop();

      if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!)),
        );
      }
    }
  }

  @override
  void dispose() {
    try {
      final provider = context.read<VideoCallProvider>();
      provider.removeListener(_handleCallStateChange);
    } catch (e) {
      debugPrint('Error removing listener: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button - user must accept or reject
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Consumer<VideoCallProvider>(
          builder: (context, provider, child) {
            // Debug print to verify data
            debugPrint('📱 Incoming call from: ${provider.currentCallerName}');
            debugPrint('📱 Caller ID: ${provider.currentCallerId}');

            final callerName = provider.currentCallerName ?? 'Unknown Caller';

            return SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Caller Avatar with pulse animation
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse effect
                      _PulseAnimation(),

                      // Avatar
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.green[400]!, Colors.blue[400]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            callerName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Caller Name
                  Text(
                    callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Incoming call text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.videocam, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Incoming Video Call...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Reject Button
                        Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () {
                                  provider.rejectCall();
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(
                                  Icons.call_end,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Decline',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),

                        // Accept Button
                        Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  await provider.acceptCall();

                                  // Navigate to video call screen
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => VideoCallScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.videocam,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Pulse animation widget
class _PulseAnimation extends StatefulWidget {
  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 120 * _animation.value,
          height: 120 * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.green.withOpacity(1 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}