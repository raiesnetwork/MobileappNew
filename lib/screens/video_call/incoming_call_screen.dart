import 'package:flutter/material.dart';
import 'package:ixes.app/screens/video_call/video_call.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/video_call_provider.dart';

class IncomingCallScreen extends StatefulWidget {
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final VideoCallProvider _provider;

  bool _isActioning = false; // prevent double-tap
  bool _isPopping   = false; // prevent double-pop → red screen bug

  @override
  void initState() {
    super.initState();
    _provider = context.read<VideoCallProvider>();
    _provider.addListener(_handleCallStateChange);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Called when provider state changes (e.g. caller cancelled)
  // ─────────────────────────────────────────────────────────────────────────
  void _handleCallStateChange() {
    if (!mounted || _isActioning || _isPopping) return;

    // ✅ Only pop on 'ended' — NOT on 'idle'
    // Provider auto-resets ended → idle after 2s which was causing a
    // second pop attempt → red screen / "Unknown" reappear bug
    if (_provider.callState == CallState.ended) {
      debugPrint('📵 IncomingCallScreen: caller cancelled → popping safely');
      _safePop();
    }
  }

  /// Pop safely — never mid-build frame
  void _safePop() {
    if (_isPopping || !mounted) return;
    _isPopping = true;

    // Stop listening immediately so no further state changes fire
    _provider.removeListener(_handleCallStateChange);

    // ✅ addPostFrameCallback = never pop during a build → avoids red screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_handleCallStateChange);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Decline
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onDecline() async {
    if (_isActioning || _isPopping) return;
    _isActioning = true;

    // Remove listener BEFORE rejectCall() so the 'ended' state change
    // doesn't re-trigger _handleCallStateChange → double-pop
    _provider.removeListener(_handleCallStateChange);

    await _provider.rejectCall();

    if (mounted) Navigator.of(context).pop();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Accept
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onAccept() async {
    if (_isActioning || _isPopping) return;
    _isActioning = true;

    _provider.removeListener(_handleCallStateChange);

    await _provider.acceptCall();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VideoCallScreen()),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _onDecline();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Consumer<VideoCallProvider>(
          builder: (context, provider, child) {
            final callerName = provider.currentCallerName ?? 'Unknown Caller';

            return SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Caller avatar with pulse animation
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const _PulseAnimation(),
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
                            callerName.isNotEmpty
                                ? callerName[0].toUpperCase()
                                : '?',
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

                  Text(
                    callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Incoming Video Call...',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Accept / Decline buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Decline
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
                                  )
                                ],
                              ),
                              child: IconButton(
                                onPressed: _onDecline,
                                icon: const Icon(Icons.call_end,
                                    size: 32, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Decline',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16)),
                          ],
                        ),

                        // Accept
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
                                  )
                                ],
                              ),
                              child: IconButton(
                                onPressed: _onAccept,
                                icon: const Icon(Icons.videocam,
                                    size: 32, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Accept',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Pulse ring animation
// ─────────────────────────────────────────────────────────────────────────────
class _PulseAnimation extends StatefulWidget {
  const _PulseAnimation();

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