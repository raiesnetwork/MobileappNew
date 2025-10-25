// services/notification_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/apiConstants.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class NotificationService {
  Future<List<Map<String, dynamic>>?> fetchNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final url = Uri.parse('$apiBaseUrl$GETALLNOTIFICATIONS');
      print("Notification API URL: $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("GETALLNOTIFICATIONS Status Code: ${response.statusCode}");
      print("GETALLNOTIFICATIONS Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List notifications = json['notifications'];
        return notifications.cast<Map<String, dynamic>>();
      } else {
        print("Error: ${response.reasonPhrase}");
        return null;
      }
    } catch (e) {
      print('Exception in fetchNotifications: $e');
      return null;
    }
  }
}
