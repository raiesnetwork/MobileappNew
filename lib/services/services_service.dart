import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart' as http_parser;

class ServicesService {
  Future<Map<String, dynamic>> getAllServices({int page = 1, int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': [],
          'totalPages': 0,
          'currentPage': 1,
          'totalServices': 0
        };
      }

      final response = await http.get(
        Uri.parse('https://api.ixes.ai/api/service/fetchallservices?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Success',
          'data': decoded['data'] ?? [],
          'totalPages': decoded['totalPages'] ?? 1,
          'currentPage': decoded['currentPage'] ?? 1,
          'totalServices': decoded['totalServices'] ?? 0
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch services',
          'data': [],
          'totalPages': 0,
          'currentPage': 1,
          'totalServices': 0
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error fetching services: ${e.toString()}',
        'data': [],
        'totalPages': 0,
        'currentPage': 1,
        'totalServices': 0
      };
    }
  }

  Future<Map<String, dynamic>> getAllCommunityServices({String? communityId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': []
        };
      }

      final uri = communityId != null && communityId.isNotEmpty
          ? Uri.parse('${apiBaseUrl}api/service/allservices?communityId=$communityId')
          : Uri.parse('${apiBaseUrl}api/service/allservices');

      print('🔍 Community ID: $communityId');
      print('🌐 Request URI: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // FIXED: Handle different response structures
        List<dynamic> allServices = [];

        // Check if response has services directly
        if (decoded['services'] != null) {
          allServices = decoded['services'];
        } else {
          // Otherwise combine different service types
          final communityServices = decoded['communityServices'] ?? [];
          final userServices = decoded['userServices'] ?? [];
          final memberServices = decoded['memberServices'] ?? [];
          allServices = [...communityServices, ...userServices, ...memberServices];
        }

        print('✅ Combined Services Length: ${allServices.length}');
        print('📋 First service (if any): ${allServices.isNotEmpty ? allServices[0] : 'None'}');

        return {
          'error': false, // FIXED: Ensure error is false on success
          'message': decoded['message'] ?? 'Services fetched successfully',
          'data': allServices
        };
      } else {
        try {
          final decoded = jsonDecode(response.body);
          print('⚠️ Error from API: ${decoded['message']}');
          return {
            'error': true,
            'message': decoded['message'] ?? 'Failed to fetch services',
            'data': []
          };
        } catch (e) {
          print('⚠️ Failed to decode error response: $e');
          return {
            'error': true,
            'message': 'Server error: ${response.statusCode}',
            'data': []
          };
        }
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Network error: ${e.toString()}',
        'data': []
      };
    }
  }

  // FIXED VERSION - Key issues resolved:
