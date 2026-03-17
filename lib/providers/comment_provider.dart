import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/comment_service.dart';
import '../services/post_service.dart';

class CommentProvider with ChangeNotifier {
  final Map<String, List<Map<String, dynamic>>> _commentsByPostId = {};
  bool _isLoading = false;
  bool _isPosting = false; // Move this declaration before the getter
  String _error = '';
  List<Post> _posts = [];
  String _currentUserProfile = ''; // Add current user profile

  // Getters
  bool get isLoading => _isLoading;
  bool get isPosting => _isPosting;
  String get error => _error;
  List<Post> get posts => _posts;
  String _currentUserId = '';
  String get currentUserId => _currentUserId;

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  // Get current user profile image
  String getCurrentUserProfile() => _currentUserProfile;


  // Set current user profile (call this when user logs in)
  void setCurrentUserProfile(String profileImageUrl) {
    _currentUserProfile = profileImageUrl;
    notifyListeners();
  }

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void setError(String msg) {
    _error = msg;
    notifyListeners();
  }

  void setPosts(List<Post> fetchedPosts) {
    _posts = fetchedPosts;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchAllPosts({
    required int offset,
    required int limit,
    bool isRefresh = false, // Add parameter to indicate refresh vs load more
  }) async {
    final result = await PostService().getAllPosts(offset: offset, limit: limit);

    if (result != null &&
        result['posts'] != null &&
        result['posts']['transformedPosts'] != null) {
      final List<dynamic> data = result['posts']['transformedPosts'];
      final newPosts = data.map((e) => Post.fromJson(e)).toList();

      if (isRefresh || offset == 0) {
        // If refreshing or loading first page, replace the list
        _posts = newPosts;
      } else {
        // If loading more, append to existing list
        _posts.addAll(newPosts);
      }

      notifyListeners();
      return result;
    } else {
      if (isRefresh || offset == 0) {
        _posts = [];
      }
      notifyListeners();
      return null;
    }
  }
  List<Post> _communityPosts = [];
  String _currentCommunityId = '';

// Getter for community posts
  List<Post> get communityPosts => _communityPosts;
  String get currentCommunityId => _currentCommunityId;

// Fetch community posts method
  Future<Map<String, dynamic>?> fetchCommunityPosts({
    required String communityId,
    required int offset,
    required int limit,
  }) async {
    setLoading(true);

    final result = await PostService().getCommunityPosts(
      communityId: communityId,
      offset: offset,
      limit: limit,
    );

    if (result != null && result['posts'] != null) {
      final List<dynamic> data = result['posts'];
      _communityPosts = data.map((e) => Post.fromJson(e)).toList();
      _currentCommunityId = communityId;
      setLoading(false);
      notifyListeners();
      return result;
    } else {
      _communityPosts = [];
      _currentCommunityId = '';
      setLoading(false);
      notifyListeners();
      return null;
    }
  }


  List<Comment> getCommentsForPost(String postId) {
    try {
      // First try regular posts
      final postInMain = _posts.indexWhere((p) => p.id == postId);
      if (postInMain != -1) {
        return _posts[postInMain].comments;
      }

      // Then try community posts
      final postInCommunity = _communityPosts.indexWhere((p) => p.id == postId);
      if (postInCommunity != -1) {
        return _communityPosts[postInCommunity].comments;
      }

      return [];
    } catch (e) {
      print("Error in getCommentsForPost: $e");
      return [];
    }
  }


  Future<bool> postComment({
    required String postId,
    required String commentContent,
    required int offset,
    required int limit,
    String? communityId, // ✅ Add communityId parameter
  }) async {
    _isPosting = true;
    notifyListeners();

    try {
      final result = await CommentService.postComment(
        postId: postId,
        commentContent: commentContent,
      );

      if (result['success']) {
        // ✅ Fetch based on feed type
        if (communityId != null) {
          await fetchCommunityPosts(
            communityId: communityId,
            offset: offset,
            limit: limit,
          );
        } else {
          await fetchAllPosts(offset: offset, limit: limit);
        }

        // Now call getCommentsForPost after posts are refreshed
        final updatedComments = getCommentsForPost(postId);
        print("Updated comments for $postId: $updatedComments");

        _isPosting = false;
        notifyListeners();

        return true;
      } else {
        _isPosting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isPosting = false;
      notifyListeners();
      print('Error posting comment: $e');
      return false;
    }
  }


  /// Update a post and refresh the feed
  Future<bool> updatePost({
    required BuildContext context,
    required String postId,
    String? postContent,
    String? mediaType,
    String? deleteOldMediaUrl,
    List<String>? newImagePaths,
    String? newVideoPath,
    required int offset,
    required int limit,
    String? communityId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await PostService.updatePost(
        postId: postId,
        postContent: postContent,
        mediaType: mediaType,
        deleteOldMediaUrl: deleteOldMediaUrl,
        newImagePaths: newImagePaths,
        newVideoPath: newVideoPath,
      );

      _isLoading = false;

      if (result['success']) {
        // ✅ NO SNACKBAR HERE - Let the screen handle it
        print('✅ Provider: Post updated successfully');

        // Refresh the appropriate feed
        if (communityId != null) {
          await fetchCommunityPosts(
            communityId: communityId,
            offset: offset,
            limit: limit,
          );
        } else {
          await fetchAllPosts(offset: offset, limit: limit, isRefresh: true);
        }

        notifyListeners();
        return true;
      } else {
        // ❌ Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update post'),
            backgroundColor: Colors.red,
          ),
        );

        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating post: $e'),
          backgroundColor: Colors.red,
        ),
      );

      print('❌ Error in updatePost provider: $e');
      return false;
    }
  }


  // Optional: Add this helper method for better state management
  void isloading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  final Map<String, Map<String, dynamic>> _interactionMap = {};

  Map<String, dynamic>? getPostInteractionData(String postId) {
    return _interactionMap[postId];
  }

  Future<void> refreshCurrentPage({
    required BuildContext context,
    required int currentPage,
    required int postsPerPage,
    required List<Post> visiblePosts,
    required Function(List<Post>) onUpdate,
  }) async {
    final offset = currentPage * postsPerPage;

    final response =
        await fetchAllPosts(offset: offset, limit: postsPerPage); // ✅ Now works

    if (response != null &&
        response['posts'] != null &&
        response['posts']['transformedPosts'] != null) {
      final List<dynamic> data = response['posts']['transformedPosts'];
      final freshPosts = data.map((e) => Post.fromJson(e)).toList();

      print("✅ Updating posts for page $currentPage");
      onUpdate(freshPosts);
    }
  }

  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    // 🔁 Optimistic UI update
    final isLiked = _posts[index].isLikedByUser;
    _posts[index].isLikedByUser = !isLiked;
    _posts[index].likes += isLiked ? -1 : 1;
    notifyListeners();

    final result = isLiked
        ? await CommentService.unlikePost(postId)
        : await CommentService.likePost(postId);

    if (!result['success']) {
      // ❌ Revert on failure
      _posts[index].isLikedByUser = isLiked;
      _posts[index].likes += isLiked ? 1 : -1;
      notifyListeners();
    }
  }

  Future<bool> reportPost({
    required BuildContext context, // Add context here
    required String postId,
    required String reportReason,
  }) async {
    try {
      final result = await CommentService.reportPost(
        postId: postId,
        reportReason: reportReason,
      );

      final message = result['message'] ?? 'Something went wrong';

      if (message == "Post reported successfully") {
        setError(''); // Clear errors on success

        // ✅ Show success SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );

        return true;
      } else {
        setError(message);

        // ❌ Optional: Show failure SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );

        return false;
      }
    } catch (e) {
      final error = 'Unexpected error: ${e.toString()}';
      setError(error);

      // ❌ Show exception SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }
  }

  Future<void> markPostNotInterested(
    BuildContext context,
    String postId,
  ) async {
    final result = await CommentService.markAsNotInterested(postId: postId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) {
      // Optionally update state or refresh post list
    }
  }

  Future<void> deletePost(BuildContext context, String postId) async {
    final result = await CommentService.deletePost(postId: postId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) {
      _posts.removeWhere((post) => post.id == postId);
      print(
          "Deleting post with URL: https://api.ixes.ai/api/post/delete/$postId");


      notifyListeners();
    }
  }
  // Add these properties at the top with other declarations
  // Add these properties at the top with other declarations
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoadingUsers = false;
  int _currentUserPage = 1;
  int _totalUserPages = 1;

// Add these getters
  List<Map<String, dynamic>> get allUsers => _allUsers;
  bool get isLoadingUsers => _isLoadingUsers;
  int get currentUserPage => _currentUserPage;
  int get totalUserPages => _totalUserPages;

  /// Fetch all users with pagination and search
  Future<bool> fetchAllUsers({
    String? search,
    int pageNo = 1,
    bool isLoadMore = false,
  }) async {
    _isLoadingUsers = true;
    notifyListeners();

    try {
      final result = await CommentService.getAllUsers(
        search: search,
        pageNo: pageNo,
      );

      if (result['success']) {
        final List<dynamic> users = result['allUsers'] ?? [];

        if (isLoadMore) {
          // Append users when loading more
          _allUsers.addAll(users.map((e) => e as Map<String, dynamic>).toList());
        } else {
          // Replace users on new search or first load
          _allUsers = users.map((e) => e as Map<String, dynamic>).toList();
        }

        _currentUserPage = result['currentPage'] ?? 1;
        _totalUserPages = result['totalPage'] ?? 1;

        _isLoadingUsers = false;
        notifyListeners();
        return true;
      } else {
        _isLoadingUsers = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Error fetching users: $e');
      _isLoadingUsers = false;
      notifyListeners();
      return false;
    }
  }
  Future<bool> editComment({
    required BuildContext context,
    required String commentId,
    required String commentContent,
    required String postId,
    required int offset,
    required int limit,
    String? communityId,
  }) async {
    // ✅ Optimistic update — change comment content instantly
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final commentIndex = _posts[postIndex].comments.indexWhere((c) => c.id == commentId);
      if (commentIndex != -1) {
        _posts[postIndex].comments[commentIndex] = Comment(
          id: commentId,
          content: commentContent,
          createdAt: _posts[postIndex].comments[commentIndex].createdAt,
          userName: _posts[postIndex].comments[commentIndex].userName,
          profileImage: _posts[postIndex].comments[commentIndex].profileImage,
          isAdmin: _posts[postIndex].comments[commentIndex].isAdmin,
          userId: _posts[postIndex].comments[commentIndex].userId,
        );
        notifyListeners();
      }
    }
    // Same for communityPosts
    final cPostIndex = _communityPosts.indexWhere((p) => p.id == postId);
    if (cPostIndex != -1) {
      final commentIndex = _communityPosts[cPostIndex].comments.indexWhere((c) => c.id == commentId);
      if (commentIndex != -1) {
        _communityPosts[cPostIndex].comments[commentIndex] = Comment(
          id: commentId,
          content: commentContent,
          createdAt: _communityPosts[cPostIndex].comments[commentIndex].createdAt,
          userName: _communityPosts[cPostIndex].comments[commentIndex].userName,
          profileImage: _communityPosts[cPostIndex].comments[commentIndex].profileImage,
          isAdmin: _communityPosts[cPostIndex].comments[commentIndex].isAdmin,
          userId: _communityPosts[cPostIndex].comments[commentIndex].userId,
        );
        notifyListeners();
      }
    }

    final result = await CommentService.editComment(
      commentId: commentId,
      commentContent: commentContent,
    );

    if (result['success']) {
      if (communityId != null) {
        fetchCommunityPosts(communityId: communityId, offset: offset, limit: limit);
      } else {
        fetchAllPosts(offset: offset, limit: limit, isRefresh: true);
      }
      return true;
    } else {
      return false;
    }
  }

  Future<bool> deleteComment({
    required BuildContext context,
    required String commentId,
    required String postId,
    required int offset,
    required int limit,
    String? communityId,
  }) async {
    // ✅ Optimistic update — remove comment instantly
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      _posts[postIndex].comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    }
    final cPostIndex = _communityPosts.indexWhere((p) => p.id == postId);
    if (cPostIndex != -1) {
      _communityPosts[cPostIndex].comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    }

    final result = await CommentService.deleteComment(commentId: commentId);

    if (result['success']) {
      if (communityId != null) {
        fetchCommunityPosts(communityId: communityId, offset: offset, limit: limit);
      } else {
        fetchAllPosts(offset: offset, limit: limit, isRefresh: true);
      }
      return true;
    } else {
      return false;
    }
  }

  /// Share a post
  Future<bool> sharePost({
    required BuildContext context,
    required String postId,
    required String type, // "user" or "group"
    required String userId, // Receiver ID
    required String shareContext, // "feed", "campaign", "service", "announcement"
    String? contextId, // Required if shareContext is not "feed"
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await CommentService.sharePost(
        postId: postId,
        type: type,
        userId: userId,
        shareContext: shareContext,
        contextId: contextId,
      );

      _isLoading = false;

      if (result['success']) {
        // ✅ Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Post shared successfully'),
            backgroundColor: Colors.green,
          ),
        );

        notifyListeners();
        return true;
      } else {
        // ❌ Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to share post'),
            backgroundColor: Colors.red,
          ),
        );

        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing post: $e'),
          backgroundColor: Colors.red,
        ),
      );

      print('❌ Error in sharePost provider: $e');
      return false;
    }
  }

  /// Clear users list (useful when closing search or user selection dialog)
  void clearUsersList() {
    _allUsers = [];
    _currentUserPage = 1;
    _totalUserPages = 1;
    notifyListeners();
  }
}