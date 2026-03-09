import 'package:flutter/material.dart';
import 'package:ixes.app/screens/chats_page/group_chat/send_file_message.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../providers/group_provider.dart';

class GroupChatDetailPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isAdmin;

  const GroupChatDetailPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  State<GroupChatDetailPage> createState() => _GroupChatDetailPageState();
}

class _GroupChatDetailPageState extends State<GroupChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  bool _isSending = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeChat());
  }

  Future<void> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id');
      setState(() {});
    } catch (e) {
      print('Error getting current user ID: $e');
    }
  }

  void _initializeChat() {
    final provider = Provider.of<GroupChatProvider>(context, listen: false);
    provider.setCurrentGroup(widget.groupId);
    provider.fetchGroupMessages(widget.groupId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      final provider = context.read<GroupChatProvider>();
      final g = provider.getGroupById(widget.groupId);
      final communityInfo = g != null
          ? {
              "_id": g['_id'] ?? widget.groupId,
              "name": g['name'] ?? widget.groupName
            }
          : {"_id": widget.groupId, "name": widget.groupName};
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupFileMessageScreen(
                groupId: widget.groupId,
                groupName: widget.groupName,
                communityInfo: communityInfo),
          ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _startRecording() async => setState(() => _isRecording = true);
  Future<void> _stopRecording() async => setState(() => _isRecording = false);

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  bool _sameDay(String a, String b) {
    try {
      final da = DateTime.parse(a);
      final db = DateTime.parse(b);
      return da.year == db.year && da.month == db.month && da.day == db.day;
    } catch (_) {
      return true;
    }
  }

  // ── Consistent color per sender name (WhatsApp style) ──────────────────
  static const _nameColors = [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFF0984E3),
    Color(0xFFE17055),
    Color(0xFF74B9FF),
    Color(0xFFFD79A8),
    Color(0xFF55EFC4),
    Color(0xFFA29BFE),
    Color(0xFFFF7675),
    Color(0xFF00CEC9),
  ];

  Color _colorForName(String name) {
    final seed = name.codeUnits.fold(0, (a, b) => a + b);
    return _nameColors[seed % _nameColors.length];
  }

  // ── Image provider (base64 or URL) ─────────────────────────────────────
  ImageProvider? _imageProvider(String? src) {
    if (src == null || src.isEmpty || src == 'null') return null;
    try {
      if (src.startsWith('data:image') ||
          src.startsWith('/9j/') ||
          src.startsWith('iVBORw0KGgo')) {
        final b64 = src.startsWith('data:image') ? src.split(',')[1] : src;
        return MemoryImage(base64Decode(b64));
      }
      return NetworkImage(src);
    } catch (_) {
      return null;
    }
  }

  // ── AppBar group avatar ─────────────────────────────────────────────────
  Widget _buildGroupAvatarSmall(Map<String, dynamic>? group) {
    final name = group?['name'] ?? widget.groupName;
    final img = group?['profileImage']?.toString();
    final hasImg = img != null && img.isNotEmpty && img != 'null';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'G';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: !hasImg
            ? const LinearGradient(
                colors: [Color(0xFF9B8FF5), Color(0xFF6C5CE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.transparent,
        backgroundImage: hasImg ? _imageProvider(img) : null,
        child: !hasImg
            ? Text(letter,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16))
            : null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SENDER AVATAR  — shown on left of messages from other users
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSenderAvatar(Map<String, dynamic> senderMap) {
    final profile = senderMap['profile'];
    final name = profile?['name']?.toString() ?? '?';
    final imgSrc = profile?['profileImage']?.toString();
    final hasImg = imgSrc != null && imgSrc.isNotEmpty && imgSrc != 'null';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _colorForName(name);
    final imgProv = hasImg ? _imageProvider(imgSrc) : null;

    return CircleAvatar(
      radius: 16,
      backgroundColor: color,
      backgroundImage: imgProv,
      child: imgProv == null
          ? Text(letter,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12))
          : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MESSAGE BUBBLE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMessageBubble(
    Map<String, dynamic> message, {
    bool showAvatar = true, // false when consecutive messages from same sender
  }) {
    final rawSender = message['senderId'];
    Map<String, dynamic>? senderMap;
    String senderName = 'Unknown';
    String senderId = '';

    if (rawSender is Map<String, dynamic>) {
      senderMap = rawSender;
      senderName = rawSender['profile']?['name'] ?? 'Unknown';
      senderId = rawSender['_id'] ?? '';
    } else if (rawSender is String) {
      senderId = rawSender;
    }

    final isMe = _currentUserId != null && _currentUserId == senderId;
    final text = message['text'] ?? '';
    final timestamp = message['createdAt'] ?? '';
    final readers = List<String>.from(message['readers'] ?? []);
    final fileUrl = message['fileUrl']?.toString();
    final fileType = message['fileType']?.toString();
    final fileName = message['fileName']?.toString();
    final audioUrl = message['audioUrl']?.toString();
    final isAudio = message['isAudio'] == true;

    final nameColor = _colorForName(senderName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Left: avatar placeholder or real avatar ────────────────
          if (!isMe) ...[
            SizedBox(
              width: 36,
              child: showAvatar
                  ? (senderMap != null
                      ? _buildSenderAvatar(senderMap)
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          child: Icon(Icons.person,
                              size: 16, color: Colors.grey[600]),
                        ))
                  : const SizedBox(), // keeps alignment consistent
            ),
            const SizedBox(width: 6),
          ],

          // ── Bubble ────────────────────────────────────────────────
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF6C5CE7) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
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
                  // Sender name — only on first bubble in a group
                  if (!isMe && showAvatar) ...[
                    Text(
                      senderName,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: nameColor),
                    ),
                    const SizedBox(height: 3),
                  ],

                  // Audio
                  if (isAudio && audioUrl != null) ...[
                    _buildAudioBubble(isMe),
                    const SizedBox(height: 4),
                  ],

                  // File / Image
                  if (fileUrl != null && fileType != null && !isAudio) ...[
                    _buildFileBubble(fileUrl, fileType, fileName, isMe),
                    const SizedBox(height: 4),
                  ],

                  // Text
                  if (text.isNotEmpty) ...[
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: isMe ? Colors.white : Colors.grey[850],
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],

                  // Time + read ticks
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white60 : Colors.grey[500],
                        ),
                      ),
                      if (isMe && readers.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.done_all,
                            size: 13, color: Colors.white60),
                        const SizedBox(width: 2),
                        Text('${readers.length}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white60)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Audio bubble ─────────────────────────────────────────────────────────
  Widget _buildAudioBubble(bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withOpacity(0.25)
                : const Color(0xFF6C5CE7).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_arrow_rounded,
              size: 22, color: isMe ? Colors.white : const Color(0xFF6C5CE7)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 3,
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.5) : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Text('Voice message',
                style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white70 : Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  // ── File / Image bubble ───────────────────────────────────────────────────
  Widget _buildFileBubble(String url, String type, String? name, bool isMe) {
    final ext = name != null ? name.split('.').last.toLowerCase() : '';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);

    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(url,
            width: 200,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _genericFile(ext, name, isMe)),
      );
    }
    return _genericFile(ext, name, isMe);
  }

  Widget _genericFile(String ext, String? name, bool isMe) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Opening ${name ?? 'file'}'))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_fileIcon(ext),
                size: 26,
                color: isMe ? Colors.white70 : const Color(0xFF6C5CE7)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name ?? 'File',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : Colors.grey[800]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(ext.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white60 : Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_fields;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  // ── Date divider ─────────────────────────────────────────────────────────
  Widget _buildDateDivider(String timestamp) {
    String label = '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(dt.year, dt.month, dt.day))
          .inDays;
      if (diff == 0)
        label = 'Today';
      else if (diff == 1)
        label = 'Yesterday';
      else
        label = '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12)),
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  // ── Get sender id string from message ─────────────────────────────────────
  String _senderId(Map<String, dynamic> msg) {
    final s = msg['senderId'];
    if (s is Map<String, dynamic>) return s['_id'] ?? '';
    if (s is String) return s;
    return '';
  }

  // ── Messages list ─────────────────────────────────────────────────────────
  Widget _buildMessagesList() {
    return Consumer<GroupChatProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingMessages) {
          return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 20),
              Text('Loading messages...',
                  style: TextStyle(color: Colors.grey[600])),
            ]),
          );
        }

        if (provider.messagesError != null) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06), blurRadius: 10)
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.red[50], shape: BoxShape.circle),
                    child: Icon(Icons.error_outline,
                        size: 48, color: Colors.red[400])),
                const SizedBox(height: 16),
                Text('Something went wrong',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800])),
                const SizedBox(height: 8),
                Text(provider.messagesError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => provider.fetchGroupMessages(widget.groupId),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: const Text('Try Again'),
                ),
              ]),
            ),
          );
        }

        final messages = provider.currentGroupMessages;

        if (messages.isEmpty) {
          return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.grey[100], shape: BoxShape.circle),
                  child: Icon(Icons.chat_bubble_outline,
                      size: 60, color: Colors.grey[400])),
              const SizedBox(height: 20),
              Text('No messages yet',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 6),
              Text('Be the first to send a message!',
                  style: TextStyle(fontSize: 15, color: Colors.grey[500])),
            ]),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return RefreshIndicator(
          onRefresh: () async => provider.fetchGroupMessages(widget.groupId),
          color: Theme.of(context).colorScheme.primary,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final msg = messages[i];
              final prev = i > 0 ? messages[i - 1] : null;
              final next = i < messages.length - 1 ? messages[i + 1] : null;

              final showDateDiv = prev == null ||
                  !_sameDay(msg['createdAt'] ?? '', prev['createdAt'] ?? '');

              // Show avatar only on the LAST consecutive bubble from same sender
              // (WhatsApp-style: avatar appears at the bottom of a group of msgs)
              final isSameSenderAsNext = next != null &&
                  _senderId(next) == _senderId(msg) &&
                  _senderId(msg) != (_currentUserId ?? '');

              return Column(
                children: [
                  if (showDateDiv) _buildDateDivider(msg['createdAt'] ?? ''),
                  _buildMessageBubble(msg, showAvatar: !isSameSenderAsNext),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildMessageInput() {
    final provider = context.read<GroupChatProvider>();
    final g = provider.getGroupById(widget.groupId);
    final communityInfo = g != null
        ? {
            "_id": g['_id'] ?? widget.groupId,
            "name": g['name'] ?? widget.groupName
          }
        : {"_id": widget.groupId, "name": widget.groupName};

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25)),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[800]),
                          cursorColor: const Color(0xFF6C5CE7),
                          enabled: !_isSending,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            icon: Icon(Icons.camera_alt,
                                size: 20,
                                color: _isSending
                                    ? Colors.grey[400]
                                    : const Color(0xFF6C5CE7)),
                            onPressed: _isSending ? null : _capturePhoto,
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            icon: Icon(Icons.attach_file,
                                size: 20,
                                color: _isSending
                                    ? Colors.grey[400]
                                    : const Color(0xFF6C5CE7)),
                            onPressed: _isSending
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => GroupFileMessageScreen(
                                            groupId: widget.groupId,
                                            groupName: widget.groupName,
                                            communityInfo: communityInfo))),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _isSending
                                  ? Colors.grey[400]
                                  : const Color(0xFF6C5CE7),
                              shape: BoxShape.circle,
                            ),
                            child: _isSending
                                ? const Center(
                                    child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                                Colors.white))))
                                : IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    icon: const Icon(Icons.send,
                                        size: 18, color: Colors.white),
                                    onPressed: _isSending ? null : _sendMessage,
                                  ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : const Color(0xFF6C5CE7),
                    shape: BoxShape.circle),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic,
                      size: 22, color: Colors.white),
                  onPressed: _isSending
                      ? null
                      : (_isRecording ? _stopRecording : _startRecording),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage() async {
    if (_isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<GroupChatProvider>();
    final g = provider.getGroupById(widget.groupId);
    final communityInfo = {
      "_id": g?['_id'] ?? widget.groupId,
      "name": g?['name'] ?? widget.groupName
    };

    setState(() => _isSending = true);
    _messageController.clear();
    _scrollToBottom();

    try {
      final ok = await provider.sendGroupMessage(
          groupId: widget.groupId, text: text, communityInfo: communityInfo);
      if (ok) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _scrollToBottom();
        });
      } else {
        _messageController.text = text;
        if (provider.sendMessageError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(provider.sendMessageError!),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: _sendMessage)));
        }
      }
    } catch (e) {
      _messageController.text = text;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        shadowColor: Colors.grey[200],
        surfaceTintColor: Colors.transparent,
        title: Consumer<GroupChatProvider>(
          builder: (context, provider, _) {
            final group = provider.getGroupById(widget.groupId);
            final count = group?['memberCount'] ?? 0;
            return Row(children: [
              _buildGroupAvatarSmall(group),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.groupName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                      if (count > 0)
                        Text('$count members',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400)),
                    ]),
              ),
            ]);
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'add_member') {
                widget.isAdmin
                    ? _showAddMembersDialog()
                    : ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Only admins can add members')));
              } else if (v == 'group_info') {
                _showGroupInfo();
              }
            },
            icon: const Icon(Icons.more_vert, color: Color(0xFF6C5CE7)),
            itemBuilder: (_) => [
              if (widget.isAdmin)
                const PopupMenuItem(
                    value: 'add_member',
                    child: Row(children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 12),
                      Text('Add Member')
                    ])),
              const PopupMenuItem(
                  value: 'group_info',
                  child: Row(children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Text('Group Info')
                  ])),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border(top: BorderSide(color: Colors.red[200]!))),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text('Recording...',
                    style: TextStyle(
                        color: Colors.red[700], fontWeight: FontWeight.w500)),
                const Spacer(),
                TextButton(
                    onPressed: _stopRecording, child: const Text('Stop')),
              ]),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  void _showAddMembersDialog() {
    final provider = context.read<GroupChatProvider>();
    provider.fetchAllUsers();
    showDialog(
      context: context,
      builder: (_) {
        String? selectedId;
        return Consumer<GroupChatProvider>(
          builder: (context, p, __) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Select Member'),
            content: SizedBox(
              width: double.maxFinite,
              height: 200,
              child: p.isFetchingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : p.allUsers.isEmpty
                      ? Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              const Text('No users available'),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                  onPressed: () => p.fetchAllUsers(),
                                  child: const Text('Retry')),
                            ]))
                      : StatefulBuilder(
                          builder: (ctx, setS) => DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Select a user'),
                            value: selectedId,
                            items: p.allUsers.map((u) {
                              final id = u['_id'] as String?;
                              final name = u['profile']?['name'] as String? ??
                                  u['mobile'] as String? ??
                                  'Unknown';
                              return DropdownMenuItem<String>(
                                  value: id, child: Text(name));
                            }).toList(),
                            onChanged: (v) => setS(() => selectedId = v),
                          ),
                        ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: p.isAddingMembers || selectedId == null
                    ? null
                    : () async {
                        await p.addMembersToGroup(
                            groupId: widget.groupId, memberIds: [selectedId!]);
                        if (mounted) Navigator.pop(context);
                      },
                child: p.isAddingMembers
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGroupInfo() {
    final provider = context.read<GroupChatProvider>();
    final group = provider.getGroupById(widget.groupId);
    if (group == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.grey[300], shape: BoxShape.circle),
                child: group['profileImage'] != null
                    ? ClipOval(
                        child: Image.network(group['profileImage'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.group, size: 50)))
                    : const Icon(Icons.group, size: 50),
              )),
              const SizedBox(height: 16),
              Center(
                  child: Text(group['name'] ?? 'Unknown Group',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold))),
              if (group['description'] != null &&
                  group['description'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                    child: Text(group['description'],
                        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                        textAlign: TextAlign.center)),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _infoRow(
                      'Members', '${group['memberCount'] ?? 0}', Icons.people),
                  const Divider(),
                  _infoRow(
                      'Role',
                      group['isAdmin'] == true
                          ? 'Admin'
                          : (group['isMember'] == true
                              ? 'Member'
                              : 'Not a member'),
                      group['isAdmin'] == true
                          ? Icons.admin_panel_settings
                          : Icons.person),
                ]),
              ),
              const SizedBox(height: 20),
              if (group['isMember'] == true)
                _actionButton('Leave Group', Icons.exit_to_app, Colors.red,
                    () => Navigator.pop(context))
              else if (group['isRequested'] == true)
                _actionButton(
                    'Request Pending', Icons.hourglass_empty, Colors.grey, null)
              else
                _actionButton('Join Group', Icons.add, Colors.blue,
                    () => Navigator.pop(context)),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12)),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ]),
    );

  }
}
