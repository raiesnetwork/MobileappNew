import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';


class CouponService {
  // ─────────────────────────────────────────────────────────────────────────────
  // HELPER: returns auth headers
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, String>?> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return null;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. GET ALL COUPONS  →  GET /api/coupon/getAll-coupon
  // Returns { createdCoupons: [], receivedCoupons: [] }
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUserCoupons() async {
    try {
      final headers = await _authHeaders();
      if (headers == null) {
        return _authError(['createdCoupons', 'receivedCoupons']);
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/coupon/getAll-coupon'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'createdCoupons': decoded['createdCoupons'] ?? [],
          'receivedCoupons': decoded['receivedCoupons'] ?? [],
        };
      }
      return _parseError(response.body, {'createdCoupons': [], 'receivedCoupons': []});
    } catch (e) {
      return _exception(e, {'createdCoupons': [], 'receivedCoupons': []});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. CREATE COUPON  →  POST /api/coupon/create-coupon  (multipart, supports image)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createCoupon({
    required String name,
    required String details,
    required String type,
    required String expiry,
    required String code,
    String? couponType,
    File? imageFile,
    String? link,
    Map<String, dynamic>? discountAmount,
    double? discountPercentage,
    int? coinAmount,
    String? rewardType,
  }) async {
    try {
      print("➡️ [createCoupon] Creating coupon...");
      print("📝 Data: name=$name, type=$type, code=$code");

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print("❌ [createCoupon] No auth token");
        return _authError(['coupon']);
      }

      final uri = Uri.parse('${apiBaseUrl}api/coupon/create-coupon');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['name'] = name
        ..fields['details'] = details
        ..fields['type'] = type
        ..fields['expiry'] = expiry
        ..fields['code'] = code;

      if (couponType != null) request.fields['couponType'] = couponType;
      request.fields['link'] = (link != null && link.isNotEmpty) ? link : '';

      // ✅ Type-specific fields
      if (type == 'coupon') {
        if (couponType == 'discount-amount' && discountAmount != null) {
          request.fields['discountAmount'] = jsonEncode(discountAmount);
        } else if (couponType == 'discount-in-percentage') {
          request.fields['discountPercentage'] = (discountPercentage ?? 0).toString();
        }
      } else if (type == 'coins' && coinAmount != null) {
        request.fields['coinAmount'] = coinAmount.toString();
      } else if (type == 'rewards' && rewardType != null) {
        request.fields['rewardType'] = rewardType;
      }

      print("📦 [createCoupon] Fields: ${request.fields}");

      // ✅ Attach image if provided
      if (imageFile != null) {
        print("🖼️ [createCoupon] Attaching image: ${imageFile.path}");
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', imageFile.path.split('.').last),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📥 [createCoupon] Status Code: ${response.statusCode}");
      print("📥 [createCoupon] Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ [createCoupon] Coupon created successfully");
        return {
          'error': false,
          'message': 'Coupon created successfully',
          'coupon': jsonDecode(response.body)
        };
      }

      print("❌ [createCoupon] API Error");
      return _parseError(response.body, {'coupon': null});
    } catch (e) {
      print("🔥 [createCoupon] Exception: $e");
      return _exception(e, {'coupon': null});
    }
  }
  // ─────────────────────────────────────────────────────────────────────────────
  // 3. SEND COUPON TO USER  →  POST /api/coupon/send-coupon
  // Body: { couponId, receiverId }
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendCouponToUser({
    required String couponId,
    required String receiverId,
  }) async {
    return _post('api/coupon/send-coupon', {'couponId': couponId, 'receiverId': receiverId});
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. SEND COUPON TO GROUP/COMMUNITY  →  POST /api/coupon/send-community
  // Body: { couponId, groupId }
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendCouponToGroup({
    required String couponId,
    required String groupId,
  }) async {
    return _post('api/coupon/send-community', {
      'couponId': couponId,
      'communityId': groupId, // ← changed from 'groupId' to 'communityId'
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. ADD COUPON CODE TO SERVICE  →  POST /api/coupon/add-to-service
  // Body: { couponCode, serviceId }
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addCouponToService({
    required String couponCode,
    required String serviceId,
  }) async {
    return _post('api/coupon/add-to-service', {'couponCode': couponCode, 'serviceId': serviceId});
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. VERIFY COUPON  →  POST /api/coupon/verify
  // Body: { code, store? }
  // Returns: { error, message, coupon }
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyCoupon({
    required String code,
    String? store,
  }) async {
    final body = <String, dynamic>{'code': code};
    if (store != null) body['store'] = store;
    return _post('api/coupon/verify', body);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. VERIFY iXES SUBSCRIPTION COUPON  →  POST /api/coupon/verify-ixes-coupon
  // Body: { code }
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyIxesCoupon({required String code}) async {
    return _post('api/coupon/verify-ixes-coupon', {'code': code});
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. GET USER LIST  →  GET /api/coupon/get-users
  // Returns up to 10 users
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUserList() async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return _authError(['users']);

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/coupon/get-users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {'error': false, 'users': decoded['users'] ?? []};
      }
      return _parseError(response.body, {'users': []});
    } catch (e) {
      return _exception(e, {'users': []});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return _authError([]);

      final response = await http.post(
        Uri.parse('$apiBaseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'error': false, ...jsonDecode(response.body) as Map<String, dynamic>};
      }
      return _parseError(response.body, {});
    } catch (e) {
      return _exception(e, {});
    }
  }

  Map<String, dynamic> _authError(List<String> emptyKeys) => {
    'error': true,
    'message': 'Authentication token is missing',
    for (final k in emptyKeys) k: k.endsWith('s') ? [] : null,
  };

  Map<String, dynamic> _parseError(String body, Map<String, dynamic> defaults) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return {'error': true, 'message': decoded['message'] ?? decoded['error'] ?? 'Request failed', ...defaults};
    } catch (_) {
      return {'error': true, 'message': 'Request failed', ...defaults};
    }
  }

  Map<String, dynamic> _exception(Object e, Map<String, dynamic> defaults) =>
      {'error': true, 'message': 'Network error: ${e.toString()}', ...defaults};
}