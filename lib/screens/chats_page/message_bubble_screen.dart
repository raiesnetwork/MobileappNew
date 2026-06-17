import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/chats_page/view_file_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/personal_chat_provider.dart';
import '../../api_service/user_api_service.dart';
import '../home/feedpage/feed_screen.dart';
import 'group_chat/forwarded_message_screen.dart';

class MessageBubble extends StatefulWidget {
  final String? content;
  final bool isMe;
  final DateTime timestamp;
  final String? status;
  final bool isFile;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final String? localFilePath;
  final bool isOptimistic;
  final bool readBy;
  final String messageId;
  final String? receiverId;
  final bool isSharedPost;
  final Map<String, dynamic>? sharedPostData;
  final bool isForwarded;
  final bool isLink;
  final Map<String, dynamic>? linkMeta;

  // Voice message properties
  final bool isAudio;
  final String? audioUrl;
  final int? audioDurationMs;
  final String? replyTo;
  final Map<String, dynamic>? replyToMessage;
  final Function(Map<String, dynamic>)? onReply;

  const MessageBubble({
    Key? key,
    this.content,
    required this.isMe,
    required this.timestamp,
    this.status,
    this.isFile = false,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.localFilePath,
    this.isOptimistic = false,
    this.readBy = false,
    required this.messageId,
    this.receiverId,
    this.isAudio = false,
    this.audioUrl,
    this.audioDurationMs,
    this.replyTo,
    this.replyToMessage,
    this.onReply,
    this.isSharedPost = false,
    this.sharedPostData,
    this.isForwarded = false,
    this.isLink = false,
    this.linkMeta,
  }) : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  // Voice message variables
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _isPlayerInitialized = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localAudioPath;
  bool _isLoadingAudio = false;
  StreamSubscription? _playerSubscription;

  // ── Shared-post inline video player ──────────────────────────────────
  VideoPlayerController? _sharedVideoController;
  bool _sharedVideoInitialized = false;
  bool _sharedVideoPlaying = false;
  bool _sharedVideoError = false;

  // ── Enriched post data fetched from API when share omits video/images ──
  Map<String, dynamic>? _enrichedPostData;
  bool _isFetchingPost = false;

  bool _isNetworkImage(String imageUrl) {
    return imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
  }

  @override
  void initState() {
    super.initState();
    if (widget.isAudio) {
      _initializePlayer();
      if (widget.audioDurationMs != null && widget.audioDurationMs! > 0) {
        _duration = Duration(milliseconds: widget.audioDurationMs!);
      }
    }

    if (widget.isSharedPost && widget.sharedPostData != null) {
      final postData = widget.sharedPostData!;
      final postId = postData['_id']?.toString() ?? '';
      final images = postData['images'];
      final hasImages = images is List && images.isNotEmpty;
      final hasVideo = _extractSharedPostVideoUrl(postData) != null;

      if (!hasImages && !hasVideo && postId.length == 24) {
        // Backend share API stripped media — fetch the full post
        WidgetsBinding.instance.addPostFrameCallback((_) => _fetchFullPost(postId));
      } else {
        final videoUrl = _extractSharedPostVideoUrl(postData);
        if (videoUrl != null && videoUrl.isNotEmpty) {
          _initSharedVideo(videoUrl);
        }
      }
    }
  }

