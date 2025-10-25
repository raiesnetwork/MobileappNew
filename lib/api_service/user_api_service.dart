// ignore_for_file: prefer_typing_uninitialized_variables

import 'dart:developer';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:ixes.app/api_service/ApiHelper.dart';
// import 'package:ixes.app/api_s/ervice/ApiHelper.dart';
// import 'package:ixes.app/api_service/ApiHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:nacl_qr_delivery_app/lib/api_service/ApiHelper.dart';
import 'dart:convert';

import '../constants/apiConstants.dart';

class UserAPI {
  Future<Map<String, dynamic>> SignUpApi(
      BuildContext context, Map<String, dynamic> params) async {
    try {
      final String url = apiBaseUrl + SIGNUP;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(params),
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

  Future<dynamic> getAllPosts(
    int offset,
    int limit,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final url =
          Uri.parse('$apiBaseUrl$GETALLPOST?offset=$offset&limit=$limit');

      print("getallfeedpost URL: $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("getallfeedpost Status Code: ${response.statusCode}");
      print("getallfeedpost Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("getallfeedpost Error: ${response.reasonPhrase}");
        return null;
      }
    } catch (e) {
      print('Error in getallfeedpost: $e');

      return null;
    }
  }
}
 