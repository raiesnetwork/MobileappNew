import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';

class PostProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isLoadingPosts = false;
  String? _errorMessage;
  List<Post> _posts = [];
  Map<String, dynamic>? _joinedCommunity;

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingPosts => _isLoadingPosts;
  String? get errorMessage => _errorMessage;
  List<Post> get posts => _posts;
  Map<String, dynamic>? get joinedCommunity => _joinedCommunity;
  bool get hasError => _errorMessage != null;

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Create post method - now accepts file paths instead of base64
  Future<bool> createPost({
    required String mediaType,
    required String postContent,
    List<String>? postImages, // Now expecting file paths
    String? postVideo,        // Now expecting file path
    String? communityId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await PostService.createPost(
        mediaType,
        postContent,
        postImages,    // Pass file paths to service
        postVideo,     // Pass file path to service
        communityId,
      );

      print('🔄 Service result: $result');
      print('🔄 Result type: ${result.runtimeType}');

      _isLoading = false;

      // Check if result is null
      if (result == null) {
        _errorMessage = 'Server returned null response';
        notifyListeners();
        return false;
      }

      // Check if result is a Map
      if (result is! Map<String, dynamic>) {
        _errorMessage = 'Invalid response format from server';
        notifyListeners();
        return false;
      }

      if (result['success'] == true) {
        // Add the new post to the beginning of the posts list
        final newPost = result['post'];
        print('✅ New post: $newPost');
        if (newPost != null) {
          _posts.insert(0, newPost);
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Failed to create post';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Error in createPost provider: $e');
      _isLoading = false;
      _errorMessage = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}