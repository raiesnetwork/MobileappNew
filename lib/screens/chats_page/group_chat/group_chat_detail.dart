import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/group_provider.dart';

import '../../../services/socket_service.dart';
import 'group_add_remove_member_screen.dart';
import 'group_message_bubble_screen.dart' show GroupMessageBubble;

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
  final ImagePicker _imagePicker = ImagePicker();

  String? _currentUserId;
  bool _isSending = false;
  File? _selectedFile;

  // ── Voice recording ─────────────────────────────────────────────────────
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // ── Reply ────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _replyingToMessage;

  // ── Compression constants ────────────────────────────────────────────────
  static const int _maxImageBytes = 800 * 1024;
  static const int _maxAudioBytes = 4 * 1024 * 1024;

// Add this field at the top of _GroupChatDetailPageState:
  late GroupChatProvider _groupChatProvider;

// In initState, save the reference:
  @override
  void initState() {
    super.initState();
    _groupChatProvider = context.read<GroupChatProvider>(); // ✅ save early
    _loadCurrentUser();
    _initializeRecorder();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeChat());
  }

// In dispose, use the saved reference instead of context.read:
  @override
  void dispose() {
    _groupChatProvider.onNewMessageReceived = null; // ✅ no context.read here

    _recordingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _recorder?.closeRecorder();
    SocketService().leaveGroup(widget.groupId);
    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      try { File(_recordingPath!).deleteSync(); } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _currentUserId = prefs.getString('user_id'));
  }

  void _initializeChat() {
    final provider = context.read<GroupChatProvider>();
    provider.setCurrentGroup(widget.groupId);
    provider.fetchGroupMessages(widget.groupId);
    provider.clearUnreadCount(widget.groupId);
    SocketService().joinGroup(widget.groupId);

    // ✅ Auto scroll when new message arrives via socket
    provider.onNewMessageReceived = () {
      if (mounted) _scrollToBottom();
    };
  }



  String _readableSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic']
        .contains(ext);
  }

  Future<File> _compressImage(File imageFile) async {
    final ext = p.extension(imageFile.path).toLowerCase();
    final format = ext == '.png' ? CompressFormat.png : CompressFormat.jpeg;
    final tmpDir = await getTemporaryDirectory();
    final outExt = ext == '.png' ? 'png' : 'jpg';

    for (final quality in [80, 60, 40, 25]) {
      final result = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: quality,
        format: format,
        keepExif: false,
      );
      if (result == null) break;

      final outPath = p.join(
          tmpDir.path, 'img_${DateTime.now().millisecondsSinceEpoch}.$outExt');
      final outFile = File(outPath)..writeAsBytesSync(result);

      if (result.length <= _maxImageBytes || quality == 25) return outFile;
    }
    return imageFile;
  }

  Future<File> _compressAudio(File audioFile) async {
    final size = await audioFile.length();
    if (size <= _maxAudioBytes) return audioFile;
    print('⚠️ Audio ${_readableSize(size)} exceeds limit — sending as-is');
    return audioFile;
  }

  Future<File> _compressFile(File file) async {
    if (_isImageFile(file.path)) return await _compressImage(file);
    return await _compressAudio(file);
  }

  Future<File> _compressAndWarnUser(File rawFile) async {
    final origSize = await rawFile.length();
    final compressed = await _compressFile(rawFile);
    final newSize = await compressed.length();
    if (newSize < origSize && mounted) {
      final saved =
      ((origSize - newSize) / origSize * 100).toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '📦 Compressed: ${_readableSize(origSize)} → ${_readableSize(newSize)} ($saved% smaller)'),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
      ));
    }
    return compressed;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RECORDER
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _initializeRecorder() async {
    try {
      _recorder = FlutterSoundRecorder();
      final status = await Permission.microphone.request();
      if (status == PermissionStatus.granted) {
        await _recorder!.openRecorder();
        setState(() => _isRecorderInitialized = true);
      } else {
        _showMicPermissionDialog();
      }
    } catch (e) {
      print('💥 Recorder init error: $e');
    }
  }

  void _showMicPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
            'To send voice messages, allow microphone access in settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized || _recorder == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Voice recorder not available'),
          backgroundColor: Colors.red));
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      _recordingPath =
      '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.startRecorder(
          toFile: _recordingPath, codec: Codec.aacMP4);
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_isRecording && mounted) {
          setState(() => _recordingDuration = Duration(seconds: t.tick));
        } else {
          t.cancel();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _recorder == null) return;
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      if (_recordingPath != null && File(_recordingPath!).existsSync()) {
        _showVoicePreview();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to stop recording: $e'),
          backgroundColor: Colors.red));
    }
  }

  void _showVoicePreview() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, size: 25, color: Colors.blue),
              const SizedBox(height: 16),
              Text('Voice message recorded',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Duration: ${_formatDuration(_recordingDuration)}'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteRecording();
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.red),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendVoiceMessage();
                    },
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendVoiceMessage() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No voice recording found'),
          backgroundColor: Colors.red));
      return;
    }

    final provider = context.read<GroupChatProvider>();
    final communityInfo = _buildCommunityInfo(provider);
    final durationMs = _recordingDuration.inMilliseconds;
    final replyId = _replyingToMessage?['_id']?.toString();
    final replySnapshot = _replyingToMessage;

    try {
      final audioFile = File(_recordingPath!);
      final uploadFile = await _compressFile(audioFile);

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      provider.addMessageToCurrentGroup({
        '_id': tempId,
        'isAudio': true,
        'audioUrl': uploadFile.path,
        'localFilePath': uploadFile.path,
        'audioDurationMs': durationMs,
        'senderId': _buildMyFakeSenderMap(),
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'sending',
        'isOptimistic': true,
        if (replySnapshot != null) 'replyToMessage': replySnapshot,
      });
      _scrollToBottom();
      _clearReply();

      // Replace with:
      final ok = await provider.sendGroupVoiceMessage(
        groupId: widget.groupId,
        audioFile: uploadFile,
        communityInfo: communityInfo,
        audioDurationMs: durationMs,
        replyTo: replyId,
        tempId: tempId, // ← ADD THIS
      );

      if (ok) {

        _scrollToBottom();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Voice message sent! (${_formatDuration(_recordingDuration)})'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ));
        }
      } else {
        provider.updateOptimisticStatus(widget.groupId, tempId, 'failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
            Text('Failed: ${provider.sendVoiceError ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _deleteRecording();
    }
  }

  void _deleteRecording() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      try {
        File(_recordingPath!).deleteSync();
      } catch (_) {}
      _recordingPath = null;
    }
    if (mounted) setState(() => _recordingDuration = Duration.zero);
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CAMERA & FILE PICKER
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
          source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
          _messageController.text = _selectedFile!.path.split('/').last;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _messageController.text = _selectedFile!.path.split('/').last;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red));
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND TEXT / FILE
  // ════════════════════════════════════════════════════════════════════════
  void _sendMessage() async {
    if (_isSending) return;

    final provider = context.read<GroupChatProvider>();
    final communityInfo = _buildCommunityInfo(provider);

    if (_selectedFile != null) {
      setState(() => _isSending = true);
      final rawFile = _selectedFile!;
      setState(() {
        _selectedFile = null;
        _messageController.clear();
      });

      try {
        final fileToSend = await _compressAndWarnUser(rawFile);

        final replyId = _replyingToMessage?['_id']?.toString();
        final replySnapshot = _replyingToMessage;

        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        provider.addMessageToCurrentGroup({
          '_id': tempId,
          'isFile': true,
          'fileName': p.basename(fileToSend.path),
          'fileUrl': fileToSend.path,
          'localFilePath': fileToSend.path,
          'senderId': _buildMyFakeSenderMap(),
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'sending',
          'isOptimistic': true,
          if (replySnapshot != null) 'replyToMessage': replySnapshot,
        });
        _scrollToBottom();
        _clearReply();

        final ok = await provider.sendGroupFileMessage(
          groupId: widget.groupId,
          file: fileToSend,
          communityInfo: communityInfo,
          replyTo: replyId,
          tempId: tempId, // ← ADD THIS
        );

        if (ok) {


          _scrollToBottom();
        } else {
          provider.updateOptimisticStatus(widget.groupId, tempId, 'failed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Failed to send file: ${provider.sendFileError ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    } else {
      final text = _messageController.text.trim();
      if (text.isEmpty) return;

      final replyId = _replyingToMessage?['_id']?.toString();

      setState(() => _isSending = true);
      _messageController.clear();
      _scrollToBottom();

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      provider.addMessageToCurrentGroup({
        '_id': tempId,
        'text': text,
        'senderId': _buildMyFakeSenderMap(),
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'sending',
        'isOptimistic': true,
        if (_replyingToMessage != null) 'replyToMessage': _replyingToMessage,
      });
      _clearReply();

      try {
        final ok = await provider.sendGroupMessage(
          groupId: widget.groupId,
          text: text,
          communityInfo: communityInfo,
          replyTo: replyId,
          tempId: tempId, // ← ADD THIS
        );

        if (ok) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _scrollToBottom();
          });
        } else {
          provider.updateOptimisticStatus(widget.groupId, tempId, 'failed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(provider.sendMessageError ?? 'Failed to send'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    provider.removeOptimisticMessage(widget.groupId, tempId);
                    _messageController.text = text;
                  }),
            ));
          }
        }
      } catch (e) {
        provider.removeOptimisticMessage(widget.groupId, tempId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════
  Map<String, dynamic> _buildCommunityInfo(GroupChatProvider provider) {
    final g = provider.getGroupById(widget.groupId);
    return {
      '_id': g?['_id'] ?? widget.groupId,
      'name': g?['name'] ?? widget.groupName,
    };
  }

  Map<String, dynamic> _buildMyFakeSenderMap() {
    return {
      '_id': _currentUserId ?? '',
      'profile': {'name': 'You'},
    };
  }

  void _setReplyMessage(Map<String, dynamic> message) =>
      setState(() => _replyingToMessage = message);

  void _clearReply() => setState(() => _replyingToMessage = null);

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

  bool _sameDay(String a, String b) {
    try {
      final da = DateTime.parse(a);
      final db = DateTime.parse(b);
      return da.year == db.year && da.month == db.month && da.day == db.day;
    } catch (_) {
      return true;
    }
  }

  String _senderId(Map<String, dynamic> msg) {
    final s = msg['senderId'];
    if (s is Map<String, dynamic>) return s['_id']?.toString() ?? '';
    return s?.toString() ?? '';
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

  // ════════════════════════════════════════════════════════════════════════
  //  MEMBER MANAGEMENT — async so we can refresh on return
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _openMemberManagement({bool adminMode = true}) async {
    final provider = context.read<GroupChatProvider>();
    final group = provider.getGroupById(widget.groupId) ??
        provider.getMyGroupById(widget.groupId);
    final members = (group?['members'] as List<dynamic>?) ?? [];

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupMemberManagementScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
          currentMembers: members,
          initialTabIndex: adminMode ? 0 : 1,
        ),
      ),
    );

    // Re-fetch from server so member list is always fresh on return
    if (mounted) {
      await provider.fetchMyGroups();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          if (_isRecording) _buildRecordingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.grey[800],
      elevation: 0,
      shadowColor: Colors.grey[200],
      surfaceTintColor: Colors.transparent,
      title: Consumer<GroupChatProvider>(
        builder: (_, provider, __) {
          final group = provider.getGroupById(widget.groupId);
          final count = group?['memberCount'] ?? 0;
          final name = group?['name'] ?? widget.groupName;
          final img = group?['profileImage']?.toString();
          final hasImg = img != null && img.isNotEmpty && img != 'null';

          return Row(children: [
            Container(
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
                    ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16))
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
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
            switch (v) {
              case 'manage_members':
                _openMemberManagement(adminMode: true);
                break;
              case 'remove_members':
                _openMemberManagement(adminMode: false);
                break;
              case 'group_info':
                _showGroupInfo();
                break;
            }
          },
          icon: const Icon(Icons.more_vert, color: Color(0xFF6C5CE7)),
          itemBuilder: (_) => [
            if (widget.isAdmin)
              const PopupMenuItem(
                value: 'manage_members',
                child: Row(children: [
                  Icon(Icons.manage_accounts_rounded,
                      color: Color(0xFF6C5CE7)),
                  SizedBox(width: 12),
                  Text('Manage Members'),
                ]),
              ),
            const PopupMenuItem(
              value: 'group_info',
              child: Row(children: [
                Icon(Icons.info_outline),
                SizedBox(width: 12),
                Text('Group Info'),
              ]),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMessagesList() {
    return Consumer<GroupChatProvider>(
      builder: (_, provider, __) {
        if (provider.isLoadingMessages) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary),
                  ),
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
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10)
                  ]),
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
                    style:
                    TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      provider.fetchGroupMessages(widget.groupId),
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                      Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: const Text('Try Again'),
                ),
              ]),
            ),
          );
        }

        final messages = provider.currentGroupMessages
            .where((m) => m['isDelete'] != true)
            .toList();

        if (messages.isEmpty) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  Text('Be the first to say something!',
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey[500])),
                ]),
          );
        }

        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());

        return RefreshIndicator(
          onRefresh: () async =>
              provider.fetchGroupMessages(widget.groupId),
          color: const Color(0xFF6C5CE7),
          child: ListView.builder(
            controller: _scrollController,
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final msg = messages[i];
              final prev = i > 0 ? messages[i - 1] : null;
              final next =
              i < messages.length - 1 ? messages[i + 1] : null;

              final showDateDiv = prev == null ||
                  !_sameDay(
                      msg['createdAt'] ?? '', prev['createdAt'] ?? '');

              final isSameSenderAsNext = false;

              return Column(
                children: [
                  if (showDateDiv)
                    _buildDateDivider(msg['createdAt'] ?? ''),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GroupMessageBubble(
                      message: msg,
                      currentUserId: _currentUserId,
                      groupId: widget.groupId,
                      showAvatar: !isSameSenderAsNext,
                      onReply: _setReplyMessage,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDateDivider(String timestamp) {
    String label = '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(dt.year, dt.month, dt.day))
          .inDays;
      if (diff == 0) {
        label = 'Today';
      } else if (diff == 1) {
        label = 'Yesterday';
      } else {
        label = '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12)),
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ]),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
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
        Text('Recording... ${_formatDuration(_recordingDuration)}',
            style: TextStyle(
                color: Colors.red[700], fontWeight: FontWeight.w500)),
        const Spacer(),
        TextButton(
            onPressed: _stopRecording, child: const Text('Stop')),
      ]),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingToMessage != null) _buildReplyPreviewBar(),
              if (_selectedFile != null) _buildFilePreviewChip(),
              Row(
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
                                hintText: _selectedFile != null
                                    ? 'Add a caption...'
                                    : 'Type a message...',
                                hintStyle:
                                TextStyle(color: Colors.grey[500]),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                              maxLines: null,
                              textCapitalization:
                              TextCapitalization.sentences,
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[800]),
                              cursorColor: const Color(0xFF6C5CE7),
                              enabled: !_isSending,
                              onSubmitted: (_) {
                                if (!_isSending) _sendMessage();
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    icon: Icon(Icons.camera_alt,
                                        size: 20,
                                        color: (_selectedFile == null &&
                                            !_isSending)
                                            ? const Color(0xFF6C5CE7)
                                            : Colors.grey[400]),
                                    onPressed: (_selectedFile == null &&
                                        !_isSending)
                                        ? _capturePhoto
                                        : null,
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    icon: Icon(Icons.attach_file,
                                        size: 20,
                                        color: (_selectedFile == null &&
                                            !_isSending)
                                            ? const Color(0xFF6C5CE7)
                                            : Colors.grey[400]),
                                    onPressed: (_selectedFile == null &&
                                        !_isSending)
                                        ? _pickFile
                                        : null,
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
                                            child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                AlwaysStoppedAnimation(
                                                    Colors
                                                        .white))))
                                        : IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints:
                                      const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36),
                                      icon: const Icon(Icons.send,
                                          size: 18,
                                          color: Colors.white),
                                      onPressed: _isSending
                                          ? null
                                          : _sendMessage,
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
                        color: _isRecording
                            ? Colors.red
                            : const Color(0xFF6C5CE7),
                        shape: BoxShape.circle),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 44, minHeight: 44),
                      icon: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 22,
                          color: Colors.white),
                      onPressed: _isSending
                          ? null
                          : (_isRecording
                          ? _stopRecording
                          : _startRecording),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreviewBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border(
            left: BorderSide(color: const Color(0xFF6C5CE7), width: 3)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyingToMessage!['senderName'] ?? 'message'}',
                  style: const TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  _replyingToMessage!['text'] ??
                      (_replyingToMessage!['isFile'] == true
                          ? '📎 ${_replyingToMessage!['fileName']}'
                          : (_replyingToMessage!['isAudio'] == true
                          ? '🎤 Voice message'
                          : '')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ]),
        ),
        IconButton(
          icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
          onPressed: _clearReply,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }

  Widget _buildFilePreviewChip() {
    return FutureBuilder<int>(
      future: _selectedFile!.length(),
      builder: (context, snap) {
        final sizeStr = snap.hasData ? _readableSize(snap.data!) : '...';
        final name = _selectedFile!.path.split('/').last;
        final isImg = _isImageFile(_selectedFile!.path);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(children: [
            Icon(isImg ? Icons.image : Icons.attach_file,
                size: 18, color: const Color(0xFF6C5CE7)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500)),
                    Text(sizeStr,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ]),
            ),
            if (isImg && snap.hasData && snap.data! > _maxImageBytes)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4)),
                child: Text('Will compress',
                    style: TextStyle(
                        fontSize: 10, color: Colors.orange[800])),
              ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
              padding: EdgeInsets.zero,
              constraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => setState(() {
                _selectedFile = null;
                _messageController.clear();
              }),
            ),
          ]),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  GROUP INFO BOTTOM SHEET
  // ════════════════════════════════════════════════════════════════════════
  void _showGroupInfo() {
    final provider = context.read<GroupChatProvider>();
    final group = provider.getGroupById(widget.groupId) ??
        provider.getMyGroupById(widget.groupId);
    if (group == null) return;

    final members = (group['members'] as List<dynamic>?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // ── Drag Handle ──
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Group Avatar + Name + Description ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (group['profileImage'] == null ||
                          (group['profileImage'] as String).isEmpty)
                          ? const LinearGradient(
                        colors: [Color(0xFF9B8FF5), Color(0xFF6C5CE7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.transparent,
                      backgroundImage: (group['profileImage'] != null &&
                          (group['profileImage'] as String).isNotEmpty)
                          ? NetworkImage(group['profileImage'])
                          : null,
                      child: (group['profileImage'] == null ||
                          (group['profileImage'] as String).isEmpty)
                          ? Text(
                        (group['name'] ?? 'G')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                        ),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    group['name'] ?? 'Unknown Group',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (group['description'] != null &&
                      (group['description'] as String).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      group['description'],
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Stats Row ──
                  Row(
                    children: [
                      Expanded(
                        child: _infoStatCard(
                          icon: Icons.people_rounded,
                          label: 'Members',
                          value: '${group['memberCount'] ?? members.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoStatCard(
                          icon: group['isAdmin'] == true
                              ? Icons.admin_panel_settings_rounded
                              : Icons.person_rounded,
                          label: 'Your Role',
                          value: group['isAdmin'] == true ? 'Admin' : 'Member',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(color: Colors.grey[100], thickness: 1),

            // ── Members List Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${members.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (group['isAdmin'] == true)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _openMemberManagement(adminMode: true);
                      },
                      child: const Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6C5CE7),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Members List ──
            Expanded(
              child: members.isEmpty
                  ? Center(
                child: Text(
                  'No members to display',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final m = members[i];
                  final isAdmin =
                      m is Map && (m['isAdmin'] == true || m['role'] == 'admin');

                  // Extract name
                  String name = 'Member';
                  if (m is Map) {
                    final profile = m['profile'];
                    if (profile is Map &&
                        profile['name'] != null &&
                        profile['name'].toString().trim().isNotEmpty) {
                      name = profile['name'].toString().trim();
                    } else if (m['name'] != null) {
                      name = m['name'].toString().trim();
                    } else if (m['mobile'] != null) {
                      name = m['mobile'].toString().trim();
                    }
                  }

                  // Extract mobile
                  String mobile = '';
                  if (m is Map) {
                    mobile = (m['mobile'] ??
                        (m['profile'] is Map
                            ? m['profile']['mobile']
                            : null) ??
                        '')
                        .toString();
                  }

                  // Extract avatar
                  String? avatar;
                  if (m is Map) {
                    final profile = m['profile'];
                    if (profile is Map) {
                      final img = profile['profileImage']?.toString() ?? '';
                      if (img.isNotEmpty && img != 'null') avatar = img;
                    }
                  }

                  final initials = name[0].toUpperCase();
                  final hasAvatar =
                      avatar != null && avatar.isNotEmpty && avatar != 'null';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: !hasAvatar
                                    ? const LinearGradient(
                                  colors: [
                                    Color(0xFF9B8FF5),
                                    Color(0xFF6C5CE7)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                    : null,
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.transparent,
                                backgroundImage: hasAvatar
                                    ? NetworkImage(avatar!)
                                    : null,
                                child: !hasAvatar
                                    ? Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                                    : null,
                              ),
                            ),
                            if (isAdmin)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB347),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(Icons.star_rounded,
                                      size: 9, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Name + mobile
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1D2E),
                                ),
                              ),
                              if (mobile.isNotEmpty && mobile != name)
                                Text(
                                  mobile,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9DA3B4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Admin badge
                        if (isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                              const Color(0xFFFFB347).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                color: Color(0xFFE08500),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Leave Group (members only, NO join button) ──
            if (group['isMember'] == true && group['isAdmin'] != true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final ok = await provider.cancelGroupRequest(widget.groupId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'Left group' : 'Failed to leave'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ));
                      }
                    },
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    label: const Text('Leave Group',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

// Add this helper widget alongside _infoRow:
  Widget _infoStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C5CE7)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9DA3B4),
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E))),
            ],
          ),
        ],
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
        Text(label,
            style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}