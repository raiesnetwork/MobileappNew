import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ixes.app/providers/voice_call_provider.dart';
import 'package:ixes.app/screens/widgets/video_call.dart';
import 'package:ixes.app/screens/widgets/voice_call.dart';
import 'dart:convert';
import 'dart:async';
import 'package:ixes.app/screens/BottomNaviagation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../services/api_service.dart';

class VoiceRoomScreen extends StatefulWidget {
  final bool fromFcmAutoAccept;
  const VoiceRoomScreen({Key? key, this.fromFcmAutoAccept = false}) : super(key: key);

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  late final VoiceCallProvider _provider;

  Room? _room;
  bool _isMicEnabled = true;
  bool _isSpeakerOn = true;
  bool _isConnecting = true;
  bool _isEnding = false;

  // ✅ FIX: _hasJoined removed — screens now always handle state changes
  // The old guard caused "stuck on connecting" when remote ended during join

  Timer? _callTimer;
  int _callDuration = 0;

  AudioPlayer? _ringPlayer;
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<VoiceCallProvider>();
    debugPrint(
        '🏁 VoiceRoomScreen: initState | callState=${_provider.callState} | acceptedViaCallKit=${_provider.acceptedViaCallKit} | isReceiver=${_provider.isReceiver} | fromFcmAutoAccept=${widget.fromFcmAutoAccept}');

    // ✅ FIX: Check if call already ended before screen was built (race condition)
    if (_provider.callEndedBeforeJoin || _provider.callState == VoiceCallState.ended) {
      debugPrint('⚠️ VoiceRoomScreen: call already ended before screen built — closing immediately');
      _provider.clearCallEndedBeforeJoin();
      WidgetsBinding.instance.addPostFrameCallback((_) => _closeScreen());
      return;
    }

    _provider.addListener(_handleCallStateChange);

    if (_provider.isReceiver && !_provider.acceptedViaCallKit) {
      _initAndStartRinging();
    }

    _joinRoom();
    _startCallTimer();
  }

  Future<void> _initAndStartRinging() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      _ringPlayer = AudioPlayer();
      await _ringPlayer!.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer!.play(AssetSource('sounds/ringtone.mp3'));
    } catch (e) {
      debugPrint('⚠️ VoiceRoomScreen: could not start ringtone: $e');
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
      debugPrint('⚠️ VoiceRoomScreen: could not stop ringtone: $e');
    } finally {
      _ringPlayer = null;
    }
  }

