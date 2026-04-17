import 'package:audioplayers/audioplayers.dart';
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

  // ✅ BUG 7 FIX: nullable player + _isRinging guard prevents double stop/dispose
  AudioPlayer? _ringPlayer;
  bool _isRinging = false;

  bool _isActioning = false;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<VideoCallProvider>();
    _provider.addListener(_handleCallStateChange);
    _initAndStartRinging();
  }

  Future<void> _initAndStartRinging() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      _ringPlayer = AudioPlayer();
      await _ringPlayer!.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer!.play(AssetSource('sounds/ringtone.mp3'));
    } catch (e) {
      debugPrint('⚠️ IncomingCallScreen: could not play ringtone: $e');
      _isRinging = false;
    }
  }

  Future<void> _stopRinging() async {
    if (!_isRinging || _ringPlayer == null) return;
    _isRinging = false;
    try {
      await _ringPlayer!.stop();
      await _ringPlayer!.dispose();
    } catch (e) {
      debugPrint('⚠️ IncomingCallScreen: could not stop ringtone: $e');
    } finally {
      _ringPlayer = null; // ✅ Null out — dispose() won't touch it again
    }
  }

  void _handleCallStateChange() {
    if (!mounted || _isActioning || _isPopping) return;

    if (_provider.callState == CallState.ended) {
      debugPrint('📵 IncomingCallScreen: caller cancelled → popping safely');
      _safePop();
    }
  }

  void _safePop() {
    if (_isPopping || !mounted) return;
    _isPopping = true;
    _provider.removeListener(_handleCallStateChange);
    _stopRinging(); // safe — guarded by _isRinging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_handleCallStateChange);
    _stopRinging(); // ✅ No-op if already stopped
    super.dispose();
  }

  Future<void> _onDecline() async {
    if (_isActioning || _isPopping) return;
    _isActioning = true;
    _provider.removeListener(_handleCallStateChange);
    await _stopRinging();
    await _provider.rejectCall();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onAccept() async {
    if (_isActioning || _isPopping) return;
    _isActioning = true;
    _provider.removeListener(_handleCallStateChange);
    await _stopRinging();
    // ✅ acceptCall() is now handled inside VideoCallScreen._joinRoom()
    // so we do NOT call _provider.acceptCall() here — it would double-emit
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VideoCallScreen()),
      );
    }
  }

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
                            callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
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
                                      spreadRadius: 2)
                                ],
                              ),
                              child: IconButton(
                                onPressed: _onDecline,
                                icon: const Icon(Icons.call_end, size: 32, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Decline',
                                style: TextStyle(color: Colors.white70, fontSize: 16)),
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
                                      spreadRadius: 2)
                                ],
                              ),
                              child: IconButton(
                                onPressed: _onAccept,
                                icon: const Icon(Icons.videocam, size: 32, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Accept',
                                style: TextStyle(color: Colors.white70, fontSize: 16)),
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