import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/constants.dart';
import '../../providers/campaign_provider.dart';

class CreateCampaignScreen extends StatefulWidget {
  final dynamic campaign;
  final String communityId;

  const CreateCampaignScreen(
      {super.key, this.campaign, required this.communityId});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountNeededController = TextEditingController();
  final _amountPerUserController = TextEditingController();
  final _totalMembersController = TextEditingController();

  String _currency = '₹';
  String? _campaignType = 'MANDATORY';
  // FIX BUG 1: schedule stored/sent in lowercase — backend switch expects lowercase
  String? _schedule = 'monthly';
  String? _promotionType = '';
  DateTime? _endDate;
  DateTime? _dueDate;

  File? _selectedImage;
  String? _imageBase64; // only for genuine base64 strings
  // FIX BUG 3: separate field to hold existing S3/HTTP URL during edit
  String? _existingImageUrl;
  bool _isProcessingImage = false;

  final ImagePicker _picker = ImagePicker();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool get _isEditing => widget.campaign != null;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    if (_isEditing) {
      final c = widget.campaign;
      _titleController.text = c['title'] ?? '';
      _descriptionController.text = c['description'] ?? '';
      _amountNeededController.text =
          c['totalAmountNeeded']?.toString() ?? '';
      // FIX BUG 2: backend field is amountPayablePerUser, not amountPerUser
      _amountPerUserController.text =
          c['amountPayablePerUser']?.toString() ?? '';
      _totalMembersController.text = c['totalMembers']?.toString() ?? '';
      _currency = c['currency'] ?? '₹';
      _campaignType = c['type'] ?? 'MANDATORY';
      // FIX BUG 1: keep schedule lowercase
      _schedule = (c['schedule'] ?? 'monthly').toString().toLowerCase();
      _promotionType = c['promotionType'] ?? '';

      // FIX BUG 3: detect if coverImage is a URL or base64
      final rawImage =
          c['coverImageBase64'] ?? c['coverImage'] ?? '';
      if (rawImage.isNotEmpty) {
        if (rawImage.startsWith('data:image') ||
            (!rawImage.startsWith('http') &&
                !rawImage.startsWith('https'))) {
          // genuine base64
          final b64 = rawImage.contains(',')
              ? rawImage.split(',').last
              : rawImage;
          _imageBase64 = b64;
        } else {
          // S3 / HTTP URL — store separately, never base64Decode this
          _existingImageUrl = rawImage;
        }
      }

      if (c['endDate'] != null && _isValidDate(c['endDate'])) {
        try {
          _endDate = DateTime.parse(c['endDate'].toString());
        } catch (_) {}
      }
      if (c['dueDate'] != null && _isValidDate(c['dueDate'])) {
        try {
          _dueDate = DateTime.parse(c['dueDate'].toString());
        } catch (_) {}
      }
    }
  }

  bool _isValidDate(String? v) {
    if (v == null || v.isEmpty) return false;
    return !RegExp(
        r'^(one_time|daily|weekly|monthly|quarterly|half_yearly|yearly|2_day)$',
        caseSensitive: false)
        .hasMatch(v);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountNeededController.dispose();
    _amountPerUserController.dispose();
    _totalMembersController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _showImagePicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose Image',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 16),
              _sheetOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
              _sheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_selectedImage != null ||
                  _imageBase64 != null ||
                  _existingImageUrl != null) ...[
                const SizedBox(height: 10),
                _sheetOption(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove Image',
                  color: const Color(0xFFE53935),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedImage = null;
                      _imageBase64 = null;
                      _existingImageUrl = null;
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? const Color(0xFF374151);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    color: c,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isProcessingImage = true);
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        setState(() {
          _selectedImage = File(pickedFile.path);
          _imageBase64 = base64Encode(bytes);
          _existingImageUrl = null;
          _isProcessingImage = false;
        });
      } else {
        setState(() => _isProcessingImage = false);
      }
    } catch (e) {
      setState(() => _isProcessingImage = false);
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _selectDate(String field) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (field == 'endDate') _endDate = picked;
        if (field == 'dueDate') _dueDate = picked;
      });
    }
  }

  Future<void> _saveCampaign() async {
    if (widget.communityId.isEmpty) {
      _showSnackBar('Community ID is required', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields', isError: true);
      return;
    }
    if (_endDate == null) {
      _showSnackBar('End date is required', isError: true);
      return;
    }

    final double amountPerUser = _amountPerUserController.text.isEmpty
        ? 0
        : double.parse(_amountPerUserController.text);
    final double totalAmountNeeded = _amountNeededController.text.isEmpty
        ? 0
        : double.parse(_amountNeededController.text);
    final int totalMembers = _totalMembersController.text.isEmpty
        ? 0
        : int.parse(_totalMembersController.text);

    final campaignData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'communityId': widget.communityId,
      'communities': [],
      'campaignType': _campaignType,
      'endDate':
      _endDate != null ? '${_endDate!.toIso8601String()}Z' : null,
      'dueDate':
      _dueDate != null ? '${_dueDate!.toIso8601String()}Z' : null,
      'amountPerUser': amountPerUser,
      'totalAmountNeeded': totalAmountNeeded,
      'currency': _currency,
      // FIX BUG 1: send schedule in lowercase — backend switch is case-sensitive
      'schedule': _schedule,
      // FIX BUG 3: send base64 for new uploads, URL for existing S3 images
      'coverImageBase64': _imageBase64 ?? '',
      'coverImage': _existingImageUrl ?? '',
      'totalMembers': totalMembers,
      'promotionType': _promotionType,
      'productIds': [],
      'serviceIds': [],
    };

    try {
      final provider = context.read<CampaignProvider>();
      Map<String, dynamic> response;
      if (_isEditing) {
        response = await provider.editCampaign(
            widget.campaign['_id'], campaignData);
      } else {
        response = await provider.createCampaign(campaignData);
      }
      if (!mounted) return;
      if (!response['error']) {
        _showSnackBar(
            response['message'] ??
                (_isEditing
                    ? 'Campaign updated!'
                    : 'Campaign created!'),
            isError: false);
        Navigator.pop(context, true);
      } else {
        _showSnackBar(
            response['message'] ?? 'Something went wrong',
            isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        backgroundColor:
        isError ? const Color(0xFFE53935) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Color(0xFF1A1A2E), size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Campaign' : 'New Campaign',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cover image picker ────────────────────────────
                _buildSectionLabel('Cover Image'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _showImagePicker,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _buildImagePreview(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Basic info card ───────────────────────────────
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Basic Information'),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _titleController,
                        label: 'Campaign Title',
                        hint: 'e.g. Annual Maintenance Fund',
                        icon: Icons.campaign_outlined,
                        validator: (v) =>
                        v?.isEmpty ?? true ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Describe the purpose of this campaign...',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                        validator: (v) =>
                        v?.isEmpty ?? true ? 'Description is required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Campaign settings card ────────────────────────
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Campaign Settings'),
                      const SizedBox(height: 14),
                      _buildDropdown<String>(
                        value: _campaignType,
                        label: 'Campaign Type',
                        icon: Icons.category_outlined,
                        items: const [
                          DropdownMenuItem(
                              value: 'MANDATORY',
                              child: Text('Mandatory')),
                          DropdownMenuItem(
                              value: 'MARKETING',
                              child: Text('Marketing')),
                        ],
                        onChanged: (v) => setState(() => _campaignType = v),
                      ),
                      const SizedBox(height: 14),
                      _buildDropdown<String>(
                        value: _schedule,
                        label: 'Schedule',
                        icon: Icons.repeat_rounded,
                        items: const [
                          DropdownMenuItem(
                              value: 'one_time', child: Text('One Time')),
                          DropdownMenuItem(
                              value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(
                              value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(
                              value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(
                              value: 'quarterly', child: Text('Quarterly')),
                          DropdownMenuItem(
                              value: 'half_yearly',
                              child: Text('Half Yearly')),
                          DropdownMenuItem(
                              value: 'yearly', child: Text('Yearly')),
                          DropdownMenuItem(
                              value: '2_day', child: Text('Every 2 Days')),
                        ],
                        onChanged: (v) => setState(() => _schedule = v),
                        validator: (v) =>
                        v == null ? 'Schedule is required' : null,
                      ),
                      if (_campaignType == 'MARKETING') ...[
                        const SizedBox(height: 14),
                        _buildTextField(
                          initialValue: _promotionType,
                          label: 'Promotion Type',
                          hint: 'e.g. products, service',
                          icon: Icons.storefront_outlined,
                          onChanged: (v) => _promotionType = v,
                          validator: (v) =>
                          _campaignType == 'MARKETING' &&
                              (v?.isEmpty ?? true)
                              ? 'Required for marketing campaigns'
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Dates card ────────────────────────────────────
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Dates'),
                      const SizedBox(height: 14),
                      _buildDateButton(
                        label: 'End Date',
                        date: _endDate,
                        icon: Icons.event_rounded,
                        onTap: () => _selectDate('endDate'),
                        required: true,
                      ),
                      const SizedBox(height: 10),
                      _buildDateButton(
                        label: 'Due Date',
                        date: _dueDate,
                        icon: Icons.event_available_rounded,
                        onTap: () => _selectDate('dueDate'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Payment card ──────────────────────────────────
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Payment Details'),
                      const SizedBox(height: 14),
                      _buildDropdown<String>(
                        value: _currency,
                        label: 'Currency',
                        icon: Icons.currency_exchange_rounded,
                        items: const [
                          DropdownMenuItem(value: '₹', child: Text('₹ INR')),
                          DropdownMenuItem(
                              value: 'USD', child: Text('\$ USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('€ EUR')),
                          DropdownMenuItem(value: 'GBP', child: Text('£ GBP')),
                        ],
                        onChanged: (v) => setState(() => _currency = v!),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _amountNeededController,
                        label: 'Total Amount Needed',
                        hint: '0.00',
                        icon: Icons.account_balance_wallet_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v?.isEmpty ?? true)
                            return 'Amount is required';
                          if (double.tryParse(v!) == null || double.parse(v) <= 0)
                            return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _amountPerUserController,
                        label: 'Amount Per User',
                        hint: '0.00',
                        icon: Icons.person_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (_campaignType == 'MANDATORY') {
                            if (v?.isEmpty ?? true)
                              return 'Required for mandatory campaigns';
                            if (double.tryParse(v!) == null ||
                                double.parse(v) <= 0)
                              return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _totalMembersController,
                        label: 'Total Members',
                        hint: '0',
                        icon: Icons.group_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (_campaignType == 'MANDATORY') {
                            if (v?.isEmpty ?? true)
                              return 'Required for mandatory campaigns';
                            if (int.tryParse(v!) == null || int.parse(v) <= 0)
                              return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Submit button ─────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveCampaign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isEditing ? 'Update Campaign' : 'Create Campaign',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Image preview ─────────────────────────────────────────────────────────
  Widget _buildImagePreview() {
    if (_isProcessingImage) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Primary, strokeWidth: 2),
              SizedBox(height: 12),
              Text('Processing...',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            ],
          ),
        ),
      );
    }
    // New image selected from device
    if (_selectedImage != null) {
      return Image.file(_selectedImage!, fit: BoxFit.cover,
          width: double.infinity, height: double.infinity);
    }
    // Existing base64 image
    if (_imageBase64 != null && _imageBase64!.isNotEmpty) {
      try {
        return Image.memory(base64Decode(_imageBase64!),
            fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      } catch (_) {}
    }
    // FIX BUG 3: existing S3/HTTP URL — load with Image.network, never base64Decode
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return Image.network(_existingImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _imagePlaceholder());
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF0F4FF),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_photo_alternate_outlined,
                size: 36, color: Primary),
          ),
          const SizedBox(height: 12),
          const Text('Tap to add a cover image',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Recommended: 16:9 ratio',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        ],
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.5,
        ));
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final decoration = InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFF),
      labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    if (controller != null) {
      return TextFormField(
        controller: controller,
        decoration: decoration,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(
            fontSize: 15, color: Color(0xFF1A1A2E), fontWeight: FontWeight.w500),
      );
    }
    return TextFormField(
      initialValue: initialValue,
      decoration: decoration,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
          fontSize: 15, color: Color(0xFF1A1A2E), fontWeight: FontWeight.w500),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Primary, width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFAFF),
        labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1A1A2E),
          fontWeight: FontWeight.w500),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF9CA3AF)),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
    bool required = false,
  }) {
    final hasDate = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate ? Primary.withOpacity(0.4) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: hasDate ? Primary : const Color(0xFF9CA3AF)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label${required ? ' *' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasDate ? Primary : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDate
                        ? DateFormat('MMM dd, yyyy').format(date!)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 15,
                      color: hasDate
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFFD1D5DB),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: const Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }
}