// REPLACE WITH:
  void _handleCallStateChange() {
    if (!mounted || _isEnding) return;
    debugPrint('🔔 VoiceRoomScreen: callState=${_provider.callState}');

    if (_provider.callState == VoiceCallState.ended ||
        (_provider.callState == VoiceCallState.idle && _isConnecting)) {
      debugPrint('📴 VoiceRoomScreen: remote ended → closing');
      _closeScreen();
    }
  }

  void _closeScreen() {
    if (_isEnding) return;
    _isEnding = true;
    _stopRinging();
    _provider.removeListener(_handleCallStateChange);
    _provider.clearCallEndedBeforeJoin();
    final room = _room;
    _room = null;
    room?.disconnect();
    _callTimer?.cancel();
    FlutterCallkitIncoming.endAllCalls();
    if (mounted) {
      if (widget.fromFcmAutoAccept) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => VoiceCallListener(
              child: IncomingCallListener(
                child: MainScreen(key: mainScreenKey, initialIndex: 0),
              ),
            ),
          ),
              (route) => false,
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<List<RTCIceServer>> _fetchIceServers() async {
    try {
      final response = await ApiService.get('/api/chat/get-turn-credentials');

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] as Map<String, dynamic>?;
        final iceList = (data?['iceServers'] ?? data?['ice_servers']) as List<dynamic>?;

        if (iceList != null && iceList.isNotEmpty) {
          debugPrint('✅ Got ${iceList.length} ICE servers from Twilio');
          return iceList.map((server) {
            final s = server as Map<String, dynamic>;
            final rawUrl = s['urls'] ?? s['url'];
            final urlString = rawUrl?.toString() ?? '';
            final username = s['username']?.toString();
            final credential = s['credential']?.toString();
            return RTCIceServer(
              urls: [urlString],
              username: username,
              credential: credential,
            );
          }).toList();
        }
      }
      debugPrint('⚠️ ICE fetch failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('⚠️ Could not fetch ICE servers: $e');
    }

    return [RTCIceServer(urls: ['stun:stun.l.google.com:19302'])];
  }

  Future<void> _joinRoom() async {
    try {
      // ✅ FIX: Check if call ended before we even start joining
      if (_isEnding || _provider.callState == VoiceCallState.ended) {
        debugPrint('⚠️ VoiceRoomScreen: call already ended — aborting join');
        _closeScreen();
        return;
      }

      final bool isReceiver = _provider.isReceiver;
      final bool wasAutoAccepted = _provider.acceptedViaCallKit;

      debugPrint('🔑 VoiceRoomScreen: isReceiver=$isReceiver | autoAccepted=$wasAutoAccepted | roomName=${_provider.currentRoomName}');

      if (isReceiver) {
        debugPrint('📞 VoiceRoomScreen: receiver emitting acceptVoiceCall...');
        await _provider.acceptVoiceCall();
        await _stopRinging();
      } else {
        debugPrint('🎙️ VoiceRoomScreen: CALLER side — skipping acceptVoiceCall emit');
      }

      // ✅ FIX: Check again after acceptVoiceCall — remote may have cancelled
      if (_isEnding || _provider.callState == VoiceCallState.ended) {
        debugPrint('⚠️ VoiceRoomScreen: call ended during acceptVoiceCall — aborting');
        _closeScreen();
        return;
      }

      debugPrint('🎫 VoiceRoomScreen: fetching voice token...');
      bool success = await _provider.fetchVoiceToken();
      if (!success) {
        debugPrint('⚠️ VoiceRoomScreen: token fetch failed, retrying in 1s...');
        await Future.delayed(const Duration(seconds: 1));
        // ✅ FIX: Check again after delay
        if (_isEnding || _provider.callState == VoiceCallState.ended) {
          _closeScreen();
          return;
        }
        success = await _provider.fetchVoiceToken();
      }
      if (!success) {
        debugPrint('❌ VoiceRoomScreen: token fetch failed after retry');
        _showError('Failed to get call token');
        return;
      }
      debugPrint('✅ VoiceRoomScreen: token fetched');

      // ✅ FIX: Check again before connecting to LiveKit
      if (_isEnding || _provider.callState == VoiceCallState.ended) {
        debugPrint('⚠️ VoiceRoomScreen: call ended before LiveKit connect — aborting');
        _closeScreen();
        return;
      }

      final iceServers = await _fetchIceServers();
      debugPrint('🌐 VoiceRoomScreen: using ${iceServers.length} ICE servers');

      debugPrint('🔌 VoiceRoomScreen: connecting to LiveKit...');
      _room = Room();
      await _room!.connect(
        'wss://meet.ixes.ai',
        _provider.voiceToken!,
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
        connectOptions: ConnectOptions(
          rtcConfiguration: RTCConfiguration(iceServers: iceServers),
        ),
      );

      // ✅ FIX: Check once more after LiveKit connect
      if (_isEnding || _provider.callState == VoiceCallState.ended) {
        debugPrint('⚠️ VoiceRoomScreen: call ended during LiveKit connect — cleaning up');
        await _room?.disconnect();
        _room = null;
        _closeScreen();
        return;
      }

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      _room!.addListener(_onRoomUpdate);
      _provider.notifyParticipantJoined();

      debugPrint('✅ VoiceRoomScreen: joined LiveKit room');

      if (mounted) setState(() => _isConnecting = false);
    } catch (e) {
      debugPrint('❌ VoiceRoomScreen: error joining room: $e');
      if (!_isEnding) _showError('Failed to join call: $e');
    }
  }

  void _onRoomUpdate() {
    if (mounted && !_isEnding) setState(() {});
  }

  Future<void> _toggleMicrophone() async {
    if (_room != null) {
      _isMicEnabled = !_isMicEnabled;
      await _room!.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
      if (mounted) setState(() {});
    }
  }

  void _toggleSpeaker() {
    if (mounted) setState(() => _isSpeakerOn = !_isSpeakerOn);
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    debugPrint('📴 VoiceRoomScreen: user ended call');
    _isEnding = true;
    await _stopRinging();
    _provider.removeListener(_handleCallStateChange);
    _provider.notifyParticipantLeft();
    await _provider.endVoiceCall();
    final room = _room;
    _room = null;
    await room?.disconnect();
    _callTimer?.cancel();
    await FlutterCallkitIncoming.endAllCalls();
    if (mounted) {
      if (widget.fromFcmAutoAccept) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => VoiceCallListener(
              child: IncomingCallListener(
                child: MainScreen(key: mainScreenKey, initialIndex: 0),
              ),
            ),
          ),
              (route) => false,
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void _showError(String message) {
    debugPrint('❌ VoiceRoomScreen: error: $message');
    _stopRinging();
    _isEnding = true;
    _provider.removeListener(_handleCallStateChange);
    final room = _room;
    _room = null;
    room?.disconnect();
    _callTimer?.cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      if (widget.fromFcmAutoAccept) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => VoiceCallListener(
              child: IncomingCallListener(child: MainScreen(key: mainScreenKey, initialIndex: 0)),
            ),
          ),
              (route) => false,
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 VoiceRoomScreen: dispose');
    _stopRinging();
    _provider.removeListener(_handleCallStateChange);
    _callTimer?.cancel();
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    _room = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white54)),
              SizedBox(height: 20),
              Text('Connecting...', style: TextStyle(color: Colors.white54, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final callerName = _provider.currentReceiverName ?? _provider.currentCallerName ?? 'Voice Call';

    return WillPopScope(
      onWillPop: () async {
        await _endCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [Color(0xFF1A1A2E), Color(0xFF0D0D14)],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildCenterContent(callerName)),
                  _buildControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _circleIconButton(icon: Icons.keyboard_arrow_down, onTap: () => _endCall()),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text('End-to-end encrypted',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          ),
          const Spacer(),
          _circleIconButton(icon: Icons.person_add_alt_1_outlined, onTap: () {}),
        ],
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildCenterContent(String callerName) {
    return Consumer<VoiceCallProvider>(
      builder: (_, provider, __) {
        final isWaiting = _isConnecting;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF4A90D9), Color(0xFF845EC2)],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4A90D9).withOpacity(0.35), blurRadius: 40, spreadRadius: 8),
                ],
              ),
              child: const Icon(Icons.person, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                callerName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isWaiting)
              Text('Connecting...', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 16))
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_formatDuration(_callDuration),
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _smallControlButton(
            icon: _provider.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: _provider.isSpeakerOn ? Colors.blue.withOpacity(0.8) : Colors.white.withOpacity(0.12),
            onPressed: () => _provider.setSpeaker(!_provider.isSpeakerOn),
          ),
          _smallControlButton(
            icon: _isSpeakerOn ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
            color: _isSpeakerOn ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.06),
            onPressed: _toggleSpeaker,
          ),
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: Colors.redAccent, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.45), blurRadius: 24, spreadRadius: 2)],
              ),
              child: const Icon(Icons.call_end_rounded, size: 30, color: Colors.white),
            ),
          ),
          _smallControlButton(
            icon: _provider.isMuted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
            color: _provider.isMuted ? Colors.redAccent.withOpacity(0.8) : Colors.white.withOpacity(0.12),
            onPressed: () async {
              _provider.setMuted(!_provider.isMuted);
              await _room?.localParticipant?.setMicrophoneEnabled(!_provider.isMuted);
              setState(() {});
            },
          ),
          _smallControlButton(
            icon: Icons.dialpad_rounded,
            color: Colors.white.withOpacity(0.12),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _smallControlButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}