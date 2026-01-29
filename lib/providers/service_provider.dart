import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:ixes.app/services/services_service.dart';

class ServicesProvider with ChangeNotifier {
  final ServicesService _service = ServicesService();

  // Separate loading states
  bool _isLoading = false;
  bool _isMyServicesLoading = false;
  bool _isCommunityServicesLoading = false;
  bool _isServiceActionLoading = false;
  bool _isServiceDetailsLoading = false;
  bool _isMyProductsLoading = false;
  String _razorpayKeyId = 'rzp_test_R9SkYwGQh6HuUF';
  Map<String, dynamic> _orderData = {};

  // Separate error states
  bool _hasError = false;
  bool _hasMyServicesError = false;
  bool _hasCommunityServicesError = false;
  bool _hasServiceActionError = false;
  bool _hasServiceDetailsError = false;
  bool _hasMyProductsError = false;

  // Separate messages
  String _message = '';
  String _myServicesMessage = '';
  String _communityServicesMessage = '';
  String _serviceActionMessage = '';
  String _serviceDetailsMessage = '';
  String _myProductsMessage = '';

  // Separate data lists
  List<dynamic> _services = [];
  List<dynamic> _myServices = [];
  List<dynamic> _communityServices = [];
  Map<String, dynamic> _serviceDetails = {};
  List<dynamic> _myProducts = [];

  // Pagination properties for All Services
  int _servicesCurrentPage = 1;
  int _servicesTotalPages = 1;
  int _servicesTotalCount = 0;
  bool _isLoadingMoreServices = false;
  final int _servicesLimit = 10;

  int _currentTabIndex = 0;

  // Getters for All Services
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get message => _message;
  List<dynamic> get services => _services;

  // Pagination getters for All Services
  int get servicesCurrentPage => _servicesCurrentPage;
  int get servicesTotalPages => _servicesTotalPages;
  int get servicesTotalCount => _servicesTotalCount;
  bool get isLoadingMoreServices => _isLoadingMoreServices;
  bool get hasMoreServices => _servicesCurrentPage < _servicesTotalPages;

  // Getters for My Services
  bool get isMyServicesLoading => _isMyServicesLoading;
  bool get hasMyServicesError => _hasMyServicesError;
  String get myServicesMessage => _myServicesMessage;
  List<dynamic> get myServices => _myServices;

  // Getters for Community Services
  bool get isCommunityServicesLoading => _isCommunityServicesLoading;
  bool get hasCommunityServicesError => _hasCommunityServicesError;
  String get communityServicesMessage => _communityServicesMessage;
  List<dynamic> get communityServices => _communityServices;

  // Getters for Service Actions (activate/deactivate)
  bool get isServiceActionLoading => _isServiceActionLoading;
  bool get hasServiceActionError => _hasServiceActionError;
  String get serviceActionMessage => _serviceActionMessage;

  // Getters for Service Details
  bool get isServiceDetailsLoading => _isServiceDetailsLoading;
  bool get hasServiceDetailsError => _hasServiceDetailsError;
  String get serviceDetailsMessage => _serviceDetailsMessage;
  Map<String, dynamic> get serviceDetails => _serviceDetails;

  // Getters for My Products
  bool get isMyProductsLoading => _isMyProductsLoading;
  bool get hasMyProductsError => _hasMyProductsError;
  String get myProductsMessage => _myProductsMessage;
  List<dynamic> get myProducts => _myProducts;

  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
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
    // 1. Set loading state
    _isLoading = true;
    _hasError = false;
    _message = '';
    notifyListeners();

