import 'package:flutter/material.dart';
import 'package:ixes.app/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';


import 'package:ixes.app/screens/service_request/service_request_deatils_page.dart';
import '../../api_service/user_api_service.dart';
import '../BottomNaviagation.dart';
import '../announcement_page/announcement_screen.dart';
import '../campaigns_page/campaigns_info screen.dart';
import '../chats_page/group_chat/group_chat_detail.dart';
import '../services_page/service_details.dart';

// ── Type buckets ──────────────────────────────────────────────────────────────

const _postTypes = [
  'post', 'like', 'comment', 'PostLike', 'PostComment', 'PostShare', 'Post',
];
const _announcementTypes = ['Announcement'];
const _chatTypes = [
  'chat', 'message', 'directMessage', 'ChatMessage', 'Conversation',
];
const _communityTypes = ['community', 'GroupRequest'];
const _serviceReqTypes = ['ServiceReq', 'assignedServiceReq'];
const _dashTypes = [
  'campaign', 'Service', 'Invoice', 'StoreSubscription', 'SubDomain', 'AddProduct',
];

// ── Pure helpers ──────────────────────────────────────────────────────────────

IconData _iconFor(String type) {
  if (_announcementTypes.contains(type)) return Icons.campaign_outlined;
  if (_postTypes.contains(type)) return Icons.article_outlined;
  if (_chatTypes.contains(type) || type == 'GroupChat') return Icons.chat_bubble_outline;
  if (_communityTypes.contains(type)) return Icons.group_outlined;
  if (_serviceReqTypes.contains(type)) return Icons.support_agent_outlined;
  if (_dashTypes.contains(type)) return Icons.dashboard_outlined;
  return Icons.notifications_outlined;
}

Color _colorFor(String type, bool unread) {
  if (!unread) return const Color(0xFFBDBDBD);
  if (_announcementTypes.contains(type)) return const Color(0xFF4CAF50);
  if (_postTypes.contains(type)) return const Color(0xFFFF9800);
  if (_chatTypes.contains(type) || type == 'GroupChat') return const Color(0xFF9C27B0);
  if (_communityTypes.contains(type)) return const Color(0xFFFF4081);
  if (_serviceReqTypes.contains(type)) return const Color(0xFF00BCD4);
  if (_dashTypes.contains(type)) return const Color(0xFF2196F3);
  return const Color(0xFF2196F3);
}

String _labelFor(String type) {
  const labels = {
    'Announcement': 'Announcement',
    'post': 'Post', 'Post': 'Post',
    'like': 'Like', 'PostLike': 'Like',
    'comment': 'Comment', 'PostComment': 'Comment',
    'PostShare': 'Share',
    'chat': 'Chat', 'message': 'Message', 'directMessage': 'Direct Message',
    'ChatMessage': 'Message', 'Conversation': 'Chat',
    'GroupChat': 'Group Chat',
    'community': 'Community', 'GroupRequest': 'Group Request',
    'ServiceReq': 'Service Request', 'assignedServiceReq': 'Assigned Request',
    'campaign': 'Campaign', 'Service': 'Service', 'Invoice': 'Invoice',
    'StoreSubscription': 'Subscription', 'SubDomain': 'Sub Domain',
    'AddProduct': 'Product',
  };
  return labels[type] ?? type;
}

