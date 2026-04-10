import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ixes.app/providers/meeting_provider.dart';
import 'package:flutter_background/flutter_background.dart';
import 'dart:async';
import 'dart:io';

import '../../services/meeting_overlay_service.dart';

class MeetingRoomScreen extends StatefulWidget {
  final String meetingId;

  const MeetingRoomScreen({Key? key, required this.meetingId}) : super(key: key);

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  Room? _room;

  // ── Separated track lists ─────────────────────────────────────────────────
  List<ParticipantTrack> _participantTracks = []; // all tracks (for count badge)
  List<ParticipantTrack> _cameraTrack = [];        // camera-only tracks
  List<ParticipantTrack> _screenShareTracks = [];  

  LocalParticipant? _localParticipant;

  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isChatOpen = false;
  bool _isParticipantsOpen = false;
  bool _isConnecting = true;
  bool _isScreenSharing = false;
  String? _errorMessage;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final Set<String> _displayedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _checkAndRestoreFromOverlay();
    final overlayService = MeetingOverlayService();
    overlayService.addListener(_onOverlayUpdate);
  }

  void _onOverlayUpdate() {
    if (mounted && _localParticipant != null) {
      setState(() {
        _isVideoEnabled = _localParticipant!.isCameraEnabled();
        _isAudioEnabled = _localParticipant!.isMicrophoneEnabled();
      });
    }
  }

  Future<void> _checkAndRestoreFromOverlay() async {
    final overlayService = MeetingOverlayService();

    if (overlayService.isMinimized &&
        overlayService.meetingId == widget.meetingId &&
        overlayService.room != null) {

      _room = overlayService.room;
      _localParticipant = overlayService.localParticipant;

      _setupRoomListeners();
      _updateParticipants();

      final actualCameraState = _localParticipant?.isCameraEnabled() ?? true;
      final actualMicState = _localParticipant?.isMicrophoneEnabled() ?? true;
      final actualScreenShare = _localParticipant?.isScreenShareEnabled() ?? false;

      setState(() {
        _isConnecting = false;
        _isVideoEnabled = actualCameraState;
        _isAudioEnabled = actualMicState;
        _isScreenSharing = actualScreenShare;
      });

      final meetingProvider = context.read<MeetingProvider>();
      if (!meetingProvider.isChatJoined) {
        meetingProvider.joinChatRoom();
      }
      return;
    }

    await _initializeMeeting();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MORE MENU
  // ─────────────────────────────────────────────────────────────────────────
  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Screen Share
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isScreenSharing
                          ? Colors.green.withOpacity(0.2)
                          : Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isScreenSharing
                          ? Icons.stop_screen_share
                          : Icons.screen_share,
                      color: _isScreenSharing ? Colors.green : Colors.white,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    _isScreenSharing ? 'Stop Sharing' : 'Share Screen',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _isScreenSharing
                        ? 'Tap to stop screen share'
                        : 'Share your screen with participants',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleScreenShare();
                  },
                ),

                Divider(color: Colors.white.withOpacity(0.1), height: 1),

                // Minimize
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.picture_in_picture_alt,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Minimize',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Keep meeting running in background',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _minimizeMeeting();
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN SHARE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _toggleScreenShare() async {
    if (_localParticipant == null) return;

    try {
      if (_isScreenSharing) {
        await _localParticipant!.setScreenShareEnabled(false);

        if (Platform.isAndroid) {
          await FlutterBackground.disableBackgroundExecution()
              .catchError((e) => debugPrint('⚠️ disableBackground error: $e'));
        }

        setState(() => _isScreenSharing = false);
        debugPrint('🛑 Screen share stopped');
      } else {
        if (Platform.isAndroid) {
          final success = await FlutterBackground.enableBackgroundExecution();
          if (!success) {
            _showScreenShareError(
                'Failed to enable background execution for screen sharing.');
            return;
          }
        }

        await _localParticipant!.setScreenShareEnabled(true);
        setState(() => _isScreenSharing = true);
        debugPrint('✅ Screen share started');
      }
    } catch (e) {
      debugPrint('❌ Screen share toggle error: $e');
      setState(() => _isScreenSharing = false);

      if (Platform.isAndroid) {
        await FlutterBackground.disableBackgroundExecution().catchError((_) {});
      }

      _showScreenShareError('Screen sharing failed: $e');
    }
  }

  void _showScreenShareError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MINIMIZE
  // ─────────────────────────────────────────────────────────────────────────
  void _minimizeMeeting() {
    if (_room == null || _localParticipant == null) {
      debugPrint('⚠️ Cannot minimize: room or participant is null');
      return;
    }

    final overlayService = MeetingOverlayService();
    overlayService.initialize(
      room: _room!,
      localParticipant: _localParticipant!,
      meetingId: widget.meetingId,
    );

    overlayService.showOverlay(context);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _initializeMeeting() async {
    final meetingProvider = context.read<MeetingProvider>();

    await _connectToRoom();
    if (_room == null) return;

    if (meetingProvider.isHost) {
      await meetingProvider.rejoinAsHost();
    }

    await Future.delayed(const Duration(milliseconds: 500));
    meetingProvider.joinChatRoom();
  }

  Future<void> _connectToRoom() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final meetingProvider = context.read<MeetingProvider>();
      final accessToken = meetingProvider.accessToken;

      if (accessToken == null) throw Exception('No access token available');

      _room = Room();
      _setupRoomListeners();

      await _room!.connect(
        'wss://meet.ixes.ai',
        accessToken,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
        ),
      );

      await _room!.localParticipant?.setCameraEnabled(_isVideoEnabled);
      await _room!.localParticipant?.setMicrophoneEnabled(_isAudioEnabled);

      setState(() {
        _localParticipant = _room!.localParticipant;
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to meeting: $e';
        _isConnecting = false;
      });
    }
  }

  EventsListener<RoomEvent>? _roomListener;

  void _setupRoomListeners() {
    if (_roomListener != null) _roomListener = null;

    _room?.removeListener(_onRoomUpdate);
    _room?.addListener(_onRoomUpdate);

    _roomListener = _room?.createListener()
      ?..on<RoomDisconnectedEvent>((event) async {
        debugPrint('🔴 DISCONNECT EVENT - Reason: ${event.reason}');
        if (!mounted) return;

        final overlayService = MeetingOverlayService();
        if (overlayService.isMinimized) overlayService.hideOverlay();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
      })
      ..on<ParticipantConnectedEvent>((event) {
        debugPrint('👤 Participant connected: ${event.participant.identity}');
        _updateParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint('👋 Participant disconnected: ${event.participant.identity}');
        _updateParticipants();
      })
      ..on<TrackPublishedEvent>((event) {
        debugPrint('📹 Track published');
        _updateParticipants();
      })
      ..on<TrackUnpublishedEvent>((event) {
        debugPrint('📹 Track unpublished');
        if (event.publication.source == TrackSource.screenShareVideo &&
            event.participant is LocalParticipant) {
          setState(() => _isScreenSharing = false);
        }
        _updateParticipants();
      })
      ..on<TrackSubscribedEvent>((event) {
        debugPrint('📹 Track subscribed');
        _updateParticipants();
      })
      ..on<TrackUnsubscribedEvent>((event) {
        debugPrint('📹 Track unsubscribed');
        _updateParticipants();
      });
  }

  void _onRoomUpdate() => _updateParticipants();

  // ─────────────────────────────────────────────────────────────────────────
  // UPDATE PARTICIPANTS — separates camera vs screen share tracks
  // ─────────────────────────────────────────────────────────────────────────
  void _updateParticipants() {
    if (_room == null) return;

    final cameras = <ParticipantTrack>[];
    final screens = <ParticipantTrack>[];

    // Local participant
    for (var pub in _room!.localParticipant!.trackPublications.values) {
      if (pub.track != null && pub.kind == TrackType.VIDEO) {
        final track = ParticipantTrack(
          participant: _room!.localParticipant!,
          videoTrack: pub.track as VideoTrack?,
          publication: pub,
          isScreenShare: pub.source == TrackSource.screenShareVideo,
        );
        if (pub.source == TrackSource.screenShareVideo) {
          screens.add(track);
        } else {
          cameras.add(track);
        }
      }
    }

    // Remote participants
    for (var participant in _room!.remoteParticipants.values) {
      for (var pub in participant.trackPublications.values) {
        if (pub.track != null && pub.kind == TrackType.VIDEO) {
          final track = ParticipantTrack(
            participant: participant,
            videoTrack: pub.track as VideoTrack?,
            publication: pub,
            isScreenShare: pub.source == TrackSource.screenShareVideo,
          );
          if (pub.source == TrackSource.screenShareVideo) {
            screens.add(track);
          } else {
            cameras.add(track);
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _screenShareTracks = screens;
        _cameraTrack = cameras;
        _participantTracks = [...cameras, ...screens]; // for count badge
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final overlayService = MeetingOverlayService();
        if (overlayService.isMinimized &&
            overlayService.meetingId == widget.meetingId) {
          return true;
        }
        _showLeaveDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: _isConnecting ? _buildLoadingState() : _buildMeetingUI(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            'Connecting to meeting...',
            style:
            TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingUI() {
    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildParticipantsGrid()),
            _buildControls(),
          ],
        ),

        // Side panels
        if (_isChatOpen || _isParticipantsOpen)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Material(
              elevation: 12,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  minWidth: 300,
                ).normalize(),
                child: Container(
                  width: 380,
                  color: Colors.white,
                  child: _isChatOpen
                      ? _buildChatPanel()
                      : _buildParticipantsPanel(),
                ),
              ),
            ),
          ),

        // Screen share active banner
        if (_isScreenSharing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                padding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: Colors.green.withOpacity(0.9),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.screen_share, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'You are sharing your screen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final meetingProvider = context.watch<MeetingProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting ID',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.meetingId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.meetingId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Meeting ID copied'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.copy,
                            size: 16, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (meetingProvider.isHost)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          const SizedBox(width: 12),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_participantTracks.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PARTICIPANTS GRID — screen share takes full view, cameras go to strip
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildParticipantsGrid() {
    // ── Someone is screen sharing ─────────────────────────────────────────
    if (_screenShareTracks.isNotEmpty) {
      return Column(
        children: [
          // Primary screen share fills the main area
          Expanded(
            flex: 4,
            child: _buildParticipantTile(_screenShareTracks[0]),
          ),

          // Additional screen shares (rare) in a small row
          if (_screenShareTracks.length > 1)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _screenShareTracks.length - 1,
                itemBuilder: (_, i) => SizedBox(
                  width: 140,
                  child: _buildParticipantTile(_screenShareTracks[i + 1]),
                ),
              ),
            ),

          // Camera thumbnails strip at the bottom
          if (_cameraTrack.isNotEmpty)
            Container(
              height: 110,
              color: const Color(0xFF111111),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                itemCount: _cameraTrack.length,
                itemBuilder: (_, i) => Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _cameraTrack[i].participant is LocalParticipant
                          ? const Color(0xFF2196F3)
                          : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildParticipantTile(_cameraTrack[i]),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // ── No screen share: normal camera grid ──────────────────────────────
    final tracks = _cameraTrack;

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Waiting for participants...',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (tracks.length == 1) return _buildParticipantTile(tracks[0]);

    if (tracks.length == 2) {
      return Column(
        children: [
          Expanded(child: _buildParticipantTile(tracks[0])),
          const SizedBox(height: 2),
          Expanded(child: _buildParticipantTile(tracks[1])),
        ],
      );
    }

    if (tracks.length == 3) {
      return Column(
        children: [
          Expanded(child: _buildParticipantTile(tracks[0])),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildParticipantTile(tracks[1])),
                const SizedBox(width: 2),
                Expanded(child: _buildParticipantTile(tracks[2])),
              ],
            ),
          ),
        ],
      );
    }

    if (tracks.length == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildParticipantTile(tracks[0])),
                const SizedBox(width: 2),
                Expanded(child: _buildParticipantTile(tracks[1])),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildParticipantTile(tracks[2])),
                const SizedBox(width: 2),
                Expanded(child: _buildParticipantTile(tracks[3])),
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3 / 4,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: tracks.length,
      itemBuilder: (_, i) => _buildParticipantTile(tracks[i]),
    );
  }

  Widget _buildParticipantTile(ParticipantTrack track) {
    final participant = track.participant;
    final isLocal = participant is LocalParticipant;
    final videoTrack = track.videoTrack;
    final isScreenShare = track.isScreenShare;

    return Container(
      color: const Color(0xFF1A1A1A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or placeholder
          if (videoTrack != null && !videoTrack.muted)
            VideoTrackRenderer(
              videoTrack,
              fit: isScreenShare
                  ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                  : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            _buildVideoPlaceholder(participant),

          // Screen share label
          if (isScreenShare)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.screen_share, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Screen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Name + mic badge
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isScreenShare) ...[
                        Icon(
                          participant.isMicrophoneEnabled()
                              ? Icons.mic
                              : Icons.mic_off,
                          color: participant.isMicrophoneEnabled()
                              ? Colors.white
                              : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isLocal
                            ? (isScreenShare ? 'Your Screen' : 'You')
                            : (participant.name.isNotEmpty
                            ? participant.name
                            : participant.identity),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Blue border for local participant
          if (isLocal)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF2196F3),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder(Participant participant) {
    final isLocal = participant is LocalParticipant;
    final displayName = isLocal
        ? 'You'
        : (participant.name.isNotEmpty
        ? participant.name
        : participant.identity);
    final initial = displayName.substring(0, 1).toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 48,
          backgroundColor: const Color(0xFF2196F3),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTROLS BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: _isVideoEnabled,
            onPressed: _toggleVideo,
          ),
          _buildControlButton(
            icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: _isAudioEnabled,
            onPressed: _toggleAudio,
          ),
          _buildControlButton(
            icon: Icons.chat_bubble,
            label: 'Chat',
            isActive: _isChatOpen,
            onPressed: () {
              setState(() {
                _isChatOpen = !_isChatOpen;
                _isParticipantsOpen = false;
              });
            },
            badge: context.watch<MeetingProvider>().chatMessages.length,
          ),
          _buildControlButton(
            icon: Icons.people,
            label: 'People',
            isActive: _isParticipantsOpen,
            onPressed: () {
              setState(() {
                _isParticipantsOpen = !_isParticipantsOpen;
                _isChatOpen = false;
              });
            },
            badge: context.watch<MeetingProvider>().isHost
                ? context.watch<MeetingProvider>().pendingRequests.length
                : null,
          ),
          _buildControlButton(
            icon: Icons.more_vert,
            label: 'More',
            isActive: false,
            onPressed: _showMoreMenu,
          ),
          _buildControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            isActive: false,
            onPressed: _showLeaveDialog,
            backgroundColor: const Color(0xFFE53935),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    Color? backgroundColor,
    int? badge,
  }) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: backgroundColor ??
                          (isActive
                              ? const Color(0xFF2196F3)
                              : Colors.white.withOpacity(0.1)),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                ),
              ),
              if (badge != null && badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF2A2A2A), width: 2),
                    ),
                    constraints:
                    const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Center(
                      child: Text(
                        badge > 99 ? '99+' : badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border:
              Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble,
                      color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Chat',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                ),
                IconButton(
                  icon:
                  const Icon(Icons.close, color: Color(0xFF666666)),
                  onPressed: () => setState(() => _isChatOpen = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<MeetingProvider>(
              builder: (context, provider, child) {
                final messages = provider.chatMessages;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No messages yet',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Start the conversation!',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14)),
                      ],
                    ),
                  );
                }

                final uniqueMessages = <Map<String, dynamic>>[];
                final seenIds = <String>{};
                for (var message in messages) {
                  final messageId =
                      '${message['userId']}_${message['message']}_${message['timestamp']}';
                  if (!seenIds.contains(messageId)) {
                    seenIds.add(messageId);
                    uniqueMessages.add(message);
                  }
                }

                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: uniqueMessages.length,
                  itemBuilder: (context, index) {
                    final message = uniqueMessages[index];
                    final isMe =
                        message['userId'] == provider.currentUserId;
                    return _buildChatMessage(
                      username: message['username'] ?? 'Unknown',
                      message: message['message'] ?? '',
                      timestamp: message['timestamp'],
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border:
              Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage({
    required String username,
    required String message,
    required dynamic timestamp,
    required bool isMe,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? 'You' : username,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              )
                  : null,
              color: isMe ? null : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1A1A1A),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border:
              Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people,
                      color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Participants',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                ),
                IconButton(
                  icon:
                  const Icon(Icons.close, color: Color(0xFF666666)),
                  onPressed: () =>
                      setState(() => _isParticipantsOpen = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<MeetingProvider>(
              builder: (context, provider, child) {
                final shouldShowPending =
                    provider.isHost && provider.pendingRequests.isNotEmpty;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (shouldShowPending)
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.orange[50],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius:
                                      BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                        Icons.hourglass_empty,
                                        color: Colors.white,
                                        size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Pending Requests (${provider.pendingRequests.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...provider.pendingRequests
                                  .map((r) => _buildPendingRequest(r)),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      if (_participantTracks.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.grey[50],
                          child: Text(
                            'In Meeting (${_participantTracks.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _participantTracks.length,
                          itemBuilder: (context, index) =>
                              _buildParticipantListItem(
                                  _participantTracks[index]),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No participants yet',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequest(Map<String, dynamic> request) {
    final name = request['name'] ?? 'Unknown';
    final requestId = '${request['meetingId']}-${request['userId']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange,
            radius: 20,
            child: Text(name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1A1A1A))),
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.check, color: Colors.white, size: 20),
              onPressed: () => context
                  .read<MeetingProvider>()
                  .approveJoinRequest(requestId),
              tooltip: 'Approve',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => context
                  .read<MeetingProvider>()
                  .rejectJoinRequest(requestId),
              tooltip: 'Reject',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantListItem(ParticipantTrack track) {
    final participant = track.participant;
    final isLocal = participant is LocalParticipant;
    final name = isLocal
        ? 'You'
        : (participant.name.isNotEmpty
        ? participant.name
        : participant.identity);
    final provider = context.watch<MeetingProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2196F3),
            radius: 20,
            child: Text(name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1A1A1A)),
                      overflow: TextOverflow.ellipsis),
                ),
                if (provider.isHost && isLocal)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF2196F3),
                        Color(0xFF1976D2)
                      ]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('HOST',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: participant.isMicrophoneEnabled()
                      ? Colors.grey[100]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  participant.isMicrophoneEnabled()
                      ? Icons.mic
                      : Icons.mic_off,
                  size: 16,
                  color: participant.isMicrophoneEnabled()
                      ? Colors.grey[700]
                      : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: participant.isCameraEnabled()
                      ? Colors.grey[100]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  participant.isCameraEnabled()
                      ? Icons.videocam
                      : Icons.videocam_off,
                  size: 16,
                  color: participant.isCameraEnabled()
                      ? Colors.grey[700]
                      : Colors.red,
                ),
              ),
              if (provider.isHost && !isLocal) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon:
                    const Icon(Icons.person_remove, size: 16),
                    color: Colors.red,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        _kickParticipant(participant.identity),
                    tooltip: 'Remove participant',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    context.read<MeetingProvider>().sendChatMessage(message);
    _chatController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVideo() async {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    await _room?.localParticipant?.setCameraEnabled(_isVideoEnabled);
    MeetingOverlayService().notifyListeners();
  }

  Future<void> _toggleAudio() async {
    setState(() => _isAudioEnabled = !_isAudioEnabled);
    await _room?.localParticipant?.setMicrophoneEnabled(_isAudioEnabled);
    MeetingOverlayService().notifyListeners();
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Leave Meeting?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content:
          const Text('Are you sure you want to leave this meeting?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _leaveMeeting();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEAVE MEETING — crash-safe, never awaits screen share stop on main thread
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _leaveMeeting() async {
    debugPrint('🚪 Leaving meeting...');
    if (!mounted) return;

    // 1. Remove listeners immediately to stop any further UI updates
    _room?.removeListener(_onRoomUpdate);
    _roomListener?.dispose();
    _roomListener = null;

    // 2. Hide overlay if active
    final overlayService = MeetingOverlayService();
    if (overlayService.isMinimized &&
        overlayService.meetingId == widget.meetingId) {
      overlayService.hideOverlay();
    }

    // 3. Fire-and-forget screen share stop — NEVER await this.
    //    OrientationAwareScreenCapturer.stopCapture() blocks the main thread
    //    via CountDownLatch and causes an ANR/crash if awaited during leave.
    if (_isScreenSharing && _localParticipant != null) {
      debugPrint('🛑 Fire-and-forget screen share stop');
      _localParticipant!.setScreenShareEnabled(false).catchError((e) {
        debugPrint('⚠️ Screen share stop (background): $e');
      });
      if (Platform.isAndroid) {
        FlutterBackground.disableBackgroundExecution().catchError((e) {
          debugPrint('⚠️ Background disable (background): $e');
        });
      }
      if (mounted) setState(() => _isScreenSharing = false);
    }

    // 4. Notify provider
    if (mounted) context.read<MeetingProvider>().leaveMeeting();

    // 5. Navigate away FIRST — then disconnect room in background
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);

    // 6. Disconnect and dispose room after navigation (background)
    final roomToDispose = _room;
    _room = null;
    if (roomToDispose != null) {
      Future.microtask(() async {
        try {
          await roomToDispose
              .disconnect()
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('⚠️ Room disconnect (background): $e');
        }
        try {
          await roomToDispose.dispose();
        } catch (e) {
          debugPrint('⚠️ Room dispose (background): $e');
        }
      });
    }
  }

  Future<void> _kickParticipant(String participantIdentity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Remove Participant?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
              'Are you sure you want to remove $participantIdentity from the meeting?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await context
          .read<MeetingProvider>()
          .kickParticipant(participantIdentity);

      final provider = context.read<MeetingProvider>();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ??
                provider.successMessage ??
                'Participant removed'),
            backgroundColor:
            provider.errorMessage != null ? Colors.red : Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISPOSE — never blocks, never awaits screen share
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    debugPrint('🧹 Disposing MeetingRoomScreen');

    final overlayService = MeetingOverlayService();
    overlayService.removeListener(_onOverlayUpdate);

    _chatController.dispose();
    _chatScrollController.dispose();

    if (_room != null) {
      _room!.removeListener(_onRoomUpdate);
      _roomListener?.dispose();
      _roomListener = null;
    }

    final isMinimizing = overlayService.isMinimized &&
        overlayService.meetingId == widget.meetingId;

    if (!isMinimizing) {
      // Fire-and-forget — NEVER block dispose()
      if (_isScreenSharing && Platform.isAndroid) {
        FlutterBackground.disableBackgroundExecution().catchError((_) {});
      }
      final roomToDispose = _room;
      _room = null;
      if (roomToDispose != null) {
        roomToDispose.disconnect().catchError((_) {});
        roomToDispose.dispose().catchError((_) {});
      }
    } else {
      debugPrint('✅ Keeping room active (minimized)');
    }

    debugPrint('✅ MeetingRoomScreen disposed');
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ParticipantTrack
// ─────────────────────────────────────────────────────────────────────────────
class ParticipantTrack {
  final Participant participant;
  final VideoTrack? videoTrack;
  final TrackPublication publication;
  final bool isScreenShare;

  ParticipantTrack({
    required this.participant,
    required this.videoTrack,
    required this.publication,
    this.isScreenShare = false,
  });
}