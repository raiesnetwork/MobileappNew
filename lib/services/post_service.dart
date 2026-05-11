import 'dart:convert';
import 'dart:io';
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:ixes.app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PostService {

  // ✅ GET ALL POSTS
  Future<dynamic> getAllPosts({
    required int offset,
    required int limit,
  }) async {
    try {
      int pageNumber = (offset ~/ limit) + 1;
      print("Offset: $offset, Calculated Page: $pageNumber");

      final response = await ApiService.get(
        '/api/mobile/posts?page=$pageNumber&limit=$limit',
      );
      ApiService.checkResponse(response);

      print("GETALLPOSTS Status Code: ${response.statusCode}");
      print("GETALLPOSTS Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("GETALLPOSTS Error: ${response.reasonPhrase}");
        return null;
      }
    } catch (e) {
      print('Error in GETALLPOSTS: $e');
      return null;
    }
  }

  // ✅ GET COMMUNITY POSTS
  Future<dynamic> getCommunityPosts({
    required String communityId,
    required int offset,
    required int limit,
  }) async {
    try {
      final response = await ApiService.get(
        '/api/post/$communityId?offset=$offset&limit=$limit',
      );
      ApiService.checkResponse(response);

      print("GET_COMMUNITY_POSTS Status Code: ${response.statusCode}");
      print("GET_COMMUNITY_POSTS Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("GET_COMMUNITY_POSTS Error: ${response.reasonPhrase}");
        return null;
      }
    } catch (e) {
      print('Error in GET_COMMUNITY_POSTS: $e');
      return null;
    }
  }

  // ✅ GET POST BY ID
  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      final response = await ApiService.get('/api/mobile/posts/$postId');
      ApiService.checkResponse(response);
      print('📡 getPostById status: ${response.statusCode}');
      print('📡 getPostById body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('getPostById error: $e');
      return null;
    }
  }

  // ✅ CREATE POST
  static Future<Map<String, dynamic>> createPost(
      String mediaType,
      String postContent,
      List<String>? imagePaths,
      String? videoPath,
      String? communityId,
      ) async {
    try {
      final fields = <String, String>{
        'mediaType': mediaType,
        'postContent': postContent,
        if (communityId != null) 'communityId': communityId,
      };

      final files = <http.MultipartFile>[];

      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (int i = 0; i < imagePaths.length; i++) {
          final file = File(imagePaths[i]);
          if (await file.exists()) {
            files.add(await http.MultipartFile.fromPath(
              'files',
              file.path,
              filename: 'image_$i.${file.path.split('.').last}',
            ));
          }
        }
      }

      if (videoPath != null) {
        final file = File(videoPath);
        if (await file.exists()) {
          files.add(await http.MultipartFile.fromPath(
            'files',
            file.path,
            filename: 'video.${file.path.split('.').last}',
          ));
        }
      }

      print('📤 Multipart request prepared');
      print('📤 Fields: $fields');
      print('📤 Files count: ${files.length}');

      final response = await ApiService.multipart(
        endpoint: '/api/post',
        method: 'POST',
        fields: fields,
        files: files,
      );
      ApiService.checkResponse(response);

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: "${response.body}"');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isEmpty ||
            response.body.trim() == '' ||
            response.body == 'null') {
          return {
            'success': true,
            'post': null,
            'message': 'Post created successfully'
          };
        }
        try {
          final data = json.decode(response.body);
          if (data != null && data is Map<String, dynamic>) {
            if (data.containsKey('post') && data['post'] != null) {
              return {
                'success': true,
                'post': Post.fromJson(data['post']),
                'message': data['message'] ?? 'Post created successfully'
              };
            } else {
              return {
                'success': true,
                'post': null,
                'message': data['message'] ?? 'Post created successfully'
              };
            }
          } else {
            return {
              'success': true,
              'post': null,
              'message': 'Post created successfully'
            };
          }
        } catch (parseError) {
          print('⚠️ Response parsing failed but request succeeded: $parseError');
          return {
            'success': true,
            'post': null,
            'message': 'Post created successfully'
          };
        }
      } else {
        try {
          if (response.body.isNotEmpty && response.body != 'null') {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ??
                  'Failed to create post: ${response.statusCode}',
            };
          } else {
            return {
              'success': false,
              'message': 'Failed to create post: ${response.statusCode}'
            };
          }
        } catch (parseError) {
          return {
            'success': false,
            'message': 'Failed to create post: ${response.statusCode}'
          };
        }
      }
    } catch (e) {
      print('❌ Error in createPost: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ✅ UPDATE POST
  static Future<Map<String, dynamic>> updatePost({
    required String postId,
    String? postContent,
    String? mediaType,
    String? deleteOldMediaUrl,
    List<String>? newImagePaths,
    String? newVideoPath,
  }) async {
    try {
      final fields = <String, String>{
        if (postContent != null && postContent.isNotEmpty)
          'postContent': postContent,
        if (mediaType != null && mediaType.isNotEmpty) 'mediaType': mediaType,
        if (deleteOldMediaUrl != null && deleteOldMediaUrl.isNotEmpty)
          'deleteOldMediaUrl': deleteOldMediaUrl,
      };

      final files = <http.MultipartFile>[];

      if (newImagePaths != null && newImagePaths.isNotEmpty) {
        for (int i = 0; i < newImagePaths.length; i++) {
          final file = File(newImagePaths[i]);
          if (await file.exists()) {
            files.add(await http.MultipartFile.fromPath(
              'files',
              file.path,
              filename: 'image_$i.${file.path.split('.').last}',
            ));
          }
        }
      }

      if (newVideoPath != null) {
        final file = File(newVideoPath);
        if (await file.exists()) {
          files.add(await http.MultipartFile.fromPath(
            'files',
            file.path,
            filename: 'video.${file.path.split('.').last}',
          ));
        }
      }

      print('📤 Update request prepared for post: $postId');
      print('📤 Fields: $fields');
      print('📤 Files count: ${files.length}');

      final response = await ApiService.multipart(
        endpoint: '/api/post/update/$postId',
        method: 'PUT',
        fields: fields,
        files: files,
      );
      ApiService.checkResponse(response);

      print('📥 Update response status: ${response.statusCode}');
      print('📥 Update response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty ||
            response.body.trim() == '' ||
            response.body == 'null') {
          return {
            'success': true,
            'message': 'Post updated successfully',
            'post': null
          };
        }
        try {
          final data = json.decode(response.body);
          if (data['error'] == false) {
            return {
              'success': true,
              'message': data['message'] ?? 'Post updated successfully',
              'post': data['post'],
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Failed to update post'
            };
          }
        } catch (parseError) {
          print(
              '⚠️ Response parsing failed but request succeeded: $parseError');
          return {
            'success': true,
            'message': 'Post updated successfully',
            'post': null
          };
        }
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Post not found'};
      } else {
        try {
          if (response.body.isNotEmpty && response.body != 'null') {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ??
                  'Failed to update post: ${response.statusCode}',
            };
          } else {
            return {
              'success': false,
              'message': 'Failed to update post: ${response.statusCode}'
            };
          }
        } catch (parseError) {
          return {
            'success': false,
            'message': 'Failed to update post: ${response.statusCode}'
          };
        }
      }
    } catch (e) {
      print('❌ Error in updatePost: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}