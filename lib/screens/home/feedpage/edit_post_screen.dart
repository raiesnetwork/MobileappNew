import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../models/post_model.dart';
import '../../../providers/comment_provider.dart';
import '../../../constants/constants.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;
  final String? communityId;

  const EditPostScreen({
    Key? key,
    required this.post,
    this.communityId,
  }) : super(key: key);

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<String> existingImages = [];
  String? existingVideo;
  List<XFile> newImages = [];
  XFile? newVideo;
  Set<String> mediaToDelete = {};

  bool isUploading = false;
  String? mediaType;

  @override
  void initState() {
    super.initState();
    _contentController.text = widget.post.postContent;

    existingImages = List.from(widget.post.postImages.where((img) =>
    img.isNotEmpty && !img.startsWith('/')
    ));

    if (widget.post.postVideo != null && widget.post.postVideo!.isNotEmpty) {
      existingVideo = widget.post.postVideo!.first;
    }

    if (existingVideo != null) {
      mediaType = 'video';
    } else if (existingImages.isNotEmpty) {
      mediaType = 'image';
    } else {
      mediaType = null;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          newImages.addAll(images);
          if (mediaType == null || mediaType == 'video') {
            mediaType = 'image';
          }
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick images', isError: true);
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          newVideo = video;
          mediaType = 'video';
          newImages.clear();
          existingImages.clear();
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick video', isError: true);
    }
  }

  void _removeExistingImage(String imageUrl) {
    setState(() {
      existingImages.remove(imageUrl);
      mediaToDelete.add(imageUrl);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      newImages.removeAt(index);
    });
  }

  void _removeExistingVideo() {
    if (existingVideo != null) {
      setState(() {
        mediaToDelete.add(existingVideo!);
        existingVideo = null;
      });
    }
  }

  void _removeNewVideo() {
    setState(() {
      newVideo = null;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updatePost() async {
    final content = _contentController.text.trim();

    if (content.isEmpty &&
        existingImages.isEmpty &&
        newImages.isEmpty &&
        existingVideo == null &&
        newVideo == null) {
      _showSnackBar('Post must have content or media', isError: true);
      return;
    }

    setState(() => isUploading = true);

    try {
      final provider = context.read<CommentProvider>();

      List<String>? newImagePaths;
      if (newImages.isNotEmpty) {
        newImagePaths = newImages.map((img) => img.path).toList();
      }

      String? newVideoPath = newVideo?.path;
      String? deleteMediaUrl = mediaToDelete.isNotEmpty ? mediaToDelete.first : null;

      print('🔄 Starting update for post: ${widget.post.id}');

      final success = await provider.updatePost(
        context: context,
        postId: widget.post.id,
        postContent: content.isNotEmpty ? content : null,
        mediaType: mediaType,
        deleteOldMediaUrl: deleteMediaUrl,
        newImagePaths: newImagePaths,
        newVideoPath: newVideoPath,
        offset: 0,
        limit: 10,
        communityId: widget.communityId,
      );

      if (success) {
        print('✅ Update successful, fetching latest data...');

        // ✅ CRITICAL: Fetch fresh data BEFORE navigating back
        if (widget.communityId != null) {
          await provider.fetchCommunityPosts(
            communityId: widget.communityId!,
            offset: 0,
            limit: 10,
          );
        } else {
          await provider.fetchAllPosts(
            offset: 0,
            limit: 10,
            isRefresh: true,
          );
        }

        print('✅ Data refreshed, now navigating back...');

        if (mounted) {
          _showSnackBar('Post updated successfully');
          // Small delay to ensure state is updated
          await Future.delayed(Duration(milliseconds: 100));
          Navigator.pop(context, true);
        }
      } else {
        print('❌ Update failed');
        if (mounted) {
          setState(() => isUploading = false);
        }
      }
    } catch (e) {
      print('❌ Error in _updatePost: $e');
      _showSnackBar('Failed to update post', isError: true);
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyMedia = (existingImages.isNotEmpty || existingVideo != null) ||
        (newImages.isNotEmpty || newVideo != null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Post',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton(
              onPressed: isUploading ? null : _updatePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isUploading
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                'Update',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content TextField
            Container(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _contentController,
                maxLines: 6,
                style: TextStyle(fontSize: 15, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind?',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),

            Divider(height: 1, thickness: 1),

            // Media Buttons
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.image,
                      label: 'Add Images',
                      onTap: _pickImages,
                      isDisabled: isUploading || mediaType == 'video',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.videocam,
                      label: 'Add Video',
                      onTap: _pickVideo,
                      isDisabled: isUploading || hasAnyMedia,
                    ),
                  ),
                ],
              ),
            ),

            // Existing Images
            if (existingImages.isNotEmpty)
              _buildMediaSection(
                title: 'Current Images',
                child: _buildImageGrid(existingImages, isExisting: true),
              ),

            // New Images
            if (newImages.isNotEmpty)
              _buildMediaSection(
                title: 'New Images',
                child: _buildNewImageGrid(),
              ),

            // Existing Video
            if (existingVideo != null)
              _buildMediaSection(
                title: 'Current Video',
                child: _buildVideoTile(onRemove: _removeExistingVideo),
              ),

            // New Video
            if (newVideo != null)
              _buildMediaSection(
                title: 'New Video',
                child: _buildVideoTile(
                  onRemove: _removeNewVideo,
                  label: 'Video Selected',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDisabled,
  }) {
    return OutlinedButton.icon(
      onPressed: isDisabled ? null : onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, style: TextStyle(fontSize: 14)),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color: isDisabled ? Colors.grey[300]! : Primary.withOpacity(0.5),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        foregroundColor: isDisabled ? Colors.grey : Primary,
      ),
    );
  }

  Widget _buildMediaSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildImageGrid(List<String> images, {bool isExisting = false}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.error, color: Colors.red),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeExistingImage(images[index]),
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNewImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: newImages.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(newImages[index].path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeNewImage(index),
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoTile({
    required VoidCallback onRemove,
    String label = 'Current Video',
  }) {
    return Stack(
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 48, color: Colors.grey[600]),
                SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}