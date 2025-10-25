import 'package:flutter/material.dart';
import 'package:ixes.app/screens/chats_page/group_chat/send_file_message.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/group_provider.dart';

class GroupChatDetailPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isAdmin; // ✅ Add this

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

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final senderId = message['senderId'];
    String senderName = 'Unknown User';
    if (senderId is Map<String, dynamic>) {
      senderName = senderId['profile']?['name'] ?? 'Unknown User';
    } else if (senderId is String) {
      senderName = senderId;
    }

    String messageSenderId = '';
    if (senderId is Map<String, dynamic>) {
      messageSenderId = senderId['_id'] ?? '';
    } else if (senderId is String) {
      messageSenderId = senderId;
    }

    final messageText = message['text'] ?? '';
    final timestamp = message['createdAt'] ?? '';
    final readers = List<String>.from(message['readers'] ?? []);
    final isCurrentUser =
        _currentUserId != null && _currentUserId == messageSenderId;

    // Handle file messages
    final fileUrl = message['fileUrl'];
    final fileType = message['fileType'];
    final fileName = message['fileName'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCurrentUser) ...[
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (fileUrl != null && fileType != null) ...[
                _buildFileMessage(fileUrl, fileType, fileName),
                const SizedBox(height: 4),
              ],
              if (messageText.isNotEmpty) ...[
                Text(
                  messageText,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCurrentUser ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  if (isCurrentUser && readers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${readers.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileMessage(String fileUrl, String fileType, String? fileName) {
    final extension =
        fileName != null ? fileName.split('.').last.toLowerCase() : '';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(extension);

    return GestureDetector(
      onTap: () {
        // TODO: Implement file opening (e.g., open URL in browser or download)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening $fileName')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _getFileIcon(extension),
              color: Colors.white70,
              size: 30,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName ?? 'File',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fileType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70.withOpacity(0.7),
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

  IconData _getFileIcon(String extension) {
    switch (extension) {
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

  Widget _buildMessagesList() {
    return Consumer<GroupChatProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingMessages) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.messagesError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading messages',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.messagesError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.fetchGroupMessages(widget.groupId),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final messages = provider.currentGroupMessages;

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to send a message!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(messages[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    final provider = context.read<GroupChatProvider>();
    final currentGroup = provider.getGroupById(widget.groupId);

    // Prepare communityInfo
    final communityInfo = currentGroup != null
        ? {
            "_id": currentGroup['_id'] ?? widget.groupId,
            "name": currentGroup['name'] ?? widget.groupName,
          }
        : {
            "_id": widget.groupId,
            "name": widget.groupName,
          };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 6,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // File attachment button
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupFileMessageScreen(
                      groupId: widget.groupId,
                      groupName: widget.groupName,
                      communityInfo: communityInfo,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_file,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<GroupChatProvider>();
    final currentGroup = provider.getGroupById(widget.groupId);
    if (currentGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group information not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final communityInfo = {
      "_id": currentGroup['_id'] ?? widget.groupId,
      "name": currentGroup['name'] ?? widget.groupName,
    };

    final messageText = text;
    _messageController.clear();

    try {
      final success = await provider.sendGroupMessage(
        groupId: widget.groupId,
        text: messageText,
        communityInfo: communityInfo,
      );

      if (success) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      } else {
        _messageController.text = messageText;
        if (provider.sendMessageError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.sendMessageError!),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _sendMessage();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      _messageController.text = messageText;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Consumer<GroupChatProvider>(
              builder: (context, provider, child) {
                final group = provider.getGroupById(widget.groupId);
                if (group != null) {
                  final memberCount = group['memberCount'] ?? 0;
                  return Text(
                    '$memberCount members',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'add_member':
                  if (widget.isAdmin) {
                    _showAddMembersDialog();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Only admins can add members'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  break;
                case 'group_info':
                  _showGroupInfo();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (widget.isAdmin) // ✅ show only if admin
                const PopupMenuItem(
                  value: 'add_member',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 12),
                      Text('Add Member'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'group_info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Text('Group Info'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  void _showAddMembersDialog() {
    final provider = context.read<GroupChatProvider>();

    // Trigger user fetch when dialog is opened
    provider.fetchAllUsers();

    showDialog(
      context: context,
      builder: (context) {
        String? selectedUserId; // For single selection

        return Consumer<GroupChatProvider>(
          builder: (context, provider, child) {
            return AlertDialog(
              title: const Text('Select Member'),
              content: SizedBox(
                width: double.maxFinite,
                height: 200, // Smaller height for dropdown
                child: provider.isFetchingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : provider.allUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                const Text(
                                  'No users available',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  provider.addMemberMessage.isNotEmpty
                                      ? provider.addMemberMessage
                                      : 'Unable to fetch users.',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => provider.fetchAllUsers(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : StatefulBuilder(
                            builder: (context, setState) {
                              return DropdownButton<String>(
                                isExpanded: true,
                                hint: const Text('Select a user'),
                                value: selectedUserId,
                                items: provider.allUsers.map((user) {
                                  final userId = user['_id'] as String?;
                                  final userName =
                                      user['profile']?['name'] as String? ??
                                          user['mobile'] as String? ??
                                          'Unknown';
                                  return DropdownMenuItem<String>(
                                    value: userId,
                                    child: Text(userName),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedUserId = value;
                                  });
                                },
                              );
                            },
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      provider.isFetchingUsers || provider.allUsers.isEmpty
                          ? null
                          : () async {
                              if (selectedUserId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select a user'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final result = await provider.addMembersToGroup(
                                groupId: widget.groupId,
                                memberIds: [selectedUserId!], // Single user
                              );
                            },
                  child: provider.isAddingMembers
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
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
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: group['profileImage'] != null
                            ? ClipOval(
                                child: Image.network(
                                  group['profileImage'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.group, size: 50),
                                ),
                              )
                            : const Icon(Icons.group, size: 50),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        group['name'] ?? 'Unknown Group',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (group['description'] != null &&
                        group['description'].isNotEmpty) ...[
                      Center(
                        child: Text(
                          group['description'],
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow('Members',
                              '${group['memberCount'] ?? 0}', Icons.people),
                          const Divider(),
                          _buildInfoRow(
                              'Created',
                              _formatTimestamp(group['createdAt'] ?? ''),
                              Icons.calendar_today),
                          if (group['isAdmin'] == true) ...[
                            const Divider(),
                            _buildInfoRow(
                                'Role', 'Admin', Icons.admin_panel_settings),
                          ] else if (group['isMember'] == true) ...[
                            const Divider(),
                            _buildInfoRow('Role', 'Member', Icons.person),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (group['isMember'] == true) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement leave group
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Leave Group'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ] else if (group['isRequested'] == true) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.hourglass_empty),
                          label: const Text('Request Pending'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement join group
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Join Group'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
