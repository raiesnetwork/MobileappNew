import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/video_call_provider.dart';
import '../video_call/incoming_call_screen.dart';

class IncomingCallListener extends StatefulWidget {
  final Widget child;
  const IncomingCallListener({Key? key, required this.child}) : super(key: key);

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  late final VideoCallProvider _provider;
  bool _isShowingIncomingScreen = false; // ✅ prevents double push

  @override
  void initState() {
    super.initState();
    // ✅ Read directly in initState — safe here (not in build or dispose)
    _provider = context.read<VideoCallProvider>();
    _provider.addListener(_handleCallStateChange);
  }

  @override
  void dispose() {
    _provider.removeListener(_handleCallStateChange);
    super.dispose();
  }

  void _handleCallStateChange() {
    if (!mounted) return;

    // ✅ Only show on ringing + caller name exists + not already showing
    if (_provider.callState == CallState.ringing &&
        _provider.currentCallerName != null &&
        _provider.currentCallerName!.isNotEmpty &&
        !_provider.acceptedViaCallKit &&
        !_isShowingIncomingScreen) {

      _isShowingIncomingScreen = true;
      debugPrint('📲 IncomingCallListener: pushing IncomingCallScreen');

      // ✅ postFrameCallback — never push mid-build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(),
            fullscreenDialog: true,
          ),
        ).then((_) {
          // ✅ Reset when screen is popped for any reason
          _isShowingIncomingScreen = false;
          debugPrint('📲 IncomingCallListener: IncomingCallScreen dismissed');
        });
      });
    }

    // ✅ DO NOT handle ended/idle here — IncomingCallScreen pops itself
    // Handling it here too = double pop = black screen / app crash
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}