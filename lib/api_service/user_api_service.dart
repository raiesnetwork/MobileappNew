import 'dart:convert';
import 'package:flutter/material.dart';
import '../constants/apiConstants.dart';
import '../services/api_service.dart';


class UserAPI {
  Future<Map<String, dynamic>> SignUpApi(
      BuildContext context, Map<String, dynamic> params) async {
    try {
      final response = await ApiService.post(
        SIGNUP,
        params,
        requireAuth: false, // signup doesn't need auth
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          ...responseData,
          'statusCode': 200,
        };
      } else {
        return {
          'statusCode': response.statusCode,
          'message': responseData['message'] ?? 'Server error',
        };
      }
    } catch (e) {
      print('❌ Error in SignUpApi: $e');
      return {
        'statusCode': 500,
        'message': 'Something went wrong. Please try again.',
      };
    }
  }

  Future<dynamic> getAllPosts(int offset, int limit) async {
    try {
      final response = await ApiService.get(
        '$GETALLPOST?offset=$offset&limit=$limit',
      );

      ApiService.checkResponse(response);

      print('getallfeedpost Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('getallfeedpost Error: ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      print('Error in getallfeedpost: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      // ✅ Try multiple endpoint patterns
      final endpoints = [
        '/api/mobile/post/$postId',
        '/api/mobile/posts/$postId',
        '/api/post/$postId',
        '/api/posts/$postId',
      ];

      for (final endpoint in endpoints) {
        final response = await ApiService.get(endpoint);
        ApiService.checkResponse(response);
        print('📡 getPostById trying $endpoint → ${response.statusCode}');

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      }

      print('❌ getPostById: all endpoints returned non-200');
      return null;
    } catch (e) {
      print('getPostById error: $e');
      return null;
    }
  }
}