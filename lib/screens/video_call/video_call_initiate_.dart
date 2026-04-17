import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:ixes.app/screens/video_call/video_call.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/video_call_provider.dart';

class CallingScreen extends StatefulWidget {
  const CallingScreen({Key? key}) : super(key: key);

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with SingleTickerProviderStateMixin {

  late final VideoCallProvider _provider;
  late AnimationController _pulseController;
  bool _isActioning = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  final AudioPlayer _ringPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _provider = context.read<VideoCallProvider>();
    _provider.addListener(_handleCallStateChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _ringPlayer.setReleaseMode(ReleaseMode.loop);
    _ringPlayer.play(AssetSource('sounds/outgoing.mp3'));
  }

  void _handleCallStateChange() {
    if (!mounted || _isActioning) return;

    if (_provider.callState == CallState.connected) {
      _isActioning = true;
      _provider.removeListener(_handleCallStateChange);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VideoCallScreen()),
      );
      return;
    }

    if (_provider.callState == CallState.ended ||
        _provider.callState == CallState.idle) {
      _isActioning = true;
      _provider.removeListener(_handleCallStateChange);

      final errorMsg = _provider.errorMessage;
      Navigator.of(context).pop();

      if (errorMsg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red[700],
          ),
        );
        _provider.clearMessages();
      }
    }
  }

  Future<void> _cancelCall() async {
    if (_isActioning) return;
    _isActioning = true;
    _provider.removeListener(_handleCallStateChange);
    await _provider.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _provider.removeListener(_handleCallStateChange);
    _pulseController.dispose();
    _ringPlayer.stop();
    _ringPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _cancelCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // ✅ center everything
            children: [
              const Spacer(),

              // ── Animated Avatar ──────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) {
                    return Container(
                      width: 140 + (_pulseController.value * 20),
                      height: 140 + (_pulseController.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue[400]!, Colors.purple[400]!],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (_provider.currentReceiverName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),

              // ── Receiver Name — centered, wraps cleanly ──────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _provider.currentReceiverName ?? 'Unknown',
                  textAlign: TextAlign.center, // ✅ center the text
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Calling dots ─────────────────────────────────
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
                    style: TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                ],
              ),

              const Spacer(),

              // ── Video Call label ─────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.blue[300], size: 20),
                    const SizedBox(width: 8),
                    const Text('Video Call',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 60),

              // ── Controls ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildControlButton(
                    icon: _provider.isMuted ? Icons.mic_off : Icons.mic,
                    color: _provider.isMuted
                        ? Colors.red.withOpacity(0.8)
                        : Colors.white.withOpacity(0.2),
                    onPressed: () {
                      _provider.setMuted(!_provider.isMuted);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 40),

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
                        )
                      ],
                    ),
                    child: IconButton(
                      onPressed: _cancelCall,
                      icon: const Icon(Icons.call_end, size: 35, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 40),

                  _buildControlButton(
                    icon: _provider.isSpeakerOn
                        ? Icons.volume_up
                        : Icons.volume_down,
                    color: _provider.isSpeakerOn
                        ? Colors.blue.withOpacity(0.8)
                        : Colors.white.withOpacity(0.2),
                    onPressed: () {
                      _provider.setSpeaker(!_provider.isSpeakerOn);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}