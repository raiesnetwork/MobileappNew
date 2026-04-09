import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:ixes.app/services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart' as http_parser;

class ServicesService {
  Future<Map<String, dynamic>> getAllServices({int page = 1, int limit = 10}) async {
    try {
      print('🔍 Fetching ALL services - Page: $page, Limit: $limit');

      final response = await ApiService.get(
          '/api/service/fetchallservices?page=$page&limit=$limit');
      ApiService.checkResponse(response);

      print('📡 Status: ${response.statusCode}');
      print('📦 FULL Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final pagination = decoded['pagination'] ?? {};
        final services = decoded['data'] ?? [];

        print('📊 Services returned: ${services.length}');
        print('📊 Total from pagination: ${pagination['total']}');
        print('📊 Total pages: ${pagination['totalPages']}');
        print('📊 Current page: ${pagination['page']}');

        if (services.isNotEmpty) {
          print('📋 Service IDs in response:');
          for (var i = 0; i < services.length; i++) {
            print('   ${i + 1}. ID: ${services[i]['_id']} | Name: ${services[i]['name']} | Provider: ${services[i]['serviceProvider']} | Status: ${services[i]['status']}');
          }
        }

        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Success',
          'data': services,
          'totalPages': pagination['totalPages'] ?? 1,
          'currentPage': pagination['page'] ?? 1,
          'totalServices': pagination['total'] ?? 0
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('❌ Error response: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch services',
          'data': [],
          'totalPages': 0,
          'currentPage': 1,
          'totalServices': 0
        };
      }
    } catch (e, stackTrace) {
      print('💥 Exception in getAllServices: $e');
      print('Stack trace: $stackTrace');
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
      final endpoint = (communityId != null && communityId.isNotEmpty)
          ? '/api/service/allservices?communityId=$communityId'
          : '/api/service/allservices';

      print('🔍 Community ID: $communityId');

      final response = await ApiService.get(endpoint);
      ApiService.checkResponse(response);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> allServices = [];
        if (decoded['services'] != null) {
          allServices = decoded['services'];
        } else {
          final communityServices = decoded['communityServices'] ?? [];
          final userServices = decoded['userServices'] ?? [];
          final memberServices = decoded['memberServices'] ?? [];
          allServices = [...communityServices, ...userServices, ...memberServices];
        }

        print('✅ Combined Services Length: ${allServices.length}');

        return {
          'error': false,
          'message': decoded['message'] ?? 'Services fetched successfully',
          'data': allServices
        };
      } else {
        try {
          final decoded = jsonDecode(response.body);
          return {
            'error': true,
            'message': decoded['message'] ?? 'Failed to fetch services',
            'data': []
          };
        } catch (e) {
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
        return {'error': true, 'message': 'Authentication token is missing'};
      }

      final uri = Uri.parse('${apiBaseUrl}api/service/create-service');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

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

      for (var day in availableDays) {
        request.fields['availableDays'] = day;
      }

      if (image != null) {
        try {
          if (!await image.exists()) {
            return {'error': true, 'message': 'Selected image file does not exist'};
          }

          final fileSize = await image.length();
          print('📏 Original size: $fileSize bytes');

          File imageToUpload = image;

          if (fileSize > 500 * 1024) {
            final compressedBytes = await FlutterImageCompress.compressWithFile(
              image.path,
              quality: 70,
              minWidth: 1024,
              minHeight: 1024,
            );

            if (compressedBytes != null) {
              final tempDir = await getTemporaryDirectory();
              final tempPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final compressedFile = File(tempPath);
              await compressedFile.writeAsBytes(compressedBytes);
              imageToUpload = compressedFile;
            }
          }

          final finalSize = await imageToUpload.length();
          if (finalSize > 5 * 1024 * 1024) {
            return {'error': true, 'message': 'Image is too large. Please select a smaller image.'};
          }

          final extension = imageToUpload.path.split('.').last.toLowerCase();
          String mimeType = 'image/jpeg';
          if (extension == 'png') mimeType = 'image/png';
          else if (extension == 'webp') mimeType = 'image/webp';

          request.files.add(await http.MultipartFile.fromPath(
            'image',
            imageToUpload.path,
            contentType: http_parser.MediaType.parse(mimeType),
          ));
        } catch (e) {
          return {'error': true, 'message': 'Failed to process image: ${e.toString()}'};
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      ApiService.checkResponse(response); // ✅ 401 check

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 413) {
        return {'error': true, 'message': 'Image is too large for the server. Please select a smaller image.'};
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (e) {
        return {'error': true, 'message': 'Server returned invalid response. Status: ${response.statusCode}'};
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'error': decoded['err'] ?? decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Service created successfully',
          'data': decoded['service'] ?? {},
        };
      }

      return {'error': true, 'message': decoded['message'] ?? 'Failed to create service'};
    } catch (e, stackTrace) {
      print('💥 Exception: $e');
      print('Stack trace: $stackTrace');
      return {'error': true, 'message': 'Error creating service: ${e.toString()}'};
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

      final response = await ApiService.post('/api/service/edit-service', body);
      ApiService.checkResponse(response);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service updated successfully',
          'service': decoded['service'] ?? {},
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {'error': true, 'message': decoded['message'] ?? 'Failed to update service'};
      }
    } catch (e) {
      return {'error': true, 'message': 'Error updating service: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deleteService({required String serviceId}) async {
    try {
      final response = await ApiService.get(
          '/api/service/deleteService?serviceId=$serviceId');
      ApiService.checkResponse(response);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Service deleted successfully',
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {'err': true, 'message': decoded['message'] ?? 'Failed to delete service'};
      }
    } catch (e) {
      return {'err': true, 'message': 'Error deleting service: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getMyServices() async {
    try {
      final response = await ApiService.get('/api/service/myservices');
      ApiService.checkResponse(response);

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
        return {'error': true, 'message': decoded['message'] ?? 'Failed to fetch my services', 'myServices': []};
      }
    } catch (e) {
      return {'error': true, 'message': 'Error fetching my services: ${e.toString()}', 'myServices': []};
    }
  }

  Future<Map<String, dynamic>> activateService(String serviceId) async {
    try {
      final response = await ApiService.get(
          '/api/service/activateService?serviceId=$serviceId');
      ApiService.checkResponse(response);

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
        return {'err': true, 'message': decoded['message'] ?? 'Failed to activate service', 'service': {}};
      }
    } catch (e) {
      return {'err': true, 'message': 'Error activating service: ${e.toString()}', 'service': {}};
    }
  }

  Future<Map<String, dynamic>> deactivateService(String serviceId) async {
    try {
      final response = await ApiService.get(
          '/api/service/deactivateService?serviceId=$serviceId');
      ApiService.checkResponse(response);

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
        return {'err': true, 'message': decoded['message'] ?? 'Failed to deactivate service', 'service': {}};
      }
    } catch (e) {
      return {'err': true, 'message': 'Error deactivating service: ${e.toString()}', 'service': {}};
    }
  }