  /// Fetch full post by ID using the app's authenticated API service.
  /// This gets the complete post data (including postVideo) that the
  /// share API strips out when creating the sharedPostData object.
  Future<void> _fetchFullPost(String postId) async {
    if (_isFetchingPost || !mounted) return;
    setState(() => _isFetchingPost = true);
    try {
      // Uses UserAPI which calls ApiService.get() — auth token attached automatically
      final response = await UserAPI().getPostById(postId);
      if (!mounted) return;

      if (response != null) {
        // getPostById returns the full decoded JSON — unwrap the data field
        final data = (response['data'] is Map
            ? response['data']
            : response['post'] is Map
            ? response['post']
            : response) as Map<String, dynamic>?;

        if (data != null) {
          final merged = Map<String, dynamic>.from(widget.sharedPostData!);

          // Merge video fields from full post into our shared post data
          for (final k in ['postVideo', 'video', 'videos', 'videoUrl',
            'mediaVideo', 'postVideos', 'videoFile']) {
            if (data[k] != null) merged[k] = data[k];
          }

          // Merge image fields if still empty
          final existingImages = merged['images'];
          if (existingImages is! List || existingImages.isEmpty) {
            for (final k in ['images', 'image', 'media', 'attachments',
              'postImages', 'photos']) {
              if (data[k] != null) { merged['images'] = data[k]; break; }
            }
          }

          setState(() => _enrichedPostData = merged);

          final videoUrl = _extractSharedPostVideoUrl(merged);
          debugPrint('🎬 ✅ Enriched post fetched. Video: $videoUrl');
          debugPrint('🎬 ✅ Enriched keys: ${merged.keys.toList()}');

          if (videoUrl != null && videoUrl.isNotEmpty) {
            await _initSharedVideo(videoUrl);
          }
        }
      } else {
        debugPrint('🎬 ❌ fetchFullPost: getPostById returned null for $postId');
      }
    } catch (e) {
      debugPrint('🎬 ❌ fetchFullPost error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingPost = false);
    }
  }

  // ── Video helpers ─────────────────────────────────────────────────────

  /// Extracts the first usable video URL from a shared post map.
  /// Logs ALL keys in the post data so you can see exactly what the backend sends.
  String? _extractSharedPostVideoUrl(Map<String, dynamic> postData) {
    // ── DEBUG: print every key+value so we know what the backend sends ──
    debugPrint('🎬 [VIDEO DEBUG] All keys in sharedPostData: ${postData.keys.toList()}');
    for (final k in postData.keys) {
      final v = postData[k];
      if (v != null) {
        final preview = v.toString().length > 120
            ? '${v.toString().substring(0, 120)}...'
            : v.toString();
        debugPrint('🎬   [$k] (${v.runtimeType}) = $preview');
      }
    }

    // ── Search every possible key the backend might use ──────────────
    for (final key in [
      'postVideo',       // most common in your feed_screen.dart
      'video',
      'videos',
      'videoUrl',
      'mediaVideo',
      'postVideos',
      'videoFile',
      'videoFiles',
      'media',           // sometimes media contains video
      'attachments',
      'videoLink',
      'mp4',
      'clip',
      'clips',
    ]) {
      final v = postData[key];
      if (v == null) continue;

      // List of strings
      if (v is List && v.isNotEmpty) {
        for (final item in v) {
          if (item == null) continue;
          final s = item.toString().trim();
          // Accept if it looks like a video URL or has a video extension
          if (s.isNotEmpty && _looksLikeVideo(s)) {
            debugPrint('🎬 ✅ Found video under key "$key" (list): $s');
            return _normalizeUrl(s);
          }
        }
        // If no item passed the video check, still try the first non-empty item
        // (backend might not use video extensions for blob URLs)
        for (final item in v) {
          if (item == null) continue;
          final s = item.toString().trim();
          if (s.isNotEmpty && !s.startsWith('data:image/')) {
            debugPrint('🎬 ✅ Found video (fallback list) under key "$key": $s');
            return _normalizeUrl(s);
          }
        }
      }

      // Plain string
      if (v is String && v.isNotEmpty && !v.startsWith('data:image/')) {
        debugPrint('🎬 ✅ Found video under key "$key" (string): $v');
        return _normalizeUrl(v);
      }
    }

    debugPrint('🎬 ❌ No video found in sharedPostData');
    return null;
  }

  /// Returns true if a URL/path looks like a video file.
  bool _looksLikeVideo(String s) {
    final lower = s.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('.mkv') ||
        lower.contains('.webm') ||
        lower.contains('.m4v') ||
        lower.contains('.3gp') ||
        lower.startsWith('data:video/') ||
        lower.contains('/video/') ||
        lower.contains('video');
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('data:')) {
      return url;
    }
    return 'https://api.ixes.ai/$url';
  }

