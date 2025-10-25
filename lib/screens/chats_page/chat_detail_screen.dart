import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/personal_chat_provider.dart';
import './message_bubble_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String userId;
  final String chatTitle;
  final Map<String, dynamic> userProfile;

  const ChatDetailScreen({
    Key? key,
    required this.userId,
    required this.chatTitle,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  File? _selectedFile;
  bool _messagesLoaded = false;

  // Voice recording variables
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PersonalChatProvider>();
      await provider.fetchConversation(widget.userId);

      // After fetching, mark as read
      await provider.updateReadStatus(
        senderId: widget.userId,
        receiverId: provider.currentUserId!,
      );

      // Mark messages as loaded
      if (mounted) {
        setState(() {
          _messagesLoaded = true;
        });
      }
    });
  }

  // Initialize voice recorder
  Future<void> _initializeRecorder() async {
    try {
      _recorder = FlutterSoundRecorder();

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status == PermissionStatus.granted) {
        await _recorder!.openRecorder();
        setState(() {
          _isRecorderInitialized = true;
        });
        print('✅ Voice recorder initialized successfully');
      } else {
        print('❌ Microphone permission denied');
        _showPermissionDialog();
      }
    } catch (e) {
      print('💥 Error initializing recorder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize voice recorder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text('To send voice messages, please allow microphone access in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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

  // Start voice recording
  Future<void> _startRecording() async {
    if (!_isRecorderInitialized || _recorder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice recorder not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${tempDir.path}/$fileName';

      // Try different codecs with fallback
      try {
        await _recorder!.startRecorder(
          toFile: _recordingPath,
          codec: Codec.aacMP4,
        );
      } catch (e) {
        print('AAC failed, trying MP3: $e');
        try {
          final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.mp3';
          _recordingPath = '${tempDir.path}/$fileName';
          await _recorder!.startRecorder(
            toFile: _recordingPath,
            codec: Codec.mp3,
          );
        } catch (e2) {
          print('MP3 failed, using default codec: $e2');
          final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.wav';
          _recordingPath = '${tempDir.path}/$fileName';
          await _recorder!.startRecorder(
            toFile: _recordingPath,
          );
        }
      }

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start duration timer
      _startDurationTimer();

      print('🎤 Started recording to: $_recordingPath');
    } catch (e) {
      print('💥 Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Stop voice recording
  Future<void> _stopRecording() async {
    if (!_isRecording || _recorder == null) return;

    try {
      await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      print('🎤 Stopped recording. File: $_recordingPath');

      if (_recordingPath != null && File(_recordingPath!).existsSync()) {
        _showVoicePreview();
      }
    } catch (e) {
      print('💥 Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Timer for recording duration
  void _startDurationTimer() {
    Stream.periodic(const Duration(seconds: 1), (i) => i).listen((count) {
      if (_isRecording) {
        setState(() {
          _recordingDuration = Duration(seconds: count + 1);
        });
      }
    });
  }

  // Show voice message preview
  void _showVoicePreview() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Voice message recorded',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Duration: ${_formatDuration(_recordingDuration)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
                    foregroundColor: Colors.red,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendVoiceMessage();
                  },
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Send voice message
  Future<void> _sendVoiceMessage() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No voice recording found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = context.read<PersonalChatProvider>();
    final receiverId = widget.userProfile['_id'];
    final currentUserId = provider.currentUserId;

    if (receiverId == null || currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to send voice message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final audioFile = File(_recordingPath!);
      final response = await provider.sendVoiceMessage(
        audioFile: audioFile,
        receiverId: receiverId,
        readBy: false,
      );

      if (response != null) {
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice message sent!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: ${provider.sendMessageError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending voice message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _deleteRecording();
    }
  }

  // Delete recording file
  void _deleteRecording() {
    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      File(_recordingPath!).deleteSync();
      _recordingPath = null;
    }
  }

  // Format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Quick scroll to bottom for new messages
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeOut,
        );
      }
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    final provider = context.read<PersonalChatProvider>();
    final receiverId = widget.userProfile['_id'];
    final currentUserId = provider.currentUserId;

    if (receiverId == null || currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error: Unable to send message. receiverId: $receiverId, currentUserId: $currentUserId'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedFile != null) {
      // Force HTTP for file messages since socket isn't implemented
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      int fileSize = 0;
      try {
        fileSize = await _selectedFile!.length();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final optimisticMessage = {
        '_id': tempId,
        'fileUrl': _selectedFile!.path,
        'fileName': _selectedFile!.path.split('/').last,
        'fileType': _getFileType(_selectedFile!.path),
        'fileSize': fileSize.toString(),
        'senderId': currentUserId,
        'receiverId': receiverId,
        'isFile': true,
        'createdAt': DateTime.now().toString(),
        'status': 'sending',
        'isOptimistic': true,
        'localFilePath': _selectedFile!.path,
      };

      provider.messages.add(optimisticMessage);
      provider.notifyListeners();

      final fileToSend = _selectedFile!;

      setState(() {
        _selectedFile = null;
        _messageController.clear();
      });

      _scrollToBottom();

      try {
        // Force HTTP by setting useSocket to false
        final response = await provider.sendFileMessage(
          file: fileToSend,
          receiverId: receiverId,
          readBy: false,
        );

        if (response != null) {
          final messageIndex = provider.messages.indexWhere((m) => m['_id'] == tempId);
          if (messageIndex >= 0) {
            final messageData = response;
            provider.messages[messageIndex] = {
              '_id': messageData['_id'] ?? tempId,
              'fileUrl': _constructFullFileUrl(messageData['fileUrl']),
              'fileName': messageData['fileName'] ?? fileToSend.path.split('/').last,
              'fileType': messageData['fileType'] ?? _getFileType(fileToSend.path),
              'fileSize': messageData['fileSize'] ?? fileSize.toString(),
              'senderId': messageData['senderId'] ?? currentUserId,
              'receiverId': messageData['receiverId'] is Map
                  ? messageData['receiverId']['_id'] ?? receiverId
                  : messageData['receiverId'] ?? receiverId,
              'isFile': messageData['isFile'] ?? true,
              'createdAt': messageData['createdAt'] ?? DateTime.now().toString(),
              'status': 'sent',
              'localFilePath': fileToSend.path,
              'isFromServer': true,
              'readBy': messageData['readBy'] ?? false,
            };
            provider.notifyListeners();
          }
        } else {
          final messageIndex = provider.messages.indexWhere((m) => m['_id'] == tempId);
          if (messageIndex >= 0) {
            provider.messages[messageIndex]['status'] = 'failed';
            provider.notifyListeners();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send file: ${provider.sendMessageError ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        final messageIndex = provider.messages.indexWhere((m) => m['_id'] == tempId);
        if (messageIndex >= 0) {
          provider.messages[messageIndex]['status'] = 'failed';
          provider.notifyListeners();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (content.isNotEmpty) {
      // Send text message (existing code)
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      final optimisticMessage = {
        '_id': tempId,
        'text': content,
        'senderId': currentUserId,
        'receiverId': receiverId,
        'createdAt': DateTime.now().toString(),
        'status': 'sending',
        'isOptimistic': true,
        'readBy': false,
      };

      provider.messages.add(optimisticMessage);
      provider.notifyListeners();

      _messageController.clear();
      _scrollToBottom();

      try {
        final result = await provider.sendMessage(
          receiverId: receiverId,
          text: content,
          readBy: false,
        );

        if (result != null && (result['error'] == false || result['success'] == true)) {
          final messageIndex = provider.messages.indexWhere((m) => m['_id'] == tempId);
          if (messageIndex >= 0) {
            final messageData = result['message'];
            if (messageData != null) {
              provider.messages[messageIndex] = {
                '_id': messageData['_id'] ?? tempId,
                'text': messageData['text'] ?? content,
                'senderId': messageData['senderId'] ?? currentUserId,
                'receiverId': messageData['receiverId'] is Map
                    ? messageData['receiverId']['_id'] ?? receiverId
                    : messageData['receiverId'] ?? receiverId,
                'createdAt': messageData['createdAt'] ?? DateTime.now().toString(),
                'status': 'sent',
                'readBy': messageData['readBy'] ?? false,
                'isFromServer': true,
              };
            } else {
              provider.messages[messageIndex]['status'] = 'sent';
              provider.messages[messageIndex]['readBy'] = false;
            }
            provider.notifyListeners();
          }
        } else {
          final messageIndex = provider.messages.indexWhere((m) => m['_id'] == tempId);
          if (messageIndex >= 0) {
            provider.messages[messageIndex]['status'] = 'failed';
            provider.notifyListeners();
          }
        }
      } catch (e) {
        final messageIndex = provider.messages.indexWhere((m) => m['_id'] == tempId);
        if (messageIndex >= 0) {
          provider.messages[messageIndex]['status'] = 'failed';
          provider.notifyListeners();
        }
      }
    }
  }

  String _getFileType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  String _constructFullFileUrl(String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) return '';

    if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
      return fileUrl;
    }

    const String baseUrl = 'https://api.ixes.ai';
    String cleanPath = fileUrl;
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }

    if (cleanPath.contains('/voice/')) {
      return '$baseUrl$cleanPath';
    }

    return '$baseUrl/fileUrl$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = widget.userProfile['profile']['profileImage'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.transparent,
                backgroundImage: profileImage != null && profileImage.isNotEmpty
                    ? (profileImage.startsWith('data:image/')
                    ? MemoryImage(base64Decode(profileImage.split(',')[1]))
                    : NetworkImage(profileImage))
                    : null,
                child: profileImage == null || profileImage.isEmpty
                    ? Text(
                  widget.chatTitle.isNotEmpty
                      ? widget.chatTitle[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        shadowColor: Colors.grey[200],
        surfaceTintColor: Colors.transparent,
      ),
      body: Consumer<PersonalChatProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading conversation...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[400],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Oops! Something went wrong',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error ?? 'Unknown error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _messagesLoaded = false;
                        provider.fetchConversation(widget.userId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final messages = provider.messages ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start the conversation by sending a message below',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _messagesLoaded = false;
                    });
                    await provider.fetchConversation(widget.userId);
                    if (mounted) {
                      setState(() {
                        _messagesLoaded = true;
                      });
                    }
                  },
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Colors.white,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    physics: const BouncingScrollPhysics(),
                    reverse: _messagesLoaded,
                    itemBuilder: (context, index) {
                      final actualIndex = _messagesLoaded ? messages.length - 1 - index : index;
                      final message = messages[actualIndex];
                      final isMe = message['senderId'] == provider.currentUserId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MessageBubble(
                          content: message['text'],
                          isMe: isMe,
                          timestamp: DateTime.parse(message['createdAt']),
                          status: message['status'],
                          isFile: message['isFile'] ?? false,
                          fileUrl: message['fileUrl'],
                          fileName: message['fileName'],
                          fileType: message['fileType'],
                          localFilePath: message['localFilePath'],
                          isOptimistic: message['isOptimistic'] ?? false,
                          readBy: message['readBy'] ?? false,
                          messageId: message['_id'] ?? '',
                          receiverId: isMe ? message['receiverId'] : message['senderId'],
                          // Voice message properties
                          isAudio: message['isAudio'] ?? false,
                          audioUrl: message['audioUrl'],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Recording indicator
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border(
                      top: BorderSide(color: Colors.red[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recording... ${_formatDuration(_recordingDuration)}',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _stopRecording,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                ),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_selectedFile != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.attach_file, size: 20, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedFile!.path.split('/').last,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => setState(() {
                                    _selectedFile = null;
                                    _messageController.clear();
                                  }),
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText: _selectedFile != null
                                        ? 'Add a caption...'
                                        : 'Type a message...',
                                    hintStyle: TextStyle(color: Colors.grey[500]),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  maxLines: null,
                                  textCapitalization: TextCapitalization.sentences,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Voice message button
                            Container(
                              decoration: BoxDecoration(
                                color: _isRecording ? Colors.red[100] : Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: _isRecording
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: _isRecording ? _stopRecording : _startRecording,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // File attachment button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.attach_file,
                                  color: _selectedFile == null
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[500],
                                ),
                                onPressed: _selectedFile == null ? _pickFile : null,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Send button
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.send, color: Colors.white),
                                onPressed: _sendMessage,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    // Clean up voice recorder
    if (_recorder != null) {
      _recorder!.closeRecorder();
    }
    _deleteRecording();

    super.dispose();
  }
}