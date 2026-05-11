import 'package:flutter/material.dart';
import 'package:ixes.app/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

// ✅ Only need mainScreenKey — no individual screen imports needed
import 'package:ixes.app/screens/BottomNaviagation.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false)
          .loadNotifications();
    });
  }

  Future<void> _refresh() async {
    await Provider.of<NotificationProvider>(context, listen: false)
        .loadNotifications();
  }

  // ✅ MAIN NAVIGATION METHOD — pops screen then switches tab in MainScreen
  void _navigateFromNotification(Map<String, dynamic> notification) {
    final type = notification['type'] ?? '';
    print('🔔 Tapped notification → type: "$type"');
    print('🔔 relatedData: ${notification['relatedData']}');
    print('🔔 full notification: $notification');
    final provider =
    Provider.of<NotificationProvider>(context, listen: false);

    // Mark this notification type as read
    provider.markTypesAsRead([type]);

    final relatedData = notification['relatedData'] as Map<String, dynamic>?;

    // ✅ Tab indices in MainScreen PageView:
    // 0 → FeedScreen
    // 1 → NewaScreen
    // 2 → PersonalChatScreen
    // 3 → CommunitiesScreen
    // 4 → DashboardScreen

    const postTypes = [
      'post', 'like', 'comment', 'PostLike', 'PostComment',
      'PostShare', 'Post', 'Announcement'
    ];
    const chatTypes = [
      'chat', 'message', 'directMessage', 'ChatMessage', 'Conversation', 'GroupChat'
    ];
    const communityTypes = ['community', 'GroupRequest'];
    const dashTypes = [
      'campaign', 'Service', 'Invoice', 'StoreSubscription',
      'SubDomain', 'AddProduct', 'ServiceReq'
    ];

    // ✅ Close NotificationScreen first
    Navigator.pop(context);

    if (postTypes.contains(type)) {
      // Extract postId from relatedData
      final postId = relatedData?['postId']?.toString() ??
          relatedData?['referenceId']?.toString() ??
          notification['referenceId']?.toString() ??
          notification['postId']?.toString();

      // Switch to Home tab (0) with postId
      mainScreenKey.currentState?.navigateToTab(0, postId: postId);

    } else if (chatTypes.contains(type)) {
      // Extract sender info for direct chat navigation
      final senderId = relatedData?['senderId']?.toString() ??
          relatedData?['userId']?.toString() ??
          notification['senderId']?.toString();

      final senderName = relatedData?['senderName']?.toString() ??
          relatedData?['name']?.toString() ??
          notification['senderName']?.toString() ??
          'Chat';

      final senderProfile = relatedData?['senderProfile'] ??
          relatedData?['userProfile'] ??
          notification['senderProfile'];

      // Switch to Chats tab (2), opens ChatDetailScreen if senderId available
      mainScreenKey.currentState?.navigateToTab(
        2,
        chatUserId: senderId,
        chatTitle: senderName,
        chatUserProfile: senderProfile,
      );

    } else if (communityTypes.contains(type)) {
      // Switch to Communities tab (3)
      mainScreenKey.currentState?.navigateToTab(3);

    } else if (dashTypes.contains(type)) {
      // Switch to Dashboard tab (4)
      mainScreenKey.currentState?.navigateToTab(4);

    } else {
      // Unknown type — fallback to Home tab
      mainScreenKey.currentState?.navigateToTab(0);
    }
  }

  // ✅ Icon per notification type
  IconData _getNotificationIcon(String type) {
    const postTypes = [
      'post', 'like', 'comment', 'PostLike', 'PostComment', 'PostShare', 'Post', 'Announcement'
    ];
    const chatTypes = [
      'chat', 'message', 'directMessage', 'ChatMessage', 'Conversation', 'GroupChat'
    ];
    const communityTypes = ['community', 'GroupRequest'];
    const dashTypes = [
      'campaign', 'Service', 'Invoice', 'StoreSubscription',
      'SubDomain', 'AddProduct', 'ServiceReq'
    ];

    if (postTypes.contains(type)) return Icons.article;
    if (chatTypes.contains(type)) return Icons.chat_bubble;
    if (communityTypes.contains(type)) return Icons.group;
    if (dashTypes.contains(type)) return Icons.dashboard;
    return Icons.notifications;
  }

  // ✅ Color per notification type
  Color _getNotificationColor(String type, bool isUnread) {
    if (!isUnread) return Colors.grey.shade400;

    const postTypes = [
      'post', 'like', 'comment', 'PostLike', 'PostComment', 'PostShare', 'Post', 'Announcement'
    ];
    const chatTypes = [
      'chat', 'message', 'directMessage', 'ChatMessage', 'Conversation', 'GroupChat'
    ];
    const communityTypes = ['community', 'GroupRequest'];
    const dashTypes = [
      'campaign', 'Service', 'Invoice', 'StoreSubscription',
      'SubDomain', 'AddProduct', 'ServiceReq'
    ];

    if (postTypes.contains(type)) return const Color(0xFFFF9800);
    if (chatTypes.contains(type)) return const Color(0xFF9C27B0);
    if (communityTypes.contains(type)) return const Color(0xFFFF4081);
    if (dashTypes.contains(type)) return const Color(0xFF2196F3);
    return Colors.blue;
  }

  Future<void> _clearAllNotifications() async {
    final provider =
    Provider.of<NotificationProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to clear all notifications? This action cannot be undone.'),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? userId = prefs.getString('user_id');

        if (userId != null) {
          provider.clearAll(userId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All notifications cleared'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing notifications: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String formatDate(String rawDate) {
    try {
      final dateTime = DateTime.parse(rawDate).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('dd MMM yyyy • hh:mm a').format(dateTime);
    } catch (_) {
      return rawDate;
    }
  }

  List<Map<String, dynamic>> _getSortedNotifications(
      List<Map<String, dynamic>> notifications) {
    final sorted = List<Map<String, dynamic>>.from(notifications);
    sorted.sort((a, b) {
      try {
        return DateTime.parse(b['createdAt'] ?? '')
            .compareTo(DateTime.parse(a['createdAt'] ?? ''));
      } catch (_) {
        return 0;
      }
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (provider.notifications.isNotEmpty) {
                return TextButton.icon(
                  onPressed: _clearAllNotifications,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style:
                  TextButton.styleFrom(foregroundColor: Colors.red),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications found.',
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final sortedNotifications =
          _getSortedNotifications(provider.notifications);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sortedNotifications.length,
              itemBuilder: (context, index) {
                final item = sortedNotifications[index];
                final message = item['message'] ?? 'No message';
                final type = item['type'] ?? 'Notification';
                final createdAt = formatDate(item['createdAt'] ?? '');
                final isUnread = item['read'] == false;
                final iconData = _getNotificationIcon(type);
                final iconColor = _getNotificationColor(type, isUnread);

                return GestureDetector(
                  onTap: () => _navigateFromNotification(item), // ✅ tap to navigate
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color:
                      isUnread ? Colors.blue.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isUnread
                          ? Border.all(
                          color: Colors.blue.shade200, width: 1)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isUnread
                              ? iconColor.withOpacity(0.15)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData,
                            color: iconColor, size: 24), // ✅ type-based icon
                      ),
                      title: Text(
                        message,
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Flexible(
                              flex: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: iconColor
                                      .withOpacity(0.1), // ✅ type-colored badge
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: iconColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                createdAt,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: isUnread
                          ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: iconColor, // ✅ type-colored dot
                          shape: BoxShape.circle,
                        ),
                      )
                          : const Icon(Icons.chevron_right,
                          color: Colors.grey,
                          size: 18), // ✅ arrow hint for read
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}