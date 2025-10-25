import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CouponService {



  Future<Map<String, dynamic>> getUserCoupons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'createdCoupons': [],
          'receivedCoupons': [],
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/coupon/getAll-coupon');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getUserCoupons - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        return {
          'error': false,
          'message': 'Coupons fetched successfully',
          'createdCoupons': decoded['createdCoupons'] ?? [],
          'receivedCoupons': decoded['receivedCoupons'] ?? [],
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch coupons',
          'createdCoupons': [],
          'receivedCoupons': [],
        };
      }
    } catch (e) {
      print('Error in getUserCoupons: $e');
      return {
        'error': true,
        'message': 'Error fetching coupons: ${e.toString()}',
        'createdCoupons': [],
        'receivedCoupons': [],
      };
    }
  }
  Future<Map<String, dynamic>> createCoupon({
    required String name,
    required String details,
    required String type,
    required String expiry,
    required String code,
    String? couponType,
    String? image,
    String? link,
    Map<String, dynamic>? discountAmount,
    double? discountPercentage,
    int? coinAmount,
    String? rewardType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'coupon': null,
        };
      }

      // Build request body
      final Map<String, dynamic> requestBody = {
        'name': name,
        'details': details,
        'type': type,
        'expiry': expiry,
        'code': code,
      };

      // Add optional fields
      if (couponType != null) requestBody['couponType'] = couponType;
      if (image != null && image.isNotEmpty) requestBody['image'] = image;
      if (link != null && link.isNotEmpty) requestBody['link'] = link;

      // Add type-specific fields
      if (type == 'coupon') {
        if (couponType == 'discount-amount' && discountAmount != null) {
          requestBody['discountAmount'] = discountAmount;
        } else if (couponType == 'discount-in-percentage' && discountPercentage != null) {
          requestBody['discountPercentage'] = discountPercentage;
        }
      } else if (type == 'coins' && coinAmount != null) {
        requestBody['coinAmount'] = coinAmount;
      } else if (type == 'rewards' && rewardType != null) {
        requestBody['rewardType'] = rewardType;
      }

      final uri = Uri.parse('${apiBaseUrl}api/coupon/create-coupon');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('createCoupon - Status Code: ${response.statusCode}');
      print('Request body: ${jsonEncode(requestBody)}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        return {
          'error': false,
          'message': 'Coupon created successfully',
          'coupon': decoded,
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create coupon',
          'coupon': null,
        };
      }
    } catch (e) {
      print('Error in createCoupon: $e');
      return {
        'error': true,
        'message': 'Error creating coupon: ${e.toString()}',
        'coupon': null,
      };
    }
  }
}
