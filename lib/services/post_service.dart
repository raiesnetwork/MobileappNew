import 'dart:convert';
import 'dart:io';
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// POST SERVICE CLASS
class PostService {

  Future<dynamic> getAllPosts({
    required int offset,
    required int limit,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      // Convert offset to page number
      int pageNumber = (offset ~/ limit) + 1; // Convert offset to page number
      final url = Uri.parse('https://api.ixes.ai/api/mobile/posts?page=$pageNumber&limit=$limit');

      print("Feed API URL: $url");
      print("Offset: $offset, Calculated Page: $pageNumber"); // Debug print

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("GETALLPOSTS Status Code: ${response.statusCode}");
      print("GETALLPOSTS Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("GETALLPOSTS Details Error: ${response.reasonPhrase}");
        return null;
      }
    } catch (e) {
      print('Error in GETALLPOSTS: $e');
      return null;
    }
  }

  Future<dynamic> getCommunityPosts({
    required String communityId,
    required int offset,
    required int limit,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final url = Uri.parse(
          '${apiBaseUrl}api/post/$communityId?offset=$offset&limit=$limit');

      print("Community Posts API URL: $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("GET_COMMUNITY_POSTS Status Code: ${response.statusCode}");
      print("GET_COMMUNITY_POSTS Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("GET_COMMUNITY_POSTS Details Error: ${response.reasonPhrase}");
        return null;
      }
    } catch (e) {
      print('Error in GET_COMMUNITY_POSTS: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createPost(
      String mediaType,
      String postContent,
      List<String>? imagePaths,  // Changed from base64 to file paths
      String? videoPath,         // Changed from base64 to file path
      String? communityId,
      ) async {
    try {
      // Get auth token
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse('${apiBaseUrl}api/post'));

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add text fields
      request.fields['mediaType'] = mediaType;
      request.fields['postContent'] = postContent;

      if (communityId != null) {
        request.fields['communityId'] = communityId;
      }

      // Add image files
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (int i = 0; i < imagePaths.length; i++) {
          final file = File(imagePaths[i]);
          if (await file.exists()) {
            final multipartFile = await http.MultipartFile.fromPath(
              'files', // Use 'files' as the field name for multiple files
              file.path,
              filename: 'image_$i.${file.path.split('.').last}',
            );
            request.files.add(multipartFile);
          }
        }
      }

      // Add video file
      if (videoPath != null) {
        final file = File(videoPath);
        if (await file.exists()) {
          final multipartFile = await http.MultipartFile.fromPath(
            'files', // Use 'files' as the field name
            file.path,
            filename: 'video.${file.path.split('.').last}',
          );
          request.files.add(multipartFile);
        }
      }

      print('📤 Multipart request prepared');
      print('📤 Fields: ${request.fields}');
      print('📤 Files count: ${request.files.length}');

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: "${response.body}"');
      print('📥 Response body length: ${response.body.length}');
      print('📥 Response body isEmpty: ${response.body.isEmpty}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle successful response with empty/null body
        if (response.body.isEmpty || response.body.trim() == '' || response.body == 'null') {
          print('✅ Empty response body - Post created successfully');
          return {
            'success': true,
            'post': null,
            'message': 'Post created successfully'
          };
        }

        // Try to parse the response body if it exists
        try {
          final data = json.decode(response.body);
          print('✅ Parsed data: $data');

          // Check if data contains post information
          if (data != null && data is Map<String, dynamic>) {
            // If post data exists in response
            if (data.containsKey('post') && data['post'] != null) {
              return {
                'success': true,
                'post': Post.fromJson(data['post']),
                'message': data['message'] ?? 'Post created successfully'
              };
            } else {
              // Response exists but no post data
              return {
                'success': true,
                'post': null,
                'message': data['message'] ?? 'Post created successfully'
              };
            }
          } else {
            // Data is not a valid map
            return {
              'success': true,
              'post': null,
              'message': 'Post created successfully'
            };
          }
        } catch (parseError) {
          // If parsing fails but status is success, still return success
          print('⚠️ Response parsing failed but request succeeded: $parseError');
          return {
            'success': true,
            'post': null,
            'message': 'Post created successfully'
          };
        }
      } else {
        // Handle error responses
        try {
          if (response.body.isNotEmpty && response.body != 'null') {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ?? 'Failed to create post: ${response.statusCode}',
            };
          } else {
            return {
              'success': false,
              'message': 'Failed to create post: ${response.statusCode}',
            };
          }
        } catch (parseError) {
          return {
            'success': false,
            'message': 'Failed to create post: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('❌ Error in createPost: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}