import 'package:flutter/material.dart';
import 'package:ixes.app/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:ixes.app/screens/BottomNaviagation.dart';
import 'package:ixes.app/screens/service_request/service_request_deatils_page.dart';
import '../../api_service/user_api_service.dart';
import '../campaigns_page/campaigns_info screen.dart';
import '../chats_page/group_chat/group_chat_detail.dart';
import '../services_page/service_details.dart';

// ── Notification type buckets (single source of truth) ──────────────────────
const _postTypes = [
  'post', 'like', 'comment', 'PostLike', 'PostComment',
  'PostShare', 'Post', 'Announcement',
];
const _chatTypes = [
  'chat', 'message', 'directMessage', 'ChatMessage', 'Conversation',
];
const _communityTypes = ['community', 'GroupRequest'];
const _serviceReqTypes = ['ServiceReq', 'assignedServiceReq'];
const _dashTypes = [
  'campaign', 'Service', 'Invoice', 'StoreSubscription',
  'SubDomain', 'AddProduct',
];

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

  Future<void> _refresh() =>
      Provider.of<NotificationProvider>(context, listen: false)
          .loadNotifications();

  // ── Navigation helpers ───────────────────────────────────────────────────

  /// Pop this screen then switch to [tab] in MainScreen.
  void _goToTab(int tab, {String? postId}) {
    Navigator.pop(context);
    void go() {
      final state = mainScreenKey.currentState;
      if (state == null || !state.mounted) {
        Future.delayed(const Duration(milliseconds: 200), go);
        return;
      }
      state.navigateToTab(tab, postId: postId);
    }
    go();
  }

  /// Pop this screen then push [screen] on top — back button returns to
  /// whichever tab was active (does NOT change _currentIndex).
  void _popAndPush(Widget screen) {
    Navigator.pop(context);
    void push() {
      final ctx = mainScreenKey.currentContext;
      if (ctx == null) {
        Future.delayed(const Duration(milliseconds: 200), push);
        return;
      }
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
    }
    push();
  }

  // ── Main navigation dispatcher ───────────────────────────────────────────

  Future<void> _onNotificationTapped(Map<String, dynamic> n) async {
    final type = (n['type'] ?? '') as String;
    final related = n['relatedData'] as Map<String, dynamic>?;

    // Mark this type as read immediately
    Provider.of<NotificationProvider>(context, listen: false)
        .markTypesAsRead([type]);

    // ── POST ──────────────────────────────────────────────────────────────
    if (_postTypes.contains(type)) {
      final postId = related?['postId']?.toString() ??
          related?['referenceId']?.toString() ??
          n['referenceId']?.toString() ??
          n['postId']?.toString();

      if (postId == null || postId.isEmpty || postId.length != 24) {
        _goToTab(0);
        return;
      }

      // Check post still exists before navigating
      final response = await UserAPI().getPostById(postId);
      if (!mounted) return;

      final exists = response != null &&
          response['success'] == true &&
          response['data'] != null;

      _goToTab(0, postId: exists ? postId : null);

      if (!exists) {
        Future.delayed(const Duration(milliseconds: 500), () {
          final ctx = mainScreenKey.currentContext;
          if (ctx == null) return;
          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Post Not Found'),
              content: const Text(
                  'This post no longer exists or may have been removed.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        });
      }
      return;
    }

    // ── PERSONAL CHAT ─────────────────────────────────────────────────────
    if (_chatTypes.contains(type)) {
      _goToTab(2);
      return;
    }

    // ── GROUP CHAT ────────────────────────────────────────────────────────
    if (type == 'GroupChat') {
      final groupId = related?['groupId']?.toString() ??
          n['referenceId']?.toString();

      // Try to extract group name from the message string
      final msg = n['message']?.toString() ?? '';
      String groupName = 'Group Chat';
      final q = RegExp(r'"([^"]+)"').firstMatch(msg);
      if (q != null) {
        groupName = q.group(1) ?? groupName;
      } else {
        final m = RegExp(r'\bin\s+(.+)$', caseSensitive: false).firstMatch(msg);
        if (m != null) groupName = m.group(1)?.trim() ?? groupName;
      }

      Navigator.pop(context);
      void go() {
        final state = mainScreenKey.currentState;
        if (state == null || !state.mounted) {
          Future.delayed(const Duration(milliseconds: 200), go);
          return;
        }
        state.navigateToTab(2);
        if (groupId != null && groupId.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            final ctx = mainScreenKey.currentContext;
            if (ctx == null) return;
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => GroupChatDetailPage(
                  groupId: groupId,
                  groupName: groupName,
                  isAdmin: false,
                ),
              ),
            );
          });
        }
      }
      go();
      return;
    }

    // ── SERVICE REQUEST ───────────────────────────────────────────────────
    if (_serviceReqTypes.contains(type)) {
      final id = related?['assignedServiceReqId']?.toString() ??
          related?['serviceReqId']?.toString() ??
          n['referenceId']?.toString();
      if (id != null && id.isNotEmpty) {
        _popAndPush(ServiceRequestDetailsScreen(requestId: id));
      } else {
        _goToTab(4);
      }
      return;
    }

    // ── SERVICE ───────────────────────────────────────────────────────────
    if (type == 'Service') {
      final id = related?['serviceId']?.toString() ??
          n['referenceId']?.toString();
      if (id != null && id.isNotEmpty) {
        _popAndPush(ServiceDetailsScreen(serviceId: id));
      } else {
        _goToTab(4);
      }
      return;
    }

    // ── CAMPAIGN ──────────────────────────────────────────────────────────
    if (type == 'campaign') {
      final id = related?['campaignId']?.toString() ??
          n['referenceId']?.toString();
      final communityName = related?['communityName']?.toString() ??
          n['communityName']?.toString() ??
          '';
      if (id != null && id.isNotEmpty) {
        _popAndPush(CampaignDetailsScreen(
          campaignId: id,
          communityName: communityName,
        ));
      } else {
        _goToTab(4);
      }
      return;
    }

    // ── COMMUNITY ─────────────────────────────────────────────────────────
    if (_communityTypes.contains(type)) {
      _goToTab(3);
      return;
    }

    // ── DASHBOARD types ───────────────────────────────────────────────────
    if (_dashTypes.contains(type)) {
      _goToTab(4);
      return;
    }

    // ── DEFAULT ───────────────────────────────────────────────────────────
    _goToTab(0);
  }

  // ── Icon / colour helpers ────────────────────────────────────────────────

  IconData _iconFor(String type) {
    if (_postTypes.contains(type)) return Icons.article;
    if (_chatTypes.contains(type) || type == 'GroupChat') return Icons.chat_bubble;
    if (_communityTypes.contains(type)) return Icons.group;
    if (_serviceReqTypes.contains(type)) return Icons.support_agent_outlined;
    if (_dashTypes.contains(type)) return Icons.dashboard;
    return Icons.notifications;
  }

  Color _colorFor(String type, bool unread) {
    if (!unread) return Colors.grey.shade400;
    if (_postTypes.contains(type)) return const Color(0xFFFF9800);
    if (_chatTypes.contains(type) || type == 'GroupChat')
      return const Color(0xFF9C27B0);
    if (_communityTypes.contains(type)) return const Color(0xFFFF4081);
    if (_serviceReqTypes.contains(type)) return const Color(0xFF00BCD4);
    if (_dashTypes.contains(type)) return const Color(0xFF2196F3);
    return Colors.blue;
  }

  // ── Clear all ────────────────────────────────────────────────────────────

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to clear all notifications? This cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      if (!mounted) return;
      Provider.of<NotificationProvider>(context, listen: false)
          .clearAll(userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications cleared'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Date formatter ───────────────────────────────────────────────────────

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('dd MMM yyyy • hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    final copy = List<Map<String, dynamic>>.from(list);
    copy.sort((a, b) {
      try {
        return DateTime.parse(b['createdAt'] ?? '')
            .compareTo(DateTime.parse(a['createdAt'] ?? ''));
      } catch (_) {
        return 0;
      }
    });
    return copy;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, p, __) => p.notifications.isEmpty
                ? const SizedBox.shrink()
                : TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (_, provider, __) {
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
                    style:
                    TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final items = _sorted(provider.notifications);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final type = (item['type'] ?? '') as String;
                final message = (item['message'] ?? 'No message') as String;
                final unread = item['read'] == false;
                final color = _colorFor(type, unread);

                return GestureDetector(
                  onTap: () => _onNotificationTapped(item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: unread ? Colors.blue.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: unread
                          ? Border.all(color: Colors.blue.shade200)
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
                          color: unread
                              ? color.withOpacity(0.15)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_iconFor(type), color: color, size: 24),
                      ),
                      title: Text(
                        message,
                        style: TextStyle(
                          fontWeight:
                          unread ? FontWeight.w600 : FontWeight.w500,
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
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatDate(item['createdAt'] ?? ''),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: unread
                          ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
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