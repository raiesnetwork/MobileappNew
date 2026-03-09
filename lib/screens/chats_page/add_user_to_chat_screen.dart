import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../providers/comment_provider.dart';
import './chat_detail_screen.dart'; // adjust path as needed

class AddChatUserScreen extends StatefulWidget {
  const AddChatUserScreen({Key? key}) : super(key: key);

  @override
  State<AddChatUserScreen> createState() => _AddChatUserScreenState();
}

class _AddChatUserScreenState extends State<AddChatUserScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _searchQuery = '';
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommentProvider>().fetchAllUsers(pageNo: 1);
    });

    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() => _searchQuery = query);
      _debounceSearch(query);
    }
  }

  DateTime? _lastSearch;
  void _debounceSearch(String query) {
    _lastSearch = DateTime.now();
    final captured = _lastSearch;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_lastSearch == captured && mounted) {
        context.read<CommentProvider>().fetchAllUsers(
          search: query.isEmpty ? null : query,
          pageNo: 1,
        );
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    final provider = context.read<CommentProvider>();
    if (provider.currentUserPage >= provider.totalUserPages) return;

    setState(() => _isLoadingMore = true);
    await provider.fetchAllUsers(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      pageNo: provider.currentUserPage + 1,
      isLoadMore: true,
    );
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _navigateToChat(Map<String, dynamic> user) {
    Navigator.pop(context, user);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildAppBar(),
            _buildSearchBar(),
            Expanded(child: _buildUserList()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + subtitle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'New Message',
                        style: TextStyle(
                          color: Color(0xFF1A1D2E),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Select a person to start chatting',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFEEF0F6)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EAF2), width: 1),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1A1D2E),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search by name, email or phone...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.grey[400],
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
              onPressed: () {
                _searchController.clear();
                context.read<CommentProvider>().fetchAllUsers(pageNo: 1);
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return Consumer<CommentProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingUsers && provider.allUsers.isEmpty) {
          return _buildLoadingState();
        }

        if (provider.allUsers.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: provider.allUsers.length + 1,
          itemBuilder: (context, index) {
            if (index == provider.allUsers.length) {
              return _isLoadingMore
                  ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Primary),
                    ),
                  ),
                ),
              )
                  : const SizedBox(height: 20);
            }

            final user = provider.allUsers[index];
            return _UserCard(
              user: user,
              index: index,
              onChatTap: () => _navigateToChat(user),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Primary),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Finding people...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F8),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.people_outline_rounded,
            size: 52,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _searchQuery.isNotEmpty ? 'No results found' : 'No users yet',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1D2E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _searchQuery.isNotEmpty
              ? 'Try a different name or email'
              : 'Users will appear here',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final int index;
  final VoidCallback onChatTap;

  const _UserCard({
    required this.user,
    required this.index,
    required this.onChatTap,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
      Duration(milliseconds: 300 + (widget.index * 30).clamp(0, 300)),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        widget.user['profile'] as Map<String, dynamic>? ?? {};
    final name = profile['name']?.toString() ?? 'Unknown';
    final email = widget.user['email']?.toString() ?? '';
    final mobile = widget.user['mobile']?.toString() ?? '';
    final profileImage = profile['profileImage']?.toString() ?? '';
    final role = widget.user['role']?.toString() ?? '';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onChatTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFEEF0F6),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    _buildAvatar(name, profileImage),
                    const SizedBox(width: 14),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1D2E),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (role.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    role,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.email_outlined,
                                    size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (mobile.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined,
                                    size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 5),
                                Text(
                                  mobile,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Chat button only
                    GestureDetector(
                      onTap: widget.onChatTap,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Primary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String profileImage) {
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      [const Color(0xFFEF4444), const Color(0xFFF97316)],
    ];
    final colorPair = colors[name.codeUnitAt(0) % colors.length];

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: profileImage.isEmpty
            ? LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        boxShadow: [
          BoxShadow(
            color: colorPair[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: profileImage.isNotEmpty
            ? (profileImage.startsWith('data:image/')
            ? Image.memory(
          base64Decode(profileImage.split(',')[1]),
          fit: BoxFit.cover,
        )
            : Image.network(
          profileImage,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarInitial(name),
        ))
            : _avatarInitial(name),
      ),
    );
  }

  Widget _avatarInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }
}