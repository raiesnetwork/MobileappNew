import 'package:flutter/material.dart';
import 'package:ixes.app/screens/voice_call/voice_call_room_screen.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/voice_call_provider.dart';

class IncomingVoiceCallDialog extends StatefulWidget {
  const IncomingVoiceCallDialog({Key? key}) : super(key: key);

  @override
  State<IncomingVoiceCallDialog> createState() =>
      _IncomingVoiceCallDialogState();
}

class _IncomingVoiceCallDialogState extends State<IncomingVoiceCallDialog>
    with SingleTickerProviderStateMixin {
  late final VoiceCallProvider _provider;
  late AnimationController _animationController;

  bool _isActioning = false; // prevent double-tap
  bool _isPopping   = false; // prevent double-pop (the red screen bug)

  @override
  void initState() {
    super.initState();
    _provider = context.read<VoiceCallProvider>();
    _provider.addListener(_handleCallStateChange);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Called when provider state changes (e.g. caller cancelled)
  // ─────────────────────────────────────────────────────────────────────────
  void _handleCallStateChange() {
    // ✅ Guard 1: don't act if we're already in the middle of an action
    if (!mounted || _isActioning || _isPopping) return;

    // ✅ Only pop on 'ended' — NOT on 'idle'.
    // The provider auto-resets ended → idle after 2s. If we also pop on idle
    // we get a second pop which causes the "Unknown" reappearing screen bug.
    if (_provider.callState == VoiceCallState.ended) {
      debugPrint('📵 IncomingVoiceCallDialog: caller cancelled → popping safely');
      _safePop();
    }
  }

  /// Pops the screen safely, even if called during a build frame.
  void _safePop() {
    if (_isPopping || !mounted) return;
    _isPopping = true;

    // Remove listener immediately so no further state changes trigger us
    _provider.removeListener(_handleCallStateChange);

    // ✅ Use addPostFrameCallback so we never pop mid-build (avoids red screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_handleCallStateChange);
    _animationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Decline
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onDecline() async {
    if (_isActioning || _isPopping) return;
    _isActioning = true;

    // Remove listener BEFORE rejecting so the resulting state change
    // to 'ended' doesn't trigger _handleCallStateChange → double-pop
    _provider.removeListener(_handleCallStateChange);

    await _provider.rejectVoiceCall();

    if (mounted) Navigator.of(context).pop();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Accept
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onAccept() async {
    if (_isActioning || _isPopping) return;
    _isActioning = true;

    _provider.removeListener(_handleCallStateChange);

    await _provider.acceptVoiceCall();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VoiceRoomScreen()),
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
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                      onPressed: _onDecline,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_animationController.value * 0.15),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.purple[400]!],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.phone, size: 60, color: Colors.white),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              const Text(
                'Incoming Voice Call',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              Consumer<VoiceCallProvider>(
                builder: (_, provider, __) => Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blue[300]!, Colors.purple[300]!],
                        ),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.currentCallerName ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.isConference ? 'Conference Call' : 'Voice Call',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    Column(
                      children: [
                        Container(
                          width: 75,
                          height: 75,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 3,
                              )
                            ],
                          ),
                          child: IconButton(
                            onPressed: _onDecline,
                            icon: const Icon(Icons.call_end, size: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Decline',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),

                    // Accept
                    Column(
                      children: [
                        Container(
                          width: 75,
                          height: 75,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 3,
                              )
                            ],
                          ),
                          child: IconButton(
                            onPressed: _onAccept,
                            icon: const Icon(Icons.call, size: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Accept',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}