// 1. API expects "image" as array but code sends single data URL string
// 2. API expects numbers for cost/slots but code sends strings
// 3. Missing proper error response handling

  Future<Map<String, dynamic>> createService({
    required String name,
    required String description,
    required String location,
    String? communityId,
    required String category,
    required String subCategory,
    required String openHourFrom,
    required String openHourEnd,
    required String cost,
    required String slots,
    required String currency,
    required String costPer,
    required String serviceProvider,
    required List<String> availableDays,
    File? image,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('🔑 Token: $token');

      if (token == null || token.isEmpty) {
        print('❌ Token missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/create-service');
      print('📤 API URL: $uri');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields - matching the exact format from your Postman test
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['location'] = location;
      if (communityId != null && communityId.isNotEmpty) {
        request.fields['communityId'] = communityId;
      }
      request.fields['mainCategory'] = category;
      request.fields['subCategory'] = subCategory;
      request.fields['cost'] = cost;
      request.fields['currency'] = currency;
      request.fields['serviceProvider'] = serviceProvider;
      request.fields['slots'] = slots;

      // Add availableDays as multiple fields with the same name (standard form array format)
      for (var day in availableDays) {
        request.fields['availableDays'] = day;
      }

      print('📤 Available days being sent: $availableDays');

      // Add image file if provided
      if (image != null) {
        try {
          print('📸 Processing image: ${image.path}');

          if (!await image.exists()) {
            print('❌ Image file does not exist');
            return {
              'error': true,
              'message': 'Selected image file does not exist',
            };
          }

          final fileSize = await image.length();
          print('📏 Image file size: ${fileSize} bytes');

          if (fileSize > 5 * 1024 * 1024) {
            print('❌ Image file too large');
            return {
              'error': true,
              'message': 'Image file is too large. Please select an image smaller than 5MB',
            };
          }

          // Determine MIME type
          final extension = image.path.split('.').last.toLowerCase();
          String mimeType;
          switch (extension) {
            case 'jpg':
            case 'jpeg':
              mimeType = 'image/jpeg';
              break;
            case 'png':
              mimeType = 'image/png';
              break;
            case 'webp':
              mimeType = 'image/webp';
              break;
            default:
              mimeType = 'image/jpeg';
          }

          // Add file to multipart request
          final multipartFile = await http.MultipartFile.fromPath(
            'image',
            image.path,
            contentType: http_parser.MediaType.parse(mimeType),
          );

          request.files.add(multipartFile);
          print('✅ Image added to multipart request with mime type: $mimeType');
        } catch (e) {
          print('💥 Image processing error: $e');
          return {
            'error': true,
            'message': 'Failed to process image: ${e.toString()}',
          };
        }
      } else {
        print('⚠️ No image selected');
      }

      print('📤 Sending multipart request...');
      print('📦 Fields: ${request.fields.keys.toList()}');
      print('📦 Files: ${request.files.length}');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      // Parse response
      final decoded = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Service created successfully');

        // Check response structure - API returns 'err' not 'error'
        final hasError = decoded['err'] ?? decoded['error'] ?? false;

        return {
          'error': hasError,
          'message': decoded['message'] ?? 'Service created successfully',
          'data': decoded['service'] ?? {},
        };
      } else {
        print('⚠️ Service creation failed');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create service',
        };
      }
    } catch (e, stackTrace) {
      print('💥 Exception occurred: $e');
      print('Stack trace: $stackTrace');
      return {
        'error': true,
        'message': 'Error creating service: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> editService({
    required String id,
    String? name,
    String? description,
    List<String>? image,
    String? location,
    String? communityId,
    String? category,
    String? subCategory,
    num? cost,
    num? slots,
    String? currency,
    List<String>? availableDays,
    String? costPer,
    String? openHourFrom,
    String? openHourEnd,
    String? serviceProvider,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
        };
      }

      final body = {
        '_id': id,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (image != null) 'image': image,
        if (location != null) 'location': location,
        if (communityId != null) 'communityId': communityId,
        if (category != null) 'category': category,
        if (subCategory != null) 'subCategory': subCategory,
        if (cost != null) 'cost': cost,
        if (slots != null) 'slots': slots,
        if (currency != null) 'currency': currency,
        if (availableDays != null) 'availableDays': availableDays,
        if (costPer != null) 'costPer': costPer,
        if (openHourFrom != null) 'openHourFrom': openHourFrom,
        if (openHourEnd != null) 'openHourEnd': openHourEnd,
        if (serviceProvider != null) 'serviceProvider': serviceProvider,
      };

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/service/edit-service'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service updated successfully',
          'service': decoded['service'] ?? {},
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update service',
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error updating service: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> deleteService({
    required String serviceId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {'err': true, 'message': 'Authentication token is missing'};
      }

      final response = await http.get(
        Uri.parse(
            '${apiBaseUrl}api/service/deleteService?serviceId=$serviceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service deleted successfully',
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to delete service',
        };
      }
    } catch (e) {
      return {
        'err': true,
        'message': 'Error deleting service: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getMyServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'myServices': []
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/myservices');
      print('🔍 Fetching my services from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Success',
          'myServices': decoded['myServices'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch my services',
          'myServices': []
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching my services: ${e.toString()}',
        'myServices': []
      };
    }
  }
  Future<Map<String, dynamic>> activateService(String serviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'err': true,
          'message': 'Authentication token is missing',
          'service': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/activateService?serviceId=$serviceId');
      print('🔍 Activating service from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service activated successfully',
          'service': decoded['service'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to activate service',
          'service': {}
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'err': true,
        'message': 'Error activating service: ${e.toString()}',
        'service': {}
      };
    }
  }

  Future<Map<String, dynamic>> deactivateService(String serviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'err': true,
          'message': 'Authentication token is missing',
          'service': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/deactivateService?serviceId=$serviceId');
      print('🔍 Deactivating service from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service deactivated successfully',
          'service': decoded['service'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to deactivate service',
          'service': {}
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'err': true,
        'message': 'Error deactivating service: ${e.toString()}',
        'service': {}
      };
    }
  }
  Future<Map<String, dynamic>> getServiceDetails(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/details/$id');
      print('🔍 Fetching service details from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Service details fetched successfully',
          'data': decoded['data'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch service details',
          'data': {}
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching service details: ${e.toString()}',
        'data': {}
      };
    }
  }
  Future<Map<String, dynamic>> getMyProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': [],
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/myproducts');
      print('🔍 Fetching my products from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Products fetched successfully',
          'data': decoded['myProducts'] ?? [],
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch products',
          'data': [],
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching products: ${e.toString()}',
        'data': [],
      };
    }
  }


  /// Create Razorpay Payment Order
  Future<Map<String, dynamic>> createPaymentOrder({
    required num amount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'err': true,
          'message': 'Authentication token is missing',
          'order': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/create-order');
      print('🔍 Creating payment order at: $uri');
      print('💰 Amount: $amount');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
        }),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Order created successfully',
          'order': decoded['order'] ?? {}
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to create payment order',
          'order': {}
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'err': true,
        'message': 'Error creating payment order: ${e.toString()}',
        'order': {}
      };
    }
  }

  /// Verify Payment and Create Booking
  Future<Map<String, dynamic>> verifyPayment({
    required Map<String, dynamic> response,
    required String serviceId,
    required num amount,
    required String date,
    required int slots,
    required List<String> selectedSlots, // ✅ ADDED
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'err': true,
          'message': 'Authentication token is missing',
          'booking': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/verify-payment');
      print('🔍 Verifying payment at: $uri');
      print('📦 Service ID: $serviceId');
      print('💰 Amount: $amount');
      print('📅 Date: $date');
      print('🎫 Slots count: $slots');
      print('🎫 Selected slots: $selectedSlots'); // ✅ ADDED LOG

      final body = {
        'response': response,
        'serviceId': serviceId,
        'amount': amount,
        'date': date,
        'slots': slots,
        'selectedSlots': selectedSlots, // ✅ ADDED TO BODY
      };

      print('📤 Request Body: ${jsonEncode(body)}');

      final httpResponse = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('📡 Response Status: ${httpResponse.statusCode}');
      print('📦 Response Body: ${httpResponse.body}');

      if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
        final decoded = jsonDecode(httpResponse.body);
        print('✅ Success Response - err: ${decoded['err']}');
        print('✅ Success Response - message: ${decoded['message']}');
        print('✅ Success Response - booking: ${decoded['booking']}');

        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Payment verified and booking created successfully',
          'booking': decoded['booking'] ?? {}
        };
      } else {
        final decoded = jsonDecode(httpResponse.body);

        // DETAILED ERROR LOGGING
        print('❌ HTTP Error - Status Code: ${httpResponse.statusCode}');
        print('❌ Error Response - Full Body: ${httpResponse.body}');
        print('❌ Error Response - err: ${decoded['err']}');
        print('❌ Error Response - message: ${decoded['message']}');
        print('❌ Error Response - error object: ${decoded['error']}');

        // Check if error object has more details
        if (decoded['error'] != null && decoded['error'] is Map) {
          final errorMap = decoded['error'] as Map;
          print('❌ Error Details:');
          errorMap.forEach((key, value) {
            print('   - $key: $value');
          });
        }

        // Check for any other fields in response
        print('❌ All response keys: ${decoded.keys.toList()}');

        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to verify payment',
          'booking': {},
          'errorDetails': decoded['error'] // Include error details
        };
      }
    } catch (e, stackTrace) {
      print('💥 Exception occurred: $e');
      print('💥 Exception type: ${e.runtimeType}');
      print('💥 Stack trace: $stackTrace');

      return {
        'err': true,
        'message': 'Error verifying payment: ${e.toString()}',
        'booking': {}
      };
    }
  }
  Future<Map<String, dynamic>> getMyBookings({
    int page = 1,
    int limit = 10,
    String? paymentStatus,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': [],
        };
      }

      // Build query parameters
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (paymentStatus != null && paymentStatus.isNotEmpty) {
        queryParams['paymentStatus'] = paymentStatus;
      }

      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }

      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/my-bookings')
          .replace(queryParameters: queryParams);
      print('🔍 Fetching my bookings from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Bookings fetched successfully',
          'data': decoded['bookings'] ?? [],
          'page': decoded['page'] ?? page,
          'limit': decoded['limit'] ?? limit,
          'totalBookings': decoded['totalBookings'] ?? 0,
          'totalPages': decoded['totalPages'] ?? 0,
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch bookings',
          'data': [],
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching bookings: ${e.toString()}',
        'data': [],
      };
    }
  }
  /// Create Partner Razorpay Order
  Future<Map<String, dynamic>> createPartnerOrder({
    required String dealerId,
    required num amount,
    required Map<String, dynamic> customerDetails,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'err': true,
          'message': 'Authentication token is missing',
          'order': {},
          'key_id': ''
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/onlinePayment/create-partner-order');
      print('🔍 Creating partner order at: $uri');
      print('💰 Amount: $amount');
      print('👤 Customer: ${customerDetails['name']}');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'dealerId': dealerId,
          'amount': amount,
          'customerDetails': customerDetails,
        }),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        // Check for No_OAuth error
        if (decoded['order'] != null && decoded['order']['error'] == 'No_OAuth') {
          return {
            'err': true,
            'message': 'Dealer has not connected Razorpay OAuth',
            'order': {},
            'key_id': ''
          };
        }

        return {
          'err': false,
          'message': 'Order created successfully',
          'order': decoded['order'] ?? {},
          'key_id': decoded['key_id'] ?? ''
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to create partner order',
          'order': {},
          'key_id': ''
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'err': true,
        'message': 'Error creating partner order: ${e.toString()}',
        'order': {},
        'key_id': ''
      };
    }
  }

  /// Verify Razorpay Payment and Create Order
  Future<Map<String, dynamic>> verifyPaymentAndCreateOrder({
    required Map<String, dynamic> response,
    required List<Map<String, dynamic>> productDetails,
    required num totalAmount,
    required String paymentMethod,
    required String addressId,
    Map<String, dynamic>? couponData,
    required String type,
    String? businessDealerId,
    required String courierId,
    required String dealerId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'err': true,
          'message': 'Authentication token is missing',
          'data': {}
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/storuser/verify-payment');
      print('🔍 Verifying payment at: $uri');
      print('💰 Total Amount: $totalAmount');
      print('📦 Products: ${productDetails.length}');

      final body = {
        'datas': {
          'response': response,
          'productDetails': productDetails,
          'totalAmount': totalAmount,
          'paymentMethod': paymentMethod,
          'addressId': addressId,
          'couponData': couponData,
          'type': type,
          'businessDealerId': businessDealerId,
          'CourierId': courierId,
          'dealerId': dealerId,
        }
      };

      print('📤 Request Body: ${jsonEncode(body)}');

      final httpResponse = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('📡 Response Status: ${httpResponse.statusCode}');
      print('📦 Response Body: ${httpResponse.body}');

      if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
        final decoded = jsonDecode(httpResponse.body);
        print('✅ Success Response - err: ${decoded['err']}');
        print('✅ Success Response - message: ${decoded['message']}');
        print('✅ Success Response - data: ${decoded['data']}');

        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Payment completed and order created successfully',
          'data': decoded['data'] ?? {}
        };
      } else {
        final decoded = jsonDecode(httpResponse.body);

        // DETAILED ERROR LOGGING
        print('❌ HTTP Error - Status Code: ${httpResponse.statusCode}');
        print('❌ Error Response - Full Body: ${httpResponse.body}');
        print('❌ Error Response - err: ${decoded['err']}');
        print('❌ Error Response - message: ${decoded['message']}');

        // Check if error object has more details
        if (decoded['error'] != null && decoded['error'] is Map) {
          final errorMap = decoded['error'] as Map;
          print('❌ Error Details:');
          errorMap.forEach((key, value) {
            print('   - $key: $value');
          });
        }

        print('❌ All response keys: ${decoded.keys.toList()}');

        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to verify payment',
          'data': {},
          'errorDetails': decoded['error']
        };
      }
    } catch (e, stackTrace) {
      print('💥 Exception occurred: $e');
      print('💥 Exception type: ${e.runtimeType}');
      print('💥 Stack trace: $stackTrace');

      return {
        'err': true,
        'message': 'Error verifying payment: ${e.toString()}',
        'data': {}
      };
    }
  }

}