  Future<Map<String, dynamic>> getServiceDetails(String id) async {
    try {
      final response = await ApiService.get('/api/service/details/$id');
      ApiService.checkResponse(response);

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
        return {'error': true, 'message': decoded['message'] ?? 'Failed to fetch service details', 'data': {}};
      }
    } catch (e) {
      return {'error': true, 'message': 'Error fetching service details: ${e.toString()}', 'data': {}};
    }
  }

  Future<Map<String, dynamic>> getMyProducts() async {
    try {
      final response = await ApiService.get('/api/mobile/all-products');
      ApiService.checkResponse(response);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');   // Keep this for debugging

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Correct parsing for your actual API structure
        final productsList = decoded['data']?['products'] ?? [];

        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Products fetched successfully',
          'data': productsList,        // ← Now correctly passing the products list
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch products',
          'data': []
        };
      }
    } catch (e) {
      print('❌ Error in getMyProducts: $e');
      return {
        'error': true,
        'message': 'Error fetching products: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> createPaymentOrder({required num amount}) async {
    try {
      final response = await ApiService.post(
          '/api/service/create-order', {'amount': amount});
      ApiService.checkResponse(response);

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
        return {'err': true, 'message': decoded['message'] ?? 'Failed to create payment order', 'order': {}};
      }
    } catch (e) {
      return {'err': true, 'message': 'Error creating payment order: ${e.toString()}', 'order': {}};
    }
  }

  Future<Map<String, dynamic>> verifyPayment({
    required Map<String, dynamic> response,
    required String serviceId,
    required num amount,
    required String date,
    required int slots,
    required List<String> selectedSlots,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {'err': true, 'message': 'Authentication token is missing', 'booking': {}};
      }

      final body = {
        'response': response,
        'serviceId': serviceId,
        'amount': amount,
        'date': date,
        'slots': slots,
        'selectedSlots': selectedSlots,
      };

      print('📤 Request Body: ${jsonEncode(body)}');

      final httpResponse = await ApiService.post('/api/service/verify-payment', body);
      ApiService.checkResponse(httpResponse);

      print('📡 Response Status: ${httpResponse.statusCode}');
      print('📦 Response Body: ${httpResponse.body}');

      if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
        final decoded = jsonDecode(httpResponse.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Payment verified successfully',
          'booking': decoded['booking'] ?? {}
        };
      } else if (httpResponse.statusCode == 500) {
        print('⚠️ Server returned 500 - attempting fallback booking fetch...');
        try {
          final bookingResponse = await ApiService.get('/api/service/my-bookings?limit=1');
          ApiService.checkResponse(bookingResponse);

          if (bookingResponse.statusCode == 200) {
            final bookingDecoded = jsonDecode(bookingResponse.body);
            final bookings = bookingDecoded['bookings'] as List?;

            if (bookings != null && bookings.isNotEmpty) {
              final latestBooking = bookings.first;
              final bookingServiceId =
                  latestBooking['serviceId']?['_id'] ?? latestBooking['serviceId'];

              if (bookingServiceId?.toString() == serviceId) {
                return {'err': false, 'message': 'Payment verified successfully', 'booking': latestBooking};
              }
            }
          }
        } catch (fallbackError) {
          print('❌ Fallback booking fetch failed: $fallbackError');
        }

        final decoded = jsonDecode(httpResponse.body);
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to verify payment',
          'booking': {},
          'errorDetails': decoded['error']
        };
      } else {
        final decoded = jsonDecode(httpResponse.body);
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to verify payment',
          'booking': {},
          'errorDetails': decoded['error']
        };
      }
    } catch (e, stackTrace) {
      print('💥 Exception occurred: $e');
      print('💥 Stack trace: $stackTrace');
      return {'err': true, 'message': 'Error verifying payment: ${e.toString()}', 'booking': {}};
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
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (paymentStatus != null && paymentStatus.isNotEmpty) queryParams['paymentStatus'] = paymentStatus;
      if (fromDate != null && fromDate.isNotEmpty) queryParams['fromDate'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) queryParams['toDate'] = toDate;

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await ApiService.get('/api/service/my-bookings?$queryString');
      ApiService.checkResponse(response);

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
        return {'error': true, 'message': decoded['message'] ?? 'Failed to fetch bookings', 'data': []};
      }
    } catch (e) {
      return {'error': true, 'message': 'Error fetching bookings: ${e.toString()}', 'data': []};
    }
  }

  Future<Map<String, dynamic>> createPartnerOrder({
    required String dealerId,
    required num amount,
    required Map<String, dynamic> customerDetails,
  }) async {
    try {
      final body = {
        'dealerId': dealerId,
        'amount': amount,
        'customerDetails': customerDetails,
      };

      final response = await ApiService.post(
          '/api/onlinePayment/create-partner-order', body);
      ApiService.checkResponse(response);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['order'] != null && decoded['order']['error'] == 'No_OAuth') {
          return {'err': true, 'message': 'Dealer has not connected Razorpay OAuth', 'order': {}, 'key_id': ''};
        }
        return {
          'err': false,
          'message': 'Order created successfully',
          'order': decoded['order'] ?? {},
          'key_id': decoded['key_id'] ?? ''
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {'err': true, 'message': decoded['message'] ?? 'Failed to create partner order', 'order': {}, 'key_id': ''};
      }
    } catch (e) {
      return {'err': true, 'message': 'Error creating partner order: ${e.toString()}', 'order': {}, 'key_id': ''};
    }
  }

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

      final httpResponse = await ApiService.post(
          '/api/storuser/verify-payment', body);
      ApiService.checkResponse(httpResponse);

      print('📡 Response Status: ${httpResponse.statusCode}');
      print('📦 Response Body: ${httpResponse.body}');

      if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
        final decoded = jsonDecode(httpResponse.body);
        return {
          'err': decoded['err'] ?? false,
          'message': decoded['message'] ?? 'Payment completed and order created successfully',
          'data': decoded['data'] ?? {}
        };
      } else {
        final decoded = jsonDecode(httpResponse.body);
        return {
          'err': true,
          'message': decoded['message'] ?? 'Failed to verify payment',
          'data': {},
          'errorDetails': decoded['error']
        };
      }
    } catch (e, stackTrace) {
      print('💥 Exception occurred: $e');
      print('💥 Stack trace: $stackTrace');
      return {'err': true, 'message': 'Error verifying payment: ${e.toString()}', 'data': {}};
    }
  }
}