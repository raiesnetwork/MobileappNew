import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:ixes.app/screens/voice_call/voice_call_room_screen.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/voice_call_provider.dart';

class IncomingVoiceCallDialog extends StatefulWidget {
  const IncomingVoiceCallDialog({Key? key}) : super(key: key);

  @override
  State<IncomingVoiceCallDialog> createState() => _IncomingVoiceCallDialogState();
}

class _IncomingVoiceCallDialogState extends State<IncomingVoiceCallDialog>
    with SingleTickerProviderStateMixin {
  late final VoiceCallProvider _provider;
  late AnimationController _animationController;

  // ✅ BUG 7 FIX: nullable player + guard prevents double stop/dispose
  AudioPlayer? _ringPlayer;
  bool _isRinging = false;

  bool _isActioning = false;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<VoiceCallProvider>();
    _provider.addListener(_handleCallStateChange);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

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
      debugPrint('⚠️ IncomingVoiceCallDialog: could not play ringtone: $e');
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
      debugPrint('⚠️ IncomingVoiceCallDialog: could not stop ringtone: $e');
    } finally {
      _ringPlayer = null; // ✅ Null out — dispose() is a no-op after this
    }
  }

  void _handleCallStateChange() {
    if (!mounted || _isActioning || _isPopping) return;

    if (_provider.callState == VoiceCallState.ended) {
      debugPrint('📵 IncomingVoiceCallDialog: caller cancelled → popping safely');
      _safePop();
    }
  }

  void _safePop() {
    if (_isPopping || !mounted) return;
    _isPopping = true;
    _provider.removeListener(_handleCallStateChange);
    _stopRinging();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_handleCallStateChange);
    _animationController.dispose();
    _stopRinging(); // ✅ No-op if already stopped and nulled
    super.dispose();
  }

  Future<void> _onDecline() async {
    if (_isActioning || _isPopping) return;
    _isActioning = true;
    _provider.removeListener(_handleCallStateChange);
    await _stopRinging();
    await _provider.rejectVoiceCall();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onAccept() async {
    if (_isActioning || _isPopping) return;
    _isActioning = true;
    _provider.removeListener(_handleCallStateChange);
    await _stopRinging();
    // ✅ acceptVoiceCall() is handled inside VoiceRoomScreen._joinRoom()
    // Do NOT call it here — would cause double-emit
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VoiceRoomScreen()),
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
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.isConference ? 'Conference Call' : 'Voice Call',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
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
                                  spreadRadius: 3)
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
                                  spreadRadius: 3)
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