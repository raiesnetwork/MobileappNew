import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/comment_provider.dart';


class SharePostScreen extends StatefulWidget {
  final String postId;
  final String shareContext; // "feed", "campaign", "service", "announcement"
  final String? contextId; // Required if shareContext is not "feed"

  const SharePostScreen({
    Key? key,
    required this.postId,
    this.shareContext = 'feed',
    this.contextId,
  }) : super(key: key);

  @override
  State<SharePostScreen> createState() => _SharePostScreenState();
}

class _SharePostScreenState extends State<SharePostScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    // Clear users list when leaving screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<CommentProvider>(context, listen: false).clearUsersList();
      }
    });
    super.dispose();
  }

  void _loadUsers({bool isLoadMore = false}) {
    final provider = Provider.of<CommentProvider>(context, listen: false);

    if (isLoadMore) {
      if (_currentPage < provider.totalUserPages) {
        _currentPage++;
        provider.fetchAllUsers(
          search: _searchQuery.isEmpty ? null : _searchQuery,
          pageNo: _currentPage,
          isLoadMore: true,
        );
      }
    } else {
      _currentPage = 1;
      provider.fetchAllUsers(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        pageNo: _currentPage,
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<CommentProvider>(context, listen: false);
      if (!provider.isLoadingUsers && _currentPage < provider.totalUserPages) {
        _loadUsers(isLoadMore: true);
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _isSearching = value.isNotEmpty;
    });

    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == value) {
        _loadUsers();
      }
    });
  }

  Future<void> _sharePost(String userId, String userName) async {
    final provider = Provider.of<CommentProvider>(context, listen: false);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await provider.sharePost(
      context: context,
      postId: widget.postId,
      type: 'user',
      userId: userId, shareContext: 'feed',

    );

    // Close loading dialog
    if (mounted) Navigator.pop(context);

    if (success && mounted) {
      // Close share screen
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post shared with $userName successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            Provider.of<CommentProvider>(context, listen: false).clearUsersList();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Share Post',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _isSearching
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Users List
          Expanded(
            child: Consumer<CommentProvider>(
              builder: (context, provider, child) {
                if (provider.isLoadingUsers && provider.allUsers.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.allUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSearching
                              ? 'No users found'
                              : 'No users available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.allUsers.length +
                      (provider.isLoadingUsers ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    // Loading indicator at the end
                    if (index == provider.allUsers.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final user = provider.allUsers[index];
                    final profile = user['profile'] as Map<String, dynamic>?;
                    final userName = profile?['name'] ?? 'Unknown User';
                    final profileImage = profile?['profileImage'] as String?;
                    final email = user['email'] ?? '';
                    final userId = user['_id'] ?? '';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: profileImage != null &&
                            profileImage.isNotEmpty
                            ? NetworkImage(profileImage)
                            : null,
                        child: profileImage == null || profileImage.isEmpty
                            ? Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                      title: Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: email.isNotEmpty
                          ? Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      )
                          : null,
                      trailing: ElevatedButton(
                        onPressed: () => _sharePost(userId, userName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6200EE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Send',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}