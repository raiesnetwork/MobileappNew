

import 'package:flutter/material.dart';
import 'package:ixes.app/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
  }

  Future<void> _refresh() async {
    await Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
  }

  Future<void> _clearAllNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
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
        // Get userId from SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? userId = prefs.getString('user_id');

        if (userId != null) {
          provider.clearAll(userId);

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All notifications cleared'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to clear notifications: User not found'),
                backgroundColor: Colors.red,
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

      // Show relative time for recent notifications
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        // Show full date for older notifications
        return DateFormat('dd MMM yyyy • hh:mm a').format(dateTime);
      }
    } catch (_) {
      return rawDate;
    }
  }

  // ✅ Helper method to sort notifications by date (latest first)
  List<Map<String, dynamic>> _getSortedNotifications(List<Map<String, dynamic>> notifications) {
    final sorted = List<Map<String, dynamic>>.from(notifications);

    sorted.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['createdAt'] ?? '');
        final dateB = DateTime.parse(b['createdAt'] ?? '');

        // Sort in descending order (latest first)
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0; // Keep original order if date parsing fails
      }
    });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              // Only show clear all button if there are notifications
              if (provider.notifications.isNotEmpty) {
                return TextButton.icon(
                  onPressed: _clearAllNotifications,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
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
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications found.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          // ✅ Get sorted notifications (latest first)
          final sortedNotifications = _getSortedNotifications(provider.notifications);

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
                final isUnread = item['status'] == 'unread' || item['read'] == false;

                return Container(
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUnread ? Colors.blue.shade100 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications,
                        color: isUnread ? Colors.blue : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      message,
                      style: TextStyle(
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
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
                                color: Colors.grey.shade600,
                              ),
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
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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