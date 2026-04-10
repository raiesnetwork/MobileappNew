import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ixes.app/providers/voice_call_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({Key? key}) : super(key: key);

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
  bool _hasJoined = false;

  Timer? _callTimer;
  int _callDuration = 0;

  // ── Ringing (receiver side — plays before LiveKit join) ───────────────
  final AudioPlayer _ringPlayer = AudioPlayer();
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<VoiceCallProvider>();
    debugPrint(
        '🏁 VoiceRoomScreen: initState | callState=${_provider.callState} | acceptedViaCallKit=${_provider.acceptedViaCallKit}');
    _provider.addListener(_handleCallStateChange);

    // FIX: if the call was NOT auto-accepted via CallKit, the receiver
    // must manually accept — ring them here (socket path, not FCM path).
    // FCM path already rings via the system. This covers the in-app case.
    if (!_provider.acceptedViaCallKit) {
      _startRinging();
    }

    _joinRoom();
    _startCallTimer();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RINGING
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _startRinging() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource('sounds/ringtone.mp3'));
    } catch (e) {
      debugPrint('⚠️ VoiceRoomScreen: could not play ringtone: $e');
    }
  }

  Future<void> _stopRinging() async {
    if (!_isRinging) return;
    _isRinging = false;
    try {
      await _ringPlayer.stop();
    } catch (e) {
      debugPrint('⚠️ VoiceRoomScreen: could not stop ringtone: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CALL STATE LISTENER
  // ════════════════════════════════════════════════════════════════════════

  void _handleCallStateChange() {
    if (!mounted || _isEnding) return;

    debugPrint(
        '🔔 VoiceRoomScreen: callState=${_provider.callState} | hasJoined=$_hasJoined | isEnding=$_isEnding');

    if (!_hasJoined) {
      debugPrint(
          '⚠️ VoiceRoomScreen: ignoring state change — not joined yet');
      return;
    }

    if (_provider.callState == VoiceCallState.ended ||
        _provider.callState == VoiceCallState.idle) {
      debugPrint('📴 VoiceRoomScreen: remote ended → closing');
      _closeScreen();
    }
  }

  void _closeScreen() {
    if (_isEnding) return;
    _isEnding = true;
    _stopRinging();
    _provider.removeListener(_handleCallStateChange);
    _room?.disconnect();
    _callTimer?.cancel();
    FlutterCallkitIncoming.endAllCalls();
    if (mounted) Navigator.of(context).pop();
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

  // ════════════════════════════════════════════════════════════════════════
  //  ICE SERVERS
  // ════════════════════════════════════════════════════════════════════════

  Future<List<RTCIceServer>> _fetchIceServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        Uri.parse('https://api.ixes.ai/api/chat/get-turn-credentials'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] as Map<String, dynamic>;
        final iceList = data['iceServers'] as List<dynamic>;
        debugPrint('✅ Got ${iceList.length} ICE servers from Twilio');
        return iceList.map((server) {
          final s = server as Map<String, dynamic>;
          final urls =
              s['urls']?.toString() ?? s['url']?.toString() ?? '';
          final username = s['username']?.toString();
          final credential = s['credential']?.toString();
          return RTCIceServer(
              urls: [urls], username: username, credential: credential);
        }).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Could not fetch ICE servers: $e — using defaults');
    }
    return [RTCIceServer(urls: ['stun:stun.l.google.com:19302'])];
  }

  // ════════════════════════════════════════════════════════════════════════
  //  JOIN ROOM
  //  FIX: token fetch retries once on failure; acceptVoiceCall is called
  //  for non-CallKit flows before connecting to LiveKit.
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _joinRoom() async {
    try {
      final bool wasAutoAccepted = _provider.acceptedViaCallKit;
      debugPrint(
          '🔑 VoiceRoomScreen: autoAccepted=$wasAutoAccepted | roomName=${_provider.currentRoomName}');

      // FIX: for socket-originated calls the receiver must emit accept
      // BEFORE fetching the token so the caller's UI transitions correctly.
      if (!wasAutoAccepted) {
        debugPrint(
            '📞 VoiceRoomScreen: emitting acceptVoiceCall via socket...');
        await _provider.acceptVoiceCall();
        // Stop ringing as soon as we accept
        await _stopRinging();
      }

      // Step 1: Fetch voice token — retry once on failure
      debugPrint('🎫 VoiceRoomScreen: fetching voice token...');
      bool success = await _provider.fetchVoiceToken();
      if (!success) {
        debugPrint('⚠️ VoiceRoomScreen: token fetch failed, retrying...');
        await Future.delayed(const Duration(seconds: 1));
        success = await _provider.fetchVoiceToken();
      }
      if (!success) {
        debugPrint('❌ VoiceRoomScreen: token fetch failed after retry');
        _showError('Failed to get call token');
        return;
      }
      debugPrint('✅ VoiceRoomScreen: token fetched');

      // Step 2: Fetch ICE servers
      final iceServers = await _fetchIceServers();
      debugPrint(
          '🌐 VoiceRoomScreen: using ${iceServers.length} ICE servers');

      // Step 3: Connect to LiveKit
      debugPrint('🔌 VoiceRoomScreen: connecting to LiveKit...');
      _room = Room();
      await _room!.connect(
        'wss://meet.ixes.ai',
        _provider.voiceToken!,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
        connectOptions: ConnectOptions(
          rtcConfiguration: RTCConfiguration(
            iceServers: iceServers,
            iceTransportPolicy: RTCIceTransportPolicy.relay,
          ),
        ),
      );

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      _room!.addListener(_onRoomUpdate);
      _provider.notifyParticipantJoined();

      _hasJoined = true;
      debugPrint(
          '✅ VoiceRoomScreen: joined LiveKit room | _hasJoined=true');

      if (mounted) setState(() => _isConnecting = false);
    } catch (e) {
      debugPrint('❌ VoiceRoomScreen: error joining room: $e');
      _showError('Failed to join call: $e');
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
    _stopRinging();
    _provider.removeListener(_handleCallStateChange);
    _provider.notifyParticipantLeft();
    await _provider.endVoiceCall();
    await _room?.disconnect();
    _callTimer?.cancel();
    await FlutterCallkitIncoming.endAllCalls();
    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String message) {
    debugPrint('❌ VoiceRoomScreen: error: $message');
    _stopRinging();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    debugPrint(
        '🧹 VoiceRoomScreen: dispose | _hasJoined=$_hasJoined');
    _stopRinging();
    _ringPlayer.dispose();
    _provider.removeListener(_handleCallStateChange);
    _callTimer?.cancel();
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

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
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
              SizedBox(height: 20),
              Text('Connecting...',
                  style:
                  TextStyle(color: Colors.white54, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final callerName = _provider.currentReceiverName ??
        _provider.currentCallerName ??
        'Voice Call';

    return WillPopScope(
      onWillPop: () async {
        _showEndCallDialog();
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
          _circleIconButton(
            icon: Icons.keyboard_arrow_down,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 13, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text('End-to-end encrypted',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12)),
            ],
          ),
          const Spacer(),
          _circleIconButton(
              icon: Icons.person_add_alt_1_outlined, onTap: () {}),
        ],
      ),
    );
  }

  Widget _circleIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildCenterContent(String callerName) {
    return Consumer<VoiceCallProvider>(
      builder: (_, provider, __) {
        final isWaiting = provider.participants.isEmpty;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A90D9), Color(0xFF845EC2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90D9).withOpacity(0.35),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child:
              const Icon(Icons.person, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 28),
            Text(callerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
            const SizedBox(height: 12),
            if (isWaiting)
              Text('Connecting...',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 16))
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(_formatDuration(_callDuration),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16)),
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
      padding:
      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _smallControlButton(
            icon: _provider.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            color: _provider.isSpeakerOn
                ? Colors.blue.withOpacity(0.8)
                : Colors.white.withOpacity(0.12),
            onPressed: () =>
                _provider.setSpeaker(!_provider.isSpeakerOn),
          ),
          _smallControlButton(
            icon: _isSpeakerOn
                ? Icons.hearing_rounded
                : Icons.hearing_disabled_rounded,
            color: _isSpeakerOn
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.06),
            onPressed: _toggleSpeaker,
          ),
          GestureDetector(
            onTap: _showEndCallDialog,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.45),
                    blurRadius: 24,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Icon(Icons.call_end_rounded,
                  size: 30, color: Colors.white),
            ),
          ),
          _smallControlButton(
            icon: _provider.isMuted
                ? Icons.mic_off_rounded
                : Icons.mic_none_rounded,
            color: _provider.isMuted
                ? Colors.redAccent.withOpacity(0.8)
                : Colors.white.withOpacity(0.12),
            onPressed: () async {
              _provider.setMuted(!_provider.isMuted);
              await _room?.localParticipant
                  ?.setMicrophoneEnabled(!_provider.isMuted);
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

  Widget _smallControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration:
        BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  void _showEndCallDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('End Call?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
            'Are you sure you want to end this call?',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endCall();
            },
            style:
            TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('End Call',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}