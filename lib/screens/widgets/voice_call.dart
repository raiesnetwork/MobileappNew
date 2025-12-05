import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/voice_call_provider.dart';


import '../voice_call/incming_voice_call.dart';
class VoiceCallListener extends StatefulWidget {
  final Widget child;

  const VoiceCallListener({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<VoiceCallListener> createState() => _VoiceCallListenerState();
}

class _VoiceCallListenerState extends State<VoiceCallListener> {
  VoiceCallState? _previousState;
  bool _isDialogShowing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceCallProvider>(
      builder: (context, provider, child) {
        // Listen for state changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleStateChange(provider);
        });

        return widget.child;
      },
    );
  }

  void _handleStateChange(VoiceCallProvider provider) {
    final currentState = provider.callState;

    debugPrint('🎯 VoiceCallListener: State changed from $_previousState to $currentState');
    debugPrint('🎯 Dialog showing: $_isDialogShowing');

    // Show dialog when call is ringing and dialog is not already showing
    if (currentState == VoiceCallState.ringing &&
        _previousState != VoiceCallState.ringing &&
        !_isDialogShowing) {
      debugPrint('📞 SHOWING INCOMING CALL DIALOG');
      debugPrint('📞 Caller: ${provider.currentCallerName}');
      _showIncomingCallDialog();
    }

    // Dismiss dialog if call state changes from ringing to something else
    else if (_previousState == VoiceCallState.ringing &&
        currentState != VoiceCallState.ringing &&
        _isDialogShowing) {
      debugPrint('❌ DISMISSING INCOMING CALL DIALOG');
      _dismissDialog();
    }

    _previousState = currentState;
  }

  void _showIncomingCallDialog() {
    if (!mounted) return;

    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const IncomingVoiceCallDialog(),
    ).then((_) {
      debugPrint('📞 Dialog dismissed');
      _isDialogShowing = false;
    });
  }

  void _dismissDialog() {
    if (!mounted) return;
    if (_isDialogShowing) {
      Navigator.of(context, rootNavigator: true).pop();
      _isDialogShowing = false;
    }
  }
}