    try {
      // 2. Call service to create
      final response = await _service.createService(
        name: name,
        description: description,
        location: location,
        communityId: communityId,
        category: category,
        subCategory: subCategory,
        openHourFrom: openHourFrom,
        openHourEnd: openHourEnd,
        cost: cost,
        slots: slots,
        currency: currency,
        costPer: costPer,
        serviceProvider: serviceProvider,
        availableDays: availableDays,
        image: image,
      );

      // 3. Handle response
      if (!response['error']) {
        _message = response['message'] ?? 'Service created successfully';
        _hasError = false;

        // 4. Refresh all services list
        print('🔄 Refreshing services list...');
        await fetchServices(refresh: true);

        // 5. Refresh community services if applicable
        if (communityId != null && communityId.isNotEmpty) {
          print('🔄 Refreshing community services...');
          await fetchCommunityServices(communityId: communityId);
        }

        // 6. Refresh my services
        print('🔄 Refreshing my services...');
        await fetchMyServices();

        print('✅ All services refreshed');
      } else {
        _hasError = true;
        _message = response['message'] ?? 'Failed to create service';
        print('❌ Error: $_message');
      }

      // 7. Update loading state
      _isLoading = false;
      notifyListeners();

      // 8. Return response
      return response;
    } catch (e) {
      print('💥 Provider exception: $e');
      _hasError = true;
      _message = 'Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();

      return {
        'error': true,
        'message': _message,
      };
    }
  }

  /// Fetch all services with pagination
  Future<void> fetchServices({bool refresh = false}) async {
    // Reset pagination on refresh
    if (refresh) {
      _servicesCurrentPage = 1;
      _services = [];
    }

    _isLoading = true;
    _hasError = false;
    notifyListeners();

    final response = await _service.getAllServices(
      page: _servicesCurrentPage,
      limit: _servicesLimit,
    );

    if (!response['error']) {
      _services = response['data'];
      _message = response['message'];
      _servicesTotalPages = response['totalPages'] ?? 1;
      _servicesCurrentPage = response['currentPage'] ?? 1;
      _servicesTotalCount = response['totalServices'] ?? 0;
      _hasError = false;
      print('✅ Fetched ${_services.length} services');
    } else {
      _hasError = true;
      _message = response['message'];
      _services = [];
      print('❌ Fetch error: $_message');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load more services (pagination)
  Future<void> loadMoreServices() async {
    if (_isLoadingMoreServices || !hasMoreServices) return;

    _isLoadingMoreServices = true;
    notifyListeners();

    try {
      final response = await _service.getAllServices(
        page: _servicesCurrentPage + 1,
        limit: _servicesLimit,
      );

      if (!response['error']) {
        _services.addAll(response['data'] ?? []);
        _servicesCurrentPage = response['currentPage'] ?? _servicesCurrentPage + 1;
        _servicesTotalPages = response['totalPages'] ?? _servicesTotalPages;
        _servicesTotalCount = response['totalServices'] ?? _servicesTotalCount;
        _message = response['message'];
        print('✅ Loaded more services. Total: ${_services.length}');
      } else {
        print('❌ Error loading more: ${response['message']}');
      }
    } catch (e) {
      print('💥 Exception loading more: $e');
    } finally {
      _isLoadingMoreServices = false;
      notifyListeners();
    }
  }

  /// Fetch user's own services
  Future<void> fetchMyServices() async {
    _isMyServicesLoading = true;
    _hasMyServicesError = false;
    _myServices = [];
    notifyListeners();

    final response = await _service.getMyServices();

    if (!response['error']) {
      _myServices = response['myServices'] ?? [];
      _myServicesMessage = response['message'] ?? 'My services fetched successfully';
      print('✅ Fetched ${_myServices.length} my services');
    } else {
      _hasMyServicesError = true;
      _myServicesMessage = response['message'] ?? 'Failed to fetch my services';
      _myServices = [];
      print('❌ My services error: $_myServicesMessage');
    }

    _isMyServicesLoading = false;
    notifyListeners();
  }

  /// Fetch community services
  Future<void> fetchCommunityServices({String? communityId}) async {
    print('🚀 Fetching community services: $communityId');

    _isCommunityServicesLoading = true;
    _hasCommunityServicesError = false;
    _communityServices = [];
    _communityServicesMessage = 'Loading...';
    notifyListeners();

    try {
      final response = await _service.getAllCommunityServices(communityId: communityId);

      if (!response['error']) {
        _communityServices = List<dynamic>.from(response['data'] ?? []);
        _communityServicesMessage = response['message'] ?? 'Success';
        _hasCommunityServicesError = false;
        print('✅ Fetched ${_communityServices.length} community services');
      } else {
        _hasCommunityServicesError = true;
        _communityServicesMessage = response['message'] ?? 'Unknown error';
        _communityServices = [];
        print('❌ Community services error: $_communityServicesMessage');
      }
    } catch (e) {
      print('💥 Exception: $e');
      _hasCommunityServicesError = true;
      _communityServicesMessage = 'Failed to load: ${e.toString()}';
      _communityServices = [];
    }

    _isCommunityServicesLoading = false;
    notifyListeners();
  }

  Future<void> editService({
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
    _isMyServicesLoading = true;
    _hasMyServicesError = false;
    notifyListeners();

    final response = await _service.editService(
      id: id,
      name: name,
      description: description,
      image: image,
      location: location,
      communityId: communityId,
      category: category,
      subCategory: subCategory,
      cost: cost,
      slots: slots,
      currency: currency,
      availableDays: availableDays,
      costPer: costPer,
      openHourFrom: openHourFrom,
      openHourEnd: openHourEnd,
      serviceProvider: serviceProvider,
    );

    if (!response['error']) {
      _myServicesMessage = response['message'];
      await fetchMyServices();
      if (communityId != null && communityId.isNotEmpty) {
        await fetchCommunityServices(communityId: communityId);
      }
    } else {
      _hasMyServicesError = true;
      _myServicesMessage = response['message'];
    }

    _isMyServicesLoading = false;
    notifyListeners();
  }

  Future<void> deleteService({
    required String serviceId,
    String? communityId,
  }) async {
    final serviceIndex =
    _myServices.indexWhere((service) => service['_id'] == serviceId);
    dynamic removedService;

    if (serviceIndex != -1) {
      removedService = _myServices.removeAt(serviceIndex);
      notifyListeners();
    }

    final response = await _service.deleteService(serviceId: serviceId);

    if (!response['err']) {
      _myServicesMessage =
          response['message'] ?? 'Service deleted successfully';
      _hasMyServicesError = false;
    } else {
      if (removedService != null && serviceIndex != -1) {
        _myServices.insert(serviceIndex, removedService);
      }
      _hasMyServicesError = true;
      _myServicesMessage = response['message'] ?? 'Failed to delete service';
    }

    if (communityId != null && communityId.isNotEmpty) {
      await fetchCommunityServices(communityId: communityId);
    }

    notifyListeners();
  }

  Future<void> activateMyService(String serviceId) async {
    _isServiceActionLoading = true;
    _hasServiceActionError = false;
    _serviceActionMessage = '';
    notifyListeners();

    final response = await _service.activateService(serviceId);
    if (!response['err']) {
      _serviceActionMessage =
          response['message'] ?? 'Service activated successfully';
      _myServices = _myServices.map((service) {
        if (service['_id'] == serviceId) {
          return response['service'] ?? service;
        }
        return service;
      }).toList();
      final service = _myServices.firstWhere(
            (service) => service['_id'] == serviceId,
        orElse: () => null,
      );
      if (service != null &&
          service['communityId'] != null &&
          service['communityId'].isNotEmpty) {
        await fetchCommunityServices(communityId: service['communityId']);
      }
    } else {
      _hasServiceActionError = true;
      _serviceActionMessage =
          response['message'] ?? 'Failed to activate service';
    }

    _isServiceActionLoading = false;
    notifyListeners();
  }

  Future<void> deactivateMyService(String serviceId) async {
    _isServiceActionLoading = true;
    _hasServiceActionError = false;
    _serviceActionMessage = '';
    notifyListeners();

    final response = await _service.deactivateService(serviceId);
    if (!response['err']) {
      _serviceActionMessage =
          response['message'] ?? 'Service deactivated successfully';
      _myServices = _myServices.map((service) {
        if (service['_id'] == serviceId) {
          return response['service'] ?? service;
        }
        return service;
      }).toList();
      final service = _myServices.firstWhere(
            (service) => service['_id'] == serviceId,
        orElse: () => null,
      );
      if (service != null &&
          service['communityId'] != null &&
          service['communityId'].isNotEmpty) {
        await fetchCommunityServices(communityId: service['communityId']);
      }
    } else {
      _hasServiceActionError = true;
      _serviceActionMessage =
          response['message'] ?? 'Failed to deactivate service';
    }

    _isServiceActionLoading = false;
    notifyListeners();
  }

  Future<void> fetchServiceDetails(String id) async {
    _isLoading = true;
    _hasError = false;
    _message = '';
    notifyListeners();

    final response = await _service.getServiceDetails(id);
    if (!response['error']) {
      _services = [response['data']];
      _message = response['message'] ?? 'Service details fetched successfully';
    } else {
      _hasError = true;
      _message = response['message'] ?? 'Failed to fetch service details';
      _services = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchServiceDetailsSeparate(String id) async {
    _isServiceDetailsLoading = true;
    _hasServiceDetailsError = false;
    _serviceDetailsMessage = '';
    _serviceDetails = {};
    notifyListeners();

    final response = await _service.getServiceDetails(id);
    if (!response['error']) {
      _serviceDetails = response['data'] ?? {};
      _serviceDetailsMessage =
          response['message'] ?? 'Service details fetched successfully';
    } else {
      _hasServiceDetailsError = true;
      _serviceDetailsMessage =
          response['message'] ?? 'Failed to fetch service details';
      _serviceDetails = {};
    }

    _isServiceDetailsLoading = false;
    notifyListeners();
  }

  Future<void> fetchMyProducts() async {
    _isMyProductsLoading = true;
    _hasMyProductsError = false;
    _myProductsMessage = '';
    _myProducts = [];
    notifyListeners();

    final response = await _service.getMyProducts();
    if (!response['error']) {
      _myProducts = response['data'] ?? [];
      _myProductsMessage =
          response['message'] ?? 'Products fetched successfully';
    } else {
      _hasMyProductsError = true;
      _myProductsMessage = response['message'] ?? 'Failed to fetch products';
      _myProducts = [];
    }

    _isMyProductsLoading = false;
    notifyListeners();
  }

  // Payment properties
  bool _isPaymentLoading = false;
  bool _hasPaymentError = false;
  String _paymentMessage = '';
  Map<String, dynamic> _paymentOrder = {};
  Map<String, dynamic> _booking = {};

  // Payment getters
  bool get isPaymentLoading => _isPaymentLoading;
  bool get hasPaymentError => _hasPaymentError;
  String get paymentMessage => _paymentMessage;
  Map<String, dynamic> get paymentOrder => _paymentOrder;
  Map<String, dynamic> get booking => _booking;

  /// Create Payment Order
  Future<Map<String, dynamic>> createPaymentOrder({
    required num amount,
  }) async {
    _isPaymentLoading = true;
    _hasPaymentError = false;
    _paymentMessage = '';
    _paymentOrder = {};
    notifyListeners();

    try {
      final response = await _service.createPaymentOrder(amount: amount);

      if (!response['err']) {
        _paymentOrder = response['order'] ?? {};
        _paymentMessage = response['message'] ?? 'Order created successfully';
        _hasPaymentError = false;
        print('✅ Payment order created: $_paymentOrder');
      } else {
        _hasPaymentError = true;
        _paymentMessage = response['message'] ?? 'Failed to create payment order';
        _paymentOrder = {};
        print('❌ Failed to create payment order: $_paymentMessage');
      }

      _isPaymentLoading = false;
      notifyListeners();

      return response;
    } catch (e) {
      print('💥 Provider exception: $e');
      _hasPaymentError = true;
      _paymentMessage = 'Error: ${e.toString()}';
      _paymentOrder = {};
      _isPaymentLoading = false;
      notifyListeners();

      return {
        'err': true,
        'message': _paymentMessage,
        'order': {}
      };
    }
  }


  Future<Map<String, dynamic>> verifyPayment({
    required Map<String, dynamic> response,
    required String serviceId,
    required num amount,
    required String date,
    required int slots,
    required List<String> selectedSlots, // ✅ ADDED
  }) async {
    _isPaymentLoading = true;
    _hasPaymentError = false;
    _paymentMessage = '';
    _booking = {};
    notifyListeners();

    try {
      final result = await _service.verifyPayment(
        response: response,
        serviceId: serviceId,
        amount: amount,
        date: date,
        slots: slots,
        selectedSlots: selectedSlots, // ✅ PASS IT TO SERVICE
      );

      if (!result['err']) {
        _booking = result['booking'] ?? {};
        _paymentMessage = result['message'] ?? 'Payment verified successfully';
        _hasPaymentError = false;
        print('✅ Payment verified and booking created: $_booking');

        // Optionally refresh services after booking
        await fetchMyServices();
      } else {
        _hasPaymentError = true;
        _paymentMessage = result['message'] ?? 'Failed to verify payment';
        _booking = {};
        print('❌ Payment verification failed: $_paymentMessage');
      }

      _isPaymentLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      print('💥 Provider exception: $e');
      _hasPaymentError = true;
      _paymentMessage = 'Error: ${e.toString()}';
      _booking = {};
      _isPaymentLoading = false;
      notifyListeners();

      return {
        'err': true,
        'message': _paymentMessage,
        'booking': {}
      };
    }
  }

  // Bookings properties
  List<dynamic> _myBookings = [];
  bool _isLoadingBookings = false;
  String _bookingsError = '';
  int _currentPage = 1;
  int _totalBookings = 0;
  int _totalPages = 0;
  String? _paymentStatusFilter;

  // Bookings getters
  List<dynamic> get myBookings => _myBookings;
  bool get isLoadingBookings => _isLoadingBookings;
  String get bookingsError => _bookingsError;
  int get totalBookings => _totalBookings;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMoreBookings => _currentPage < _totalPages;

  Future<void> fetchMyBookings({
    int? page,
    String? paymentStatus,
    bool loadMore = false,
  }) async {
    if (_isLoadingBookings) return;

    _isLoadingBookings = true;
    _bookingsError = '';

    if (paymentStatus != null) _paymentStatusFilter = paymentStatus;

    if (loadMore) {
      _currentPage++;
    } else if (page != null) {
      _currentPage = page;
    } else {
      _currentPage = 1;
      _myBookings.clear();
    }

    notifyListeners();

    try {
      final response = await _service.getMyBookings(
        page: _currentPage,
        limit: 10,
        paymentStatus: _paymentStatusFilter,
      );

      if (response['error'] == true) {
        _bookingsError = response['message'] ?? 'Failed to fetch bookings';
      } else {
        if (loadMore) {
          _myBookings.addAll(response['data'] ?? []);
        } else {
          _myBookings = response['data'] ?? [];
        }

        _totalBookings = response['totalBookings'] ?? 0;
        _totalPages = response['totalPages'] ?? 0;
      }
    } catch (e) {
      _bookingsError = 'Error: ${e.toString()}';
      print('💥 Provider Error: $e');
    } finally {
      _isLoadingBookings = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreBookings() async {
    if (hasMoreBookings && !_isLoadingBookings) {
      await fetchMyBookings(loadMore: true);
    }
  }

  Future<void> filterBookingsByStatus(String? status) async {
    _paymentStatusFilter = status;
    await fetchMyBookings();
  }

  Future<void> refreshBookings() async {
    _currentPage = 1;
    _myBookings.clear();
    await fetchMyBookings();
  }
  /// Create Partner Order
  Future<Map<String, dynamic>> createPartnerOrder({
    required String dealerId,
    required num amount,
    required Map<String, dynamic> customerDetails,
  }) async {
    _isPaymentLoading = true;
    _hasPaymentError = false;
    _paymentMessage = '';
    _paymentOrder = {};
    notifyListeners();

    try {
      final response = await _service.createPartnerOrder(
        dealerId: dealerId,
        amount: amount,
        customerDetails: customerDetails,
      );

      if (!response['err']) {
        _paymentOrder = response['order'] ?? {};
        _razorpayKeyId = response['key_id'] ?? '';
        _paymentMessage = response['message'] ?? 'Order created successfully';
        _hasPaymentError = false;
        print('✅ Partner payment order created: $_paymentOrder');
        print('🔑 Razorpay Key ID: $_razorpayKeyId');
      } else {
        _hasPaymentError = true;
        _paymentMessage = response['message'] ?? 'Failed to create partner order';
        _paymentOrder = {};
        _razorpayKeyId = '';
        print('❌ Failed to create partner order: $_paymentMessage');
      }

      _isPaymentLoading = false;
      notifyListeners();

      return response;
    } catch (e) {
      print('💥 Provider exception: $e');
      _hasPaymentError = true;
      _paymentMessage = 'Error: ${e.toString()}';
      _paymentOrder = {};
      _razorpayKeyId = '';
      _isPaymentLoading = false;
      notifyListeners();

      return {
        'err': true,
        'message': _paymentMessage,
        'order': {},
        'key_id': ''
      };
    }
  }

  /// Verify Payment and Create Order
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
    _isPaymentLoading = true;
    _hasPaymentError = false;
    _paymentMessage = '';
    _orderData = {};
    notifyListeners();

    try {
      final result = await _service.verifyPaymentAndCreateOrder(
        response: response,
        productDetails: productDetails,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        addressId: addressId,
        couponData: couponData,
        type: type,
        businessDealerId: businessDealerId,
        courierId: courierId,
        dealerId: dealerId,
      );

      if (!result['err']) {
        _orderData = result['data'] ?? {};
        _paymentMessage = result['message'] ?? 'Payment verified and order created successfully';
        _hasPaymentError = false;
        print('✅ Payment verified and order created: $_orderData');

        // Optionally refresh orders after creation
        // await fetchMyOrders();
      } else {
        _hasPaymentError = true;
        _paymentMessage = result['message'] ?? 'Failed to verify payment';
        _orderData = {};
        print('❌ Payment verification failed: $_paymentMessage');
      }

      _isPaymentLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      print('💥 Provider exception: $e');
      _hasPaymentError = true;
      _paymentMessage = 'Error: ${e.toString()}';
      _orderData = {};
      _isPaymentLoading = false;
      notifyListeners();

      return {
        'err': true,
        'message': _paymentMessage,
        'data': {}
      };
    }
  }

// Getter for Razorpay Key ID
  String get razorpayKeyId => _razorpayKeyId;

// Getter for Order Data
  Map<String, dynamic> get orderData => _orderData;
}