String _formatDate(String raw) {
  try {
    final dt = DateTime.parse(raw).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
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

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _cachedItems = [];
  int _cachedLength = -1;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().loadNotifications();
      }
    });
  }

  Future<void> _refresh() async {
    if (mounted) await context.read<NotificationProvider>().loadNotifications();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _onNotificationTapped(Map<String, dynamic> n) async {
    if (_navigating || !mounted) {
      print('🚫 [NOTIF TAP] Ignored tap — _navigating=$_navigating mounted=$mounted');
      return;
    }
    _navigating = true;

    final type = (n['type'] ?? '') as String;
    final related = n['relatedData'] as Map<String, dynamic>?;

    print('────────────────────────────────────────────');
    print('👆 [NOTIF TAP] User tapped notification. type="$type" id=${n['_id']}');

    // Capture provider BEFORE any navigation — context gone after pop
    final provider = context.read<NotificationProvider>();

    try {
      // FIX: Do NOT pop before dispatch. Instead, dispatch first so we have
      // a valid context throughout (especially for the async post check).
      // Pop happens inside _dispatchBeforePop after setup is done.
      await _dispatchBeforePop(
        type: type,
        related: related,
        n: n,
        provider: provider,
      );
    } catch (e, st) {
      print('💥 [NOTIF NAV ERROR] type="$type" error=$e');
      print(st);
      debugPrint('Notification nav error: $e');
    } finally {
      _navigating = false;
      print('🏁 [NOTIF TAP] Dispatch finished for type="$type"');
      print('────────────────────────────────────────────');
    }
  }

  Future<void> _dispatchBeforePop({
    required String type,
    required Map<String, dynamic>? related,
    required Map<String, dynamic> n,
    required NotificationProvider provider,
  }) async {
    print('🔔 [NOTIF DISPATCH] raw type="$type"');
    print('🔔 [NOTIF DISPATCH] related=$related');
    print('🔔 [NOTIF DISPATCH] referenceId=${n['referenceId']}  notif._id=${n['_id']}  message="${n['message']}"');

    // Helper: pop this screen, then switch tab on MainScreen.
    void goTab(int tab, List<String> types, {String? postId}) {
      print('➡️ [NOTIF NAV] goTab(tab=$tab, types=$types, postId=$postId) for incoming type="$type"');
      if (mounted) {
        Navigator.of(context).pop();
      } else {
        print('⚠️ [NOTIF NAV] NotificationScreen not mounted — pop SKIPPED');
      }
      final state = mainScreenKey.currentState;
      if (state != null && state.mounted) {
        print('   ✅ mainScreenKey.currentState found & mounted — calling navigateToTab($tab)');
        state.navigateToTab(tab, postId: postId);
      } else {
        print('   ⚠️ mainScreenKey.currentState is NULL or UNMOUNTED — tab switch SKIPPED (this is likely why it sometimes does nothing!)');
      }
      provider.markTypesAsRead(types);
    }

    // Helper: pop this screen, then push a new route onto MainScreen's navigator.
    void goRoute(Widget screen, List<String> types) {
      print('➡️ [NOTIF NAV] goRoute(screen=${screen.runtimeType}, types=$types) for incoming type="$type"');
      if (mounted) {
        Navigator.of(context).pop();
      } else {
        print('⚠️ [NOTIF NAV] NotificationScreen not mounted — pop SKIPPED');
      }
      final ctx = mainScreenKey.currentContext;
      if (ctx != null) {
        print('   ✅ mainScreenKey.currentContext found — pushing ${screen.runtimeType}');
        Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => screen));
      } else {
        print('   ⚠️ mainScreenKey.currentContext is NULL — push SKIPPED, route never shown (this is likely why it sometimes does nothing!)');
      }
      provider.markTypesAsRead(types);
    }

    // ── ANNOUNCEMENT ───────────────────────────────────────────────────────
    if (_announcementTypes.contains(type)) {
      print('✅ [NOTIF MATCH] type="$type" matched _announcementTypes');
      final communityId = related?['communityId']?.toString() ??
          n['communityId']?.toString() ??
          n['referenceId']?.toString();
      print('   communityId resolved = $communityId');
      if (communityId != null && communityId.isNotEmpty) {
        goRoute(AnnouncementScreen(communityId: communityId), _announcementTypes);
      } else {
        print('   no communityId found -> falling back to goTab(0)');
        goTab(0, _announcementTypes);
      }
      return;
    }

    // ── POST ───────────────────────────────────────────────────────────────
    if (_postTypes.contains(type)) {
      print('✅ [NOTIF MATCH] type="$type" matched _postTypes');
      final postId = related?['postId']?.toString() ??
          related?['referenceId']?.toString() ??
          n['referenceId']?.toString() ??
          n['postId']?.toString();
      print('   postId resolved = $postId (length=${postId?.length})');

      if (postId != null && postId.length == 24) {
        // FIX: Do the async API check BEFORE popping/navigating so we know
        // exactly where to go. No more race between tab switch and dialog.
        print('   calling UserAPI().getPostById($postId) ...');
        final response = await UserAPI().getPostById(postId);
        print('   getPostById response = $response');
        final exists = response != null &&
            response['success'] == true &&
            response['data'] != null;
        print('   post exists = $exists');

        if (exists) {
          // Post exists — navigate to feed, passing the postId.
          goTab(0, _postTypes, postId: postId);
        } else {
          // Post is gone — switch to feed tab (no postId) then show dialog.
          print('   post NOT found -> goTab(0) then showing "Post Not Found" dialog');
          goTab(0, _postTypes);
          // Give the navigator a frame to settle before showing dialog.
          await Future.delayed(const Duration(milliseconds: 150));
          final ctx = mainScreenKey.currentContext;
          if (ctx != null) {
            showDialog(
              context: ctx,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Post Not Found'),
                content: const Text(
                    'This post no longer exists or may have been removed.'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'))
                ],
              ),
            );
          } else {
            print('   ⚠️ mainScreenKey.currentContext null — "Post Not Found" dialog SKIPPED');
          }
        }
      } else {
        print('   postId missing or not 24 chars -> goTab(0) without postId');
        goTab(0, _postTypes);
      }
      return;
    }

    // ── PERSONAL CHAT ──────────────────────────────────────────────────────
    if (_chatTypes.contains(type)) {
      print('✅ [NOTIF MATCH] type="$type" matched _chatTypes -> goTab(2)');
      goTab(2, _chatTypes);
      return;
    }

    // ── GROUP CHAT ─────────────────────────────────────────────────────────
    if (type == 'GroupChat') {
      print('✅ [NOTIF MATCH] type="$type" matched GroupChat');
      final groupId =
          related?['groupId']?.toString() ?? n['referenceId']?.toString();
      final msg = n['message']?.toString() ?? '';
      print('   groupId=$groupId  message="$msg"');
      String groupName = 'Group Chat';
      final q = RegExp(r'"([^"]+)"').firstMatch(msg);
      if (q != null) {
        groupName = q.group(1) ?? groupName;
      } else {
        final m =
        RegExp(r'\bin\s+(.+)$', caseSensitive: false).firstMatch(msg);
        if (m != null) groupName = m.group(1)?.trim() ?? groupName;
      }
      print('   resolved groupName="$groupName"');

      // Pop first so mainScreenKey navigator is free
      if (mounted) {
        Navigator.of(context).pop();
      } else {
        print('⚠️ [NOTIF NAV] NotificationScreen not mounted — pop SKIPPED');
      }

      final state = mainScreenKey.currentState;
      if (state != null && state.mounted) {
        print('   ✅ mainScreenKey.currentState found & mounted — switching to Chats tab');
        state.navigateToTab(2);
      } else {
        print('   ⚠️ mainScreenKey.currentState NULL/UNMOUNTED — tab switch to Chats SKIPPED');
      }

      if (groupId != null && groupId.isNotEmpty) {
        final ctx = mainScreenKey.currentContext;
        if (ctx != null) {
          print('   ✅ pushing GroupChatDetailPage(groupId=$groupId, groupName="$groupName")');
          Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => GroupChatDetailPage(
              groupId: groupId,
              groupName: groupName,
              isAdmin: false,
            ),
          ));
        } else {
          print('   ⚠️ mainScreenKey.currentContext NULL — GroupChatDetailPage push SKIPPED');
        }
      } else {
        print('   no groupId -> staying on Chats tab only');
      }
      provider.markTypesAsRead(['GroupChat']);
      return;
    }

    // ── SERVICE REQUEST ────────────────────────────────────────────────────
    if (_serviceReqTypes.contains(type)) {
      print('✅ [NOTIF MATCH] type="$type" matched _serviceReqTypes');
      final id = related?['assignedServiceReqId']?.toString() ??
          related?['serviceReqId']?.toString() ??
          n['referenceId']?.toString();
      print('   serviceReq id resolved = $id');
      if (id != null && id.isNotEmpty) {
        goRoute(ServiceRequestDetailsScreen(requestId: id), _serviceReqTypes);
      } else {
        print('   no id found -> falling back to goTab(4)');
        goTab(4, _serviceReqTypes);
      }
      return;
    }

    // ── SERVICE ────────────────────────────────────────────────────────────
    if (type == 'Service') {
      print('✅ [NOTIF MATCH] type="$type" matched Service');
      final id =
          related?['serviceId']?.toString() ?? n['referenceId']?.toString();
      print('   serviceId resolved = $id');
      if (id != null && id.isNotEmpty) {
        goRoute(ServiceDetailsScreen(serviceId: id), ['Service']);
      } else {
        print('   no id found -> falling back to goTab(4)');
        goTab(4, ['Service']);
      }
      return;
    }

    // ── CAMPAIGN ───────────────────────────────────────────────────────────
    if (type == 'campaign') {
      print('✅ [NOTIF MATCH] type="$type" matched campaign');
      final id =
          related?['campaignId']?.toString() ?? n['referenceId']?.toString();
      final communityName = related?['communityName']?.toString() ??
          n['communityName']?.toString() ??
          '';
      print('   campaignId=$id communityName="$communityName"');
      if (id != null && id.isNotEmpty) {
        goRoute(
            CampaignDetailsScreen(
                campaignId: id, communityName: communityName),
            ['campaign']);
      } else {
        print('   no campaignId found -> falling back to goTab(4)');
        goTab(4, ['campaign']);
      }
      return;
    }

    // ── COMMUNITY ──────────────────────────────────────────────────────────
    if (_communityTypes.contains(type)) {
      print('✅ [NOTIF MATCH] type="$type" matched _communityTypes -> goTab(3)');
      goTab(3, _communityTypes);
      return;
    }

    // ── DASHBOARD ──────────────────────────────────────────────────────────
    if (_dashTypes.contains(type)) {
      print('✅ [NOTIF MATCH] type="$type" matched _dashTypes -> goTab(4)');
      goTab(4, _dashTypes);
      return;
    }

    // ── DEFAULT ────────────────────────────────────────────────────────────
    print('⚠️ [NOTIF MATCH] type="$type" matched NOTHING ABOVE -> DEFAULT goTab(0, ["$type"])');
    goTab(0, [type]);
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to clear all notifications? This cannot be undone.'),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null || !mounted) return;
      context.read<NotificationProvider>().clearAll(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All notifications cleared'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to clear notifications'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, p, __) {
              if (p.notifications.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Could not load notifications',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: _refresh, child: const Text('Try again')),
                ],
              ),
            );
          }
          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('All caught up!',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Text('No notifications right now.',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          if (_cachedLength != provider.notifications.length) {
            _cachedItems = _sorted(provider.notifications);
            _cachedLength = provider.notifications.length;
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _cachedItems.length,
              itemBuilder: (_, i) => RepaintBoundary(
                child: _NotificationTile(
                  key: ValueKey(_cachedItems[i]['_id'] ?? i),
                  item: _cachedItems[i],
                  onTap: () => _onNotificationTapped(_cachedItems[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _NotificationTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type    = (item['type'] ?? '') as String;
    final message = (item['message'] ?? 'No message') as String;
    final unread  = item['read'] == false;
    final color   = _colorFor(type, unread);
    final icon    = _iconFor(type);
    final label   = _labelFor(type);
    final dateStr = _formatDate(item['createdAt'] ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: unread ? Colors.white : const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: unread ? color.withOpacity(0.35) : Colors.transparent,
                  width: 1.2),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: color.withOpacity(unread ? 0.12 : 0.07),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                              color: unread ? const Color(0xFF1A1A2E) : Colors.grey.shade600,
                              height: 1.4)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _TypeChip(label: label, color: color, unread: unread),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(dateStr,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 9, height: 9,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  )
                else
                  const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool unread;
  const _TypeChip({required this.label, required this.color, required this.unread});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(unread ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 11,
              color: unread ? color : Colors.grey.shade500,
              fontWeight: FontWeight.w500)),
    );
  }
}