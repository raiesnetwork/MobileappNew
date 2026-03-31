import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/group_provider.dart';
import '../../home/feedpage/feed_screen.dart';
import '../view_file_screen.dart';

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

class _GroupMessageBubbleState extends State<GroupMessageBubble> {
  static const Color _purple = Color(0xFF6C5CE7);

  late final bool _isMe;
  late final String _senderId;
  // after _isFile declaration
  late final bool _isSharedPost;
  late final String _senderName;
  late final Map<String, dynamic>? _senderMap;
  late final bool _isAudio;
  late final bool _isFile;

  FlutterSoundPlayer? _player;
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localAudioPath;
  StreamSubscription? _playerSub;

  @override
  void initState() {
    super.initState();
    _parseMessage();
    if (_isAudio) {
      _initPlayer();
      final ms = widget.message['audioDurationMs'];
      if (ms is int && ms > 0) _duration = Duration(milliseconds: ms);
    }
  }
  Widget _buildSharedPost() {
    // Try nested sharedPost first (future-proof)
    Map<String, dynamic>? postData =
    widget.message['sharedPost'] as Map<String, dynamic>?;
    if (postData == null &&
        (widget.message['forwerd'] == true ||
            widget.message['forwerdMessage'] != null)) {
      final image = widget.message['image']?.toString() ?? '';
      final text = widget.message['text']?.toString() ?? '';
      final forwardLabel =
          widget.message['forwerdMessage']?.toString() ?? 'Shared Post';

      // ✅ Extract actual postId from forwerdUrl
      // forwerdUrl format: "https://ixes.ai/feeds/6954b0fcfb282e4eb94cee1a"
      String actualPostId = '';
      final forwerdUrl = widget.message['forwerdUrl']?.toString() ?? '';
      if (forwerdUrl.isNotEmpty) {
        actualPostId = forwerdUrl.split('/').last;
      }
      // Fallback to sharedPostId if forwerdUrl not available
      if (actualPostId.isEmpty) {
        actualPostId = widget.message['sharedPostId']?.toString() ?? '';
      }

      print('✅ Group bubble resolved postId: $actualPostId from forwerdUrl: $forwerdUrl');

      postData = {
        '_id': actualPostId,
        'text': text,
        'images': (image.isNotEmpty &&
            (image.startsWith('http://') ||
                image.startsWith('https://') ||
                image.startsWith('data:image')))
            ? [image]
            : [],   // ← don't add plain text as image
        'authorName': forwardLabel,
        'authorProfile': '',
        'likesCount': 0,
        'commentsCount': 0,
      };
    }


    if (postData == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.share, size: 18,
              color: _isMe ? Colors.white70 : Colors.grey[600]),

          const SizedBox(width: 6),
          Text('Shared a post',
              style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: _isMe ? Colors.white70 : Colors.grey[600])
          ),

        ],

      );

    }
    List<dynamic> _resolvePostImages(Map<String, dynamic> postData) {
      for (final key in ['images', 'image', 'media', 'attachments', 'photos']) {
        final v = postData[key];
        if (v is List && v.isNotEmpty) return v;
        if (v is String && v.isNotEmpty) return [v];
      }
      return [];
    }
    print('🖼️ sharedPost data: ${jsonEncode(postData)}');
    print('🖼️ images field: ${postData['images']}');

    final postContent = postData['text']?.toString() ?? '';
    final postImages = _resolvePostImages(postData);
    final authorName = postData['authorName']?.toString() ?? 'Unknown';
    final authorProfile = postData['authorProfile']?.toString();
    final likesCount = postData['likesCount'] ?? 0;
    final commentsCount = postData['commentsCount'] ?? 0;

    final postId = postData?['_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (postId.isEmpty) return;
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
                title: const Text(
                  'Post',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        color: _isMe
            ? Colors.white.withOpacity(0.15)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _isMe
                ? Colors.white.withOpacity(0.25)
                : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
            child: Row(children: [
              Icon(Icons.share,
                  size: 14,
                  color: _isMe ? Colors.white60 : Colors.grey[600]),
              const SizedBox(width: 5),
              Text('Shared Post',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isMe ? Colors.white60 : Colors.grey[600])),
            ]),
          ),

          // Author
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _isMe
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

          // Post text
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

          // Post image
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


          // Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(children: [
              Icon(Icons.favorite,
                  size: 13,
                  color: _isMe ? Colors.white60 : Colors.grey[500]),
              const SizedBox(width: 3),
              Text('$likesCount',
                  style: TextStyle(
                      fontSize: 11,
                      color: _isMe ? Colors.white70 : Colors.grey[600])),
              const SizedBox(width: 12),
              Icon(Icons.comment,
                  size: 13,
                  color: _isMe ? Colors.white60 : Colors.grey[500]),
              const SizedBox(width: 3),
              Text('$commentsCount',
                  style: TextStyle(
                      fontSize: 11,
                      color: _isMe ? Colors.white70 : Colors.grey[600])),
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
        ),  // closes Container
    );   // closes GestureDetector
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
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.broken_image, size: 36, color: Colors.grey[400]),
      );
    }

    if (imageUrl.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(imageUrl.split(',')[1]),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[200],
            child: Icon(Icons.broken_image, size: 36, color: Colors.grey[400]),
          ),
        );
      } catch (_) {
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.broken_image, size: 36, color: Colors.grey[400]),
        );
      }
    }
    if (!imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://') &&
        !imageUrl.startsWith('data:image/')) {
      // Not a valid image URL or base64 — show broken image placeholder
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.broken_image, size: 36, color: Colors.grey[400]),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[200],
        child: Icon(Icons.broken_image, size: 36, color: Colors.grey[400]),
      ),
    );
  }

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
        (widget.message['fileUrl'] != null && !_isAudio);
    _isSharedPost = widget.message['forwerd'] == true ||
        widget.message['forwerdMessage'] != null ||
        widget.message['isSharedPost'] == true ||
        widget.message['sharedPost'] != null;
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
  //  AUDIO PLAYER
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _initPlayer() async {
    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      await _player!.setSubscriptionDuration(const Duration(milliseconds: 80));
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
            if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
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
        setState(() { _isPlaying = false; _position = Duration.zero; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _resolveAudioPath() async {
    final localPath = widget.message['localFilePath']?.toString();
    if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) return localPath;
    if (_localAudioPath != null && File(_localAudioPath!).existsSync()) return _localAudioPath;

    var audioUrl = widget.message['audioUrl']?.toString() ?? '';
    if (audioUrl.isEmpty) return null;
    if (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://')) {
      audioUrl = 'https://api.ixes.ai/$audioUrl';
    }

    if (mounted) setState(() => _isLoadingAudio = true);
    try {
      final tmpDir = await getTemporaryDirectory();
      final msgId = widget.message['_id']?.toString() ?? 'grp_${DateTime.now().millisecondsSinceEpoch}';
      final cachedPath = '${tmpDir.path}/grp_voice_$msgId.aac';
      if (File(cachedPath).existsSync()) { _localAudioPath = cachedPath; return _localAudioPath; }
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
  //  MESSAGE OPTIONS (Reply / Edit / Delete)
  // ════════════════════════════════════════════════════════════════════════
  void _showMessageOptions() {
    final List<Widget> options = [];

    // ── Reply — always available ─────────────────────────────────────────
    options.add(ListTile(
      leading: Icon(Icons.reply, color: _purple),
      title: const Text('Reply'),
      onTap: () {
        Navigator.pop(context);
        if (widget.onReply != null) {
          // FIX: pass senderName explicitly so the reply preview can show it
          widget.onReply!({
            '_id': widget.message['_id'],
            'text': widget.message['text'],
            'isFile': _isFile,
            'fileName': widget.message['fileName'],
            'isAudio': _isAudio,
            // FIX: always include senderName from the parsed field
            'senderName': _senderName,
            // FIX: include senderId so reply preview knows who was replied to
            'senderId': _senderId,
          });
        }
      },
    ));

    // ── Edit — only my non-optimistic text messages ──────────────────────
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
        onTap: () { Navigator.pop(context); _showEditDialog(); },
      ));
    }

    // ── Delete — all my non-optimistic, non-sending/failed messages ──────
    if (_isMe && !isOptimistic && status != 'sending' && status != 'failed') {
      options.add(ListTile(
        leading: const Icon(Icons.delete, color: Colors.red),
        title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
        onTap: () { Navigator.pop(context); _showDeleteConfirmation(); },
      ));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          ...options,
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: widget.message['text']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter new message...', border: OutlineInputBorder()),
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => _handleEdit(ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _handleEdit(String newText) async {
    if (newText.isEmpty || newText == widget.message['text']) { Navigator.pop(context); return; }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 16), Text('Editing message...'),
      ]),
      duration: Duration(seconds: 2),
    ));
    try {
      final ok = await context.read<GroupChatProvider>().editGroupMessage(
        messageId: widget.message['_id'], newText: newText, groupId: widget.groupId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Message edited successfully' : 'Failed to edit message'),
        backgroundColor: ok ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing message: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _handleDelete,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 16), Text('Deleting message...'),
      ]),
      duration: Duration(seconds: 2),
    ));
    try {
      final ok = await context.read<GroupChatProvider>().deleteGroupMessage(
        messageId: widget.message['_id'], groupId: widget.groupId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Message deleted successfully' : 'Failed to delete message'),
        backgroundColor: ok ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleFileOpen() async {
    var fileUrl = widget.message['fileUrl']?.toString() ?? '';
    final fileName = widget.message['fileName']?.toString() ?? 'file';
    if (fileUrl.isEmpty || fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File information is missing'), backgroundColor: Colors.red));
      return;
    }
    if (!fileUrl.startsWith('http://') && !fileUrl.startsWith('https://')) {
      fileUrl = 'https://api.ixes.ai/$fileUrl';
    }
    final status = widget.message['status']?.toString();
    if (status == 'sending') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is still uploading, please wait'), backgroundColor: Colors.orange));
      return;
    }
    if (status == 'failed') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File upload failed, cannot open'), backgroundColor: Colors.red));
      return;
    }
    await FileViewerHelper.openFile(
      context: context, fileUrl: fileUrl, fileName: fileName,
      localFilePath: widget.message['localFilePath']?.toString(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════
  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  String _durationLabel() {
    if (_isPlaying || _position.inSeconds > 0) return '${_formatDuration(_position)} / ${_formatDuration(_duration)}';
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
    } catch (_) { return ''; }
  }

  static const _nameColors = [
    Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFF0984E3),
    Color(0xFFE17055), Color(0xFF74B9FF), Color(0xFFFD79A8),
    Color(0xFF55EFC4), Color(0xFFA29BFE), Color(0xFFFF7675), Color(0xFF00CEC9),];

  Color _colorForName(String name) {
    final seed = name.codeUnits.fold(0, (a, b) => a + b);
    return _nameColors[seed % _nameColors.length];
  }

  ImageProvider? _imageProvider(String? src) {
    if (src == null || src.isEmpty || src == 'null') return null;
    try {
      if (src.startsWith('data:image') || src.startsWith('/9j/') || src.startsWith('iVBORw0KGgo')) {
        return MemoryImage(base64Decode(src.startsWith('data:image') ? src.split(',')[1] : src));
      }
      return NetworkImage(src);
    } catch (_) { return null; }
  }

  Widget _buildAvatar() {
    if (_senderMap == null) {
      return CircleAvatar(radius: 16, backgroundColor: Colors.grey[300],
          child: Icon(Icons.person, size: 16, color: Colors.grey[600]));
    }
    final profile = _senderMap!['profile'];
    final imgProv = _imageProvider(profile?['profileImage']?.toString());
    return CircleAvatar(
      radius: 16,
      backgroundColor: _colorForName(_senderName),
      backgroundImage: imgProv,
      child: imgProv == null
          ? Text(_senderName.isNotEmpty ? _senderName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
          : null,
    );
  }

  // ── Reply preview (inside bubble) ────────────────────────────────────────
  // FIX: Completely rewritten to match MessageBubble's working implementation.
  // Key changes:
  //   1. Reads senderName from BOTH 'senderName' key AND nested senderId map
  //   2. Falls back gracefully to "Someone" if neither is available
  //   3. Label format matches personal chat ("Replied to X")
  Widget _buildReplyPreview() {
// Try replyToMessage first (optimistic/preserved)
    Map<String, dynamic>? replyMsg =
    widget.message['replyToMessage'] as Map<String, dynamic>?;

    // If not available, try to find the original message by ID from provider
    if (replyMsg == null) {
      final replyId = widget.message['replyTo'];
      if (replyId == null || replyId is! String || replyId.isEmpty) {
        return const SizedBox.shrink();
      }
      // Look up the message from current group messages
      final provider = context.read<GroupChatProvider>();
      final allMsgs = provider.getMessagesForGroup(widget.groupId);
      try {
        final found = allMsgs.firstWhere((m) => m['_id'] == replyId);
        replyMsg = Map<String, dynamic>.from(found);
      } catch (_) {
        // Message not found in local cache — show minimal preview
        replyMsg = {'_id': replyId, 'text': 'Original message'};
      }
    }

    if (replyMsg == null) return const SizedBox.shrink();

    // FIX: Try multiple paths to get the sender name — the reply map may be
    // structured differently depending on how it was saved.
    String replySender = 'Someone';
    final rawSenderName = replyMsg['senderName'];
    if (rawSenderName != null && rawSenderName.toString().isNotEmpty) {
      replySender = rawSenderName.toString();
    } else {
      // Fallback: try nested senderId map (same structure as message itself)
      final nestedSender = replyMsg['senderId'];
      if (nestedSender is Map) {
        final name = nestedSender['profile']?['name']?.toString() ?? '';
        if (name.isNotEmpty) replySender = name;
      }
    }

    // FIX: Build preview text the same way MessageBubble does
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
        color: _isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: _isMe ? Colors.white : Colors.grey[800]!, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIX: label now consistently shows "Replied to <name>"
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

  // ── Voice bubble ─────────────────────────────────────────────────────────
  Widget _buildVoiceBubble() {
    double progress = 0;
    if (_duration.inMilliseconds > 0) {
      progress = (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    }
    const waveHeights = [
      20.0, 15.0, 10.0, 18.0, 12.0, 16.0, 14.0, 20.0,
      11.0, 15.0, 17.0, 13.0, 19.0, 10.0, 16.0, 14.0, 18.0, 12.0, 15.0, 20.0
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isMe ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _isLoadingAudio ? null : _playPauseAudio,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: _isMe ? Colors.white : Colors.grey[800], shape: BoxShape.circle),
            child: _isLoadingAudio
                ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_isMe ? _purple : Colors.white)))
                : Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                size: 24, color: _isMe ? _purple : Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(20, (i) {
                  final isActive = progress >= (i / 20);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: waveHeights[i],
                      decoration: BoxDecoration(
                        color: isActive
                            ? (_isMe ? Colors.white : _purple)
                            : (_isMe ? Colors.white38 : Colors.grey[350]),
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
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: _isMe ? Colors.white70 : Colors.grey[600])),
          ]),
        ),
        if (widget.message['status'] == 'sending') ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(_isMe ? Colors.white70 : Colors.grey[500]!)),
          ),
        ],
      ]),
    );
  }

  Widget _buildFileBubble() {
    var fileUrl = widget.message['fileUrl']?.toString() ?? '';
    final fileName = widget.message['fileName']?.toString() ?? 'file';
    final status = widget.message['status']?.toString();
    if (fileUrl.isNotEmpty && !fileUrl.startsWith('http://') && !fileUrl.startsWith('https://')) {
      fileUrl = 'https://api.ixes.ai/$fileUrl';
    }
    final fileType = FileViewerHelper.getFileType(fileUrl.isNotEmpty ? fileUrl : fileName);
    if (fileType == 'image' && fileUrl.isNotEmpty && status != 'sending') {
      return GestureDetector(
        onTap: _handleFileOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(fileUrl, width: 200, height: 180, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildGenericFileTile(fileType, fileName, status),
          ),
        ),
      );
    }
    return _buildGenericFileTile(fileType, fileName, status);
  }

  Widget _buildGenericFileTile(String fileType, String fileName, String? status) {
    return GestureDetector(
      onTap: _handleFileOpen,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isMe ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_getFileIcon(fileType), color: _isMe ? Colors.white : Colors.black87, size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fileName,
                  style: TextStyle(color: _isMe ? Colors.white : Colors.black87,
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (status == 'sending')
                Text('Uploading...', style: TextStyle(fontSize: 12, color: _isMe ? Colors.white70 : Colors.grey[600]))
              else if (status == 'failed')
                Text('Failed to upload', style: TextStyle(fontSize: 12, color: _isMe ? Colors.white70 : Colors.red[600]))
              else
                Text('Tap to open', style: TextStyle(fontSize: 12, color: _isMe ? Colors.white70 : Colors.grey[600])),
            ]),
          ),
          if (status != 'sending' && status != 'failed') ...[
            const SizedBox(width: 6),
            Icon(Icons.open_in_new, size: 16, color: _isMe ? Colors.white70 : Colors.grey[600]),
          ],
        ]),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'image': return Icons.image;
      case 'video': return Icons.videocam;
      case 'audio': return Icons.audiotrack;
      case 'pdf':   return Icons.picture_as_pdf;
      default:      return Icons.insert_drive_file;
    }
  }
  Widget _buildStatusTick() {
    final status = widget.message['status']?.toString();
    final isOptimistic = widget.message['isOptimistic'] == true;
    final readers = List<String>.from(widget.message['readers'] ?? []);

    if (status == 'sending' || isOptimistic) {
      return SizedBox(
        width: 12, height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(Colors.white60),
        ),
      );
    }

    if (status == 'failed') {
      return const Icon(Icons.error_outline, size: 13, color: Colors.redAccent);
    }

    final readByOthers = readers.length > 1;
    if (readByOthers) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.done_all, size: 13, color: Colors.lightBlueAccent),
        const SizedBox(width: 2),
        Text('${readers.length - 1}',
            style: const TextStyle(fontSize: 11, color: Colors.white60)),
      ]);
    }

    if (readers.isNotEmpty) {
      return const Icon(Icons.done_all, size: 13, color: Colors.white60);
    }

    return const Icon(Icons.done, size: 13, color: Colors.white60);
  }
  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final text = widget.message['text']?.toString() ?? '';
    final timestamp = widget.message['createdAt']?.toString() ?? '';
    final readers = List<String>.from(widget.message['readers'] ?? []);
    final hasReply = widget.message['replyToMessage'] != null ||
        (widget.message['replyTo'] != null &&
            widget.message['replyTo'] is String &&
            (widget.message['replyTo'] as String).isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: _isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: _showMessageOptions,
          child: Row(
            mainAxisAlignment: _isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Left avatar ─────────────────────────────────────────────
              if (!_isMe) ...[
                SizedBox(width: 36,
                    child: widget.showAvatar ? _buildAvatar() : const SizedBox()),
                const SizedBox(width: 6),
              ],

              // ── Bubble ──────────────────────────────────────────────────
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
                  decoration: BoxDecoration(
                    color: _isMe ? _purple : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(_isMe ? 18 : 4),
                      bottomRight: Radius.circular(_isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 5, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sender name — only on first bubble in consecutive group
                      if (!_isMe && widget.showAvatar) ...[
                        Text(_senderName,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: _colorForName(_senderName))),
                        const SizedBox(height: 3),
                      ],

                      // Reply preview
                      if (hasReply) _buildReplyPreview(),

                      // Content
                      if (_isSharedPost)
                        _buildSharedPost()
                      else if (_isAudio)
                        _buildVoiceBubble()
                      else if (_isFile)
                          _buildFileBubble()
                        else if (text.isNotEmpty)
                            GroupClickableText(text: text, isMe: _isMe),

                      const SizedBox(height: 4),


                      // Time + read ticks
                      // NEW
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_formatTime(timestamp),
                            style: TextStyle(fontSize: 11,
                                color: _isMe ? Colors.white60 : Colors.grey[500])),
                        if (_isMe) ...[
                          const SizedBox(width: 5),
                          _buildStatusTick(),
                        ],
                        if (widget.message['isEdited'] == true) ...[
                          const SizedBox(width: 5),
                          Text('edited',
                              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic,
                                  color: _isMe ? Colors.white54 : Colors.grey[400])),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),

              if (_isMe) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}




// ═══════════════════════════════════════════════════════════════════════════
// GroupClickableText
// ═══════════════════════════════════════════════════════════════════════════
class GroupClickableText extends StatelessWidget {
  final String text;
  final bool isMe;
  const GroupClickableText({Key? key, required this.text, required this.isMe}) : super(key: key);

  @override
  Widget build(BuildContext context) => RichText(text: _buildSpans());

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
          style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
        ));
      }
      final url = m.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: isMe ? Colors.lightBlueAccent : Colors.blue[800],
          fontSize: 15,
          decoration: TextDecoration.underline,
          decorationColor: isMe ? Colors.lightBlueAccent : Colors.blue[800],
          decorationThickness: 2,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchURL(url),
      ));
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(
        text: text.substring(pos),
        style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
      ));
    }
    return TextSpan(children: spans);
  }

  Future<void> _launchURL(String urlString) async {
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}