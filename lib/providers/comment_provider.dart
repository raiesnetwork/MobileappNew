import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/comment_service.dart';
import '../services/post_service.dart';

class CommentProvider with ChangeNotifier {
  final Map<String, List<Map<String, dynamic>>> _commentsByPostId = {};
  bool _isLoading = false;
  bool _isPosting = false;
  String _error = '';
  List<Post> _posts = [];
  List<Post> _injectedPosts = [];
  String _currentUserProfile = '';

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

  String getCurrentUserProfile() => _currentUserProfile;

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
    bool isRefresh = false,
  }) async {
    final result = await PostService().getAllPosts(offset: offset, limit: limit);

    if (result != null &&
        result['posts'] != null &&
        result['posts']['transformedPosts'] != null) {
      final List<dynamic> data = result['posts']['transformedPosts'];
      final newPosts = data.map((e) => Post.fromJson(e)).toList();

      if (isRefresh || offset == 0) {
        _posts = newPosts;
        for (final injected in _injectedPosts) {
          final exists = _posts.any((p) => p.id == injected.id);
          if (!exists) {
            _posts.add(injected);
          }
        }
      } else {
        _posts.addAll(newPosts);
      }

      notifyListeners();
      return result;
    } else {
      if (isRefresh || offset == 0) {
        _posts = [];
        for (final injected in _injectedPosts) {
          _posts.add(injected);
        }
      }
      notifyListeners();
      return null;
    }
  }

  List<Post> _communityPosts = [];
  String _currentCommunityId = '';

  List<Post> get communityPosts => _communityPosts;
  String get currentCommunityId => _currentCommunityId;

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
      final injectedIdx = _injectedPosts.indexWhere((p) => p.id == postId);
      if (injectedIdx != -1) {
        return _injectedPosts[injectedIdx].comments;
      }

      final postInMain = _posts.indexWhere((p) => p.id == postId);
      if (postInMain != -1) {
        return _posts[postInMain].comments;
      }

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
    String? communityId,
  }) async {
    _isPosting = true;
    notifyListeners();

    try {
      final result = await CommentService.postComment(
        postId: postId,
        commentContent: commentContent,
      );

      if (result['success']) {
        final newCommentData = result['newComment'];

        String userName = '';
        String profileImage = '';

        if (newCommentData != null) {
          final userProfile = newCommentData['userId']?['profile'];
          userName = userProfile?['name']?.toString() ?? '';
          profileImage = userProfile?['profileImage']?.toString() ?? '';
        }

        final realComment = Comment(
          id: newCommentData?['_id']?.toString() ??
              'temp_${DateTime.now().millisecondsSinceEpoch}',
          content: commentContent,
          createdAt: newCommentData?['createdAt']?.toString() ??
              DateTime.now().toIso8601String(),
          userName: userName,
          profileImage: profileImage,
          isAdmin: false,
          userId: newCommentData?['userId']?['_id']?.toString() ?? _currentUserId,
        );

        // Add to community posts
        final cIndex = _communityPosts.indexWhere((p) => p.id == postId);
        if (cIndex != -1) {
          _communityPosts[cIndex].comments.add(realComment);
        }

        // Add to regular posts
        final pIndex = _posts.indexWhere((p) => p.id == postId);
        if (pIndex != -1) {
          _posts[pIndex].comments.add(realComment);
        }

        // Add to injected posts
        final injIdx = _injectedPosts.indexWhere((p) => p.id == postId);
        if (injIdx != -1) {
          _injectedPosts[injIdx].comments.add(realComment);
        }

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
        print('✅ Provider: Post updated successfully');

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

    final response = await fetchAllPosts(offset: offset, limit: postsPerPage);

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
    final cIndex = _communityPosts.indexWhere((p) => p.id == postId);
    final injIndex = _injectedPosts.indexWhere((p) => p.id == postId);

    if (index == -1 && cIndex == -1 && injIndex == -1) return;

    final bool isLiked = index != -1
        ? _posts[index].isLikedByUser
        : cIndex != -1
        ? _communityPosts[cIndex].isLikedByUser
        : _injectedPosts[injIndex].isLikedByUser;

    // Optimistic update
    if (index != -1) {
      _posts[index].isLikedByUser = !isLiked;
      _posts[index].likes += isLiked ? -1 : 1;
    }
    if (cIndex != -1) {
      _communityPosts[cIndex].isLikedByUser = !isLiked;
      _communityPosts[cIndex].likes += isLiked ? -1 : 1;
    }
    if (injIndex != -1) {
      _injectedPosts[injIndex].isLikedByUser = !isLiked;
      _injectedPosts[injIndex].likes += isLiked ? -1 : 1;
    }
    notifyListeners();

    final result = isLiked
        ? await CommentService.unlikePost(postId)
        : await CommentService.likePost(postId);

    if (!result['success']) {
      // Revert on failure
      if (index != -1) {
        _posts[index].isLikedByUser = isLiked;
        _posts[index].likes += isLiked ? 1 : -1;
      }
      if (cIndex != -1) {
        _communityPosts[cIndex].isLikedByUser = isLiked;
        _communityPosts[cIndex].likes += isLiked ? 1 : -1;
      }
      if (injIndex != -1) {
        _injectedPosts[injIndex].isLikedByUser = isLiked;
        _injectedPosts[injIndex].likes += isLiked ? 1 : -1;
      }
      notifyListeners();
    }
  }

  Future<bool> reportPost({
    required BuildContext context,
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
        setError('');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        return true;
      } else {
        setError(message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      final error = 'Unexpected error: ${e.toString()}';
      setError(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
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
      _injectedPosts.removeWhere((post) => post.id == postId);
      print("Deleting post with URL: https://api.ixes.ai/api/post/delete/$postId");
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoadingUsers = false;
  int _currentUserPage = 1;
  int _totalUserPages = 1;

  List<Map<String, dynamic>> get allUsers => _allUsers;
  bool get isLoadingUsers => _isLoadingUsers;
  int get currentUserPage => _currentUserPage;
  int get totalUserPages => _totalUserPages;

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
          _allUsers.addAll(users.map((e) => e as Map<String, dynamic>).toList());
        } else {
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
    // Optimistic update for _posts
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final commentIndex =
      _posts[postIndex].comments.indexWhere((c) => c.id == commentId);
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

    // Optimistic update for _communityPosts
    final cPostIndex = _communityPosts.indexWhere((p) => p.id == postId);
    if (cPostIndex != -1) {
      final commentIndex = _communityPosts[cPostIndex]
          .comments
          .indexWhere((c) => c.id == commentId);
      if (commentIndex != -1) {
        _communityPosts[cPostIndex].comments[commentIndex] = Comment(
          id: commentId,
          content: commentContent,
          createdAt:
          _communityPosts[cPostIndex].comments[commentIndex].createdAt,
          userName:
          _communityPosts[cPostIndex].comments[commentIndex].userName,
          profileImage:
          _communityPosts[cPostIndex].comments[commentIndex].profileImage,
          isAdmin: _communityPosts[cPostIndex].comments[commentIndex].isAdmin,
          userId: _communityPosts[cPostIndex].comments[commentIndex].userId,
        );
        notifyListeners();
      }
    }

    // Optimistic update for _injectedPosts
    final injPostIndex = _injectedPosts.indexWhere((p) => p.id == postId);
    if (injPostIndex != -1) {
      final commentIndex = _injectedPosts[injPostIndex]
          .comments
          .indexWhere((c) => c.id == commentId);
      if (commentIndex != -1) {
        _injectedPosts[injPostIndex].comments[commentIndex] = Comment(
          id: commentId,
          content: commentContent,
          createdAt:
          _injectedPosts[injPostIndex].comments[commentIndex].createdAt,
          userName:
          _injectedPosts[injPostIndex].comments[commentIndex].userName,
          profileImage:
          _injectedPosts[injPostIndex].comments[commentIndex].profileImage,
          isAdmin:
          _injectedPosts[injPostIndex].comments[commentIndex].isAdmin,
          userId: _injectedPosts[injPostIndex].comments[commentIndex].userId,
        );
        notifyListeners();
      }
    }

    final result = await CommentService.editComment(
      commentId: commentId,
      commentContent: commentContent,
    );

    if (result['success']) {
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
    // Optimistic update for _posts
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      _posts[postIndex].comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    }

    // Optimistic update for _communityPosts
    final cPostIndex = _communityPosts.indexWhere((p) => p.id == postId);
    if (cPostIndex != -1) {
      _communityPosts[cPostIndex].comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    }

    // Optimistic update for _injectedPosts
    final injPostIndex = _injectedPosts.indexWhere((p) => p.id == postId);
    if (injPostIndex != -1) {
      _injectedPosts[injPostIndex].comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    }

    final result = await CommentService.deleteComment(commentId: commentId);

    if (result['success']) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> sharePost({
    required BuildContext context,
    required String postId,
    required String type,
    required String userId,
    required String shareContext,
    String? contextId,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Post shared successfully'),
            backgroundColor: Colors.green,
          ),
        );
        notifyListeners();
        return true;
      } else {
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

  void injectSinglePost(Post post) {
    final idx = _injectedPosts.indexWhere((p) => p.id == post.id);
    if (idx != -1) {
      _injectedPosts[idx] = post;
    } else {
      _injectedPosts.add(post);
    }
    final mainIdx = _posts.indexWhere((p) => p.id == post.id);
    if (mainIdx != -1) {
      _posts[mainIdx] = post;
    } else {
      _posts.add(post);
    }
    notifyListeners();
  }

  void clearUsersList() {
    _allUsers = [];
    _currentUserPage = 1;
    _totalUserPages = 1;
    notifyListeners();
  }

  void clearAllData() {
    _posts = [];
    _communityPosts = [];
    _injectedPosts = [];
    _currentUserId = '';
    _commentsByPostId.clear();
    notifyListeners();
  }
}