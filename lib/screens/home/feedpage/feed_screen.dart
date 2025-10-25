import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ixes.app/constants/constants.dart';

import 'package:ixes.app/screens/home/componats/base64image.dart';

import 'package:ixes.app/screens/home/componats/videopayer.dart';

import 'package:intl/intl.dart';
import 'package:ixes.app/api_service/user_api_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/post_model.dart';
import '../../../providers/comment_provider.dart';

import '../../../services/comment_service.dart';
import '../CreatePost/create_post_screen.dart';

class FeedScreen extends StatefulWidget {
  final String? postId;
  final String? communityId; // ✅ Add communityId parameter

  const FeedScreen(
      {this.postId,
      this.communityId, // ✅ Accept communityId
      super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, TextEditingController> _commentControllers = {};

  TextEditingController _getCommentController(String postId) {
    return _commentControllers.putIfAbsent(
        postId, () => TextEditingController());
  }

  // Currently displayed posts
  List<Post> posts = [];
  String postId = "685f8b3769362c216829ec53";
  List<Post> _originalPosts = []; // Store original posts for search
  bool _isSearching = false; // Track search state
  String _currentSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;
  bool isLoadingMore = false;
  Set<String> processingLikes = {};
  Set<String> processingComments = {};
  Set<String> processingShares = {};

  // Pagination settings
  static const int _postsPerPage = 10;
  int _currentPage = 0;
  int _currentPageNumber = 1;
  bool _hasMorePosts = true;
  List<Post> _allPostsCache = [];

  bool get isCommunityFeed => widget.communityId != null;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final commentProvider = context.read<CommentProvider>();

      if (isCommunityFeed) {
        commentProvider.fetchCommunityPosts(
            communityId: widget.communityId!, offset: 0, limit: 10);
      } else {
        commentProvider.fetchAllPosts(offset: 0, limit: 10);
      }
    });
    // _refreshFeed(); // ❌ Remove this line

