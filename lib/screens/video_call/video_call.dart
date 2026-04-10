import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ixes.app/providers/video_call_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class VideoCallScreen extends StatefulWidget {
  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final VideoCallProvider _provider;

  Room? _room;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _isConnecting = true;
  bool _isEnding = false;
  CameraPosition _cameraPosition = CameraPosition.front;
  bool _hasJoined = false;

  // ── Ringing (receiver side) ───────────────────────────────────────────
  final AudioPlayer _ringPlayer = AudioPlayer();
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<VideoCallProvider>();
    debugPrint(
        '🏁 VideoCallScreen: initState | callState=${_provider.callState} | acceptedViaCallKit=${_provider.acceptedViaCallKit}');
    _provider.addListener(_handleCallStateChange);

    // FIX: ring receiver in-app (non-FCM socket path)
    if (!_provider.acceptedViaCallKit) {
      _startRinging();
    }

    _requestPermissions();
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
      debugPrint('⚠️ VideoCallScreen: could not play ringtone: $e');
    }
  }

  Future<void> _stopRinging() async {
    if (!_isRinging) return;
    _isRinging = false;
    try {
      await _ringPlayer.stop();
    } catch (e) {
      debugPrint('⚠️ VideoCallScreen: could not stop ringtone: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CALL STATE
  // ════════════════════════════════════════════════════════════════════════

  void _handleCallStateChange() {
    if (!mounted || _isEnding) return;

    debugPrint(
        '🔔 VideoCallScreen: callState=${_provider.callState} | hasJoined=$_hasJoined | isEnding=$_isEnding');

    if (!_hasJoined) {
      debugPrint(
          '⚠️ VideoCallScreen: ignoring state change — not joined yet');
      return;
    }

    if (_provider.callState == CallState.ended) {
      debugPrint('📴 VideoCallScreen: call ended remotely → closing');
      _closeScreen();
    }
  }

  void _closeScreen() {
    if (_isEnding) return;
    _isEnding = true;
    _stopRinging();
    _provider.removeListener(_handleCallStateChange);
    _room?.disconnect();
    FlutterCallkitIncoming.endAllCalls();
    if (mounted) {
      if (_provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_provider.errorMessage!)),
        );
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _requestPermissions() async {
    debugPrint('🔑 VideoCallScreen: requesting permissions...');
    await Permission.camera.request();
    await Permission.microphone.request();
    await _joinRoom();
  }

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
        debugPrint(
            '✅ Got ${iceList.length} ICE servers from Twilio');
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
      debugPrint(
          '⚠️ Could not fetch ICE servers: $e — using defaults');
    }
    return [RTCIceServer(urls: ['stun:stun.l.google.com:19302'])];
  }

  // ════════════════════════════════════════════════════════════════════════
  //  JOIN ROOM
  //  FIX: acceptCall emitted for socket-path receivers before LiveKit;
  //  token retried once on failure.
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _joinRoom() async {
    try {
      final bool wasAutoAccepted = _provider.acceptedViaCallKit;
      debugPrint(
          '🔑 VideoCallScreen: autoAccepted=$wasAutoAccepted | roomName=${_provider.currentRoomName}');

      // FIX: emit accept socket event for non-CallKit receivers
      if (!wasAutoAccepted) {
        debugPrint(
            '📞 VideoCallScreen: emitting acceptCall via socket...');
        await _provider.acceptCall();
        await _stopRinging();
      }

      // Step 1: Fetch LiveKit token — retry once on failure
      debugPrint('🎫 VideoCallScreen: fetching livekit token...');
      bool success = await _provider.fetchLivekitToken();
      if (!success) {
        debugPrint(
            '⚠️ VideoCallScreen: token fetch failed, retrying...');
        await Future.delayed(const Duration(seconds: 1));
        success = await _provider.fetchLivekitToken();
      }
      if (!success) {
        debugPrint(
            '❌ VideoCallScreen: token fetch failed after retry');
        _showError('Failed to get call token');
        return;
      }
      debugPrint('✅ VideoCallScreen: token fetched');

      // Step 2: Fetch ICE servers
      final iceServers = await _fetchIceServers();
      debugPrint(
          '🌐 VideoCallScreen: using ${iceServers.length} ICE servers');

      // Step 3: Connect to LiveKit
      debugPrint('🔌 VideoCallScreen: connecting to LiveKit...');
      _room = Room();
      await _room!.connect(
        'wss://meet.ixes.ai',
        _provider.livekitToken!,
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

      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      _provider.notifyParticipantJoined();
      _room!.addListener(_onRoomUpdate);

      _hasJoined = true;
      debugPrint(
          '✅ VideoCallScreen: joined LiveKit room | _hasJoined=true');

      if (mounted) setState(() => _isConnecting = false);
    } catch (e) {
      debugPrint('❌ VideoCallScreen: error joining room: $e');
      _showError('Failed to join call: $e');
    }
  }

  void _onRoomUpdate() {
    if (mounted && !_isEnding) setState(() {});
  }

  Future<void> _toggleCamera() async {
    if (_room != null) {
      _isCameraEnabled = !_isCameraEnabled;
      await _room!.localParticipant
          ?.setCameraEnabled(_isCameraEnabled);
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_room != null) {
      _isMicEnabled = !_isMicEnabled;
      await _room!.localParticipant
          ?.setMicrophoneEnabled(_isMicEnabled);
      if (mounted) setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    try {
      final localParticipant = _room?.localParticipant;
      if (localParticipant != null && _isCameraEnabled) {
        _cameraPosition = _cameraPosition == CameraPosition.front
            ? CameraPosition.back
            : CameraPosition.front;
        final pub =
            localParticipant.videoTrackPublications.firstOrNull;
        if (pub?.track is LocalVideoTrack) {
          await (pub!.track as LocalVideoTrack)
              .setCameraPosition(_cameraPosition);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('❌ VideoCallScreen: error switching camera: $e');
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    debugPrint('📴 VideoCallScreen: user ended call');
    _isEnding = true;
    _stopRinging();
    _provider.removeListener(_handleCallStateChange);
    _provider.notifyParticipantLeft();
    await _provider.endCall();
    await _room?.disconnect();
    await FlutterCallkitIncoming.endAllCalls();
    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String message) {
    debugPrint('❌ VideoCallScreen: error: $message');
    _stopRinging();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    }
  }

  String _getOtherParticipantName() {
    if (_provider.currentCallerId != null &&
        _provider.currentCallerId != _provider.currentUserId) {
      return _provider.currentCallerName ?? 'Unknown';
    }
    if (_provider.currentReceiverId != null) {
      return _provider.currentReceiverName ?? 'Unknown';
    }
    return _provider.currentCallerName ??
        _provider.currentReceiverName ??
        'Unknown';
  }

  @override
  void dispose() {
    debugPrint(
        '🧹 VideoCallScreen: dispose | _hasJoined=$_hasJoined');
    _stopRinging();
    _ringPlayer.dispose();
    _provider.removeListener(_handleCallStateChange);
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isConnecting || _room == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text('Connecting...',
                  style: TextStyle(
                      color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _endCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_room!.remoteParticipants.isNotEmpty)
              _buildRemoteVideo()
            else
              _buildWaitingView(),
            Positioned(top: 50, right: 20, child: _buildLocalVideo()),
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar()),
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildControls()),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    final remote = _room!.remoteParticipants.values.first;
    TrackPublication? videoPub;
    for (var pub in remote.trackPublications.values) {
      if (pub.kind == TrackType.VIDEO) {
        videoPub = pub;
        break;
      }
    }
    if (videoPub != null &&
        videoPub.subscribed &&
        videoPub.track != null &&
        !videoPub.muted) {
      return SizedBox.expand(
        child: VideoTrackRenderer(
          videoPub.track as VideoTrack,
          fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1)),
              child: const Icon(Icons.videocam_off,
                  size: 50, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            Text(remote.name ?? _getOtherParticipantName(),
                style: const TextStyle(
                    color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Camera is off',
                style:
                TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingView() {
    final name = _getOtherParticipantName();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                Colors.blue[400]!,
                Colors.purple[400]!
              ]),
            ),
            child: Center(
              child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Connecting with $name...',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLocalVideo() {
    TrackPublication? localPub;
    if (_room!.localParticipant != null) {
      for (var pub
      in _room!.localParticipant!.trackPublications.values) {
        if (pub.kind == TrackType.VIDEO) {
          localPub = pub;
          break;
        }
      }
    }
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: (localPub != null &&
            localPub.track != null &&
            _isCameraEnabled)
            ? VideoTrackRenderer(localPub.track as VideoTrack,
            fit: RTCVideoViewObjectFit
                .RTCVideoViewObjectFitCover)
            : Container(
            color: Colors.black,
            child: const Center(
                child: Icon(Icons.videocam_off,
                    color: Colors.white54, size: 40))),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent
          ],
        ),
      ),
      child: Row(
        children: [
          Text(_getOtherParticipantName(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: const [
              Icon(Icons.circle, color: Colors.white, size: 8),
              SizedBox(width: 6),
              Text('Connected',
                  style: TextStyle(
                      color: Colors.white, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 40, vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: !_isCameraEnabled
                ? Icons.videocam_off
                : Icons.videocam,
            onPressed: _toggleCamera,
            backgroundColor: _isCameraEnabled
                ? Colors.white.withOpacity(0.2)
                : Colors.red,
          ),
          _buildControlButton(
            icon: _provider.isMuted ? Icons.mic_off : Icons.mic,
            onPressed: () async {
              _provider.setMuted(!_provider.isMuted);
              await _room!.localParticipant
                  ?.setMicrophoneEnabled(!_provider.isMuted);
              setState(() {});
            },
            backgroundColor: _provider.isMuted
                ? Colors.red
                : Colors.white.withOpacity(0.2),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: IconButton(
              onPressed: _endCall,
              icon: const Icon(Icons.call_end,
                  size: 28, color: Colors.white),
            ),
          ),
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            onPressed: _switchCamera,
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
          _buildControlButton(
            icon: _provider.isSpeakerOn
                ? Icons.volume_up
                : Icons.volume_off,
            onPressed: () {
              _provider.setSpeaker(!_provider.isSpeakerOn);
              setState(() {});
            },
            backgroundColor: _provider.isSpeakerOn
                ? Colors.blue.withOpacity(0.6)
                : Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration:
      BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 24)),
    );
  }
}