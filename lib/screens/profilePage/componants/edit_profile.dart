import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/profile_provider.dart';
import 'package:ixes.app/constants/constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ── Constants ──────────────────────────────────────────────────────────
  static const _accent = Color(0xFF6C5CE7);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();

  DateTime? _selectedBirthdate;
  bool _isFamilyHead = false;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Clear stale data immediately so old account never flashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProfileProvider>(context, listen: false);
      // Only fetch if profile is null (just logged in) or force-refresh
      if (provider.userProfile == null) {
        provider.getUserProfile().then((_) => _loadProfileData());
      } else {
        _loadProfileData();
      }
    });
  }

  void _loadProfileData() {
    final profile =
        Provider.of<ProfileProvider>(context, listen: false).userProfile;
    if (profile == null) return;

    setState(() {
      _nameController.text = profile['name'] ?? '';
      _emailController.text = profile['email'] ?? '';
      _mobileController.text = profile['mobile'] ?? '';
      _locationController.text = profile['location'] ?? '';
      _addressController.text = profile['address'] ?? '';
      _isFamilyHead = profile['isFamilyHead'] ?? false;

      if (profile['birthdate'] != null) {
        try {
          _selectedBirthdate = DateTime.parse(profile['birthdate']);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ── Image picker ───────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _imageFile = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  /// Matches the ServiceRequestDetailsScreen bottom sheet style exactly
  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Profile Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_outlined,
                    color: Colors.blue, size: 20),
              ),
              title: const Text('Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Use camera',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),

            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.photo_library_outlined,
                    color: Colors.purple, size: 20),
              ),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Pick from photos',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Date picker ────────────────────────────────────────────────────────
  Future<void> _selectBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _accent, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedBirthdate = picked);
  }

  // ── Save ───────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final profileProvider =
    Provider.of<ProfileProvider>(context, listen: false);

    final profileData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'location': _locationController.text.trim(),
      'address': _addressController.text.trim(),
      'isFamilyHead': _isFamilyHead.toString(),
      if (_selectedBirthdate != null)
        'birthdate': DateFormat('yyyy-MM-dd').format(_selectedBirthdate!),
    };

    final success = await profileProvider.updateUserProfile(
      profileData,
      profileImagePath: _imageFile?.path,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(profileProvider.updateProfileError ??
              'Failed to update profile'),
          backgroundColor: Colors.red));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  ImageProvider? _getDisplayImage() {
    if (_imageFile != null) return FileImage(_imageFile!);

    final profile =
        Provider.of<ProfileProvider>(context, listen: false).userProfile;
    final raw = profile?['profileImage']?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return null;

    if (raw.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(raw.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (raw.startsWith('http')) return NetworkImage(raw);
    return null;
  }

  String _getInitial() {
    final name = _nameController.text.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, _) {
          // Show loader while fetching fresh profile
          if (provider.isLoadingProfile) {
            return const Center(
                child: CircularProgressIndicator(color: _accent));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildAvatarHeader(provider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Personal Info ────────────────────────────────
                        _sectionCard(
                          title: 'Personal Information',
                          icon: Icons.person_outline_rounded,
                          color: Colors.blue,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.badge_outlined,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter your name'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Enter your email';
                                  if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(v))
                                    return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _mobileController,
                                label: 'Mobile Number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter your mobile number'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              // Birthdate picker row (styled like a text field)
                              _buildTappableField(
                                label: 'Date of Birth',
                                icon: Icons.cake_outlined,
                                value: _selectedBirthdate != null
                                    ? DateFormat('MMM dd, yyyy')
                                    .format(_selectedBirthdate!)
                                    : null,
                                placeholder: 'Select birthdate',
                                trailingIcon: Icons.calendar_today_outlined,
                                onTap: _selectBirthdate,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Location ─────────────────────────────────────
                        _sectionCard(
                          title: 'Location & Address',
                          icon: Icons.location_on_outlined,
                          color: Colors.green,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _locationController,
                                label: 'City / Location',
                                icon: Icons.location_city_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _addressController,
                                label: 'Full Address',
                                icon: Icons.home_outlined,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Family ───────────────────────────────────────
                        _sectionCard(
                          title: 'Family Settings',
                          icon: Icons.family_restroom_outlined,
                          color: Colors.purple,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Family Head',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E))),
                                    const SizedBox(height: 3),
                                    Text('Mark yourself as head of family',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isFamilyHead,
                                onChanged: (v) =>
                                    setState(() => _isFamilyHead = v),
                                activeColor: _accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Save button ──────────────────────────────────
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isLoading
                                ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              _isLoading ? 'Saving...' : 'Save Changes',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      scrolledUnderElevation: 0,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFEEEEF5)),
      ),
    );
  }

  // ── Avatar Header ──────────────────────────────────────────────────────
  Widget _buildAvatarHeader(ProfileProvider provider) {
    final displayImage = _getDisplayImage();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        // Always centered regardless of name length
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with camera overlay
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent.withOpacity(0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: _accent.withOpacity(0.1),
                  backgroundImage: displayImage,
                  child: displayImage == null
                      ? Text(
                    _getInitial(),
                    style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: _accent),
                  )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showImageSourceBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _accent.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Name — centered, won't shift layout
          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : 'Your Name',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _showImageSourceBottomSheet,
            child: Text(
              'Tap photo to change',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Card (matches ServiceRequestDetailsScreen) ─────────────────
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header — same style as SR details
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── Text Field ─────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
        prefixIcon: Icon(icon, size: 18, color: _accent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F8FC),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ── Tappable Field (birthdate, etc.) ───────────────────────────────────
  Widget _buildTappableField({
    required String label,
    required IconData icon,
    required String? value,
    required String placeholder,
    required IconData trailingIcon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                    fontSize: 14,
                    color: value != null
                        ? const Color(0xFF1A1A2E)
                        : Colors.grey[400]),
              ),
            ),
            Icon(trailingIcon, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}