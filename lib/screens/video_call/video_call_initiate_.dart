import 'package:flutter/material.dart';
import 'package:ixes.app/screens/video_call/video_call.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/video_call_provider.dart';

class CallingScreen extends StatefulWidget {
  const CallingScreen({Key? key}) : super(key: key);

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> {

  // ✅ CRITICAL: save provider ref in initState — NEVER use context.read() in dispose()
  late final VideoCallProvider _provider;

  bool _isActioning = false; // prevents double-pop from button + listener

  @override
  void initState() {
    super.initState();
    _provider = context.read<VideoCallProvider>(); // ✅ safe here
    _provider.addListener(_handleCallStateChange);
  }

  void _handleCallStateChange() {
    if (!mounted || _isActioning) return;

    // Receiver accepted → go to video call room
    if (_provider.callState == CallState.connected) {
      _isActioning = true;
      _provider.removeListener(_handleCallStateChange); // stop before navigating
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VideoCallScreen()),
      );
      return;
    }

    // Receiver rejected / call ended → pop back
    if (_provider.callState == CallState.ended ||
        _provider.callState == CallState.idle) {
      _isActioning = true;
      _provider.removeListener(_handleCallStateChange); // stop before popping

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

    // ✅ Remove listener BEFORE calling endCall() to prevent double-pop
    _provider.removeListener(_handleCallStateChange);

    await _provider.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    // ✅ Use saved _provider ref — context.read() crashes here
    _provider.removeListener(_handleCallStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _cancelCall();
        return false; // we handle the pop ourselves
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Avatar
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
                    (_provider.currentReceiverName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Receiver name
              Text(
                _provider.currentReceiverName ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Calling text with animated dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Calling',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(width: 4),
                  const _LoadingDots(),
                ],
              ),

              const Spacer(),

              // ✅ End Call button uses _cancelCall()
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
                  onPressed: _cancelCall,
                  icon: const Icon(Icons.call_end, size: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated loading dots widget
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

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
      builder: (_, __) {
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