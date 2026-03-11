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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          "success": false,
          "message": "Authentication token is missing",
        };
      }
      print("token$token");
      print("postid$postId");

      final Uri url = Uri.parse("https://api.ixes.ai/api/post/comment");
      final Map<String, dynamic> body = {
        "postId": postId,
        "commentContent": commentContent,
      };

      print('📤 POST COMMENT URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('📥 COMMENT STATUS: ${response.statusCode}');
      print('📥 COMMENT RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Comment Posted Successfully');
        return {
          "success": true,
          "data": decoded['newComment'],
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

  // static Future<Map<String, dynamic>> fetchComments(String postId) async {
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString('auth_token');
  //     final url = Uri.parse("https://api.ixes.ai/api/post/$postId/comments");
  //
  //     final response = await http.get(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       return {
  //         "success": true,
  //         "data": data['comments'] ?? [],
  //       };
  //     } else {
  //       return {
  //         "success": false,
  //         "message": "Failed to load comments",
  //       };
  //     }
  //   } catch (e) {
  //     return {
  //       "success": false,
  //       "message": "Fetch error: $e",
  //     };
  //   }
  // }

  // ✅ FIXED: Returns null on error instead of throwing exception
  static Future<Post?> getPostById(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print("❌ Token missing for getPostById");
        return null;
      }

      final url = Uri.parse("https://api.ixes.ai/api/post/$postId");

      print('📤 GET POST BY ID URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📥 GET POST BY ID STATUS: ${response.statusCode}');
      print('📥 GET POST BY ID RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ Handle different response structures
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print("❌ Token missing for comment");
        return {
          "success": false,
          "message": "Authentication token is missing",
        };
      }
      print("token$token");
      print("postid$postId");

      final Uri url = Uri.parse("https://api.ixes.ai/api/post/report");
      final Map<String, dynamic> body = {
        "postId": postId,
        "reportReason": reportReason,
      };

      print('📤 reportReason URL: $url');
      print('📤 reportReason BODY: $body');
      print('🔐 TOKEN: $token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print("❌ Token missing for comment");
        return {
          "success": false,
          "message": "Authentication token is missing",
        };
      }
      print("token$token");
      print("postid$postId");

      final Uri url = Uri.parse("https://api.ixes.ai/api/post/not-intrested");
      final Map<String, dynamic> body = {
        "postId": postId,
      };

      print('📤 markAsNotInterested URL: $url');
      print('📤 markAsNotInterested BODY: $body');
      print('🔐 TOKEN: $token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('📥 markAsNotInterested STATUS: ${response.statusCode}');
      print('📥 markAsNotInterested RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ markAsNotInterested Posted Successfully');
        return {
          "success": true,
          "data": decoded['newComment'],
          "message":
          decoded['message'] ?? "markAsNotInterested posted successfully"
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

  // Get all users
  static Future<Map<String, dynamic>> getAllUsers({
    String? search,
    int pageNo = 1,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print("❌ Token missing for getAllUsers");
        return {
          "success": false,
          "message": "Authentication token is missing",
        };
      }

      // Build query parameters
      Map<String, dynamic> queryParams = {
        'pageNo': pageNo.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final Uri url = Uri.parse("https://api.ixes.ai/api/mobile/all-users")
          .replace(queryParameters: queryParams);

      print('📤 getAllUsers URL: $url');
      print('🔐 TOKEN: $token');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

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

// Share post
  static Future<Map<String, dynamic>> sharePost({
    required String postId,
    required String type, // "user" or "group"
    required String userId, // Receiver ID
    required String shareContext, // "feed", "campaign", "service", "announcement"
    String? contextId, // Required if shareContext is not "feed"
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print("❌ Token missing for sharePost");
        return {
          "success": false,
          "message": "Authentication token is missing",
        };
      }

      final Uri url = Uri.parse("https://api.ixes.ai/api/post/share");

      final Map<String, dynamic> body = {
        "postId": postId,
        "userId": userId,
        "type": type,
        "shareContext": shareContext,
      };

      // Add contextId only if shareContext is not "feed"
      if (shareContext != "feed" && contextId != null) {
        body["contextId"] = contextId;
      }

      print('📤 sharePost URL: $url');
      print('📤 sharePost BODY: $body');
      print('🔐 TOKEN: $token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          "success": false,
          "message": "Authentication token is missing",
        };
      }

      final Uri url = Uri.parse("https://api.ixes.ai/api/post/delete/$postId");
      print("Deleting post with URL: https://api.ixes.ai/api/post/delete/$postId");

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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

  // ✅ FIXED: Better error handling

  /// ✅ Like a Post
  static Future<Map<String, dynamic>> likePost(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {"success": false, "message": "Token missing"};
      }

      final url = Uri.parse("https://api.ixes.ai/api/post/like");
      final body = {"postId": postId};

      print('❤️ Sending Like for postId: $postId');
      print('📤 LIKE POST URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

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

  /// 🔻 Unlike a Post - ✅ FIXED: Changed URL from api2.ixes.ai to api.ixes.ai
  static Future<Map<String, dynamic>> unlikePost(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {"success": false, "message": "Token missing"};
      }

      // ✅ FIXED: Changed from api2.ixes.ai to api.ixes.ai
      final url = Uri.parse("https://api.ixes.ai/api/post/unlike");
      final body = {"postId": postId};

      print('💔 Sending Unlike for postId: $postId');
      print('📤 UNLIKE POST URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {"success": false, "message": "Authentication token is missing"};
      }

      final Uri url = Uri.parse("https://api.ixes.ai/api/post/comment/$commentId");

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"commentContent": commentContent}),
      );

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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {"success": false, "message": "Authentication token is missing"};
      }

      final Uri url = Uri.parse("https://api.ixes.ai/api/post/comment/$commentId");

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

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