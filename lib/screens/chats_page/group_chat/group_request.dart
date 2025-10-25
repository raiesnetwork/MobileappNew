import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/group_provider.dart';

class GroupRequestScreen extends StatefulWidget {
  const GroupRequestScreen({Key? key}) : super(key: key);

  @override
  State<GroupRequestScreen> createState() => _GroupRequestScreenState();
}

class _GroupRequestScreenState extends State<GroupRequestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupChatProvider>().fetchPendingRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<GroupChatProvider>().fetchPendingRequests();
            },
          ),
        ],
      ),
      body: Consumer<GroupChatProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingRequests) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.requestsError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.requestsError!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchPendingRequests(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final requests = provider.pendingRequests;

          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No pending requests'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final userName = req['user']?['profile']?['name'] ?? 'Unknown User';
              final groupName = req['groupName'] ?? 'Unknown Group';

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(userName),
                subtitle: Text('Wants to join $groupName'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        // TODO: Implement approve (add service/provider methods later)
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        // TODO: Implement deny (add service/provider methods later)
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}