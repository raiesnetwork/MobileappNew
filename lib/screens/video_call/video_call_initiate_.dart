import 'package:flutter/material.dart';
import 'package:ixes.app/screens/video_call/video_call.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/video_call_provider.dart';

class CallingScreen extends StatefulWidget {
  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    final videoCallProvider = context.read<VideoCallProvider>();
    videoCallProvider.addListener(_handleCallStateChange);
  }

  void _handleCallStateChange() {
    if (!mounted || _isNavigating) return;

    final videoCallProvider = context.read<VideoCallProvider>();

    if (videoCallProvider.callState == CallState.connected) {
      // Call accepted, navigate to video call screen
      _isNavigating = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => VideoCallScreen()),
      );
    } else if (videoCallProvider.callState == CallState.ended) {
      // Call rejected or ended by receiver
      _isNavigating = true;
      Navigator.of(context).pop();

      if (videoCallProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(videoCallProvider.errorMessage!),
            backgroundColor: Colors.red[700],
          ),
        );
        videoCallProvider.clearMessages();
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
        if (!_isNavigating) {
          final provider = context.read<VideoCallProvider>();
          provider.endCall();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Consumer<VideoCallProvider>(
          builder: (context, provider, child) {
            final receiverName = provider.currentReceiverName ?? 'Unknown';

            return SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // User Avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.purple[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        receiverName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Receiver Name
                  Text(
                    receiverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Calling text with animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Calling',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _LoadingDots(),
                    ],
                  ),

                  const Spacer(),

                  // End Call Button
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
                        if (!_isNavigating) {
                          _isNavigating = true;
                          provider.endCall();
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(
                        Icons.call_end,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
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
}

// Animated loading dots
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dots = (_controller.value * 4).floor() % 4;
        return Text(
          '.' * dots,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            letterSpacing: 2,
          ),
        );
      },
    );
  }
}