    _loadInitialData(); // ✅ Keep only this
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });
  }

  // ✅ Modified to support community posts
  Future<List<Post>> fetchAllPosts({int offset = 0, int limit = 10}) async {
    if (isCommunityFeed) {
      // Fetch community posts using the provider
      final provider = context.read<CommentProvider>();
      final response = await provider.fetchCommunityPosts(
        communityId: widget.communityId!,
        offset: offset,
        limit: limit,
      );

      if (response != null && response['posts'] != null) {
        final List<dynamic> data = response['posts'];
        return data.map((e) => Post.fromJson(e)).toList();
      }
      return [];
    } else {
      // Original all posts logic
      final response = await UserAPI().getAllPosts(offset, limit);

      if (response != null &&
          response['posts'] != null &&
          response['posts']['transformedPosts'] != null) {
        final List<dynamic> data = response['posts']['transformedPosts'];
        final freshPosts = data.map((e) => Post.fromJson(e)).toList();
        return freshPosts;
      } else {
        return [];
      }
    }
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _currentPage = 0;
      posts.clear();
      _originalPosts.clear();
      _allPostsCache.clear();
      _hasMorePosts = true;
      _isSearching = false;
      _currentSearchQuery = '';
    });

    final provider = context.read<CommentProvider>();
    final result = await provider.fetchAllPosts(
      offset: 0,
      limit: _postsPerPage,
      isRefresh: true, // ✅ This will replace the provider's post list
    );

    setState(() {
      posts = List.from(provider.posts);
      _originalPosts = List.from(provider.posts);
      _allPostsCache = List.from(provider.posts);
      _currentPage = 1;
      _hasMorePosts = provider.posts.length == _postsPerPage;
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
      _currentPage = 0;
      posts.clear();
      _originalPosts.clear();
      _allPostsCache.clear();
      _hasMorePosts = true;
      _isSearching = false;
      _currentSearchQuery = '';
    });

    final provider = context.read<CommentProvider>();
    Map<String, dynamic>? result;

    if (isCommunityFeed) {
      result = await provider.fetchCommunityPosts(
        communityId: widget.communityId!,
        offset: 0,
        limit: _postsPerPage,
      );
    } else {
      result = await provider.fetchAllPosts(
        offset: 0,
        limit: _postsPerPage,
        isRefresh: true,
      );
    }

    setState(() {
      // Use communityPosts for community feed, otherwise use posts
      posts = List.from(isCommunityFeed ? provider.communityPosts : provider.posts);
      _originalPosts = List.from(isCommunityFeed ? provider.communityPosts : provider.posts);
      _allPostsCache = List.from(isCommunityFeed ? provider.communityPosts : provider.posts);
      _currentPage = 1;
      _hasMorePosts = (isCommunityFeed ? provider.communityPosts : provider.posts).length == _postsPerPage;
      isLoading = false;
    });
  }

  void _loadMorePosts() async {
    if (isLoadingMore || !_hasMorePosts || _isSearching) return;

    setState(() {
      isLoadingMore = true;
    });

    final provider = context.read<CommentProvider>();
    Map<String, dynamic>? result;

    if (isCommunityFeed) {
      result = await provider.fetchCommunityPosts(
        communityId: widget.communityId!,
        offset: _currentPage * _postsPerPage,
        limit: _postsPerPage,
      );
    } else {
      result = await provider.fetchAllPosts(
        offset: _currentPage * _postsPerPage,
        limit: _postsPerPage,
        isRefresh: false,
      );
    }

    setState(() {
      // Use communityPosts for community feed, otherwise use posts
      posts = List.from(isCommunityFeed ? provider.communityPosts : provider.posts);
      _originalPosts = List.from(isCommunityFeed ? provider.communityPosts : provider.posts);
      _allPostsCache = List.from(isCommunityFeed ? provider.communityPosts : provider.posts);
      _currentPage++;
      isLoadingMore = false;
      _hasMorePosts = (isCommunityFeed ? provider.communityPosts : provider.posts).length == (_currentPage * _postsPerPage);
    });
  }



  void _performSearch(String query) {
    setState(() {
      _currentSearchQuery = query;

      if (query.isEmpty) {
        // If search is empty, show original posts
        _isSearching = false;
        posts = List.from(_originalPosts);
      } else {
        // Filter posts based on search query
        _isSearching = true;
        posts = _originalPosts.where((post) {
          return post.username.toLowerCase().contains(query.toLowerCase()) ||
              post.postContent.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Widget _buildProfileImage(String profileImageString, String username,
      {double radius = 22}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + 8),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blue.shade50,
        child: ClipOval(
          child: profileImageString.isNotEmpty
              ? (profileImageString.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: profileImageString,
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: radius * 2,
                        height: radius * 2,
                        color: Colors.grey[200],
                        child: Icon(Icons.person, color: Colors.grey[400]),
                      ),
                      errorWidget: (context, url, error) => Image.asset(
                        "assets/icons/user.png",
                        height: radius * 2,
                        width: radius * 2,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Base64ImageWidget(
                      base64String: profileImageString,
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                    ))
              : Image.asset(
                  "assets/icons/user.png",
                  height: radius * 2,
                  width: radius * 2,
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // ✅ Add dynamic app bar for community view
      appBar: isCommunityFeed
          ? AppBar(
              scrolledUnderElevation: 0,
              title: Text('Community Posts'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isCommunityFeed
                    ? 'Search community posts...'
                    : 'Search ...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _currentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: () {
                          _searchController.clear(); // Clear the text field
                          _performSearch(''); // Clear search results
                          FocusScope.of(context).unfocus(); // Close keyboard
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade600),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: _performSearch, // Use the new search method
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      // ✅ Only show FAB for all posts, not community posts
      floatingActionButton: !isCommunityFeed
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CreatePostScreen()),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/icons/floatingicon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (isLoading && posts.isEmpty) {
      return _buildLoadingState();
    }

    if (posts.isEmpty && _allPostsCache.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: Primary.withOpacity(0.4),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < posts.length) {
                    return _buildPostCard(context, posts[index]);
                  } else if (index == posts.length && _hasMorePosts) {
                    return _buildLoadingMoreIndicator();
                  } else if (index == posts.length && !_hasMorePosts) {
                    return _buildEndOfFeedIndicator();
                  }
                  return null;
                },
                childCount: posts.length +
                    (_hasMorePosts ? 1 : (posts.isNotEmpty ? 1 : 0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isCommunityFeed ? 'Loading community posts...' : 'Loading posts...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Text(
                isCommunityFeed ? "Loading community posts" : "Loading posts"),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    if (!isLoadingMore) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading more posts...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfFeedIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No more posts to show',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, Post post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Updated profile image with base64 support
                _buildProfileImage(post.profileImage, post.username),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgoFromDateTime(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.public, size: 16, color: Primary),
                const SizedBox(width: 8),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  itemBuilder: (BuildContext context) {
                    List<PopupMenuEntry> menuItems = [];

                    if (post.isAdmin == true) {
                      menuItems.add(
                        PopupMenuItem(
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _confirmDeleteUI(
                                context,
                                post.id,
                                currentPage: _currentPage,
                                postsPerPage: _postsPerPage,
                                visiblePosts: posts,
                                onUpdate: (updatedPosts) {
                                  setState(() {
                                    final startIndex =
                                        _currentPage * _postsPerPage;
                                    final endIndex =
                                        (startIndex + updatedPosts.length)
                                            .clamp(0, posts.length);
                                    posts.removeRange(startIndex, endIndex);
                                    posts.insertAll(startIndex, updatedPosts);
                                  });
                                },
                              );
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    menuItems.add(
                      PopupMenuItem(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _showReportDialog(
                              context,
                              post.id,
                              _currentPage,
                              _postsPerPage,
                              posts,
                              visiblePosts: posts,
                              (updatedPosts) {
                                setState(() {
                                  final startIndex =
                                      _currentPage * _postsPerPage;
                                  final endIndex =
                                      (startIndex + updatedPosts.length)
                                          .clamp(0, posts.length);
                                  posts.removeRange(startIndex, endIndex);
                                  posts.insertAll(startIndex, updatedPosts);
                                });
                              },
                            );
                          },
                          child: Row(
                            children: const [
                              Icon(Icons.flag, size: 18),
                              SizedBox(width: 8),
                              Text('Report'),
                            ],
                          ),
                        ),
                      ),
                    );

                    menuItems.add(
                      PopupMenuItem(
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            await _notInterestedUI(
                              context,
                              post.id,
                              _currentPage,
                              _postsPerPage,
                              posts,
                              visiblePosts: posts,
                              (updatedPosts) {
                                setState(() {
                                  final startIndex =
                                      _currentPage * _postsPerPage;
                                  final endIndex =
                                      (startIndex + updatedPosts.length)
                                          .clamp(0, posts.length);
                                  posts.removeRange(startIndex, endIndex);
                                  posts.insertAll(startIndex, updatedPosts);
                                });
                              },
                            );
                          },
                          child: Row(
                            children: const [
                              Icon(Icons.remove_circle_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Not Interested'),
                            ],
                          ),
                        ),
                      ),
                    );

                    return menuItems;
                  },
                )
              ],
            ),
          ),

          // Divider 1 (above content)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 0.5,
              color: Colors.grey[300],
            ),
          ),

          // Post Content Centered Between Dividers
          if (post.postContent.isNotEmpty ||
              post.postImages.isNotEmpty ||
              (post.postVideo != null && post.postVideo!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.postImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: post.postImages.length == 1
                          ? _buildSingleImage(post.postImages.first)
                          : _buildImageCarousel(post.postImages),
                    ),
                  if (post.postVideo != null && post.postVideo!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClipRRect(
                        child: Base64VideoWidget(
                            base64Video: post.postVideo!.first),
                      ),
                    ),
                ],
              ),
            ),

          // Divider 2 (below content)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 0.5,
              color: Colors.grey[300],
            ),
          ),

          // Action Buttons
          _buildActionButtons(post),
          if (post.postContent.isNotEmpty)
            PostContentWidget(content: post.postContent),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Post post) {
    Set<String> processingLikes = {};

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Consumer<CommentProvider>(
            builder: (context, provider, _) {
              final updatedPost = provider.posts.firstWhere(
                (p) => p.id == post.id,
                orElse: () => post,
              );

              final interaction = provider.getPostInteractionData(post.id);
              final likeCount = interaction?['likeCount'] ?? updatedPost.likes;
              final commentCount =
                  interaction?['commentCount'] ?? updatedPost.comments.length;

              return Padding(
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildActionButton(
                      icon: Icon(
                        updatedPost.isLikedByUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: updatedPost.isLikedByUser
                            ? Colors.red
                            : Colors.grey[600],
                      ),
                      label: '$likeCount',
                      onTap: () => _handleLike(updatedPost),
                      isLoading: processingLikes.contains(updatedPost.id),
                    ),
                    const SizedBox(width: 45),
                    _buildActionButton(
                      icon: Image.asset(
                        'assets/icons/comment.png',
                        height: 20,
                        width: 20,
                      ),
                      label: '$commentCount',
                      onTap: () => _handleComment(post),
                      isLoading: false,
                    ),
                    const SizedBox(width: 45),
                    _buildActionButton(
                      icon: Image.asset(
                        'assets/icons/share.png',
                        height: 20,
                        width: 20,
                      ),
                      label: '',
                      onTap: () => _handleShare(context, post),
                      isLoading: processingShares.contains(post.id),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
    Color? iconColor, // ✅ Optional color
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                    ),
                  )
                : icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLike(Post post) async {
    final provider = context.read<CommentProvider>();

    if (!provider.posts.any((p) => p.id == post.id)) return;

    if (!processingLikes.contains(post.id)) {
      processingLikes.add(post.id);

      // Toggle like/unlike
      await provider.toggleLike(post.id);

      // ✅ Fetch updated like count only (no other logic changed)
      await provider.fetchCount(post.id);

      processingLikes.remove(post.id);
    }
  }

  void _handleComment(Post post) async {
    final provider = context.read<CommentProvider>();

    // Optional: preload post data
    await provider.fetchSinglePost(post.id);

    // ⏬ Wait for bottom sheet to close
    await _showCommentsBottomSheet(post.id);

    // ⏫ Fetch updated comment count AFTER bottom sheet closes
    await provider.fetchCount(post.id);
  }

  Future<void> _showCommentsBottomSheet(String postId) async {
    final controller = _getCommentController(postId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.95,
          maxChildSize: 1.0,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<CommentProvider>(
              builder: (context, provider, _) {
                final comments = provider.getCommentsForPost(postId);

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Comments',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: Stack(
                        children: [
                          (provider.isLoading && comments.isEmpty)
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  itemCount: comments.length,
                                  itemBuilder: (context, index) {
                                    final comment = comments[comments.length -
                                        1 -
                                        index]; // Reverse the list

                                    final userName = comment.userName.isNotEmpty
                                        ? comment.userName
                                        : 'User';

                                    final createdAt =
                                        DateTime.tryParse(comment.createdAt);
                                    final timeAgo = createdAt != null
                                        ? timeAgoFromDateTime(createdAt)
                                        : '';

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Updated comment profile image with base64 support
                                          _buildProfileImage(
                                              comment.profileImage, userName,
                                              radius: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      userName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      timeAgo,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(comment.content),
                                                const SizedBox(height: 4),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                          if (provider.isPosting)
                            const Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Input field
                    Padding(
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 8,
                        top: 8,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                      ),
                      child: Row(
                        children: [
                          // Updated current user profile image with base64 support
                          _buildProfileImage(
                              provider.getCurrentUserProfile(), 'Current User',
                              radius: 20),
                          const SizedBox(width: 8),

                          // Fixed TextField styling (only one container)
                          Expanded(
                            child: Focus(
                              child: Builder(
                                builder: (context) {
                                  final isFocused = Focus.of(context).hasFocus;

                                  return TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      hintText: 'Add a comment...',
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide:
                                            BorderSide(color: Colors.grey),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide:
                                            BorderSide(color: Colors.grey),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide:
                                            BorderSide(color: Colors.black),
                                      ),
                                      filled: true,
                                      fillColor: Color(0xFFF2F2F2),
                                    ),
                                    maxLines: null,
                                    minLines: 1,
                                  );
                                },
                              ),
                            ),
                          ),

                          // Send Button
                          IconButton(
                            iconSize: 33,
                            icon: const Icon(Icons.send, color: Primary),
                            onPressed: () async {
                              final text = controller.text.trim();
                              if (text.isNotEmpty) {
                                final provider =
                                    context.read<CommentProvider>();

                                final success = await provider.postComment(
                                  postId: postId,
                                  commentContent: text,
                                  offset: 0,
                                  limit: 10,
                                );

                                if (success) {
                                  controller.clear();
                                  FocusScope.of(context).unfocus();

                                  // Refresh the single post (optional if not using it in UI)
                                  await provider.fetchSinglePost(postId);

                                  // ✅ Refresh the interaction count (includes commentCount)
                                  await provider.fetchCount(postId);

                                  // Animate scroll to top
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    scrollController.animateTo(
                                      0,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  });

                                  // await _refreshFeed();
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String timeAgoFromDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM yyyy').format(dateTime);
    }
  }

  void _handleShare(BuildContext context, Post post) async {
    final result = await CommentService.sharePost(
      postId: post.id,
      type: 'user',
      userId: 'receiver_user_id', // Replace with actual ID
      whom: 'feed',
      // whomId: 'xyz', // Optional if whom != 'feed'
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );
  }
}

Widget _buildSingleImage(String imageString) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    // decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
    child: ClipRRect(
      // borderRadius: BorderRadius.circular(8),
      child: _isNetworkImage(imageString)
          ? CachedNetworkImage(
        imageUrl: imageString,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) =>
        const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      )
          : Base64ImageWidget(
        base64String: imageString,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    ),
  );
}

Widget _buildImageCarousel(List<String> images) {
  return _ImageCarouselWithDots(images: images);
}

class _ImageCarouselWithDots extends StatefulWidget {
  final List<String> images;
  const _ImageCarouselWithDots({required this.images});

  @override
  State<_ImageCarouselWithDots> createState() => _ImageCarouselWithDotsState();
}

// Helper method to determine if the image string is a network URL
bool _isNetworkImage(String imageString) {
  return imageString.startsWith('http://') ||
      imageString.startsWith('https://') ||
      imageString.startsWith('ftp://');
}

// Alternative helper method using Uri.tryParse (more robust)
bool _isNetworkImageRobust(String imageString) {
  try {
    final uri = Uri.parse(imageString);
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'ftp');
  } catch (e) {
    return false;
  }
}

class _ImageCarouselWithDotsState extends State<_ImageCarouselWithDots> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Use AspectRatio or Flexible to give PageView proper constraints
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.9, // Responsive height
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final imageString = widget.images[index];
              return Container(
                // margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageString.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: imageString,
                          fit: BoxFit.contain, // Preserves aspect ratio
                          width: double.infinity,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        )
                      : Base64ImageWidget(
                          base64String: imageString,
                          width: double.infinity,
                          fit: BoxFit.contain, // Preserves aspect ratio
                        ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.images.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentIndex == index ? 10 : 6,
              height: _currentIndex == index ? 10 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentIndex == index ? Colors.black : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _confirmDeleteUI(
  BuildContext context,
  String postId, {
  required int currentPage,
  required int postsPerPage,
  required List<Post> visiblePosts,
  required Function(List<Post>) onUpdate,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: const Text('Are you sure you want to delete this post?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.pop(ctx);

            final provider = context.read<CommentProvider>();

            await provider.deletePost(context, postId);

            List<Post> updatedPosts = List.from(visiblePosts)
              ..removeWhere((post) => post.id == postId);

            onUpdate(updatedPosts);

            await provider.refreshCurrentPage(
              context: context,
              currentPage: currentPage,
              postsPerPage: postsPerPage,
              visiblePosts: updatedPosts,
              onUpdate: onUpdate,
            );
          },
          child: const Text(
            'Delete',
          ),
        ),
      ],
    ),
  );
}

void _showReportDialog(BuildContext context, String postId, int currentPage,
    int postsPerPage, List<Post> posts, Function(List<Post>) onUpdate,
    {required List<Post> visiblePosts}) {
  final TextEditingController _reportController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text('Report Post'),
        content: SizedBox(
          height: 80,
          width: 250,
          child: TextField(
            controller: _reportController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter your reason...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          SizedBox(
            width: 110, // Set desired width
            height: 47.5, // Set desired height
            child: ElevatedButton(
              onPressed: () async {
                final reason = _reportController.text.trim();

                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                final provider =
                    Provider.of<CommentProvider>(context, listen: false);

                await provider.reportPost(
                  postId: postId,
                  reportReason: reason,
                  context: context,
                );

                List<Post> updatedPosts = List.from(visiblePosts)
                  ..removeWhere((post) => post.id == postId);

                onUpdate(updatedPosts);

                await provider.refreshCurrentPage(
                  context: context,
                  currentPage: currentPage,
                  postsPerPage: postsPerPage,
                  visiblePosts: posts,
                  onUpdate: onUpdate,
                );
              },
              child: const Text('Submit'),
            ),
          )
        ],
      );
    },
  );
}

Future<void> _notInterestedUI(
  BuildContext context,
  String postId,
  int currentPage,
  int postsPerPage,
  List<Post> posts,
  Function(List<Post>) onUpdate, {
  required List<Post> visiblePosts,
}) async {
  final provider = context.read<CommentProvider>();

  await provider.markPostNotInterested(context, postId);
  List<Post> updatedPosts = List.from(visiblePosts)
    ..removeWhere((post) => post.id == postId);

  onUpdate(updatedPosts);

  await provider.refreshCurrentPage(
    context: context,
    currentPage: currentPage,
    postsPerPage: postsPerPage,
    visiblePosts: posts,
    onUpdate: onUpdate,
  );
}

class PostContentWidget extends StatefulWidget {
  final String content;

  const PostContentWidget({Key? key, required this.content}) : super(key: key);

  @override
  State<PostContentWidget> createState() => _PostContentWidgetState();
}

class _PostContentWidgetState extends State<PostContentWidget> {
  bool _isExpanded = false;

  // Improved URL regex pattern to match full URLs including http:// and https://
  static final RegExp _urlRegExp = RegExp(
    r'(https?://[-a-zA-Z0-9@:%._\+~#=/?&]+[-a-zA-Z0-9@:%_\+~#=/?&])',
    caseSensitive: false,
  );

  Future<void> _launchURL(String url) async {
    String formattedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      formattedUrl = 'https://$url';
    }

    final Uri uri = Uri.parse(formattedUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in external browser
        );
      } else {
        // Fallback: try to launch with different mode
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not launch $formattedUrl: $e');
      // Optionally show a snackbar to inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the link: $formattedUrl')),
      );
    }
  }

  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final matches = _urlRegExp.allMatches(text);

    if (matches.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          height: 1.4,
        ),
      ));
      return spans;
    }

    int lastIndex = 0;

    for (final match in matches) {
      // Add text before the URL
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            height: 1.4,
          ),
        ));
      }

      // Add the clickable URL
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.blue,
          height: 1.4,
          decoration: TextDecoration.underline,
          decorationColor: Colors.blue,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchURL(url),
      ));

      lastIndex = match.end;
    }

    // Add remaining text after the last URL
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          height: 1.4,
        ),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.isEmpty) return const SizedBox();

    String displayContent = widget.content;
    if (!_isExpanded && widget.content.length > 150) {
      // Find a good break point near 150 characters
      int breakPoint = 150;
      int lastSpace = widget.content.lastIndexOf(' ', breakPoint);
      if (lastSpace > 100) {
        breakPoint = lastSpace;
      }
      displayContent = widget.content.substring(0, breakPoint) + '...';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            textAlign: TextAlign.start,
            text: TextSpan(
              children: _buildTextSpans(displayContent),
            ),
          ),
          if (widget.content.length > 150)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _isExpanded ? 'See less' : 'See more',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