  Future<void> _initSharedVideo(String videoUrl) async {
    try {
      VideoPlayerController ctrl;
      if (videoUrl.startsWith('http://') || videoUrl.startsWith('https://')) {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      } else {
        // base64 / local not supported via URL controller – skip gracefully
        return;
      }
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _sharedVideoController = ctrl;
        _sharedVideoInitialized = true;
      });
    } catch (_) {
      if (mounted) setState(() => _sharedVideoError = true);
    }
  }

  void _toggleSharedVideo() {
    if (_sharedVideoController == null || !_sharedVideoInitialized) return;
    setState(() {
      if (_sharedVideoPlaying) {
        _sharedVideoController!.pause();
        _sharedVideoPlaying = false;
      } else {
        _sharedVideoController!.play();
        _sharedVideoPlaying = true;
      }
    });
  }

  // ── Shared post ───────────────────────────────────────────────────────

  bool get _isMeetingMessage =>
      (widget.content ?? '').trimLeft().startsWith('📅');

  Widget _buildMeetingCard() {
    final lines = (widget.content ?? '').split('\n');
    final title = lines.isNotEmpty ? lines[0] : 'Meeting Scheduled';
    final time = lines.length > 1 ? lines[1] : '';
    final note = lines.length > 2 ? lines[2] : '';

    String meetingUrl = widget.linkMeta?['url']?.toString() ?? '';
    if (meetingUrl.isEmpty) {
      meetingUrl = widget.linkMeta?['meetLink']?.toString() ?? '';
    }
    if (meetingUrl.isEmpty) {
      final urlMatch = RegExp(
        r'https?://[^\s\n]+',
        caseSensitive: false,
      ).firstMatch(widget.content ?? '');
      if (urlMatch != null) {
        meetingUrl = urlMatch.group(0)?.trim() ?? '';
        meetingUrl = meetingUrl.replaceAll(RegExp(r'[.,;:!?]+$'), '');
      }
    }

    return GestureDetector(
      onTap: meetingUrl.isNotEmpty
          ? () => launchUrl(Uri.parse(meetingUrl),
          mode: LaunchMode.externalApplication)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe
                ? Colors.white.withOpacity(0.3)
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12)),
              ),
              child: Row(children: [
                Icon(Icons.video_call_rounded,
                    size: 16,
                    color: widget.isMe ? Colors.white70 : Colors.grey[600]),
                const SizedBox(width: 6),
                Text('Meeting',
                    style: TextStyle(
                        color:
                        widget.isMe ? Colors.white70 : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: widget.isMe ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(time,
                        style: TextStyle(
                            color: widget.isMe
                                ? Colors.white70
                                : Colors.grey[700],
                            fontSize: 13)),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(note,
                        style: TextStyle(
                            color: widget.isMe
                                ? Colors.white60
                                : Colors.grey[600],
                            fontSize: 12)),
                  ],
                  if (meetingUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.link_rounded,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            meetingUrl,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF2563EB),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ScaffoldMessengerState get _scaffoldMessenger =>
      ScaffoldMessenger.of(context);

  Future<void> _initializePlayer() async {
    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      setState(() => _isPlayerInitialized = true);
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  Future<void> _shareMessage() async {
    try {
      if (widget.isFile || widget.isAudio) {
        String? filePath = widget.localFilePath;
        String? remoteUrl =
        widget.isAudio ? widget.audioUrl : widget.fileUrl;
        String fileName =
            widget.fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}';

        if (filePath != null &&
            filePath.isNotEmpty &&
            File(filePath).existsSync()) {
          await Share.shareXFiles([XFile(filePath)]);
          return;
        }

        if (remoteUrl != null && remoteUrl.isNotEmpty) {
          if (!remoteUrl.startsWith('http')) {
            remoteUrl = 'https://api.ixes.ai/$remoteUrl';
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('Preparing to share...'),
                ]),
                duration: Duration(seconds: 15),
              ),
            );
          }
          try {
            final tmpDir = await getTemporaryDirectory();
            final savePath = '${tmpDir.path}/$fileName';
            if (!File(savePath).existsSync()) {
              final response = await http.get(Uri.parse(remoteUrl));
              await File(savePath).writeAsBytes(response.bodyBytes);
            }
            if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
            await Share.shareXFiles([XFile(savePath)]);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Failed to share: $e'),
                backgroundColor: Colors.red,
              ));
            }
          }
        }
        return;
      }

      final text = widget.content ?? '';
      if (text.isNotEmpty) await Share.share(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _buildForwardedLabel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply_rounded,
              size: 13,
              color: widget.isMe ? Colors.white60 : Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            'Forwarded',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: widget.isMe ? Colors.white60 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playPauseAudio() async {
    if (!_isPlayerInitialized || _player == null) return;

    try {
      if (_isPlaying) {
        await _player!.pausePlayer();
        setState(() => _isPlaying = false);
      } else {
        String? audioPath = await _getAudioPath();
        if (audioPath == null) return;

        if (_duration == Duration.zero || _duration.inMilliseconds < 100) {
          await _loadAudioDuration(audioPath);
        }

        await _playerSubscription?.cancel();
        _playerSubscription = null;

        await _player!.startPlayer(
          fromURI: audioPath,
          whenFinished: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _position = Duration.zero;
              });
            }
          },
        );

        setState(() => _isPlaying = true);

        _playerSubscription = _player!.onProgress!.listen(
              (event) {
            if (!mounted || !_isPlaying) return;
            setState(() {
              _position = event.position;
              if (event.duration > Duration.zero &&
                  event.duration != _duration) {
                _duration = event.duration;
              }
            });
          },
          onError: (_) {},
          onDone: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _position = Duration.zero;
              });
            }
          },
          cancelOnError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error playing audio: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  List<dynamic> _resolvePostImages(Map<String, dynamic> postData) {
    for (final key in ['images', 'image', 'media', 'attachments', 'photos']) {
      final v = postData[key];
      if (v is List && v.isNotEmpty) return v;
      if (v is String && v.isNotEmpty) return [v];
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD SHARED POST — with video support
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildSharedPost() {
    if (widget.sharedPostData == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.share,
              color: widget.isMe ? Colors.white70 : Colors.grey[600],
              size: 20),
          const SizedBox(width: 8),
          Text('Shared a post',
              style: TextStyle(
                  color: widget.isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontStyle: FontStyle.italic)),
        ]),
      );
    }

    // Use enriched post data (fetched from API) if available, else fall back to widget data
    final postData = _enrichedPostData ?? widget.sharedPostData!;
    final shareType = postData['shareType']?.toString() ?? 'feed';

    final postId = postData['_id']?.toString() ?? '';
    final postContent = postData['text'] ?? '';
    final postImages = _resolvePostImages(postData);

    // ── VIDEO: extract first video URL from the post ──────────────────
    final videoUrl = _extractSharedPostVideoUrl(postData);
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;

    // Show loading indicator while fetching full post data
    if (_isFetchingPost && !hasVideo && postImages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.white.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe ? Colors.white.withOpacity(0.3) : Colors.grey[300]!,
          ),
        ),
        child: Row(children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.isMe ? Colors.white70 : Colors.grey[600]!,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('Loading post...',
              style: TextStyle(
                  color: widget.isMe ? Colors.white70 : Colors.grey[600],
                  fontSize: 13)),
        ]),
      );
    }

    final authorName = postData['authorName'] ?? 'Unknown';
    final authorProfile = postData['authorProfile'];
    final likesCount = postData['likesCount'] ?? 0;
    final commentsCount = postData['commentsCount'] ?? 0;
    final forwerdUrl = postData['forwerdUrl']?.toString() ?? '';

    final isOriginalShared = postData['isOriginalShared'] ?? false;
    final isForwarded = postData['isForwarded'] ?? false;

    final isValidPostId = postId.length == 24 &&
        RegExp(r'^[a-f0-9]{24}$').hasMatch(postId);

    IconData headerIcon;
    String headerLabel;

    if (isForwarded) {
      headerIcon = Icons.reply_rounded;
      headerLabel = 'Forwarded';
    } else if (isOriginalShared) {
      switch (shareType) {
        case 'announcement':
          headerIcon = Icons.campaign_rounded;
          headerLabel = 'Shared Announcement';
          break;
        case 'campaign':
          headerIcon = Icons.flag_rounded;
          headerLabel = 'Shared Campaign';
          break;
        case 'service':
          headerIcon = Icons.miscellaneous_services_rounded;
          headerLabel = 'Shared Service';
          break;
        default:
          headerIcon = Icons.share;
          headerLabel = 'Shared Post';
      }
    } else {
      headerIcon = Icons.share;
      headerLabel = 'Shared Post';
    }

    return GestureDetector(
      onTap: () async {
        if (shareType == 'feed' && isValidPostId) {
          _navigateToPost(postData);
        } else if (shareType != 'feed' && forwerdUrl.isNotEmpty) {
          final uri = Uri.parse(forwerdUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Cannot open link'),
              backgroundColor: Colors.red,
            ));
          }
        } else if (forwerdUrl.isNotEmpty) {
          final uri = Uri.parse(forwerdUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Post link not available'),
              backgroundColor: Colors.orange,
            ));
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Post link not available'),
            backgroundColor: Colors.orange,
          ));
        }
      },
      child: Container(
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.white.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe
                ? Colors.white.withOpacity(0.3)
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12)),
              ),
              child: Row(children: [
                Icon(headerIcon,
                    size: 16,
                    color:
                    widget.isMe ? Colors.white70 : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(headerLabel,
                    style: TextStyle(
                        color: widget.isMe
                            ? Colors.white70
                            : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ]),
            ),

            // Author
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: widget.isMe
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey[300],
                  backgroundImage: authorProfile != null &&
                      authorProfile.isNotEmpty
                      ? (authorProfile.startsWith('data:image/')
                      ? MemoryImage(
                      base64Decode(authorProfile.split(',')[1]))
                      : NetworkImage(authorProfile) as ImageProvider)
                      : null,
                  child: authorProfile == null || authorProfile.isEmpty
                      ? Text(
                      authorName.isNotEmpty
                          ? authorName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                          color:
                          widget.isMe ? Colors.white : Colors.grey[700],
                          fontSize: 14,
                          fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(authorName,
                      style: TextStyle(
                          color:
                          widget.isMe ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),

            // Post text
            if (postContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(postContent,
                    style: TextStyle(
                        color: widget.isMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ),

            // ── VIDEO (shown when post has a video) ──────────────────
            if (hasVideo) ...[
              // Lazy-init if initState missed it (e.g. data arrived late)
              if (!_sharedVideoInitialized && !_sharedVideoError && videoUrl != null)
                Builder(builder: (_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_sharedVideoInitialized && !_sharedVideoError && mounted) {
                      _initSharedVideo(videoUrl);
                    }
                  });
                  return const SizedBox.shrink();
                }),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildSharedPostVideo(),
              ),
            ]

            // ── IMAGE (shown when no video but images exist) ─────────
            else if (postImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildPostImage(postImages[0])),
                ),
              ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                if (shareType == 'feed') ...[
                  Icon(Icons.favorite,
                      size: 14,
                      color: widget.isMe
                          ? Colors.white60
                          : Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('$likesCount',
                      style: TextStyle(
                          color: widget.isMe
                              ? Colors.white70
                              : Colors.grey[600],
                          fontSize: 12)),
                  const SizedBox(width: 16),
                  Icon(Icons.comment,
                      size: 14,
                      color: widget.isMe
                          ? Colors.white60
                          : Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('$commentsCount',
                      style: TextStyle(
                          color: widget.isMe
                              ? Colors.white70
                              : Colors.grey[600],
                          fontSize: 12)),
                ],
                const Spacer(),
                Text('Tap to view',
                    style: TextStyle(
                        color: widget.isMe
                            ? Colors.white70
                            : Colors.blue[600],
                        fontSize: 11,
                        fontStyle: FontStyle.italic)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Inline video player widget for shared post ────────────────────────
  Widget _buildSharedPostVideo() {
    if (_sharedVideoError) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.1)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off,
                  size: 36,
                  color:
                  widget.isMe ? Colors.white38 : Colors.grey[400]),
              const SizedBox(height: 8),
              Text('Video unavailable',
                  style: TextStyle(
                      color: widget.isMe ? Colors.white60 : Colors.grey[500],
                      fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (!_sharedVideoInitialized || _sharedVideoController == null) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color:
          widget.isMe ? Colors.white.withOpacity(0.1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isMe ? Colors.white70 : Colors.grey[600]!,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleSharedVideo,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: _sharedVideoController!.value.aspectRatio
              .clamp(0.5, 2.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(_sharedVideoController!),
              // Play/pause overlay
              Center(
                child: AnimatedOpacity(
                  opacity: _sharedVideoPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 30),
                  ),
                ),
              ),
              // Video label badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam,
                          size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Video',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkPreview() {
    final meta = widget.linkMeta;
    if (meta == null) return const SizedBox();

    return GestureDetector(
      onTap: () async {
        final url = meta['url'];
        if (url != null) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: widget.isMe ? Colors.white.withOpacity(0.1) : Colors.grey[100],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((meta['image'] ?? '').toString().isNotEmpty)
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  meta['image'],
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta['title'] ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.isMe ? Colors.white : Colors.black)),
                  const SizedBox(height: 4),
                  Text(meta['description'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: widget.isMe
                              ? Colors.white70
                              : Colors.black87)),
                  const SizedBox(height: 6),
                  Text(meta['url'] ?? '',
                      style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostImage(dynamic imageData) {
    String? imageUrl;
    if (imageData is String) {
      imageUrl = imageData.isNotEmpty ? imageData : null;
    } else if (imageData is Map) {
      imageUrl = (imageData['url'] ??
          imageData['image'] ??
          imageData['imageUrl'] ??
          imageData['src'] ??
          imageData['path'])
          ?.toString();
    }

    if (imageUrl == null || imageUrl.isEmpty) return _buildImageError();

    if (!imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://') &&
        !imageUrl.startsWith('data:image/')) {
      imageUrl = 'https://api.ixes.ai/$imageUrl';
    }

    if (imageUrl.startsWith('data:image/')) {
      try {
        return Image.memory(base64Decode(imageUrl.split(',')[1]),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildImageError());
      } catch (_) {
        return _buildImageError();
      }
    }

    return Image.network(imageUrl, fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }, errorBuilder: (_, __, ___) => _buildImageError());
  }

  Widget _buildImageError() {
    return Container(
      color: widget.isMe ? Colors.white.withOpacity(0.1) : Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image,
                size: 40,
                color: widget.isMe ? Colors.white30 : Colors.grey[400]),
            const SizedBox(height: 8),
            Text('Image unavailable',
                style: TextStyle(
                    color: widget.isMe ? Colors.white60 : Colors.grey[500],
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  bool get _isImageFile {
    if (widget.fileType != null &&
        widget.fileType!.toLowerCase().contains('image')) return true;
    if (widget.fileName != null) {
      final ext = widget.fileName!.toLowerCase();
      return ext.endsWith('.png') ||
          ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.gif') ||
          ext.endsWith('.webp');
    }
    return false;
  }

  Widget _buildChatMessageImage() {
    Widget imageWidget;

    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      final file = File(widget.localFilePath!);
      if (file.existsSync()) {
        imageWidget = Image.file(file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildImageError());
      } else {
        imageWidget = _buildImageError();
      }
    } else {
      String url = widget.fileUrl ?? '';
      if (url.isNotEmpty) {
        if (!url.startsWith('http')) url = 'https://api.ixes.ai/$url';
        imageWidget = CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: widget.isMe
                ? Colors.white.withOpacity(0.1)
                : Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => _buildImageError(),
        );
      } else {
        imageWidget = _buildImageError();
      }
    }

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: widget.isMe
          ? const Radius.circular(16)
          : const Radius.circular(4),
      bottomRight: widget.isMe
          ? const Radius.circular(4)
          : const Radius.circular(16),
    );

    return GestureDetector(
      onTap: widget.status == 'sending'
          ? null
          : () => _handleFileOpen(context),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: 220,
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              if (widget.status == 'sending')
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white))),
                  ),
                ),
              if (widget.status == 'failed')
                Container(
                  color: Colors.black45,
                  child: const Center(
                      child:
                      Icon(Icons.refresh, color: Colors.white, size: 28)),
                ),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatTime(widget.timestamp),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      if (widget.isMe && widget.status != null) ...[
                        const SizedBox(width: 3),
                        if (widget.status == 'sent' && widget.readBy)
                          Icon(Icons.done_all,
                              size: 12, color: Colors.blue[200])
                        else
                          Icon(_getStatusIcon(),
                              size: 12, color: Colors.white70),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPost(Map<String, dynamic> postData) {
    if (!mounted) return;
    final postId = postData['_id']?.toString() ?? '';
    final isValidPostId = postId.length == 24 &&
        RegExp(r'^[a-f0-9]{24}$').hasMatch(postId);

    if (!isValidPostId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Post link not available'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Post',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ),
          body: FeedScreen(postId: postId),
        ),
      ),
    );
  }

  Future<void> _loadAudioDuration(String audioPath) async {
    try {
      if (widget.audioDurationMs != null && widget.audioDurationMs! > 0) {
        final d = Duration(milliseconds: widget.audioDurationMs!);
        if (mounted) setState(() => _duration = d);
        return;
      }

      final tempPlayer = FlutterSoundPlayer();
      await tempPlayer.openPlayer();
      Duration? detectedDuration;
      bool durationFound = false;

      await tempPlayer.startPlayer(fromURI: audioPath, whenFinished: () {});
      await Future.delayed(const Duration(milliseconds: 200));

      final tempSub = tempPlayer.onProgress!.listen((event) {
        if (event.duration > Duration.zero && !durationFound) {
          detectedDuration = event.duration;
          durationFound = true;
        }
      });

      int attempts = 0;
      while (!durationFound && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      await tempSub.cancel();
      await tempPlayer.stopPlayer();
      await tempPlayer.closePlayer();

      if (detectedDuration != null && mounted) {
        setState(() => _duration = detectedDuration!);
      } else if (widget.audioDurationMs != null && mounted) {
        setState(
                () => _duration = Duration(milliseconds: widget.audioDurationMs!));
      }
    } catch (e) {
      if (widget.audioDurationMs != null && mounted) {
        setState(
                () => _duration = Duration(milliseconds: widget.audioDurationMs!));
      }
    }
  }

  Future<String?> _getAudioPath() async {
    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      final localFile = File(widget.localFilePath!);
      if (await localFile.exists()) return widget.localFilePath;
    }

    if (_localAudioPath != null && File(_localAudioPath!).existsSync()) {
      return _localAudioPath;
    }

    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      setState(() => _isLoadingAudio = true);
      try {
        final response = await http.get(Uri.parse(widget.audioUrl!));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final fileName = 'voice_${widget.messageId}.aac';
          final audioFile = File('${tempDir.path}/$fileName');
          await audioFile.writeAsBytes(response.bodyBytes);
          _localAudioPath = audioFile.path;
          return _localAudioPath;
        }
      } catch (e) {
        _scaffoldMessenger.showSnackBar(SnackBar(
          content: const Text('Failed to load voice message'),
          backgroundColor: Colors.red,
        ));
      } finally {
        setState(() => _isLoadingAudio = false);
      }
    }
    return null;
  }

  String _formatDuration(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
  }

  Widget _buildVoiceMessage() {
    double progress = 0.0;
    if (_duration.inMilliseconds > 0) {
      progress =
          (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _isLoadingAudio ? null : _playPauseAudio,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: widget.isMe ? Colors.white : Colors.grey[800],
                  shape: BoxShape.circle),
              child: _isLoadingAudio
                  ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isMe ? Colors.blue : Colors.white)))
                  : Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                  color: widget.isMe ? Colors.blue : Colors.white,
                  size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(20, (index) {
                      final barProgress = index / 20;
                      final isActive = progress >= barProgress;
                      final heights = [
                        20.0, 15.0, 10.0, 18.0, 12.0, 16.0, 14.0, 20.0,
                        11.0, 15.0, 17.0, 13.0, 19.0, 10.0, 16.0, 14.0,
                        18.0, 12.0, 15.0, 20.0
                      ];
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: heights[index],
                          decoration: BoxDecoration(
                            color: isActive
                                ? (widget.isMe ? Colors.white : Colors.blue)
                                : (widget.isMe
                                ? Colors.white54
                                : Colors.grey[400]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_buildDurationText(),
                    style: TextStyle(
                        color:
                        widget.isMe ? Colors.white70 : Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (widget.status == 'sending') ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isMe ? Colors.white70 : Colors.grey[600]!)),
            ),
          ] else if (widget.status == 'failed') ...[
            const SizedBox(width: 8),
            const Icon(Icons.error_outline, size: 16, color: Colors.red),
          ],
        ],
      ),
    );
  }

  String _buildDurationText() {
    if (_isPlaying || _position.inSeconds > 0) {
      return '${_formatDuration(_position)} / ${_formatDuration(_duration)}';
    }
    if (_duration.inSeconds > 0) return _formatDuration(_duration);
    return '0:00';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment:
        widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(context),
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: EdgeInsets.symmetric(
              horizontal: (widget.isFile && _isImageFile) ? 0 : 16,
              vertical: (widget.isFile && _isImageFile) ? 0 : 10,
            ),
            decoration: BoxDecoration(
              color: (widget.isFile && _isImageFile)
                  ? Colors.transparent
                  : (widget.isMe ? Primary : Colors.grey[300]),
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomRight:
                widget.isMe ? const Radius.circular(4) : null,
                bottomLeft:
                !widget.isMe ? const Radius.circular(4) : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isForwarded == true && !widget.isSharedPost)
                  _buildForwardedLabel(),

                // Reply preview
                if (widget.replyToMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                          left: BorderSide(
                              color: widget.isMe
                                  ? Colors.white
                                  : Colors.grey[800]!,
                              width: 2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Replied to',
                            style: TextStyle(
                                color: widget.isMe
                                    ? Colors.white70
                                    : Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          widget.replyToMessage!['text'] != null &&
                              widget.replyToMessage!['text']
                                  .toString()
                                  .isNotEmpty
                              ? widget.replyToMessage!['text']
                              : (widget.replyToMessage!['isFile'] == true
                              ? '📎 ${widget.replyToMessage!['fileName'] ?? 'File'}'
                              : (widget.replyToMessage!['isAudio'] == true
                              ? '🎤 Voice message'
                              : (widget.replyToMessage![
                          'isSharedPost'] ==
                              true
                              ? '📄 Shared post'
                              : 'Message'))),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: widget.isMe
                                  ? Colors.white70
                                  : Colors.grey[700],
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],

                // Content
                if (widget.isSharedPost && widget.sharedPostData != null)
                  _buildSharedPost()
                else if (widget.isAudio)
                  _buildVoiceMessage()
                else if (widget.isFile &&
                      widget.fileUrl != null &&
                      widget.fileName != null)
                    if (_isImageFile)
                      _buildChatMessageImage()
                    else
                      GestureDetector(
                        onTap: () => _handleFileOpen(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.isMe
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(_getFileIcon(widget.fileType),
                                color: widget.isMe
                                    ? Colors.white
                                    : Colors.black87,
                                size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.fileName!,
                                        style: TextStyle(
                                            color: widget.isMe
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    if (widget.status == 'sending')
                                      Text('Uploading...',
                                          style: TextStyle(
                                              color: widget.isMe
                                                  ? Colors.white70
                                                  : Colors.grey[600],
                                              fontSize: 12))
                                    else if (widget.status == 'failed')
                                      Text('Failed to upload',
                                          style: TextStyle(
                                              color: widget.isMe
                                                  ? Colors.white70
                                                  : Colors.red[600],
                                              fontSize: 12))
                                    else
                                      Text('Tap to open',
                                          style: TextStyle(
                                              color: widget.isMe
                                                  ? Colors.white70
                                                  : Colors.grey[600],
                                              fontSize: 12)),
                                  ]),
                            ),
                            if (widget.status != 'sending' &&
                                widget.status != 'failed')
                              Icon(Icons.open_in_new,
                                  color: widget.isMe
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  size: 16),
                          ]),
                        ),
                      )
                  else if (widget.content != null) ...[
                      if (_isMeetingMessage)
                        _buildMeetingCard()
                      else ...[
                        ClickableMessageText(
                            text: widget.content!, isMe: widget.isMe),
                        if (widget.isLink && widget.linkMeta != null)
                          _buildLinkPreview(),
                      ],
                    ],

                if (!(widget.isFile && _isImageFile)) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatTime(widget.timestamp),
                            style: TextStyle(
                                color: widget.isMe
                                    ? Colors.white70
                                    : Colors.grey[600],
                                fontSize: 12)),
                        if (widget.isMe && widget.status != null) ...[
                          const SizedBox(width: 4),
                          if (widget.status == 'sent' && widget.readBy)
                            Icon(Icons.done_all,
                                size: 12, color: Colors.blue[300])
                          else
                            Icon(_getStatusIcon(),
                                size: 12,
                                color: widget.isMe
                                    ? Colors.white70
                                    : Colors.grey[600]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    List<Widget> options = [];

    options.add(ListTile(
      leading:
      Icon(Icons.reply, color: Theme.of(context).colorScheme.primary),
      title: const Text('Reply'),
      onTap: () {
        Navigator.pop(context);
        if (widget.onReply != null) {
          widget.onReply!({
            '_id': widget.messageId,
            'text': widget.content,
            'isFile': widget.isFile,
            'fileName': widget.fileName,
            'isAudio': widget.isAudio,
            'senderId': widget.isMe ? 'current_user' : 'other_user',
          });
        }
      },
    ));

    options.add(ListTile(
      leading: Icon(Icons.reply_rounded,
          color: Theme.of(context).colorScheme.primary),
      title: const Text('Forward'),
      onTap: () {
        Navigator.pop(context);
        String? meetingUrl;
        if ((widget.content ?? '').trimLeft().startsWith('📅')) {
          meetingUrl = widget.linkMeta?['url']?.toString();
          if (meetingUrl == null) {
            final match =
            RegExp(r'https?://[^\s\n]+').firstMatch(widget.content ?? '');
            meetingUrl = match
                ?.group(0)
                ?.replaceAll(RegExp(r'[.,;:!?]+$'), '');
          }
        }

        final msgMap = {
          '_id': widget.messageId,
          'text': widget.content ?? '',
          'isFile': widget.isFile,
          'fileName': widget.fileName ?? '',
          'fileUrl': widget.fileUrl ?? '',
          'isAudio': widget.isAudio,
          'audioUrl': widget.audioUrl ?? '',
          'isSharedPost': widget.isSharedPost,
          if (widget.isSharedPost) 'sharedPost': widget.sharedPostData,
          'link': widget.isLink || meetingUrl != null,
          'linkMeta': widget.linkMeta ??
              (meetingUrl != null ? {'url': meetingUrl} : null),
        };

        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ForwardMessageScreen(message: msgMap)));
      },
    ));

    if (widget.isSharedPost &&
        widget.sharedPostData != null &&
        (widget.sharedPostData!['forwerdUrl'] ?? '').toString().isNotEmpty) {
      options.add(ListTile(
        leading: Icon(Icons.link,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Copy Link'),
        onTap: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(
              text: widget.sharedPostData!['forwerdUrl'].toString()));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Link copied to clipboard'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
        },
      ));
    }

    options.add(ListTile(
      leading: Icon(Icons.share,
          color: Theme.of(context).colorScheme.primary),
      title: const Text('Share'),
      onTap: () {
        Navigator.pop(context);
        _shareMessage();
      },
    ));

    if (widget.isMe &&
        !widget.isFile &&
        !widget.isAudio &&
        widget.content != null &&
        widget.content!.isNotEmpty &&
        !widget.isOptimistic &&
        widget.status != 'sending') {
      options.add(ListTile(
        leading: Icon(Icons.edit,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Edit Message'),
        onTap: () {
          Navigator.pop(context);
          _showEditDialog(context);
        },
      ));
    }

    if (widget.isMe &&
        !widget.isOptimistic &&
        widget.status != 'sending' &&
        widget.status != 'failed') {
      options.add(ListTile(
        leading: const Icon(Icons.delete, color: Colors.red),
        title: const Text('Delete Message',
            style: TextStyle(color: Colors.red)),
        onTap: () {
          Navigator.pop(context);
          _showDeleteConfirmation(context);
        },
      ));
    }

    final String? copyableUrl = () {
      final metaUrl = widget.linkMeta?['url']?.toString() ?? '';
      if (metaUrl.isNotEmpty) return metaUrl;
      if ((widget.content ?? '').trimLeft().startsWith('📅')) {
        final match = RegExp(r'https?://[^\s\n\r]+', caseSensitive: false)
            .firstMatch(widget.content ?? '');
        if (match != null) {
          return match.group(0)?.replaceAll(RegExp(r'[.,;:!?\s]+$'), '');
        }
      }
      return null;
    }();

    if (copyableUrl != null && copyableUrl.isNotEmpty) {
      options.add(ListTile(
        leading: Icon(Icons.link,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Copy Link'),
        onTap: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: copyableUrl));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Link copied to clipboard'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
        },
      ));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          ...options,
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    if (widget.content == null) return;
    final TextEditingController editController =
    TextEditingController(text: widget.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
              hintText: 'Enter new message...',
              border: OutlineInputBorder()),
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  _handleEditMessage(context, editController.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
            'Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _handleDeleteMessage(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditMessage(
      BuildContext context, String newText) async {
    if (newText.isEmpty || newText == widget.content) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    if (!mounted) return;

    _scaffoldMessenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 16),
        Text('Editing message...'),
      ]),
      duration: Duration(seconds: 2),
    ));

    try {
      final provider = context.read<PersonalChatProvider>();
      final result = await provider.editMessage(
        messageId: widget.messageId,
        newText: newText,
        receiverId: widget.receiverId ?? '',
      );
      if (!mounted) return;
      if (result != null && result['error'] != true) {
        _scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Message edited successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      } else {
        _scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(
              'Failed to edit message: ${result?['message'] ?? 'Unknown error'}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      _scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Error editing message: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _handleDeleteMessage(BuildContext context) async {
    Navigator.pop(context);
    if (!mounted) return;

    _scaffoldMessenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 16),
        Text('Deleting message...'),
      ]),
      duration: Duration(seconds: 2),
    ));

    try {
      final provider = context.read<PersonalChatProvider>();
      final result = await provider.deleteMessage(
        messageId: widget.messageId,
        receiverId: widget.receiverId ?? '',
      );
      if (!mounted) return;
      if (result != null && result['error'] != true) {
        _scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Message deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      } else {
        String errorMessage = result?['message'] ?? 'Unknown error';
        if (errorMessage.contains('Cannot DELETE') ||
            errorMessage.contains('404')) {
          errorMessage = 'Message not found. Please refresh the chat.';
        }
        _scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('Failed to delete message: $errorMessage'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      _scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Error deleting message: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _handleFileOpen(BuildContext context) async {
    if (widget.fileUrl == null || widget.fileName == null) {
      _scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text('File information is missing'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (widget.status == 'sending') {
      _scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text('File is still uploading, please wait'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (widget.status == 'failed') {
      _scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text('File upload failed, cannot open'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    await FileViewerHelper.openFile(
      context: context,
      fileUrl: widget.fileUrl!,
      fileName: widget.fileName!,
      localFilePath: widget.localFilePath,
    );
  }

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.insert_drive_file;
    final type = fileType.toLowerCase();
    if (type.contains('image')) return Icons.image;
    if (type.contains('audio')) return Icons.audiotrack;
    if (type.contains('video')) return Icons.videocam;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('word') || type.contains('document'))
      return Icons.description;
    if (type.contains('excel') || type.contains('spreadsheet'))
      return Icons.table_chart;
    if (type.contains('powerpoint') || type.contains('presentation'))
      return Icons.slideshow;
    if (type.contains('text')) return Icons.text_snippet;
    if (type.contains('zip') || type.contains('rar')) return Icons.archive;
    return Icons.insert_drive_file;
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  IconData _getStatusIcon() {
    switch (widget.status) {
      case 'sending':
        return Icons.access_time;
      case 'sent':
        return Icons.done;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.done;
    }
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _playerSubscription = null;
    if (_isPlaying && _player != null) {
      _player!.stopPlayer().catchError((_) {});
    }
    if (_player != null) {
      _player!.closePlayer().catchError((_) {});
      _player = null;
    }

    // Dispose video controller
    _sharedVideoController?.pause();
    _sharedVideoController?.dispose();
    _sharedVideoController = null;

    super.dispose();
  }

  @override
  void deactivate() {
    _playerSubscription?.cancel();
    _playerSubscription = null;
    if (_isPlaying && _player != null) {
      _player!.pausePlayer().catchError((_) {});
      _isPlaying = false;
    }
    // Pause video on deactivate
    _sharedVideoController?.pause();
    _sharedVideoPlaying = false;
    super.deactivate();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ClickableMessageText
// ─────────────────────────────────────────────────────────────────────────────

class ClickableMessageText extends StatelessWidget {
  final String text;
  final bool isMe;

  const ClickableMessageText(
      {Key? key, required this.text, required this.isMe})
      : super(key: key);

  @override
  Widget build(BuildContext context) => RichText(text: _buildTextSpans());

  TextSpan _buildTextSpans() {
    final List<TextSpan> spans = [];

    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?'
      r'[-a-zA-Z0-9@:%._\+~#=]{1,256}'
      r'\.[a-zA-Z0-9()]{1,6}\b'
      r'([-a-zA-Z0-9()@:%_\+.~#?&//=]*)'
      r'|'
      r'https?:\/\/'
      r'localhost'
      r'(:[0-9]{1,5})?'
      r'(\/[-a-zA-Z0-9()@:%_\+.~#?&//=]*)?'
      r'|'
      r'www\.'
      r'[-a-zA-Z0-9@:%._\+~#=]{1,256}'
      r'\.[a-zA-Z0-9()]{1,6}\b'
      r'([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    final matches = urlPattern.allMatches(text);
    int currentPosition = 0;

    for (final match in matches) {
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, match.start),
          style: TextStyle(
              color: isMe ? Colors.white : Colors.black87, fontSize: 16),
        ));
      }
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: isMe ? Colors.lightBlueAccent : Colors.blue[800],
          fontSize: 16,
          decoration: TextDecoration.underline,
          decorationColor:
          isMe ? Colors.lightBlueAccent : Colors.blue[800],
          decorationThickness: 2.0,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchURL(url),
      ));
      currentPosition = match.end;
    }

    if (currentPosition < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPosition),
        style: TextStyle(
            color: isMe ? Colors.white : Colors.black87, fontSize: 16),
      ));
    }

    return TextSpan(children: spans);
  }

  Future<void> _launchURL(String urlString) async {
    if (!urlString.startsWith('http://') &&
        !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}