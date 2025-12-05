import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ixes.app/providers/video_call_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallScreen extends StatefulWidget {
  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Room? _room;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _isConnecting = true;
  bool _isEnding = false;
  CameraPosition _cameraPosition = CameraPosition.front;

  @override
  void initState() {
    super.initState();
    _setupCallEndListener();
    _requestPermissions();
  }

  void _setupCallEndListener() {
    final provider = context.read<VideoCallProvider>();
    provider.addListener(_handleCallStateChange);
  }

  void _handleCallStateChange() {
    if (!mounted || _isEnding) return;

    final provider = context.read<VideoCallProvider>();

    // If call ended by remote user, disconnect and close
    if (provider.callState == CallState.ended) {
      debugPrint('📴 Call ended by remote user, closing screen');
      _isEnding = true;

      // Disconnect room
      _room?.disconnect();

      // Close this screen
      Navigator.of(context).pop();

      // Show message if any
      if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!)),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();

    await _joinRoom();
  }

  Future<void> _joinRoom() async {
    final videoCallProvider = context.read<VideoCallProvider>();

    try {
      // Fetch LiveKit token
      final success = await videoCallProvider.fetchLivekitToken();

      if (!success) {
        _showError('Failed to join call');
        return;
      }

      // Create room
      _room = Room();

      // Connect to room
      await _room!.connect(
        'wss://meet.ixes.ai',
        videoCallProvider.livekitToken!,
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      // Enable camera and microphone
      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // Notify that participant joined
      videoCallProvider.notifyParticipantJoined();

      // Setup listeners
      _room!.addListener(_onRoomUpdate);

      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      debugPrint('Error joining room: $e');
      _showError('Failed to join call: $e');
    }
  }

  void _onRoomUpdate() {
    if (mounted && !_isEnding) {
      setState(() {});
    }
  }

  Future<void> _toggleCamera() async {
    if (_room != null) {
      _isCameraEnabled = !_isCameraEnabled;
      await _room!.localParticipant?.setCameraEnabled(_isCameraEnabled);
      setState(() {});
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_room != null) {
      _isMicEnabled = !_isMicEnabled;
      await _room!.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
      setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    try {
      final localParticipant = _room?.localParticipant;
      if (localParticipant != null && _isCameraEnabled) {
        _cameraPosition = _cameraPosition == CameraPosition.front
            ? CameraPosition.back
            : CameraPosition.front;

        final videoPublication = localParticipant.videoTrackPublications.firstOrNull;

        if (videoPublication != null) {
          final videoTrack = videoPublication.track;

          if (videoTrack != null && videoTrack is LocalVideoTrack) {
            await videoTrack.setCameraPosition(_cameraPosition);
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Error switching camera: $e');

      try {
        final localParticipant = _room?.localParticipant;
        if (localParticipant != null) {
          await localParticipant.setCameraEnabled(false);
          await Future.delayed(const Duration(milliseconds: 300));

          _cameraPosition = _cameraPosition == CameraPosition.front
              ? CameraPosition.back
              : CameraPosition.front;

          await localParticipant.setCameraEnabled(true);
          setState(() {});
        }
      } catch (e2) {
        debugPrint('Error in fallback camera switch: $e2');
      }
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    _isEnding = true;

    final videoCallProvider = context.read<VideoCallProvider>();

    // Notify that participant left
    videoCallProvider.notifyParticipantLeft();

    // End the call (sends video-call-canceled event)
    videoCallProvider.endCall();

    // Disconnect from room
    await _room?.disconnect();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.of(context).pop();
    }
  }

  // Get the name of the other participant based on call direction
  String _getOtherParticipantName() {
    final provider = context.read<VideoCallProvider>();

    // If I'm the receiver (someone called me), show caller's name
    if (provider.currentCallerId != null &&
        provider.currentCallerId != provider.currentUserId) {
      return provider.currentCallerName ?? 'Unknown';
    }

    // If I'm the caller, show receiver's name
    if (provider.currentReceiverId != null) {
      return provider.currentReceiverName ?? 'Unknown';
    }

    // Fallback
    return provider.currentCallerName ??
        provider.currentReceiverName ??
        'Unknown';
  }

  @override
  void dispose() {
    try {
      final provider = context.read<VideoCallProvider>();
      provider.removeListener(_handleCallStateChange);
    } catch (e) {
      debugPrint('Error removing listener: $e');
    }

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
              Text(
                'Connecting...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
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
            // Remote video (full screen)
            if (_room!.remoteParticipants.isNotEmpty)
              _buildRemoteVideo()
            else
              _buildWaitingView(),

            // Local video (small preview)
            Positioned(
              top: 50,
              right: 20,
              child: _buildLocalVideo(),
            ),

            // Top info bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    final remoteParticipant = _room!.remoteParticipants.values.first;

    TrackPublication? videoPublication;
    for (var pub in remoteParticipant.trackPublications.values) {
      if (pub.kind == TrackType.VIDEO) {
        videoPublication = pub;
        break;
      }
    }

    if (videoPublication != null &&
        videoPublication.subscribed &&
        videoPublication.track != null &&
        !videoPublication.muted) {
      return SizedBox.expand(
        child: VideoTrackRenderer(
          videoPublication.track as VideoTrack,
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
                color: Colors.white.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.videocam_off,
                size: 50,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              remoteParticipant.name ?? _getOtherParticipantName(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Camera is off',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingView() {
    final otherName = _getOtherParticipantName();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.purple[400]!],
              ),
            ),
            child: Center(
              child: Text(
                otherName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Waiting for $otherName to join...',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalVideo() {
    TrackPublication? localVideoPublication;
    if (_room!.localParticipant != null) {
      for (var pub in _room!.localParticipant!.trackPublications.values) {
        if (pub.kind == TrackType.VIDEO) {
          localVideoPublication = pub;
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
        child: (localVideoPublication != null &&
            localVideoPublication.track != null &&
            _isCameraEnabled)
            ? VideoTrackRenderer(
          localVideoPublication.track as VideoTrack,
          fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        )
            : Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.videocam_off, color: Colors.white54, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final otherName = _getOtherParticipantName();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Text(
            otherName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 6),
                Text(
                  'Connected',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
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
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            onPressed: _toggleCamera,
            backgroundColor: _isCameraEnabled ? Colors.white.withOpacity(0.2) : Colors.red,
          ),

          _buildControlButton(
            icon: _isMicEnabled ? Icons.mic : Icons.mic_off,
            onPressed: _toggleMicrophone,
            backgroundColor: _isMicEnabled ? Colors.white.withOpacity(0.2) : Colors.red,
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
                ),
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
            backgroundColor: Colors.white.withOpacity(0.2),
          ),

          _buildControlButton(
            icon: Icons.more_vert,
            onPressed: _showMoreOptions,
            backgroundColor: Colors.white.withOpacity(0.2),
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
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.white),
              title: const Text(
                'Invite Participant',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite participant feature coming soon!'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.screen_share, color: Colors.white),
              title: const Text(
                'Share Screen',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Screen sharing feature coming soon!'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings feature coming soon!'),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}