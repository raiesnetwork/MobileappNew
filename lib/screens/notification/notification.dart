// screens/notification_screen.dart

import 'package:flutter/material.dart';
import 'package:ixes.app/providers/notification_provider.dart';
import 'package:provider/provider.dart';
// import '../providers/notification_provider.dart';
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

  String formatDate(String rawDate) {
    try {
      final dateTime = DateTime.parse(rawDate).toLocal();
      return DateFormat('dd MMM yyyy • hh:mm a').format(dateTime);
    } catch (_) {
      return rawDate;
    }
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
            return const Center(child: Text('No notifications found.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final item = provider.notifications[index];
                final message = item['message'] ?? 'No message';
                final type = item['type'] ?? 'Notification';
                final createdAt = formatDate(item['createdAt'] ?? '');
                final isUnread = item['status'] == 'unread';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                    leading: const Icon(Icons.notifications, color: Colors.blueAccent),
                    title: Text(
                      message,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '$type • $createdAt',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: isUnread
                        ? const Icon(Icons.circle, color: Colors.red, size: 10)
                        : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
