import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/voice_call_provider.dart';
import '../voice_call/incming_voice_call.dart';

class VoiceCallListener extends StatefulWidget {
  final Widget child;
  const VoiceCallListener({Key? key, required this.child}) : super(key: key);

  @override
  State<VoiceCallListener> createState() => _VoiceCallListenerState();
}

class _VoiceCallListenerState extends State<VoiceCallListener> {
  late final VoiceCallProvider _provider;
  bool _isShowingIncomingScreen = false; // ✅ prevents double push

  @override
  void initState() {
    super.initState();
    _provider = context.read<VoiceCallProvider>();
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
    if (_provider.callState == VoiceCallState.ringing &&
        _provider.currentCallerName != null &&
        _provider.currentCallerName!.isNotEmpty &&
        !_provider.acceptedViaCallKit &&
        !_isShowingIncomingScreen) {

      _isShowingIncomingScreen = true;
      debugPrint('📞 VoiceCallListener: pushing IncomingVoiceCallDialog');
      debugPrint('📞 Caller: ${_provider.currentCallerName}');

      // ✅ postFrameCallback — never push mid-build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // ✅ Use Navigator.push NOT showDialog
        // Old showDialog + _dismissDialog caused double-pop = black screen crash
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const IncomingVoiceCallDialog(),
            fullscreenDialog: true,
          ),
        ).then((_) {
          // ✅ Reset when screen is popped for any reason
          _isShowingIncomingScreen = false;
          debugPrint('📞 VoiceCallListener: IncomingVoiceCallDialog dismissed');
        });
      });
    }

    // ✅ NO else-if dismissing here — IncomingVoiceCallDialog pops itself.
    // The old _dismissDialog() here was the exact cause of the double-pop crash.
  }

  @override
  Widget build(BuildContext context) {
    // ✅ No Consumer in build — Consumer was calling addPostFrameCallback
    // on every rebuild, queuing multiple handler calls → multiple screen pushes
    return widget.child;
  }
}