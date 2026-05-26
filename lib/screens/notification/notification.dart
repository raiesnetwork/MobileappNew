import 'package:flutter/material.dart';
import 'package:ixes.app/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:ixes.app/screens/BottomNaviagation.dart';
import 'package:ixes.app/screens/service_request/service_request_deatils_page.dart';

import '../campaigns_page/campaigns_info screen.dart';
import '../campaigns_page/getall_campaigns_screen.dart';
import '../chats_page/chat_detail_screen.dart';
import '../chats_page/group_chat/group_chat_detail.dart';
import '../chats_page/group_chat/my_groups.dart';
import '../services_page/service_details.dart';
import '../services_page/services_screen.dart';

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

  void _navigateFromNotification(Map<String, dynamic> notification) {
    final type = notification['type'] ?? '';
    print('🔔 Tapped notification → type: "$type"');
    print('🔔 ALL relatedData: ${notification['relatedData']}');
    print('🔔 ALL relatedData keys: ${(notification['relatedData'] as Map<String, dynamic>?)?.keys.toList()}');
    print('🔔 full notification keys: ${notification.keys.toList()}');
    print('🔔 full notification: $notification');

    final provider = Provider.of<NotificationProvider>(context, listen: false);
    provider.markTypesAsRead([type]);

    final relatedData = notification['relatedData'] as Map<String, dynamic>?;

    const postTypes = [
      'post', 'like', 'comment', 'PostLike', 'PostComment',
      'PostShare', 'Post', 'Announcement'
    ];
    const chatTypes = [
      'chat', 'message', 'directMessage', 'ChatMessage', 'Conversation',
    ];
    const communityTypes = ['community', 'GroupRequest'];
    const serviceReqTypes = ['ServiceReq', 'assignedServiceReq'];

    // ✅ Single null guard for entire method
    final navContext = mainScreenKey.currentContext;
    if (navContext == null) return;

    Navigator.pop(context);

    // ── POST TYPES ─────────────────────────────────────────────────────
    if (postTypes.contains(type)) {
      final postId = relatedData?['postId']?.toString() ??
          relatedData?['referenceId']?.toString() ??
          notification['referenceId']?.toString() ??
          notification['postId']?.toString();

      if (postId == null || postId.isEmpty) {
        mainScreenKey.currentState?.navigateToTab(0);
        return;
      }
      mainScreenKey.currentState?.navigateToTab(0, postId: postId);

      // ── PERSONAL CHAT ───────────────────────────────────────────────────────
    } else if (chatTypes.contains(type)) {
      final senderId = relatedData?['senderId']?.toString() ??
          relatedData?['privatChatId']?.toString() ??
          notification['referenceId']?.toString();

      // ✅ Backend only sends chatId, no name — extract from message text
      // message format: "Uday Suresh Send new message"
      final messageText = notification['message']?.toString() ?? '';
      final senderName = messageText.isNotEmpty
          ? messageText
          .replaceAll(RegExp(r'\s*(send|sent|says|shared|posted).*', caseSensitive: false), '')
          .trim()
          : 'Chat';

      print('🔔 Chat → senderId: $senderId, senderName extracted: $senderName');

      final senderProfile = <String, dynamic>{
        '_id': senderId ?? '',
        'profile': {
          'profileImage': '',
          'name': senderName,
        }
      };

      if (senderId != null && senderId.isNotEmpty) {
        mainScreenKey.currentState?.navigateToTab(2);
        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.push(
            navContext,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                userId: senderId,
                chatTitle: senderName,
                userProfile: senderProfile,
              ),
            ),
          );
        });
      } else {
        mainScreenKey.currentState?.navigateToTab(2);
      }

      // ── GROUP CHAT ──────────────────────────────────────────────────────────
    } else if (type == 'GroupChat') {
      final groupId = relatedData?['groupId']?.toString() ??
          notification['referenceId']?.toString();

      // ✅ Backend only sends groupId, no name — extract from message
      // message format: `Christin Raj A shared a new post in "St. Antony Volley Ball Coaching"`
      final messageText = notification['message']?.toString() ?? '';
      String groupName = 'Group Chat';

      // Try extract name inside quotes first
      final quoteMatch = RegExp(r'"([^"]+)"').firstMatch(messageText);
      if (quoteMatch != null) {
        groupName = quoteMatch.group(1) ?? 'Group Chat';
      }

      print('🔔 GroupChat → groupId: $groupId, groupName extracted: $groupName');

      if (groupId != null && groupId.isNotEmpty) {
        Navigator.push(
          navContext,
          MaterialPageRoute(builder: (_) => const MyGroupsScreen()),
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.push(
            navContext,
            MaterialPageRoute(
              builder: (_) => GroupChatDetailPage(
                groupId: groupId,
                groupName: groupName,
                isAdmin: false,
              ),
            ),
          );
        });
      } else {
        Navigator.push(
          navContext,
          MaterialPageRoute(builder: (_) => const MyGroupsScreen()),
        );
      }

      // ── SERVICE REQUEST ─────────────────────────────────────────────────
    } else if (serviceReqTypes.contains(type)) {
      final serviceReqId = relatedData?['assignedServiceReqId']?.toString() ??
          relatedData?['serviceReqId']?.toString() ??
          notification['referenceId']?.toString();

      print('🔔 ServiceReq → serviceReqId: $serviceReqId');

      if (serviceReqId != null && serviceReqId.isNotEmpty) {
        Navigator.push(
          navContext,
          MaterialPageRoute(
            builder: (_) => ServiceRequestDetailsScreen(
              requestId: serviceReqId,
            ),
          ),
        );
      } else {
        mainScreenKey.currentState?.navigateToTab(4);
      }

      // ── SERVICE ─────────────────────────────────────────────────────────
    } else if (type == 'Service') {
      final serviceId = relatedData?['serviceId']?.toString() ??
          notification['referenceId']?.toString();

      print('🔔 Service → serviceId: $serviceId');

      // ✅ Push ServicesScreen first so back arrow goes there
      Navigator.push(
        navContext,
        MaterialPageRoute(builder: (_) => const ServicesScreen()),
      );

      if (serviceId != null && serviceId.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.push(
            navContext,
            MaterialPageRoute(
              builder: (_) => ServiceDetailsScreen(serviceId: serviceId),
            ),
          );
        });
      }

      // ── CAMPAIGN ────────────────────────────────────────────────────────
    } else if (type == 'campaign') {
      final campaignId = relatedData?['campaignId']?.toString() ??
          notification['referenceId']?.toString();

      final communityId = relatedData?['communityId']?.toString() ??
          notification['communityId']?.toString() ??
          '';

      final communityName = relatedData?['communityName']?.toString() ??
          notification['communityName']?.toString() ??
          '';

      print('🔔 Campaign → campaignId: $campaignId, communityId: $communityId');

      // ✅ Push CampaignsScreen first so back arrow goes there
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (_) => CampaignsScreen(
            communityId: communityId,
            buildImageWidget: (url, {bool isProfileImage = false}) =>
            url != null && url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover)
                : const SizedBox.shrink(),
          ),
        ),
      );

      if (campaignId != null && campaignId.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.push(
            navContext,
            MaterialPageRoute(
              builder: (_) => CampaignDetailsScreen(
                campaignId: campaignId,
                buildImageWidget: (url, {bool isProfileImage = false}) =>
                url != null && url.isNotEmpty
                    ? Image.network(url, fit: BoxFit.cover)
                    : const SizedBox.shrink(),
                communityName: communityName,
              ),
            ),
          );
        });
      }

      // ── COMMUNITY ───────────────────────────────────────────────────────
    } else if (communityTypes.contains(type)) {
      mainScreenKey.currentState?.navigateToTab(3);

      // ── DASHBOARD TYPES ─────────────────────────────────────────────────
    } else if (type == 'Invoice' ||
        type == 'StoreSubscription' ||
        type == 'SubDomain' ||
        type == 'AddProduct') {
      mainScreenKey.currentState?.navigateToTab(4);

      // ── DEFAULT ─────────────────────────────────────────────────────────
    } else {
      mainScreenKey.currentState?.navigateToTab(0);
    }
  }

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
      'SubDomain', 'AddProduct',
    ];
    const serviceReqTypes = ['ServiceReq', 'assignedServiceReq'];

    if (postTypes.contains(type)) return Icons.article;
    if (chatTypes.contains(type)) return Icons.chat_bubble;
    if (communityTypes.contains(type)) return Icons.group;
    if (serviceReqTypes.contains(type)) return Icons.support_agent_outlined;
    if (dashTypes.contains(type)) return Icons.dashboard;
    return Icons.notifications;
  }

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
      'SubDomain', 'AddProduct',
    ];
    const serviceReqTypes = ['ServiceReq', 'assignedServiceReq'];

    if (postTypes.contains(type)) return const Color(0xFFFF9800);
    if (chatTypes.contains(type)) return const Color(0xFF9C27B0);
    if (communityTypes.contains(type)) return const Color(0xFFFF4081);
    if (serviceReqTypes.contains(type)) return const Color(0xFF00BCD4);
    if (dashTypes.contains(type)) return const Color(0xFF2196F3);
    return Colors.blue;
  }

  Future<void> _clearAllNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to clear all notifications? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
                  onTap: () => _navigateFromNotification(item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isUnread ? Colors.blue.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isUnread
                          ? Border.all(color: Colors.blue.shade200, width: 1)
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
                        child: Icon(iconData, color: iconColor, size: 24),
                      ),
                      title: Text(
                        message,
                        style: TextStyle(
                          fontWeight:
                          isUnread ? FontWeight.w600 : FontWeight.w500,
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
                                  color: iconColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
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
                          color: iconColor,
                          shape: BoxShape.circle,
                        ),
                      )
                          : const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 18),
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