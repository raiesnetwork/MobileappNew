import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/communities_provider.dart';
import 'package:ixes.app/constants/constants.dart';

class CreateCommunityScreen extends StatefulWidget {
  final Map<String, dynamic>? community; // For edit mode

  const CreateCommunityScreen({super.key, this.community});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
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

  @override
  void initState() {
    super.initState();
    if (widget.community != null) {
      _nameController.text = widget.community!['name'] ?? '';
      _descriptionController.text = widget.community!['description'] ?? '';
      _isPrivate = widget.community!['isPrivate'] ?? false;
      _existingProfileImage = widget.community!['profileImage'];
      _existingCoverImage = widget.community!['coverImage'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isProfileImage) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: isProfileImage ? 400 : 800,
        maxHeight: isProfileImage ? 400 : 600,
      );
      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final extension = pickedFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      final dataUrl = 'data:$mimeType;base64,$base64Image';

      setState(() {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

  void _showImageSourceDialog(bool isProfileImage) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera, color: Color(0xFF800080)),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera, isProfileImage);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFF800080)),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery, isProfileImage);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String? imageData, {bool isProfileImage = false}) {
    if (imageData == null || imageData.isEmpty) {
      return isProfileImage
          ? const Icon(Icons.person, color: Colors.white, size: 32)
          : const Icon(Icons.image, color: Colors.grey, size: 32);
    }
    if (imageData.startsWith('data:')) {
      final base64Data = imageData.split(',')[1];
      return Image.memory(
        base64Decode(base64Data),
        fit: BoxFit.cover,
        width: isProfileImage ? 80 : double.infinity,
        height: isProfileImage ? 80 : 120,
        errorBuilder: (context, error, stackTrace) => isProfileImage
            ? const Icon(Icons.person, color: Colors.white, size: 32)
            : const Icon(Icons.image, color: Colors.grey, size: 32),
      );
    }
    return Image.network(
      imageData,
      fit: BoxFit.cover,
      width: isProfileImage ? 80 : double.infinity,
      height: isProfileImage ? 80 : 120,
      errorBuilder: (context, error, stackTrace) => isProfileImage
          ? const Icon(Icons.person, color: Colors.white, size: 32)
          : const Icon(Icons.image, color: Colors.grey, size: 32),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      final Map<String, dynamic> result;

      if (widget.community != null) {
        result = await provider.updateCommunity(
          communityId: widget.community!['_id'],
          name: _nameController.text,
          description: _descriptionController.text,
          isPrivate: _isPrivate,
          coverImage: _coverImageBase64,
          profileImage: _profileImageBase64,
        );
      } else {
        result = await provider.createCommunity(
          name: _nameController.text,
          description: _descriptionController.text,
          isPrivate: _isPrivate,
          parentId: null,
          coverImage: _coverImageBase64,
          profileImage: _profileImageBase64,
        );
      }

      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] == true
                  ? result['message'] ?? 'Something went wrong'
                  : result['message'] ??
                  (widget.community != null
                      ? 'Community updated successfully'
                      : 'Community created successfully'),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: result['error'] == true ? Colors.red : Colors.green,
          ),
        );
      }
      if (!(result['error'] as bool)) {
        _formKey.currentState?.reset();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.community != null ? 'Edit Community' : 'Create Community',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Image
                  const Text(
                    'Cover Image',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showImageSourceDialog(false),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_coverImageFile != null)
                              Image.file(
                                _coverImageFile!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 120,
                              )
                            else if (_existingCoverImage?.isNotEmpty ?? false)
                              _buildImageWidget(_existingCoverImage!)
                            else
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    color: Colors.grey,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add Cover Image',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            if (_coverImageFile != null ||
                                (_existingCoverImage?.isNotEmpty ?? false))
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _coverImageFile = null;
                                    _coverImageBase64 = null;
                                    _existingCoverImage = null;
                                  }),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Image
                  const Text(
                    'Profile Image',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: () => _showImageSourceDialog(true),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: ClipOval(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_profileImageFile != null)
                                Image.file(
                                  _profileImageFile!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                )
                              else if (_existingProfileImage?.isNotEmpty ?? false)
                                _buildImageWidget(
                                  _existingProfileImage!,
                                  isProfileImage: true,
                                )
                              else
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.add_a_photo,
                                      color: Colors.grey,
                                      size: 32,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add Photo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              if (_profileImageFile != null ||
                                  (_existingProfileImage?.isNotEmpty ?? false))
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _profileImageFile = null;
                                      _profileImageBase64 = null;
                                      _existingProfileImage = null;
                                    }),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Community Name *',
                      prefixIcon: const Icon(Icons.group, color: Color(0xFF800080)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    validator: (value) =>
                    value?.isEmpty ?? true ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      prefixIcon: const Icon(Icons.description, color: Color(0xFF800080)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: 3,
                    validator: (value) =>
                    value?.isEmpty ?? true ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Privacy Toggle
                  CheckboxListTile(
                    value: _isPrivate,
                    onChanged: (value) => setState(() => _isPrivate = value ?? false),
                    title: Text(
                      _isPrivate ? '🔒 Private Community' : '🌐 Public Community',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF800080),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF800080)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF800080),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF800080),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          widget.community != null ? 'Update' : 'Create',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}