import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/screens/service_request/service_request_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/communities_provider.dart';
import '../announcement_page/announcement_screen.dart';
import '../home/feedpage/feed_screen.dart';
import 'communities_screen.dart';
import 'community_campaigns.dart';
import 'community_coupons.dart';
import 'community_members.dart';
import 'community_services.dart';
import 'community_stats.dart';
import 'invite_status_screen.dart';

class CommunityInfoScreen extends StatefulWidget {
  final String communityId;
  const CommunityInfoScreen({super.key, required this.communityId});

  @override
  State<CommunityInfoScreen> createState() => _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends State<CommunityInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPrivate = false;
  bool _isSubmitting = false;
  File? _profileImageFile;
  File? _coverImageFile;
  String? _profileImageBase64;
  String? _coverImageBase64;
  String? _existingProfileImage;
  String? _existingCoverImage;
  final ImagePicker _picker = ImagePicker();

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickImage(ImageSource source, bool isProfileImage,
      void Function(void Function()) setDialogState) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: isProfileImage ? 200 : 400,
        maxHeight: isProfileImage ? 200 : 300,
      );
      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final extension = pickedFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      final dataUrl = 'data:$mimeType;base64,$base64Image';

      setDialogState(() {
        if (isProfileImage) {
          _profileImageFile = imageFile;
          _profileImageBase64 = dataUrl;
          _existingProfileImage = null;
        } else {
          _coverImageFile = imageFile;
          _coverImageBase64 = dataUrl;
          _existingCoverImage = null;
        }
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error picking image: $e', Colors.red);
      }
    }
  }

  void _showImageSourceDialog(
      bool isProfileImage, void Function(void Function()) setDialogState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select ${isProfileImage ? 'Profile' : 'Cover'} Image'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogOption(Icons.photo_camera, 'Camera', () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera, isProfileImage, setDialogState);
            }),
            _buildDialogOption(Icons.photo_library, 'Gallery', () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery, isProfileImage, setDialogState);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }

  void _showCommunityDialog(Map<String, dynamic> community) {
    _nameController.text = community['name'] ?? '';
    _descriptionController.text = community['description'] ?? '';
    _isPrivate = community['isPrivate'] ?? false;
    _existingProfileImage = community['profileImage'];
    _existingCoverImage = community['coverImage'];
    _profileImageFile = null;
    _coverImageFile = null;
    _profileImageBase64 = null;
    _coverImageBase64 = null;
    _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Community',
              style: TextStyle(fontWeight: FontWeight.bold)),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(_nameController, 'Name', true),
                  const SizedBox(height: 12),
                  _buildTextField(_descriptionController, 'Description', true),
                  const SizedBox(height: 12),
                  _buildPrivacyToggle(setDialogState),
                  const SizedBox(height: 16),
                  _buildImageSelectors(setDialogState),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
              _isSubmitting ? null : () => _updateCommunity(setDialogState),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800080),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, bool required) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      ),
      validator: required
          ? (value) => value?.isEmpty ?? true ? '$label is required' : null
          : null,
    );
  }

  Widget _buildPrivacyToggle(void Function(void Function()) setDialogState) {
    return CheckboxListTile(
      value: _isPrivate,
      onChanged: (value) => setDialogState(() => _isPrivate = value ?? false),
      title: Text(
        _isPrivate ? '🔒 Private Community' : '🌐 Public Community',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF800080),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildImageSelectors(void Function(void Function()) setDialogState) {
    return Row(
      children: [
        Expanded(
          child: _buildImageSelector(
            'Profile Image',
            _profileImageFile,
            _existingProfileImage,
            true,
            setDialogState,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildImageSelector(
            'Cover Image',
            _coverImageFile,
            _existingCoverImage,
            false,
            setDialogState,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelector(
      String title,
      File? imageFile,
      String? existingImage,
      bool isProfile,
      void Function(void Function()) setDialogState,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showImageSourceDialog(isProfile, setDialogState),
          child: Container(
            width: isProfile ? 60 : double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (imageFile != null)
                    Image.file(imageFile,
                        fit: BoxFit.cover, width: double.infinity, height: 60)
                  else if (existingImage?.isNotEmpty ?? false)
                    _buildImageWidget(existingImage!, isProfileImage: isProfile)
                  else
                    Icon(
                      isProfile ? Icons.add_a_photo : Icons.add_photo_alternate,
                      color: Colors.grey,
                      size: 20,
                    ),
                  if (imageFile != null || (existingImage?.isNotEmpty ?? false))
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setDialogState(() {
                          if (isProfile) {
                            _profileImageFile = null;
                            _profileImageBase64 = null;
                            _existingProfileImage = null;
                          } else {
                            _coverImageFile = null;
                            _coverImageBase64 = null;
                            _existingCoverImage = null;
                          }
                        }),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateCommunity(
      void Function(void Function()) setDialogState) async {
    if (_formKey.currentState?.validate() ?? false) {
      setDialogState(() => _isSubmitting = true);
      final profileImageToSend = _profileImageBase64 ??
          (_existingProfileImage?.isNotEmpty ?? false
              ? _existingProfileImage
              : null);
      final coverImageToSend = _coverImageBase64 ??
          (_existingCoverImage?.isNotEmpty ?? false
              ? _existingCoverImage
              : null);
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      final result = await provider.updateCommunity(
        communityId: widget.communityId,
        name: _nameController.text,
        description: _descriptionController.text,
        isPrivate: _isPrivate,
        coverImage: coverImageToSend,
        profileImage: profileImageToSend,
      );
      setDialogState(() => _isSubmitting = false);

      if (mounted) {
        _showSnackBar(
          result['error'] == true
              ? result['message'] ?? 'Something went wrong'
              : result['message'] ?? 'Community updated successfully',
          result['error'] == true ? Colors.red : Colors.green,
        );
      }

      if (!(result['error'] as bool)) {
        Navigator.pop(context);
        setState(() {
          provider.fetchCommunityInfo(widget.communityId);
        });
      }
    }
  }

  void _confirmDeleteCommunity(String communityId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Community'),
        content: const Text('Are you sure you want to delete this community?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _deleteCommunity(communityId),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCommunity(String communityId) async {
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    final result = await provider.deleteCommunity(communityId);
    if (!context.mounted) return;
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CommunitiesScreen()),
    );
    _showSnackBar(
      result['error'] != true
          ? 'Community deleted successfully'
          : (result['message'] ?? 'Failed to delete community'),
      result['error'] != true ? Colors.green : Colors.red,
    );
  }

  void _showAddUserDialog(BuildContext context, CommunityProvider provider) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final mobileController = TextEditingController();
    final passwordController = TextEditingController();
    final userIdController = TextEditingController();
    String memberType = 'New';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add User to Community',
              style: TextStyle(fontWeight: FontWeight.bold)),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: memberType,
                    decoration: InputDecoration(
                      labelText: 'Member Type *',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'New', child: Text('New User')),
                      DropdownMenuItem(
                          value: 'Exist', child: Text('Existing User')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => memberType = value ?? 'New'),
                    validator: (value) =>
                    value == null ? 'Member type is required' : null,
                  ),
                  const SizedBox(height: 12),
                  if (memberType == 'New') ...[
                    _buildTextField(nameController, 'Name', true),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Email is required';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value!)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(mobileController, 'Mobile', true),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      obscureText: true,
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Password is required'
                          : null,
                    ),
                  ] else ...[
                    _buildTextField(userIdController, 'User ID', true),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () => _addUser(
                formKey,
                setDialogState,
                provider,
                memberType,
                nameController,
                emailController,
                mobileController,
                passwordController,
                userIdController,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800080),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _addUser(
      GlobalKey<FormState> formKey,
      void Function(void Function()) setDialogState,
      CommunityProvider provider,
      String memberType,
      TextEditingController nameController,
      TextEditingController emailController,
      TextEditingController mobileController,
      TextEditingController passwordController,
      TextEditingController userIdController,
      ) async {
    // Validate form first
    if (!(formKey.currentState?.validate() ?? false)) return;

    // Start loading - use local variable, not class variable
    setDialogState(() => _isSubmitting = true); // Remove the underscore

    try {
      final result = await provider.addUserToCommunity(
        communityId: widget.communityId,
        name: memberType == 'New' ? nameController.text.trim() : null,
        email: memberType == 'New' ? emailController.text.trim() : null,
        mobile: memberType == 'New' ? mobileController.text.trim() : null,
        password: memberType == 'New' ? passwordController.text.trim() : null,
        memberType: memberType,
        userId: memberType == 'Exist' ? userIdController.text.trim() : null,
      );

      // Stop loading
      setDialogState(() => _isSubmitting = false); // Remove the underscore

      // Show result message
      if (mounted) {
        _showSnackBar(
          result['error'] == true
              ? result['message'] ?? 'Failed to add user'
              : 'User added successfully',
          result['error'] == true ? Colors.red : Colors.green,
        );
      }

      // Close dialog and refresh if successful
      if (!(result['error'] as bool)) {
        if (mounted) {
          Navigator.pop(context);
          provider.fetchCommunityInfo(widget.communityId);
        }
      }
    } catch (e) {
      // Stop loading on error
      setDialogState(() => _isSubmitting = false); // Remove the underscore

      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
    }
  }

  void _showExitCommunityDialog(
      String communityId, String communityName, CommunityProvider provider) {
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Exit $communityName'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Are you sure you want to exit this community?',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                setDialogState(() => isLoading = true);
                final result =
                await provider.exitCommunity(communityId);
                setDialogState(() {
                  isLoading = false;
                  if (result['error'] == true) {
                    errorMessage = result['message'] as String? ??
                        'Failed to exit community';
                  }
                });

                if (result['error'] != true) {
                  _showSnackBar(
                    'Successfully exited $communityName',
                    Colors.green,
                  );
                  Navigator.pop(context);
                  // Refresh community lists after successful exit
                  provider.fetchMyCommunities();
                  provider.fetchCommunities(page: 1);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Exit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String? imageData, {bool isProfileImage = false}) {
    if (imageData == null || imageData.isEmpty) {
      return isProfileImage
          ? const Icon(Icons.person, color: Colors.white, size: 20)
          : const SizedBox();
    }

    if (imageData.startsWith('data:')) {
      final base64Data = imageData.split(',')[1];
      return Image.memory(
        base64Decode(base64Data),
        fit: BoxFit.cover,
        width: isProfileImage ? 60 : double.infinity,
        height: isProfileImage ? 60 : 160,
        errorBuilder: (context, error, stackTrace) => isProfileImage
            ? const Icon(Icons.person, color: Colors.white, size: 20)
            : const SizedBox(),
      );
    }

    return Image.network(
      imageData,
      fit: BoxFit.cover,
      width: isProfileImage ? 60 : double.infinity,
      height: isProfileImage ? 60 : 160,
      errorBuilder: (context, error, stackTrace) => isProfileImage
          ? const Icon(Icons.person, color: Colors.white, size: 20)
          : const SizedBox(),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    final communityInfoFuture = provider.fetchCommunityInfo(widget.communityId);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(28),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  Provider.of<CommunityProvider>(context, listen: false)
                      .resetCommunityInfo();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, color: Colors.red, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: communityInfoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 3));
          }

          if (snapshot.hasError || provider.infoError != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showSnackBar(
                  provider.infoError ?? 'Failed to load community info',
                  Colors.red,
                );
                Navigator.pop(context);
              }
            });
            return const SizedBox();
          }

          final communityInfo = provider.communityInfo;
          final isSuperAdmin = communityInfo['superAdmin'] ?? false;
          final pendingRequests =
              (communityInfo['pendingRequests'] as List<dynamic>?) ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(communityInfo, isSuperAdmin, provider),
                _buildGridView(),
                const SizedBox(height: 20),
                if (isSuperAdmin && pendingRequests.isNotEmpty)
                  _buildPendingRequests(pendingRequests, provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> communityInfo, bool isSuperAdmin,
      CommunityProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cover Image
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              color: Colors.grey[300],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: communityInfo['coverImage']?.isNotEmpty ?? false
                  ? _buildImageWidget(communityInfo['coverImage'])
                  : Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Text(
                    'No Cover Photo',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image, Name, and Public/Private Status in a Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Image
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: communityInfo['profileImage']?.isNotEmpty ??
                            false
                            ? _buildImageWidget(communityInfo['profileImage'],
                            isProfileImage: true)
                            : Container(
                          color: const Color(0xFF800080),
                          child: Center(
                            child: Text(
                              communityInfo['name']?.isNotEmpty ?? false
                                  ? communityInfo['name'][0].toUpperCase()
                                  : 'C',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Community Name and Public/Private Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            communityInfo['name'] ?? 'Community',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                communityInfo['isPrivate'] ?? false
                                    ? Icons.lock
                                    : Icons.public,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                communityInfo['isPrivate'] ?? false
                                    ? 'Private'
                                    : 'Public',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Action Buttons for all users
                const SizedBox(height: 12),
                _buildActionButtons(communityInfo, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      Map<String, dynamic> communityInfo, CommunityProvider provider) {
    final communityId = communityInfo['_id']?.toString() ?? '';
    final communityName = communityInfo['name']?.toString() ?? 'Unnamed Community';

    // List of buttons for super admin
    final superAdminButtons = [
      _buildActionButton(
        Icons.share,
        Colors.cyan,
            () => _navigateToInviteStatusScreen(context, communityId, communityName), // Added navigation
      ),
      const SizedBox(width: 8),
      _buildActionButton(
        Icons.person_add,
        Colors.blue,
            () => _showAddUserDialog(context, provider),
      ),
      const SizedBox(width: 8),
      _buildActionButton(
        Icons.edit,
        Colors.green,
            () => _showCommunityDialog(communityInfo),
      ),
      const SizedBox(width: 8),
      _buildActionButton(
        Icons.delete,
        Colors.red,
            () => _confirmDeleteCommunity(communityId),
      ),
      const SizedBox(width: 8),
      _buildActionButton(Icons.add_circle_outlined, Colors.orange),
      const SizedBox(width: 8),
      _buildActionButton(
        Icons.exit_to_app_outlined,
        Colors.cyan,
            () => _showExitCommunityDialog(communityId, communityName, provider),
      ),
    ];

    // List of buttons for non-admin users
    final nonAdminButtons = [
      _buildActionButton(
        Icons.share,
        Colors.cyan,
            () => _navigateToInviteStatusScreen(context, communityId, communityName), // Added navigation
      ),
      const SizedBox(width: 8),
      _buildActionButton(
        Icons.exit_to_app_outlined,
        Colors.cyan,
            () => _showExitCommunityDialog(communityId, communityName, provider),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: communityInfo['superAdmin'] == true
          ? superAdminButtons
          : nonAdminButtons,
    );
  }

  Widget _buildActionButton(IconData icon,
      [Color? color, VoidCallback? onTap]) {
    // Default color if none provided
    Color buttonColor = color ?? Colors.grey;

    return GestureDetector(
      onTap: onTap, // Will be null if not provided (button won't be tappable)
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: buttonColor, size: 16),
      ),
    );
  }

  void _navigateToInviteStatusScreen(BuildContext context, String communityId, String communityName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InviteStatusScreen(
          communityId: communityId,
          communityName: communityName,
        ),
      ),
    );
  }

  Widget _buildGridView() {
    final gridItems = [
      {
        'icon': Icons.safety_check,
        'title': 'Home',
        'screen': CommunityStatsScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.group,
        'title': 'Users',
        'screen': CommunityMembersScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.feed_sharp,
        'title': 'Feeds',
        'screen': FeedScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.campaign,
        'title': 'Campaigns',
        'screen': CommunityCampaignsScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.local_offer,
        'title': 'Coupons',
        'screen': CommunityCouponsScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.build,
        'title': 'Services',
        'screen': CommunityServicesScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.announcement,
        'title': 'Announcements',
        'screen': AnnouncementScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.support_agent,
        'title': 'Service Requests',
        'screen': AllServiceRequestsScreen(communityId: widget.communityId)
      },

    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.9,
            ),
            itemCount: gridItems.length,
            itemBuilder: (context, index) {
              final item = gridItems[index];
              return _buildGridItem(
                context,
                icon: item['icon'] as IconData,
                title: item['title'] as String,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => item['screen'] as Widget),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context,
      {required IconData icon,
        required String title,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 26,
              color: Primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a1a1a),
              letterSpacing: -0.1,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequests(
      List<dynamic> pendingRequests, CommunityProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pending_actions, color: Colors.orange[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Pending Join Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pendingRequests.map((request) {
            final userId = request['userId'] as String?;
            final userName = request['userName'] ?? 'Unknown User';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Primary.withOpacity(0.1),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: Primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRequestButton(
                        icon: Icons.check,
                        color: Colors.green,
                        onPressed: () =>
                            _handleJoinRequest(provider, userId!, true),
                      ),
                      const SizedBox(width: 8),
                      _buildRequestButton(
                        icon: Icons.close,
                        color: Colors.red,
                        onPressed: () =>
                            _handleJoinRequest(provider, userId!, false),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRequestButton(
      {required IconData icon,
        required Color color,
        required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Future<void> _handleJoinRequest(
      CommunityProvider provider, String userId, bool approve) async {
    final result =
    await provider.updateJoinRequest(widget.communityId, userId, approve);
    if (mounted) {
      _showSnackBar(
        result['error'] == true
            ? result['message'] ??
            'Failed to ${approve ? 'approve' : 'reject'} request'
            : 'Request ${approve ? 'approved' : 'rejected'}',
        result['error'] == true ? Colors.red : Colors.green,
      );
    }
    if (!(result['error'] as bool)) {
      provider.fetchCommunityInfo(widget.communityId);
    }
  }
}