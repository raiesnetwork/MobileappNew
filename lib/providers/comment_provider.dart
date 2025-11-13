import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service/user_api_service.dart';
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


  /// Fetch and update a single post (used after commenting)
  Future<void> fetchSinglePost(String postId) async {
    try {
      print("🔄 Fetching updated post data for $postId...");

      final updatedPost = await CommentService.getPostById(postId);

      if (updatedPost != null) {
        final index = _posts.indexWhere((post) => post.id == postId);

        if (index != -1) {
          print(
              "✅ Updating post at index $index with ${updatedPost.comments?.length ?? 0} comments");
          _posts[index] = updatedPost;

          // Force UI rebuild
          notifyListeners();

          print("✅ Post updated and listeners notified");
        } else {
          print("⚠️ Post not found in _posts list");
          // If post not in list, add it
          _posts.add(updatedPost);
          notifyListeners();
        }
      } else {
        print("❌ fetchSinglePost returned null for $postId");
      }
    } catch (e) {
      print('❌ Error fetching post: $e');
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

  Future<void> fetchCount(String postId) async {
    final data = await CommentService.getCount(postId);
    if (data != null) {
      _interactionMap[postId] = data;
      notifyListeners();
    } else {
      print("⚠️ Interaction count fetch failed for $postId");
    }
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
}