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
import 'community_events.dart';
import 'community_members.dart';
import 'community_services.dart';
import 'community_stats.dart';
import 'create_community_screen.dart';
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

// REPLACE the entire try block inside _pickImage with this:
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

      setDialogState(() {
        if (isProfileImage) {
          _profileImageFile = imageFile;
          _existingProfileImage = null;
        } else {
          _coverImageFile = imageFile;
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
    _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Header ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.edit_outlined,
                              color: Colors.blue.shade600, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Edit community',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600)),
                              Text('Update your community details',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Icon(Icons.close, size: 14,
                                color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [

                        // ── Cover image + remove button ──────────────────
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showImageSourceDialog(false, setDialogState),
                              child: Container(
                                height: 110,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey.shade100,
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _coverImageFile != null
                                      ? Image.file(_coverImageFile!, fit: BoxFit.cover)
                                      : _existingCoverImage?.isNotEmpty == true
                                      ? _buildImageWidget(_existingCoverImage!)
                                      : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          color: Colors.grey[400], size: 28),
                                      const SizedBox(height: 4),
                                      Text('Tap to add cover image',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[400])),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Red remove button for cover
                            if (_coverImageFile != null ||
                                _existingCoverImage?.isNotEmpty == true)
                              Positioned(
                                top: -8,
                                right: -8,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setDialogState(() {
                                    _coverImageFile = null;
                                    _existingCoverImage = null;
                                  }),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // ── Profile image row (negative top margin to overlap cover) ──
                        Transform.translate(
                          offset: const Offset(0, -20),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [

                                    // Profile image — large enough to tap easily
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        debugPrint('Profile image tapped');
                                        _showImageSourceDialog(true, setDialogState);
                                      },
                                      child: Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.15),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                          color: const Color(0xFF800080),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(13),
                                          child: _profileImageFile != null
                                              ? Image.file(_profileImageFile!,
                                              fit: BoxFit.cover)
                                              : _existingProfileImage?.isNotEmpty == true
                                              ? _buildImageWidget(
                                            _existingProfileImage!,
                                            isProfileImage: true,
                                          )
                                              : Center(
                                            child: Text(
                                              (_nameController.text.isNotEmpty
                                                  ? _nameController.text[0]
                                                  : 'C')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Pencil badge — IgnorePointer so taps pass through
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            border: Border.all(color: Colors.grey.shade300),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 3,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.edit,
                                              size: 12, color: Colors.black87),
                                        ),
                                      ),
                                    ),

                                    // Red remove button — only when image exists
                                    if (_profileImageFile != null ||
                                        _existingProfileImage?.isNotEmpty == true)
                                      Positioned(
                                        top: -6,
                                        right: -6,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => setDialogState(() {
                                            _profileImageFile = null;
                                            _existingProfileImage = null;
                                          }),
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                            child: const Icon(Icons.close,
                                                size: 11, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
// Remove the old const SizedBox(height: 44) and replace with:
                  const SizedBox(height: 8),

                  // ── Fields ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Name field
                        _buildLabel('Community name *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration('Enter community name'),
                          validator: (v) =>
                          v?.isEmpty == true ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Description field
                        _buildLabel('Description *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: _inputDecoration('What is this community about?'),
                          validator: (v) =>
                          v?.isEmpty == true ? 'Description is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Visibility toggle
                        _buildLabel('Visibility'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setDialogState(() => _isPrivate = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: !_isPrivate
                                          ? Colors.blue.shade400
                                          : Colors.grey.shade200,
                                      width: !_isPrivate ? 2 : 0.5,
                                    ),
                                    color: !_isPrivate
                                        ? Colors.blue.shade50
                                        : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.public,
                                          size: 16,
                                          color: !_isPrivate
                                              ? Colors.blue.shade600
                                              : Colors.grey),
                                      const SizedBox(width: 6),
                                      Text('Public',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: !_isPrivate
                                                  ? Colors.blue.shade700
                                                  : Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setDialogState(() => _isPrivate = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _isPrivate
                                          ? Colors.orange.shade400
                                          : Colors.grey.shade200,
                                      width: _isPrivate ? 2 : 0.5,
                                    ),
                                    color: _isPrivate
                                        ? Colors.orange.shade50
                                        : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 16,
                                          color: _isPrivate
                                              ? Colors.orange.shade600
                                              : Colors.grey),
                                      const SizedBox(width: 6),
                                      Text('Private',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: _isPrivate
                                                  ? Colors.orange.shade700
                                                  : Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // ── Action buttons ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Cancel',
                                style: TextStyle(color: Colors.grey[700])),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _updateCommunity(setDialogState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF800080),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ))
                                : const Text('Save changes',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// Helper widgets
  Widget _buildLabel(String text) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: Colors.grey[600]));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF800080))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

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
      // WITH THIS:
// Only send if user picked a NEW image — backend preserves existing from DB
      final profileImageToSend = _profileImageFile?.path;
      final coverImageToSend = _coverImageFile?.path;
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

  void _showExitCommunityDialog(
      String communityId, String communityName, CommunityProvider provider) {
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Exit $communityName'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      final result = await provider.exitCommunity(communityId);
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
  void initState() {
    super.initState();
    // Fetch community info when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CommunityProvider>(context, listen: false)
          .fetchCommunityInfo(widget.communityId);
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: Consumer<CommunityProvider>(
        builder: (context, provider, child) {
          // Show loading while data is being fetched
          if (provider.communityInfo.isEmpty ||
              provider.communityInfo['_id'] != widget.communityId) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 3),
            );
          }

          // Show error if any
          if (provider.infoError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    provider.infoError ?? 'Failed to load community info',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.fetchCommunityInfo(widget.communityId);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
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
    final communityName =
        communityInfo['name']?.toString() ?? 'Unnamed Community';

    final superAdminButtons = [
      _buildActionButton(
        Icons.share,
        Colors.cyan,
        () => _navigateToInviteStatusScreen(
            context, communityId, communityName), // Added navigation
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
      // REPLACE WITH:
      _buildActionButton(
        Icons.add_circle_outlined,
        Colors.orange,
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateCommunityScreen(
              parentId: communityId, // ← pass current community as parent
            ),
          ),
        ).then((_) {
          // Refresh community info after returning
          Provider.of<CommunityProvider>(context, listen: false)
              .fetchCommunityInfo(widget.communityId);
        }),
      ),
      const SizedBox(width: 8),
      _buildActionButton(
        Icons.exit_to_app_outlined,
        Colors.cyan,
        () => _showExitCommunityDialog(communityId, communityName, provider),
      ),
    ];

    final nonAdminButtons = [
      _buildActionButton(
        Icons.share,
        Colors.cyan,
        () =>
            _navigateToInviteStatusScreen(context, communityId, communityName),
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

  void _navigateToInviteStatusScreen(
      BuildContext context, String communityId, String communityName) {
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
        'icon': Icons.shield_outlined,
        'title': 'Home',
        'color': const Color(0xFF6C63FF),
        'bgColor': const Color(0xFFF0EFFE),
        'screen': CommunityStatsScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.group_outlined,
        'title': 'Users',
        'color': const Color(0xFF00B894),
        'bgColor': const Color(0xFFE6F8F5),
        'screen': CommunityMembersScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.dynamic_feed_outlined,
        'title': 'Feeds',
        'color': const Color(0xFF0984E3),
        'bgColor': const Color(0xFFE8F4FD),
        'screen': FeedScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.home_repair_service_outlined,
        'title': 'Services',
        'color': const Color(0xFFE17055),
        'bgColor': const Color(0xFFFDF0EC),
        'screen': CommunityServicesScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.announcement_outlined,
        'title': 'Announcements',
        'color': const Color(0xFFFD79A8),
        'bgColor': const Color(0xFFFEF0F5),
        'screen': AnnouncementScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.support_agent_outlined,
        'title': 'Service Requests',
        'color': const Color(0xFF00CEC9),
        'bgColor': const Color(0xFFE6FAFA),
        'screen': AllServiceRequestsScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.event_outlined,
        'title': 'Community Events',
        'color': const Color(0xFFA29BFE),
        'bgColor': const Color(0xFFF3F2FE),
        'screen': Builder(
          builder: (context) {
            final provider = Provider.of<CommunityProvider>(context, listen: false);
            final communityName = provider.communityInfo['name'] ?? 'Community';
            return CommunityEventsScreen(
              communityId: widget.communityId,
              communityName: communityName,
            );
          },
        )
      },
      {
        'icon': Icons.campaign_outlined,
        'title': 'Campaigns',
        'color': const Color(0xFFFFAA00),
        'bgColor': const Color(0xFFFFF8E6),
        'screen': CommunityCampaignsScreen(communityId: widget.communityId)
      },
      {
        'icon': Icons.local_offer_outlined,
        'title': 'Coupons',
        'color': const Color(0xFFE84393),
        'bgColor': const Color(0xFFFEEAF3),
        'screen': CommunityCouponsScreen(communityId: widget.communityId)
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: gridItems.length,
          itemBuilder: (context, index) {
            final item = gridItems[index];
            return _buildGridItem(
              context,
              icon: item['icon'] as IconData,
              title: item['title'] as String,
              iconColor: item['color'] as Color,
              bgColor: item['bgColor'] as Color,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => item['screen'] as Widget,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        required Color iconColor,
        required Color bgColor,
      }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
