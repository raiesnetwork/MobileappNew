import 'dart:io';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/providers/post_provider.dart';
import 'package:ixes.app/screens/BottomNaviagation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:video_player/video_player.dart';

import '../../../constants/constants.dart';
import '../../../constants/constants.dart';
import '../../../models/post_model.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;

  const CreatePostScreen({
    super.key,
    this.communityId,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedMediaType = 'content';
  List<XFile> _selectedImages = [];
  XFile? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  bool _showErrorMessage = false;

  @override
  void dispose() {
    _contentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<String> _convertToBase64(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('Failed to convert file to base64: $e');
    }
  }

  Future<List<String>> _convertImagesToBase64(List<XFile> images) async {
    List<String> base64Images = [];
    for (XFile image in images) {
      try {
        String base64String = await _convertToBase64(image.path);
        base64Images.add(base64String);
      } catch (e) {
        throw Exception('Failed to convert image to base64: $e');
      }
    }
    return base64Images;
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultipleMedia(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (images.isNotEmpty) {
        final imageFiles = images
            .where((file) =>
                file.path.toLowerCase().endsWith('.jpg') ||
                file.path.toLowerCase().endsWith('.jpeg') ||
                file.path.toLowerCase().endsWith('.png') ||
                file.path.toLowerCase().endsWith('.gif'))
            .take(5)
            .toList();

        if (imageFiles.isNotEmpty) {
          setState(() {
            _selectedImages = imageFiles;
            _selectedMediaType = 'image';
            _selectedVideo = null;
            _videoController?.dispose();
            _videoController = null;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting images: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final controller = VideoPlayerController.file(File(video.path));
        await controller.initialize();

        setState(() {
          _selectedVideo = video;
          _selectedMediaType = 'video';
          _selectedImages.clear();
          _videoController?.dispose();
          _videoController = controller;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting video: $e');
    }
  }

// Remove these methods since we're no longer using base64:
// - _convertToBase64()
// - _convertImagesToBase64()

// Update the _createPost method to pass file paths instead of base64 strings:

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    final content = _contentController.text.trim();

    if (content.isEmpty && _selectedImages.isEmpty && _selectedVideo == null) {
      _showErrorSnackBar('Please add some content, images, or video');
      return;
    }
    if ((content.isEmpty && _selectedImages.isEmpty && _selectedVideo == null)) {
      setState(() {
        _showErrorMessage = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      // Get file paths instead of converting to base64
      List<String>? imagePaths;
      if (_selectedImages.isNotEmpty) {
        imagePaths = _selectedImages.map((image) => image.path).toList();
      }

      String? videoPath;
      if (_selectedVideo != null) {
        videoPath = _selectedVideo!.path;
      }

      final success = await postProvider.createPost(
        mediaType: _selectedMediaType,
        postContent: content,
        postImages: imagePaths,  // Pass file paths instead of base64
        postVideo: videoPath,    // Pass file path instead of base64
        communityId: widget.communityId,
      );

      if (!mounted) return;

      if (success) {
        _resetForm();
        _showSuccessSnackBar('Post created successfully!');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MainScreen(initialIndex: 0),
          ),
        );
      } else {
        print("Post creation failed");
        _showErrorSnackBar('Failed to create post');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to create post: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetForm() {
    _contentController.clear();
    setState(() {
      _selectedImages.clear();
      _selectedVideo = null;
      _selectedMediaType = 'content';
      _videoController?.dispose();
      _videoController = null;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_selectedImages.isEmpty) {
        _selectedMediaType = 'content';
      }
    });
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
      _selectedMediaType = 'content';
      _videoController?.dispose();
      _videoController = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tWhite,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        backgroundColor: tWhite,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            widget.communityId != null ? 'Post to Community' : 'Create Post',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
              color: Colors.black,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Image.asset(
                "assets/icons/close.png",
                scale: 2.4,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<PostProvider>(
        builder: (context, postsData, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Post content field with improved alignment
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 120,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showErrorMessage 
                                  ? Colors.red.shade300 
                                  : Colors.transparent,
                            ),
                          ),
                          child: TextFormField(
                            controller: _contentController,
                            maxLines: null,
                            maxLength: 500,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "What's on your mind...?",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) {
                              if (_showErrorMessage &&
                                  (value.trim().isNotEmpty ||
                                      _selectedImages.isNotEmpty ||
                                      _selectedVideo != null)) {
                                setState(() {
                                  _showErrorMessage = false;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_showErrorMessage)
                              const Text(
                                'Please add some content or media',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            Text(
                              '${_contentController.text.length}/500 characters',
                              style: TextStyle(
                                color: _contentController.text.length > 450
                                    ? Colors.red
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // const SizedBox(height: 20),

                  // Media type selector with improved layout
                  Card(
                    elevation: 2,
                    shadowColor: Colors.grey.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Media',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select media type to add content',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _MediaTypeChip(
                                  label: 'Text Only',
                                  icon: Icons.text_fields,
                                  selected: _selectedMediaType == 'content',
                                  onSelected: () {
                                    setState(() {
                                      _selectedMediaType = 'content';
                                      _selectedImages.clear();
                                      _selectedVideo = null;
                                      _videoController?.dispose();
                                      _videoController = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MediaTypeChip(
                                  label: 'Images',
                                  icon: Icons.photo_library,
                                  selected: _selectedMediaType == 'image',
                                  onSelected: () {
                                    setState(() {
                                      _selectedMediaType = 'image';
                                    });
                                    _pickImages();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MediaTypeChip(
                                  label: 'Video',
                                  icon: Icons.videocam,
                                  selected: _selectedMediaType == 'video',
                                  onSelected: () {
                                    setState(() {
                                      _selectedMediaType = 'video';
                                    });
                                    _pickVideo();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Media preview section with improved layout
                  Card(
                    elevation: 2,
                    shadowColor: Colors.grey.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedImages.isEmpty && _selectedVideo == null)
                            Container(
                              height: 180,
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade50,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    color: Primary,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Selected images or video\nwill show here',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Selected images display
                          if (_selectedImages.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Selected Images (${_selectedImages.length}/5)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedImages.clear();
                                      _selectedMediaType = 'content';
                                    });
                                  },
                                  child: const Text('Clear All'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            File(_selectedImages[index].path),
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 120,
                                                height: 120,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // Selected video display
                          if (_selectedVideo != null && _videoController != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Selected Video',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _removeVideo,
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  if (_videoController!.value.isInitialized)
                                    Center(
                                      child: AspectRatio(
                                        aspectRatio: _videoController!.value.aspectRatio,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                    )
                                  else
                                    const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  Center(
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_videoController!.value.isPlaying) {
                                            _videoController!.pause();
                                          } else {
                                            _videoController!.play();
                                          }
                                        });
                                      },
                                      icon: Icon(
                                        _videoController!.value.isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_filled,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Post button with loader
                  Container(
                    padding:  EdgeInsets.symmetric(horizontal: 15.w),
                    width: double.infinity,
                    // height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: Primary.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Primary.withOpacity(0.6),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  // height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Posting...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Post',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MediaTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  const _MediaTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Primary : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Primary : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}