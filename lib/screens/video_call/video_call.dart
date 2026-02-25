import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ixes.app/providers/video_call_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VideoCallScreen extends StatefulWidget {
  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final VideoCallProvider _provider;

  Room? _room;
  bool _isMicEnabled    = true;
  bool _isCameraEnabled = true;
  bool _isConnecting    = true;
  bool _isEnding        = false;
  CameraPosition _cameraPosition = CameraPosition.front;

  @override
  void initState() {
    super.initState();
    _provider = context.read<VideoCallProvider>();
    _provider.addListener(_handleCallStateChange);
    _requestPermissions();
  }

  void _handleCallStateChange() {
    if (!mounted || _isEnding) return;
    if (_provider.callState == CallState.ended) {
      debugPrint('📴 VideoCallScreen: call ended remotely → closing');
      _isEnding = true;
      _room?.disconnect();
      if (mounted) {
        Navigator.of(context).pop();
        if (_provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_provider.errorMessage!)),
          );
        }
      }
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await _joinRoom();
  }

  // ════════════════════════════════════════════════════════════════════
  // FETCH TWILIO ICE/TURN SERVERS
  // Same endpoint as voice — replace URL with your actual API endpoint
  // ════════════════════════════════════════════════════════════════════
  Future<List<RTCIceServer>> _fetchIceServers() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final token    = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        // ✅ Replace with your actual Twilio ICE endpoint
        Uri.parse('https://api.ixes.ai/api/chat/get-turn-credentials'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body    = json.decode(response.body);
        final data    = body['data'] as Map<String, dynamic>;
        final iceList = data['iceServers'] as List<dynamic>;

        debugPrint('✅ Got ${iceList.length} ICE servers from Twilio');

        return iceList.map((server) {
          final s          = server as Map<String, dynamic>;
          final urls       = s['urls']?.toString() ?? s['url']?.toString() ?? '';
          final username   = s['username']?.toString();
          final credential = s['credential']?.toString();

          return RTCIceServer(
            urls: [urls],
            username: username,
            credential: credential,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Could not fetch ICE servers: $e — using defaults');
    }

    // Fallback: Google STUN only
    return [RTCIceServer(urls: ['stun:stun.l.google.com:19302'])];
  }

  // ════════════════════════════════════════════════════════════════════
  // JOIN LIVEKIT ROOM WITH TWILIO TURN SERVERS
  // ════════════════════════════════════════════════════════════════════
  Future<void> _joinRoom() async {
    try {
      // Step 1: Fetch LiveKit token
      final success = await _provider.fetchLivekitToken();
      if (!success) { _showError('Failed to get call token'); return; }

      // Step 2: Fetch Twilio TURN/ICE servers
      final iceServers = await _fetchIceServers();
      debugPrint('🌐 Using ${iceServers.length} ICE servers for video room');

      // Step 3: Connect to LiveKit with TURN servers injected
      // ✅ livekit_client ^2.2.0: rtcConfig is a param of Room() constructor
      _room = Room();
      await _room!.connect(
        'wss://meet.ixes.ai',
        _provider.livekitToken!, // or livekitToken!
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

      if (mounted) setState(() { _isConnecting = false; });
      debugPrint('✅ Joined video room: ${_provider.currentRoomName}');
    } catch (e) {
      debugPrint('❌ Error joining video room: $e');
      _showError('Failed to join call: $e');
    }
  }

  void _onRoomUpdate() {
    if (mounted && !_isEnding) setState(() {});
  }

  Future<void> _toggleCamera() async {
    if (_room != null) {
      _isCameraEnabled = !_isCameraEnabled;
      await _room!.localParticipant?.setCameraEnabled(_isCameraEnabled);
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_room != null) {
      _isMicEnabled = !_isMicEnabled;
      await _room!.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
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
        final pub = localParticipant.videoTrackPublications.firstOrNull;
        if (pub?.track is LocalVideoTrack) {
          await (pub!.track as LocalVideoTrack).setCameraPosition(_cameraPosition);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    _isEnding = true;
    _provider.removeListener(_handleCallStateChange);
    _provider.notifyParticipantLeft();
    await _provider.endCall();  // ← add await
    await _room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String message) {
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
        _provider.currentReceiverName ?? 'Unknown';
  }

  @override
  void dispose() {
    _provider.removeListener(_handleCallStateChange);
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }

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
              Text('Connecting...', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async { await _endCall(); return false; },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_room!.remoteParticipants.isNotEmpty)
              _buildRemoteVideo()
            else
              _buildWaitingView(),
            Positioned(top: 50, right: 20, child: _buildLocalVideo()),
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildControls()),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    final remote = _room!.remoteParticipants.values.first;
    TrackPublication? videoPub;
    for (var pub in remote.trackPublications.values) {
      if (pub.kind == TrackType.VIDEO) { videoPub = pub; break; }
    }
    if (videoPub != null && videoPub.subscribed &&
        videoPub.track != null && !videoPub.muted) {
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
              width: 100, height: 100,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1)),
              child: const Icon(Icons.videocam_off, size: 50, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            Text(remote.name ?? _getOtherParticipantName(),
                style: const TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Camera is off',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
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
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [Colors.blue[400]!, Colors.purple[400]!]),
            ),
            child: Center(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Waiting for $name to join...',
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLocalVideo() {
    TrackPublication? localPub;
    if (_room!.localParticipant != null) {
      for (var pub in _room!.localParticipant!.trackPublications.values) {
        if (pub.kind == TrackType.VIDEO) { localPub = pub; break; }
      }
    }
    return Container(
      width: 120, height: 160,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: (localPub != null && localPub.track != null && _isCameraEnabled)
            ? VideoTrackRenderer(localPub.track as VideoTrack,
            fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: const [
              Icon(Icons.circle, color: Colors.white, size: 8),
              SizedBox(width: 6),
              Text('Connected', style: TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            onPressed: _toggleCamera,
            backgroundColor:
            _isCameraEnabled ? Colors.white.withOpacity(0.2) : Colors.red,
          ),
          _buildControlButton(
            icon: _isMicEnabled ? Icons.mic : Icons.mic_off,
            onPressed: _toggleMicrophone,
            backgroundColor:
            _isMicEnabled ? Colors.white.withOpacity(0.2) : Colors.red,
          ),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 15, spreadRadius: 2)
              ],
            ),
            child: IconButton(
              onPressed: _endCall,
              icon: const Icon(Icons.call_end, size: 28, color: Colors.white),
            ),
          ),
          _buildControlButton(
              icon: Icons.flip_camera_ios,
              onPressed: _switchCamera,
              backgroundColor: Colors.white.withOpacity(0.2)),
          _buildControlButton(
              icon: Icons.more_vert,
              onPressed: _showMoreOptions,
              backgroundColor: Colors.white.withOpacity(0.2)),
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
      width: 50, height: 50,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 24)),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.white),
              title: const Text('Invite Participant',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.screen_share, color: Colors.white),
              title: const Text('Share Screen',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')));
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}