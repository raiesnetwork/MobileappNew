import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/group_provider.dart';
import '../../../providers/video_call_provider.dart';
import '../../../providers/voice_call_provider.dart';
import '../../home/feedpage/feed_screen.dart';
import '../../video_call/video_call_initiate_.dart';
import '../../voice_call/outgoing_voice_call.dart';
import '../chat_detail_screen.dart';
import '../view_file_screen.dart';
import 'forwarded_message_screen.dart';

class GroupMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final String? currentUserId;
  final String groupId;
  final bool showAvatar;
  final Function(Map<String, dynamic>)? onReply;

  const GroupMessageBubble({
    Key? key,
    required this.message,
    required this.currentUserId,
    required this.groupId,
    this.showAvatar = true,
    this.onReply,
  }) : super(key: key);

  @override
  State<GroupMessageBubble> createState() => _GroupMessageBubbleState();
}

class _GroupMessageBubbleState extends State<GroupMessageBubble>
    with AutomaticKeepAliveClientMixin {
  static const Color _purple = Color(0xFF6C5CE7);

  bool _isMe = false;
  String _senderId = '';
  bool _isSharedPost = false;
  String _senderName = 'Unknown';
  Map<String, dynamic>? _senderMap;
  bool _isAudio = false;
  bool _isFile = false;
  bool _isForwardedMsg = false;
  Map<String, dynamic>? _cachedPostData;

  FlutterSoundPlayer? _player;
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localAudioPath;
  StreamSubscription? _playerSub;

  // ── AutomaticKeepAliveClientMixin ────────────────────────────────────────
  @override
  bool get wantKeepAlive => _isSharedPost || _isAudio;

  // ════════════════════════════════════════════════════════════════════════
  //  INIT & DISPOSE
  // ════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _parseMessage();
    if (_isSharedPost) {
      _cachedPostData = _resolvePostData();
      // If we couldn't resolve real post data, demote to forwarded text
      if (_cachedPostData == null) {
        _isSharedPost = false;
        _isForwardedMsg = widget.message['forwerd'] == true;
      }
    }
    if (_isAudio) {
      _initPlayer();
      final ms = widget.message['audioDurationMs'];
      if (ms is int && ms > 0) _duration = Duration(milliseconds: ms);
    }
  }

  @override
  void deactivate() {
    _playerSub?.cancel();
    _playerSub = null;
    if (_isPlaying && _player != null) {
      _player!.pausePlayer().catchError((_) {});
      _isPlaying = false;
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    if (_player != null) {
      if (_isPlaying) _player!.stopPlayer().catchError((_) {});
      _player!.closePlayer().catchError((_) {});
      _player = null;
    }
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PARSE MESSAGE — single source of truth, strict detection
  // ════════════════════════════════════════════════════════════════════════
  void _parseMessage() {
    final rawSender = widget.message['senderId'];
    if (rawSender is Map<String, dynamic>) {
      _senderMap = rawSender;
      _senderName = rawSender['profile']?['name']?.toString() ?? 'Unknown';
      _senderId = rawSender['_id']?.toString() ?? '';
    } else {
      _senderMap = null;
      _senderName = 'Unknown';
      _senderId = rawSender?.toString() ?? '';
    }

    _isMe = widget.currentUserId != null && widget.currentUserId == _senderId;
    _isAudio = widget.message['isAudio'] == true;
    _isFile = widget.message['isFile'] == true ||
        (widget.message['fileUrl'] != null &&
            widget.message['fileUrl'].toString().isNotEmpty &&
            !_isAudio);

    // Replace the _isSharedPost detection block inside _parseMessage():

    final sharedPost = widget.message['sharedPost'];
    final hasValidSharedPost = sharedPost is Map &&
        sharedPost.isNotEmpty &&
        sharedPost['_id'] != null &&
        sharedPost['_id'].toString().length == 24 &&
        RegExp(r'^[a-f0-9]{24}$').hasMatch(sharedPost['_id'].toString());

    final fUrl = widget.message['forwerdUrl']?.toString() ?? '';

// ── non-feed shares (announcement, campaign, service) ──────
    final isNonFeedShare = widget.message['forwerd'] == true &&
        fUrl.isNotEmpty &&
        (fUrl.contains('/announcements') ||
            fUrl.contains('/campaign/') ||
            fUrl.contains('/services/'));

// ── feed shares (valid post ID at end of URL) ───────────────
    String extractedPostId = '';
    if (fUrl.isNotEmpty && !isNonFeedShare) {
      final segment = fUrl.split('/').last.trim();
      if (segment.length == 24 && RegExp(r'^[a-f0-9]{24}$').hasMatch(segment)) {
        extractedPostId = segment;
      }
    }

    final forwardedFrom = widget.message['forwardedFrom'];
    final hasForwardedFrom = forwardedFrom is Map && forwardedFrom.isNotEmpty;

    _isSharedPost = !_isAudio &&
        !_isFile &&
        (hasValidSharedPost ||
            isNonFeedShare ||                          // ← NEW
            (widget.message['forwerd'] == true && extractedPostId.isNotEmpty) ||
            hasForwardedFrom);

    _isForwardedMsg = widget.message['forwerd'] == true && !_isSharedPost;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RESOLVE POST DATA
  // ════════════════════════════════════════════════════════════════════════
  Map<String, dynamic>? _resolvePostData() {
    // Add this block at the TOP of _resolvePostData(), before Priority 1:

// ── Non-feed share (announcement / campaign / service) ──────
    final fUrl = widget.message['forwerdUrl']?.toString() ?? '';
    if (widget.message['forwerd'] == true && fUrl.isNotEmpty &&
        (fUrl.contains('/announcements') ||
            fUrl.contains('/campaign/') ||
            fUrl.contains('/services/'))) {

      String shareType = 'announcement';
      if (fUrl.contains('/campaign/')) shareType = 'campaign';
      if (fUrl.contains('/services/')) shareType = 'service';

      final image = widget.message['image']?.toString() ?? '';
      return {
        '_id': '',               // no post navigation for these
        'shareType': shareType,
        'forwerdUrl': fUrl,
        'text': widget.message['text']?.toString() ?? '',
        'images': image.isNotEmpty ? [_normalizeSingleUrl(image)] : [],
        'authorName': widget.message['forwerdMessage']?.toString() ?? 'Shared',
        'authorProfile': '',
        'likesCount': 0,
        'commentsCount': 0,
      };
    }
    // Priority 1: real sharedPost object with valid MongoDB ObjectId
    final sharedPost = widget.message['sharedPost'];
    if (sharedPost is Map && sharedPost.isNotEmpty) {
      final id = sharedPost['_id']?.toString() ?? '';
      if (id.length == 24 && RegExp(r'^[a-f0-9]{24}$').hasMatch(id)) {
        final post = Map<String, dynamic>.from(sharedPost as Map);

        List<dynamic> images = [];
        for (final key in ['images', 'image', 'media', 'attachments',
          'postImages', 'photos', 'imageUrl']) {
          final v = post[key];
          if (v is List && v.isNotEmpty) {
            final filtered = v
                .where((e) => e != null && e.toString().isNotEmpty)
                .toList();
            if (filtered.isNotEmpty) { images = filtered; break; }
          }
          if (v is String && v.isNotEmpty) { images = [v]; break; }
        }

        // Fall back to outer message image if sharedPost has none
        if (images.isEmpty) {
          final img = widget.message['image']?.toString() ?? '';
          if (img.isNotEmpty && img != 'null') images = [img];
        }

        // Normalize URLs
        images = _normalizeImages(images);
        post['images'] = images;

        if (post['authorName'] == null || post['authorName'].toString().isEmpty) {
          post['authorName'] = widget.message['forwerdMessage']?.toString() ?? 'Shared Post';
        }
        return post;
      }
    }

    // Priority 2: forwerdUrl with valid post ID
    String postId = '';

    if (fUrl.isNotEmpty && fUrl != 'null') {
      final segment = fUrl.split('/').last.trim();
      if (segment.length == 24 &&
          RegExp(r'^[a-f0-9]{24}$').hasMatch(segment)) {
        postId = segment;
      }
    }

    // Priority 3: forwardedFrom (new backend format from logs)
    // Structure: {forwardedFrom:{messageId,senderId}, image:url, text:content}
    final forwardedFrom = widget.message['forwardedFrom'];
    if (postId.isEmpty && forwardedFrom is Map) {
      // Use messageId as the post identifier for navigation
      postId = forwardedFrom['messageId']?.toString() ?? '';
      // Validate it's a real ObjectId
      if (postId.length != 24 || !RegExp(r'^[a-f0-9]{24}$').hasMatch(postId)) {
        postId = '';
      }
    }

    // Collect image — the log shows image is directly on the message
    String imageUrl = '';
    for (final key in ['image', 'forwerdImage', 'postImage',
      'sharedImage', 'forwerdImageUrl']) {
      final val = widget.message[key]?.toString() ?? '';
      if (val.isNotEmpty && val != 'null') {
        imageUrl = _normalizeSingleUrl(val);
        break;
      }
    }

    if (postId.isEmpty && imageUrl.isEmpty) return null;

    // Build the post card data from message fields
    return {
      '_id': postId,
      'text': widget.message['text']?.toString() ?? '',
      'images': imageUrl.isNotEmpty ? [imageUrl] : [],
      'authorName': widget.message['forwerdMessage']?.toString() ?? 'Shared Post',
      'authorProfile': '',
      'likesCount': 0,
      'commentsCount': 0,
    };
  }

// ── URL helpers ──────────────────────────────────────────────────────────
  List<dynamic> _normalizeImages(List<dynamic> raw) {
    return raw.map((img) {
      final s = img.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return _normalizeSingleUrl(s);
    }).where((e) => e != null).toList();
  }

  String _normalizeSingleUrl(String s) {
    if (s.startsWith('http://') || s.startsWith('https://') ||
        s.startsWith('data:image/')) return s;
    return 'https://api.ixes.ai/$s';
  }

  // ════════════════════════════════════════════════════════════════════════
  //  LINK PREVIEW
  // ════════════════════════════════════════════════════════════════════════
  bool _hasValidLinkMeta() {
    final meta = widget.message['linkMeta'];
    if (meta == null || meta is! Map) return false;
    // Server sends linkMeta with all empty strings — reject that
    final url = meta['url']?.toString().trim() ?? '';
    final title = meta['title']?.toString().trim() ?? '';
    return url.isNotEmpty || title.isNotEmpty;
  }

  Widget _buildLinkPreview() {
    final meta = widget.message['linkMeta'] as Map<String, dynamic>?;
    if (meta == null || meta.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        final url = meta['url']?.toString();
        if (url != null && url.isNotEmpty) {
          final uri =
          Uri.parse(url.startsWith('http') ? url : 'https://$url');
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
          color:
          _isMe ? Colors.white.withOpacity(0.1) : Colors.grey[100],
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
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meta['title'] != null &&
                      meta['title'].toString().isNotEmpty)
                    Text(
                      meta['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isMe ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (meta['description'] != null &&
                      meta['description'].toString().isNotEmpty)
                    Text(
                      meta['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isMe ? Colors.white70 : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    meta['url'] ?? '',
                    style: TextStyle(
                      color: _isMe
                          ? Colors.lightBlueAccent
                          : Colors.blue[700],
                      decoration: TextDecoration.underline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MEMBER PROFILE SHEET
  // ════════════════════════════════════════════════════════════════════════
  void _showMemberProfile() {
    if (_isMe || _senderMap == null) return;

    final profile = _senderMap!['profile'];
    final String? imageUrl = profile?['profileImage']?.toString();
    final String name = _senderName;
    final String userId = _senderId;

    final Map<String, dynamic> userProfile = {
      '_id': userId,
      'profile': {
        'name': name,
        'profileImage': imageUrl ?? '',
      },
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null')
                    ? const LinearGradient(
                  colors: [Color(0xFF9B8FF5), Color(0xFF6C5CE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Colors.transparent,
                backgroundImage: (imageUrl != null &&
                    imageUrl.isNotEmpty &&
                    imageUrl != 'null')
                    ? _imageProvider(imageUrl)
                    : null,
                child: (imageUrl == null ||
                    imageUrl.isEmpty ||
                    imageUrl == 'null')
                    ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Group Member',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProfileAction(
                  icon: Icons.chat_rounded,
                  label: 'Message',
                  color: const Color(0xFF6C5CE7),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          userId: userId,
                          chatTitle: name,
                          userProfile: userProfile,
                        ),
                      ),
                    );
                  },
                ),
                _buildProfileAction(
                  icon: Icons.call_rounded,
                  label: 'Call',
                  color: const Color(0xFF00B894),
                  onTap: () async {
                    Navigator.pop(context);
                    final voiceCallProvider =
                    context.read<VoiceCallProvider>();
                    voiceCallProvider.clearMessages();
                    await voiceCallProvider.initiateVoiceCall(
                      receiverId: userId,
                      receiverName: name,
                      isConference: false,
                    );
                    if (!mounted) return;
                    if (voiceCallProvider.callState ==
                        VoiceCallState.calling) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VoiceCallingScreen()),
                      );
                    } else if (voiceCallProvider.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(voiceCallProvider.errorMessage!),
                        backgroundColor: Colors.red,
                      ));
                    }
                  },
                ),
                _buildProfileAction(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: const Color(0xFF0984E3),
                  onTap: () async {
                    Navigator.pop(context);
                    final videoCallProvider =
                    context.read<VideoCallProvider>();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(
                          child: CircularProgressIndicator()),
                    );
                    try {
                      final isBusy =
                      await videoCallProvider.checkUserBusy(userId);
                      if (mounted) Navigator.of(context).pop();
                      if (isBusy) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content:
                          Text('$name is currently in another call'),
                          backgroundColor: Colors.orange,
                        ));
                        return;
                      }
                      await videoCallProvider.initiateCall(
                        receiverId: userId,
                        receiverName: name,
                      );
                      if (videoCallProvider.errorMessage != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(videoCallProvider.errorMessage!),
                          backgroundColor: Colors.red,
                        ));
                        videoCallProvider.clearMessages();
                        return;
                      }
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CallingScreen()),
                        );
                      }
                    } catch (e) {
                      if (mounted) Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
              border:
              Border.all(color: color.withOpacity(0.20), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SHARED POST (from cache only — single render path)
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildSharedPostFromCache() {
    final postData = _cachedPostData!;
    final postId = postData['_id']?.toString() ?? '';
    final postContent = postData['text']?.toString() ?? '';
    final images = postData['images'];
    final postImages = images is List ? images : [];
    final authorName = postData['authorName']?.toString() ?? 'Unknown';
    final authorProfile = postData['authorProfile']?.toString() ?? '';
    final likesCount = postData['likesCount'] ?? 0;
    final commentsCount = postData['commentsCount'] ?? 0;

    return GestureDetector(
      onTap: () async {
        final shareType = postData['shareType']?.toString() ?? 'feed';
        final forwerdUrl = postData['forwerdUrl']?.toString() ?? '';

        // ── non-feed: open in browser ──────────────────────────
        if (shareType != 'feed') {
          if (forwerdUrl.isNotEmpty) {
            final uri = Uri.parse(forwerdUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link not available'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // ── feed: navigate to post screen ──────────────────────
        if (postId.isEmpty ||
            postId.length != 24 ||
            !RegExp(r'^[a-f0-9]{24}$').hasMatch(postId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post link not available'),
              backgroundColor: Colors.orange,
            ),
          );
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
      },
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          color: _isMe ? Colors.white.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _isMe
                  ? Colors.white.withOpacity(0.25)
                  : Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isMe
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10)),
              ),
              child: Builder(builder: (_) {
                final shareType = postData['shareType']?.toString() ?? 'feed';
                IconData shareIcon;
                String shareLabel;
                switch (shareType) {
                  case 'announcement':
                    shareIcon = Icons.campaign_rounded;
                    shareLabel = 'Shared Announcement';
                    break;
                  case 'campaign':
                    shareIcon = Icons.flag_rounded;
                    shareLabel = 'Shared Campaign';
                    break;
                  case 'service':
                    shareIcon = Icons.miscellaneous_services_rounded;
                    shareLabel = 'Shared Service';
                    break;
                  default:
                    final isForwardedFrom =
                        widget.message['forwardedFrom'] is Map &&
                            (widget.message['forwardedFrom'] as Map).isNotEmpty;
                    shareIcon =
                    isForwardedFrom ? Icons.reply_rounded : Icons.share;
                    shareLabel =
                    isForwardedFrom ? 'Forwarded Post' : 'Shared Post';
                }
                return Row(children: [
                  Icon(shareIcon,
                      size: 14,
                      color: _isMe ? Colors.white60 : Colors.grey[600]),
                  const SizedBox(width: 5),
                  Text(shareLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isMe ? Colors.white60 : Colors.grey[600])),
                ]);
              }),
            ),

            // ── Author ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _isMe
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey[300],
                  backgroundImage:
                  authorProfile.isNotEmpty && authorProfile != 'null'
                      ? (authorProfile.startsWith('data:image/')
                      ? MemoryImage(
                      base64Decode(authorProfile.split(',')[1]))
                      : NetworkImage(authorProfile) as ImageProvider)
                      : null,
                  child: authorProfile.isEmpty || authorProfile == 'null'
                      ? Text(
                      authorName.isNotEmpty
                          ? authorName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                          _isMe ? Colors.white : Colors.grey[700]))
                      : null,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(authorName,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isMe ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),

            // ── Post text ─────────────────────────────────────────
            if (postContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                child: Text(postContent,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _isMe ? Colors.white : Colors.black87),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ),

            // ── Post image ────────────────────────────────────────
            if (postImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildPostImage(postImages[0]),
                  ),
                ),
              ),

            // ── Stats / Footer ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(children: [
                // only show likes/comments for feed posts
                if (postData['shareType'] == null ||
                    postData['shareType'] == 'feed') ...[
                  Icon(Icons.favorite,
                      size: 13,
                      color: _isMe ? Colors.white60 : Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text('$likesCount',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                          _isMe ? Colors.white70 : Colors.grey[600])),
                  const SizedBox(width: 12),
                  Icon(Icons.comment,
                      size: 13,
                      color: _isMe ? Colors.white60 : Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text('$commentsCount',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                          _isMe ? Colors.white70 : Colors.grey[600])),
                ],
                const Spacer(),
                Text('Tap to view',
                    style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color:
                        _isMe ? Colors.white60 : Colors.blue[600])),
              ]),
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

    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildBrokenImage();
    }

    if (!imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://') &&
        !imageUrl.startsWith('data:image/')) {
      imageUrl = 'https://api.ixes.ai/$imageUrl';
    }

    if (imageUrl.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(imageUrl.split(',')[1]),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildBrokenImage(),
        );
      } catch (_) {
        return _buildBrokenImage();
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Colors.grey[200],
        child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => _buildBrokenImage(),
    );
  }

  Widget _buildBrokenImage() {
    return Container(
      color: _isMe ? Colors.white.withOpacity(0.1) : Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image,
                size: 36,
                color: _isMe ? Colors.white38 : Colors.grey[400]),
            const SizedBox(height: 8),
            Text('Image unavailable',
                style: TextStyle(
                    color: _isMe ? Colors.white60 : Colors.grey[500],
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildForwardedLabel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply_rounded,
              size: 13,
              color: _isMe ? Colors.white60 : Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            'Forwarded',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: _isMe ? Colors.white60 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MESSAGE OPTIONS
  // ════════════════════════════════════════════════════════════════════════
  void _showMessageOptions() {
    final List<Widget> options = [];

    options.add(ListTile(
      leading: Icon(Icons.reply, color: _purple),
      title: const Text('Reply'),
      onTap: () {
        Navigator.pop(context);
        if (widget.onReply != null) {
          widget.onReply!({
            '_id': widget.message['_id'],
            'text': widget.message['text'],
            'isFile': _isFile,
            'fileName': widget.message['fileName'],
            'isAudio': _isAudio,
            'senderName': _senderName,
            'senderId': _senderId,
          });
        }
      },
    ));

    options.add(ListTile(
      leading: Icon(Icons.reply_rounded, color: _purple),
      title: const Text('Forward'),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ForwardMessageScreen(message: widget.message),
          ),
        );
      },
    ));
    // Copy Link — only for shared post / forwarded URL messages
    if (_isSharedPost &&
        _cachedPostData != null &&
        (_cachedPostData!['forwerdUrl'] ?? '').toString().isNotEmpty) {
      options.add(ListTile(
        leading: Icon(Icons.link, color: _purple),
        title: const Text('Copy Link'),
        onTap: () {
          Navigator.pop(context);
          Clipboard.setData(
            ClipboardData(
              text: _cachedPostData!['forwerdUrl'].toString(),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        },
      ));
    }
    // Copy Link — for link preview messages
    final _linkMeta = widget.message['linkMeta'];
    final _linkUrl = (_linkMeta is Map) ? (_linkMeta['url'] ?? '').toString() : '';
    if (_linkUrl.isNotEmpty) {
      options.add(ListTile(
        leading: Icon(Icons.link, color: _purple),
        title: const Text('Copy Link'),
        onTap: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: _linkUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        },
      ));
    }

    final isOptimistic = widget.message['isOptimistic'] == true;
    final status = widget.message['status']?.toString();
    if (_isMe &&
        !_isFile &&
        !_isAudio &&
        (widget.message['text'] ?? '').toString().isNotEmpty &&
        !isOptimistic &&
        status != 'sending') {
      options.add(ListTile(
        leading: Icon(Icons.edit, color: _purple),
        title: const Text('Edit Message'),
        onTap: () {
          Navigator.pop(context);
          _showEditDialog();
        },
      ));
    }

    if (_isMe &&
        !isOptimistic &&
        status != 'sending' &&
        status != 'failed') {
      options.add(ListTile(
        leading: const Icon(Icons.delete, color: Colors.red),
        title: const Text('Delete Message',
            style: TextStyle(color: Colors.red)),
        onTap: () {
          Navigator.pop(context);
          _showDeleteConfirmation();
        },
      ));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(20)),
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

  void _showEditDialog() {
    final ctrl =
    TextEditingController(text: widget.message['text']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: ctrl,
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
              onPressed: () => _handleEdit(ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _handleEdit(String newText) async {
    if (newText.isEmpty || newText == widget.message['text']) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
      final ok = await context.read<GroupChatProvider>().editGroupMessage(
        messageId: widget.message['_id'],
        newText: newText,
        groupId: widget.groupId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Message edited successfully'
            : 'Failed to edit message'),
        backgroundColor: ok ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error editing message: $e'),
          backgroundColor: Colors.red));
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
            'Are you sure you want to delete this message? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _handleDelete,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
      final ok =
      await context.read<GroupChatProvider>().deleteGroupMessage(
        messageId: widget.message['_id'],
        groupId: widget.groupId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Message deleted successfully'
            : 'Failed to delete message'),
        backgroundColor: ok ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting message: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _handleFileOpen() async {
    var fileUrl = widget.message['fileUrl']?.toString() ?? '';
    final fileName = widget.message['fileName']?.toString() ?? 'file';
    if (fileUrl.isEmpty || fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File information is missing'),
          backgroundColor: Colors.red));
      return;
    }
    if (!fileUrl.startsWith('http://') &&
        !fileUrl.startsWith('https://')) {
      fileUrl = 'https://api.ixes.ai/$fileUrl';
    }
    final status = widget.message['status']?.toString();
    if (status == 'sending') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File is still uploading, please wait'),
          backgroundColor: Colors.orange));
      return;
    }
    if (status == 'failed') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File upload failed, cannot open'),
          backgroundColor: Colors.red));
      return;
    }
    await FileViewerHelper.openFile(
      context: context,
      fileUrl: fileUrl,
      fileName: fileName,
      localFilePath: widget.message['localFilePath']?.toString(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  AUDIO PLAYER
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _initPlayer() async {
    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      await _player!
          .setSubscriptionDuration(const Duration(milliseconds: 80));
      if (mounted) setState(() => _isPlayerInitialized = true);
    } catch (e) {
      debugPrint('💥 GroupBubble player init: $e');
    }
  }

  Future<void> _playPauseAudio() async {
    if (!_isPlayerInitialized || _player == null) return;
    try {
      if (_isPlaying) {
        await _player!.pausePlayer();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        final path = await _resolveAudioPath();
        if (path == null) return;

        await _playerSub?.cancel();
        _playerSub = null;

        await _player!.startPlayer(
          fromURI: path,
          whenFinished: () {
            if (mounted)
              setState(() {
                _isPlaying = false;
                _position = Duration.zero;
              });
          },
        );
        if (mounted) setState(() => _isPlaying = true);

        _playerSub = _player!.onProgress!.listen((e) {
          if (!mounted) return;
          setState(() {
            _position = e.position;
            if (e.duration > Duration.zero) _duration = e.duration;
          });
        });
      }
    } catch (e) {
      debugPrint('💥 GroupBubble playback: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<String?> _resolveAudioPath() async {
    final localPath = widget.message['localFilePath']?.toString();
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) return localPath;
    if (_localAudioPath != null && File(_localAudioPath!).existsSync())
      return _localAudioPath;

    var audioUrl = widget.message['audioUrl']?.toString() ?? '';
    if (audioUrl.isEmpty) return null;
    if (!audioUrl.startsWith('http://') &&
        !audioUrl.startsWith('https://')) {
      audioUrl = 'https://api.ixes.ai/$audioUrl';
    }

    if (mounted) setState(() => _isLoadingAudio = true);
    try {
      final tmpDir = await getTemporaryDirectory();
      final msgId = widget.message['_id']?.toString() ??
          'grp_${DateTime.now().millisecondsSinceEpoch}';
      final cachedPath = '${tmpDir.path}/grp_voice_$msgId.aac';
      if (File(cachedPath).existsSync()) {
        _localAudioPath = cachedPath;
        return _localAudioPath;
      }
      final res = await http.get(Uri.parse(audioUrl));
      if (res.statusCode == 200) {
        await File(cachedPath).writeAsBytes(res.bodyBytes);
        _localAudioPath = cachedPath;
        return _localAudioPath;
      }
    } catch (e) {
      debugPrint('💥 Audio download: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  REPLY PREVIEW
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildReplyPreview() {
    Map<String, dynamic>? replyMsg =
    widget.message['replyToMessage'] as Map<String, dynamic>?;

    if (replyMsg == null) {
      final replyId = widget.message['replyTo'];
      if (replyId == null || replyId is! String || replyId.isEmpty) {
        return const SizedBox.shrink();
      }
      final provider = context.read<GroupChatProvider>();
      final allMsgs = provider.getMessagesForGroup(widget.groupId);
      try {
        final found = allMsgs.firstWhere((m) => m['_id'] == replyId);
        replyMsg = Map<String, dynamic>.from(found);
      } catch (_) {
        replyMsg = {'_id': replyId, 'text': 'Original message'};
      }
    }

    if (replyMsg == null) return const SizedBox.shrink();

    String replySender = 'Someone';
    final rawSenderName = replyMsg['senderName'];
    if (rawSenderName != null && rawSenderName.toString().isNotEmpty) {
      replySender = rawSenderName.toString();
    } else {
      final nestedSender = replyMsg['senderId'];
      if (nestedSender is Map) {
        final name =
            nestedSender['profile']?['name']?.toString() ?? '';
        if (name.isNotEmpty) replySender = name;
      }
    }

    final replyText = replyMsg['text']?.toString() ?? '';
    String preview;
    if (replyText.isNotEmpty) {
      preview = replyText;
    } else if (replyMsg['isAudio'] == true) {
      preview = '🎤 Voice message';
    } else if (replyMsg['isFile'] == true) {
      preview = '📎 ${replyMsg['fileName'] ?? 'File'}';
    } else {
      preview = 'Message';
    }

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _isMe
            ? Colors.white.withOpacity(0.2)
            : Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
              color: _isMe ? Colors.white : Colors.grey[800]!,
              width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replied to $replySender',
            style: TextStyle(
              color: _isMe ? Colors.white70 : Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _isMe ? Colors.white70 : Colors.grey[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  VOICE BUBBLE
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildVoiceBubble() {
    double progress = 0;
    if (_duration.inMilliseconds > 0) {
      progress = (_position.inMilliseconds / _duration.inMilliseconds)
          .clamp(0.0, 1.0);
    }
    const waveHeights = [
      20.0, 15.0, 10.0, 18.0, 12.0, 16.0, 14.0, 20.0,
      11.0, 15.0, 17.0, 13.0, 19.0, 10.0, 16.0, 14.0, 18.0, 12.0,
      15.0, 20.0
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isMe
            ? Colors.white.withOpacity(0.12)
            : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _isLoadingAudio ? null : _playPauseAudio,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color:
                _isMe ? Colors.white : Colors.grey[800],
                shape: BoxShape.circle),
            child: _isLoadingAudio
                ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                        _isMe ? _purple : Colors.white)))
                : Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                size: 24,
                color: _isMe ? _purple : Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(20, (i) {
                      final isActive = progress >= (i / 20);
                      return Expanded(
                        child: Container(
                          margin:
                          const EdgeInsets.symmetric(horizontal: 1),
                          height: waveHeights[i],
                          decoration: BoxDecoration(
                            color: isActive
                                ? (_isMe ? Colors.white : _purple)
                                : (_isMe
                                ? Colors.white38
                                : Colors.grey[350]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 5),
                Text(_durationLabel(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _isMe
                            ? Colors.white70
                            : Colors.grey[600])),
              ]),
        ),
        if (widget.message['status'] == 'sending') ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                    _isMe ? Colors.white70 : Colors.grey[500]!)),
          ),
        ],
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  FILE BUBBLE
  // ════════════════════════════════════════════════════════════════════════
  bool get _isImageFile {
    final type = widget.message['fileType']?.toString();
    if (type != null && type.toLowerCase().contains('image')) return true;
    final fileName = widget.message['fileName']?.toString();
    if (fileName != null) {
      final ext = fileName.toLowerCase();
      return ext.endsWith('.png') ||
          ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.gif') ||
          ext.endsWith('.webp');
    }
    return false;
  }

  Widget _buildFileBubble() {
    final fileUrl = widget.message['fileUrl']?.toString() ?? '';
    final fileName = widget.message['fileName']?.toString() ?? '';

    if (fileUrl.isEmpty && fileName.isEmpty) return const SizedBox.shrink();
    if (_isImageFile) return _buildChatMessageImage();

    final status = widget.message['status']?.toString();
    final fileType =
    FileViewerHelper.getFileType(fileUrl.isNotEmpty ? fileUrl : fileName);
    return _buildGenericFileTile(fileType, fileName, status);
  }

  Widget _buildChatMessageImage() {
    String fileUrl = widget.message['fileUrl']?.toString() ?? '';
    final localPath = widget.message['localFilePath']?.toString();

    Widget imageWidget;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        imageWidget = Image.file(file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildBrokenImage());
      } else {
        imageWidget = _buildBrokenImage();
      }
    } else if (fileUrl.isNotEmpty) {
      if (!fileUrl.startsWith('http://') &&
          !fileUrl.startsWith('https://')) {
        fileUrl = 'https://api.ixes.ai/$fileUrl';
      }
      imageWidget = CachedNetworkImage(
        imageUrl: fileUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: _isMe
              ? Colors.white.withOpacity(0.1)
              : Colors.grey[200],
          child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _buildBrokenImage(),
      );
    } else {
      imageWidget = _buildBrokenImage();
    }

    return GestureDetector(
      onTap:
      widget.message['status'] == 'sending' ? null : _handleFileOpen,
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 300,
          maxWidth: 250,
          minWidth: 150,
          minHeight: 150,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight:
            _isMe ? const Radius.circular(4) : null,
            bottomLeft: !_isMe ? const Radius.circular(4) : null,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight:
            _isMe ? const Radius.circular(4) : null,
            bottomLeft: !_isMe ? const Radius.circular(4) : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              if (widget.message['status'] == 'sending')
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenericFileTile(
      String fileType, String fileName, String? status) {
    return GestureDetector(
      onTap: _handleFileOpen,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isMe
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_getFileIcon(fileType),
              color: _isMe ? Colors.white : Colors.black87, size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName,
                      style: TextStyle(
                          color: _isMe ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (status == 'sending')
                    Text('Uploading...',
                        style: TextStyle(
                            fontSize: 12,
                            color: _isMe
                                ? Colors.white70
                                : Colors.grey[600]))
                  else if (status == 'failed')
                    Text('Failed to upload',
                        style: TextStyle(
                            fontSize: 12,
                            color: _isMe
                                ? Colors.white70
                                : Colors.red[600]))
                  else
                    Text('Tap to open',
                        style: TextStyle(
                            fontSize: 12,
                            color: _isMe
                                ? Colors.white70
                                : Colors.grey[600])),
                ]),
          ),
          if (status != 'sending' && status != 'failed') ...[
            const SizedBox(width: 6),
            Icon(Icons.open_in_new,
                size: 16,
                color: _isMe ? Colors.white70 : Colors.grey[600]),
          ],
        ]),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  STATUS TICK
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildStatusTick() {
    final status = widget.message['status']?.toString();
    final isOptimistic = widget.message['isOptimistic'] == true;
    final readers =
    List<String>.from(widget.message['readers'] ?? []);

    if (status == 'sending' || isOptimistic) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(Colors.white60),
        ),
      );
    }
    if (status == 'failed') {
      return const Icon(Icons.error_outline,
          size: 13, color: Colors.redAccent);
    }

    final readByOthers = readers.length > 1;
    if (readByOthers) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.done_all,
            size: 13, color: Colors.lightBlueAccent),
        const SizedBox(width: 2),
        Text('${readers.length - 1}',
            style: const TextStyle(
                fontSize: 11, color: Colors.white60)),
      ]);
    }
    if (readers.isNotEmpty) {
      return const Icon(Icons.done_all,
          size: 13, color: Colors.white60);
    }
    return const Icon(Icons.done, size: 13, color: Colors.white60);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════
  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  String _durationLabel() {
    if (_isPlaying || _position.inSeconds > 0)
      return '${_formatDuration(_position)} / ${_formatDuration(_duration)}';
    if (_duration.inSeconds > 0) return _formatDuration(_duration);
    return '0:00';
  }

  String _formatTime(String timestamp) {
    try {
      final local = DateTime.parse(timestamp).toLocal();
      final hour = local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$displayHour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  static const _nameColors = [
    Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFF0984E3),
    Color(0xFFE17055), Color(0xFF74B9FF), Color(0xFFFD79A8),
    Color(0xFF55EFC4), Color(0xFFA29BFE), Color(0xFFFF7675),
    Color(0xFF00CEC9),
  ];

  Color _colorForName(String name) {
    final seed = name.codeUnits.fold(0, (a, b) => a + b);
    return _nameColors[seed % _nameColors.length];
  }

  ImageProvider? _imageProvider(String? src) {
    if (src == null || src.isEmpty || src == 'null') return null;
    try {
      if (src.startsWith('data:image') ||
          src.startsWith('/9j/') ||
          src.startsWith('iVBORw0KGgo')) {
        return MemoryImage(base64Decode(
            src.startsWith('data:image') ? src.split(',')[1] : src));
      }
      return NetworkImage(src);
    } catch (_) {
      return null;
    }
  }

  Widget _buildAvatar() {
    if (_senderMap == null) {
      return CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          child: Icon(Icons.person, size: 16, color: Colors.grey[600]));
    }
    final profile = _senderMap!['profile'];
    final imgProv =
    _imageProvider(profile?['profileImage']?.toString());
    return CircleAvatar(
      radius: 16,
      backgroundColor: _colorForName(_senderName),
      backgroundImage: imgProv,
      child: imgProv == null
          ? Text(
          _senderName.isNotEmpty ? _senderName[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold))
          : null,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    final text = widget.message['text']?.toString() ?? '';
    final timestamp = widget.message['createdAt']?.toString() ?? '';
    final hasReply = widget.message['replyToMessage'] != null ||
        (widget.message['replyTo'] != null &&
            widget.message['replyTo'] is String &&
            (widget.message['replyTo'] as String).isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment:
        _isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisAlignment:
          _isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Left avatar ──────────────────────────────────────────
            if (!_isMe) ...[
              SizedBox(
                width: 36,
                child: widget.showAvatar
                    ? GestureDetector(
                  onTap: _showMemberProfile,
                  child: _buildAvatar(),
                )
                    : GestureDetector(
                  onTap: _showMemberProfile,
                  child: const SizedBox(width: 36, height: 36),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // ── Bubble ───────────────────────────────────────────────
            Flexible(
              child: GestureDetector(
                onTap: !_isMe ? _showMemberProfile : null,
                onLongPress: _showMessageOptions,
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth:
                      MediaQuery.of(context).size.width * 0.72),
                  padding: EdgeInsets.symmetric(
                    horizontal:
                    (_isFile && _isImageFile) ? 0 : 13,
                    vertical:
                    (_isFile && _isImageFile) ? 0 : 9,
                  ),
                  decoration: BoxDecoration(
                    color: (_isFile && _isImageFile)
                        ? Colors.transparent
                        : (_isMe ? _purple : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                      Radius.circular(_isMe ? 18 : 4),
                      bottomRight:
                      Radius.circular(_isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 5,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Forwarded label (only for non-post forwards)
                      if (_isForwardedMsg) _buildForwardedLabel(),

                      // Sender name
                      if (!_isMe && widget.showAvatar) ...[
                        Text(_senderName,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _colorForName(_senderName))),
                        const SizedBox(height: 3),
                      ],

                      // Reply preview
                      if (hasReply) _buildReplyPreview(),

                      // ── Content: single decision tree, no fallbacks ──
                      if (_isSharedPost && _cachedPostData != null)
                        _buildSharedPostFromCache()
                      else if (_isAudio)
                        _buildVoiceBubble()
                      else if (_isFile)
                          _buildFileBubble()
                        else if (text.isNotEmpty) ...[
                            GroupClickableText(
                                text: text, isMe: _isMe),
                            if (_hasValidLinkMeta()) _buildLinkPreview(),
                          ],

                      const SizedBox(height: 4),

                      // Time + status
                      Padding(
                        padding: EdgeInsets.only(
                          bottom:
                          (_isFile && _isImageFile) ? 4.0 : 0,
                          right:
                          (_isFile && _isImageFile) ? 8.0 : 0,
                          left:
                          (_isFile && _isImageFile) ? 8.0 : 0,
                        ),
                        child: Container(
                          padding: (_isFile && _isImageFile)
                              ? const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2)
                              : EdgeInsets.zero,
                          decoration: (_isFile && _isImageFile)
                              ? BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius:
                            BorderRadius.circular(10),
                          )
                              : null,
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(timestamp),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: (_isFile && _isImageFile)
                                          ? Colors.white
                                          : (_isMe
                                          ? Colors.white60
                                          : Colors.grey[500])),
                                ),
                                if (_isMe) ...[
                                  const SizedBox(width: 5),
                                  _buildStatusTick(),
                                ],
                                if (widget.message['isEdited'] ==
                                    true) ...[
                                  const SizedBox(width: 5),
                                  Text('edited',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: (_isFile &&
                                              _isImageFile)
                                              ? Colors.white70
                                              : (_isMe
                                              ? Colors.white54
                                              : Colors.grey[400]))),
                                ],
                              ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  CLICKABLE TEXT
// ════════════════════════════════════════════════════════════════════════
class GroupClickableText extends StatelessWidget {
  final String text;
  final bool isMe;
  const GroupClickableText(
      {Key? key, required this.text, required this.isMe})
      : super(key: key);

  @override
  Widget build(BuildContext context) =>
      RichText(text: _buildSpans());

  TextSpan _buildSpans() {
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)'
      r'|https?:\/\/localhost(:[0-9]{1,5})?(\/[-a-zA-Z0-9()@:%_\+.~#?&//=]*)?'
      r'|www\.[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    final spans = <TextSpan>[];
    final matches = urlPattern.allMatches(text);
    int pos = 0;
    for (final m in matches) {
      if (m.start > pos) {
        spans.add(TextSpan(
          text: text.substring(pos, m.start),
          style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 15),
        ));
      }
      final url = m.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: isMe ? Colors.lightBlueAccent : Colors.blue[800],
          fontSize: 15,
          decoration: TextDecoration.underline,
          decorationColor:
          isMe ? Colors.lightBlueAccent : Colors.blue[800],
          decorationThickness: 2,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchURL(url),
      ));
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(
        text: text.substring(pos),
        style: TextStyle(
            color: isMe ? Colors.white : Colors.black87, fontSize: 15),
      ));
    }
    return TextSpan(children: spans);
  }

  Future<void> _launchURL(String urlString) async {
    if (!urlString.startsWith('http://') &&
        !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri))
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}