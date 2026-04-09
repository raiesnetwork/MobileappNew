import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';
import '../models/post_model.dart';
import 'api_service.dart';

class CommentService {
  /// ✅ Post a Comment
  static Future<Map<String, dynamic>> postComment({
    required String postId,
    required String commentContent,
    isPosting = true,
  }) async {
    try {
      print("postid$postId");

      final Map<String, dynamic> body = {
        "postId": postId,
        "commentContent": commentContent,
      };

      print('📤 POST COMMENT');

      final response = await ApiService.post('/api/post/comment', body);
      ApiService.checkResponse(response);

      print('📥 COMMENT STATUS: ${response.statusCode}');
      print('📥 COMMENT RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Comment Posted Successfully');
        return {
          "success": true,
          "newComment": decoded['newComment'],
          "message": decoded['message'] ?? "Comment posted successfully"
        };
      } else {
        print('⚠️ Failed to Post Comment');
        return {
          "success": false,
          "message": decoded['message'] ?? "Failed to post comment"
        };
      }
    } catch (e) {
      print("❌ Network or Decoding Error: $e");
      return {
        "success": false,
        "message": "Error posting comment: ${e.toString()}",
      };
    }
  }

  static Future<Post?> getPostById(String postId) async {
    try {
      final response = await ApiService.get('/api/post/$postId');
      ApiService.checkResponse(response);

      print('📥 GET POST BY ID STATUS: ${response.statusCode}');
      print('📥 GET POST BY ID RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['post'] != null) {
          print('✅ Post found in response["post"]');
          return Post.fromJson(data['post']);
        } else if (data['data'] != null && data['data'] is Map) {
          print('✅ Post found in response["data"]');
          return Post.fromJson(data['data']);
        } else if (data is Map<String, dynamic> && data['_id'] != null) {
          print('✅ Post found in root response');
          return Post.fromJson(data);
        } else {
          print('⚠️ Unexpected response structure: $data');
          return null;
        }
      } else {
        print('❌ Failed to fetch post: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error in getPostById: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> reportPost({
    required String postId,
    required String reportReason,
  }) async {
    try {
      print("postid$postId");

      final Map<String, dynamic> body = {
        "postId": postId,
        "reportReason": reportReason,
      };

      print('📤 reportReason BODY: $body');

      final response = await ApiService.post('/api/post/report', body);
      ApiService.checkResponse(response);

      print('📥 reportReason STATUS: ${response.statusCode}');
      print('📥 reportReason RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ reportReason Posted Successfully');
        return {
          "success": true,
          "data": decoded['newComment'],
          "message": decoded['message'] ?? "reportReason posted successfully"
        };
      } else {
        print('⚠️ Failed to Post reportReason');
        return {
          "success": false,
          "message": decoded['message'] ?? "Failed to post reportReason"
        };
      }
    } catch (e) {
      print("❌ Network or Decoding Error: $e");
      return {
        "success": false,
        "message": "Error posting reportReason: ${e.toString()}",
      };
    }
  }

  static Future<Map<String, dynamic>> markAsNotInterested({
    required String postId,
  }) async {
    try {
      print("postid$postId");

      final Map<String, dynamic> body = {
        "postId": postId,
      };

      print('📤 markAsNotInterested BODY: $body');

      final response = await ApiService.post('/api/post/not-intrested', body);
      ApiService.checkResponse(response);

      print('📥 markAsNotInterested STATUS: ${response.statusCode}');
      print('📥 markAsNotInterested RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ markAsNotInterested Posted Successfully');
        return {
          "success": true,
          "data": decoded['newComment'],
          "message": decoded['message'] ?? "markAsNotInterested posted successfully"
        };
      } else {
        print('⚠️ Failed to Post markAsNotInterested');
        return {
          "success": false,
          "message": decoded['message'] ?? "Failed to post markAsNotInterested"
        };
      }
    } catch (e) {
      print("❌ Network or Decoding Error: $e");
      return {
        "success": false,
        "message": "Error posting markAsNotInterested: ${e.toString()}",
      };
    }
  }

  static Future<Map<String, dynamic>> getAllUsers({
    String? search,
    int pageNo = 1,
  }) async {
    try {
      Map<String, dynamic> queryParams = {
        'pageNo': pageNo.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await ApiService.get(
          '/api/mobile/all-users?$queryString');
      ApiService.checkResponse(response);

      print('📥 getAllUsers STATUS: ${response.statusCode}');
      print('📥 getAllUsers RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ Users fetched successfully');
        return {
          "success": true,
          "data": decoded['data'],
          "allUsers": decoded['data']['allUsers'],
          "totalPage": decoded['data']['totalPage'],
          "currentPage": decoded['data']['currentPage'],
        };
      } else {
        print('⚠️ Failed to fetch users');
        return {
          "success": false,
          "message": decoded['message'] ?? "Failed to fetch users",
        };
      }
    } catch (e) {
      print("❌ Network or Decoding Error: $e");
      return {
        "success": false,
        "message": "Error fetching users: ${e.toString()}",
      };
    }
  }

  static Future<Map<String, dynamic>> sharePost({
    required String postId,
    required String type,
    required String userId,
    required String shareContext,
    String? contextId,
  }) async {
    try {
      final Map<String, dynamic> body = {
        "postId": postId,
        "userId": userId,
        "type": type,
        "shareContext": shareContext,
      };

      if (shareContext != "feed" && contextId != null) {
        body["contextId"] = contextId;
      }

      print('📤 sharePost BODY: $body');

      final response = await ApiService.post('/api/post/share', body);
      ApiService.checkResponse(response);

      print('📥 sharePost STATUS: ${response.statusCode}');
      print('📥 sharePost RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Post shared successfully');
        return {
          "success": true,
          "message": decoded['message'] ?? "Post sent successfully",
        };
      } else {
        print('⚠️ Failed to share post');
        return {
          "success": false,
          "message": decoded['message'] ?? "Failed to share post",
        };
      }
    } catch (e) {
      print("❌ Network or Decoding Error: $e");
      return {
        "success": false,
        "message": "Error sharing post: ${e.toString()}",
      };
    }
  }

  static Future<Map<String, dynamic>> deletePost({
    required String postId,
  }) async {
    try {
      final response = await ApiService.delete('/api/post/delete/$postId');
      ApiService.checkResponse(response);

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          "success": true,
          "message": decoded['message'] ?? "Post deleted successfully",
        };
      } else {
        return {
          "success": false,
          "message": decoded['message'] ?? "Failed to delete post",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": "Error: ${e.toString()}",
      };
    }
  }

  static Future<Map<String, dynamic>> likePost(String postId) async {
    try {
      final body = {"postId": postId};

      print('❤️ Sending Like for postId: $postId');

      final response = await ApiService.post('/api/post/like', body);
      ApiService.checkResponse(response);

      print('📥 LIKE STATUS: ${response.statusCode}');
      print('📥 LIKE RESPONSE: ${response.body}');

      final data = jsonDecode(response.body);
      return {
        "success": response.statusCode == 200 || response.statusCode == 201,
        "message": data['message'] ?? "Liked",
      };
    } catch (e) {
      print("❌ Like Error: $e");
      return {"success": false, "message": "Like error: $e"};
    }
  }

  static Future<Map<String, dynamic>> unlikePost(String postId) async {
    try {
      final body = {"postId": postId};

      print('💔 Sending Unlike for postId: $postId');

      final response = await ApiService.post('/api/post/unlike', body);
      ApiService.checkResponse(response);

      print('📥 UNLIKE STATUS: ${response.statusCode}');
      print('📥 UNLIKE RESPONSE: ${response.body}');

      final data = jsonDecode(response.body);
      return {
        "success": response.statusCode == 200 || response.statusCode == 201,
        "message": data['message'] ?? "Unliked"
      };
    } catch (e) {
      print("❌ Unlike Error: $e");
      return {"success": false, "message": "Unlike error: $e"};
    }
  }

  static Future<Map<String, dynamic>> editComment({
    required String commentId,
    required String commentContent,
  }) async {
    try {
      final response = await ApiService.put(
        '/api/post/comment/$commentId',
        {"commentContent": commentContent},
      );
      ApiService.checkResponse(response);

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "message": decoded['message'] ?? "Comment updated"};
      } else {
        return {"success": false, "message": decoded['message'] ?? "Failed to edit comment"};
      }
    } catch (e) {
      return {"success": false, "message": "Error editing comment: ${e.toString()}"};
    }
  }

  static Future<Map<String, dynamic>> deleteComment({
    required String commentId,
  }) async {
    try {
      final response = await ApiService.delete('/api/post/comment/$commentId');
      ApiService.checkResponse(response);

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "message": decoded['message'] ?? "Comment deleted"};
      } else {
        return {"success": false, "message": decoded['message'] ?? "Failed to delete comment"};
      }
    } catch (e) {
      return {"success": false, "message": "Error deleting comment: ${e.toString()}"};
    }
  }
}