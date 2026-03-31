import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/communities_provider.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────
const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF1A1A1A);
const _surfaceElevated = Color(0xFF222222);
const _accent = Color(0xFFB06FFF);
const _accentDim = Color(0xFF7C3FCC);
const _accentGlow = Color(0x33B06FFF);
const _textPrimary = Color(0xFFF5F5F5);
const _textSecondary = Color(0xFF9E9E9E);
const _border = Color(0xFF2E2E2E);
const _success = Color(0xFF4CAF50);
const _error = Color(0xFFFF5252);

class CreateCommunityScreen extends StatefulWidget {
  final Map<String, dynamic>? community;
  final String? parentId; // ← pass this to create a sub-community

  const CreateCommunityScreen({
    super.key,
    this.community,
    this.parentId,
  });

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isPrivate = false;
  bool _isSubmitting = false;

  File? _profileImageFile;
  File? _coverImageFile;
  String? _existingProfileImage;
  String? _existingCoverImage;

  final ImagePicker _picker = ImagePicker();

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Focus nodes for animated fields
  final _nameFocus = FocusNode();
  final _descFocus = FocusNode();
  bool _nameHasFocus = false;
  bool _descHasFocus = false;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
    _slideCtrl.forward();

    _nameFocus.addListener(() {
      setState(() => _nameHasFocus = _nameFocus.hasFocus);
    });
    _descFocus.addListener(() {
      setState(() => _descHasFocus = _descFocus.hasFocus);
    });

    // Pre-fill fields if editing
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
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  // ─── Image Helpers ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source, bool isProfile) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: isProfile ? 500 : 1000,
        maxHeight: isProfile ? 500 : 700,
      );
      if (picked == null) return;

      final file = File(picked.path);

      setState(() {
        if (isProfile) {
          _profileImageFile = file;
          _existingProfileImage = null;
        } else {
          _coverImageFile = file;
          _existingCoverImage = null;
        }
      });
    } catch (e) {
      _showSnack('Error picking image: $e', isError: true);
    }
  }

  void _showPickerSheet(bool isProfile) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        onCamera: () => _pickImage(ImageSource.camera, isProfile),
        onGallery: () => _pickImage(ImageSource.gallery, isProfile),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _textPrimary)),
      backgroundColor: isError ? _error : _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    final provider = Provider.of<CommunityProvider>(context, listen: false);
    final Map<String, dynamic> result;

    if (widget.community != null) {
      // ── Edit mode ──────────────────────────────────────────────────────────
      result = await provider.updateCommunity(
        communityId: widget.community!['_id'],
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isPrivate: _isPrivate,
        // Send file path for new picks; null means backend keeps existing
        coverImage: _coverImageFile?.path,
        profileImage: _profileImageFile?.path,
      );
    } else {
      // ── Create mode (community or sub-community) ───────────────────────────
      result = await provider.createCommunity(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isPrivate: _isPrivate,
        parentId: widget.parentId, // null for root, communityId for sub
        coverImage: _coverImageFile?.path,
        profileImage: _profileImageFile?.path,
      );
    }

    setState(() => _isSubmitting = false);

    final hasError = result['error'] == true;
    _showSnack(
      result['message'] ??
          (hasError
              ? 'Something went wrong'
              : widget.community != null
              ? 'Community updated!'
              : widget.parentId != null
              ? 'Sub-community created!'
              : 'Community created!'),
      isError: hasError,
    );

    if (!hasError && mounted) Navigator.pop(context);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.community != null;
    final isSubCommunity = widget.parentId != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(isEdit, isSubCommunity),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 28),

                          // ── Sub-community badge ──────────────────────────
                          if (isSubCommunity) ...[
                            _buildSubCommunityBadge(),
                            const SizedBox(height: 24),
                          ],

                          _buildProfileImageSection(),
                          const SizedBox(height: 32),
                          _sectionLabel('Community Name'),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            hasFocus: _nameHasFocus,
                            hint: isSubCommunity
                                ? 'e.g. Design — Junior Chapter'
                                : 'e.g. Design Collective',
                            icon: Icons.groups_rounded,
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          _sectionLabel('Description'),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: _descriptionController,
                            focusNode: _descFocus,
                            hasFocus: _descHasFocus,
                            hint: 'What is this community about?',
                            icon: Icons.notes_rounded,
                            maxLines: 4,
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Description is required'
                                : null,
                          ),
                          const SizedBox(height: 28),
                          _buildPrivacyToggle(),
                          const SizedBox(height: 36),
                          _buildSubmitButton(isEdit, isSubCommunity),
                          const SizedBox(height: 12),
                          _buildCancelButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sub-community info badge ────────────────────────────────────────────────

  Widget _buildSubCommunityBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _accentGlow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentDim.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_tree_rounded,
                color: _accent, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Creating Sub-Community',
                    style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                SizedBox(height: 2),
                Text('This will be nested inside the parent community',
                    style:
                    TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sliver App Bar with Cover ───────────────────────────────────────────────

  Widget _buildSliverAppBar(bool isEdit, bool isSubCommunity) {
    final title = isEdit
        ? 'Edit Community'
        : isSubCommunity
        ? 'New Sub-Community'
        : 'New Community';

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _bg,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPrimary, size: 18),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
        background: GestureDetector(
          onTap: () => _showPickerSheet(false),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover image or gradient placeholder
              _coverImageFile != null
                  ? Image.file(_coverImageFile!, fit: BoxFit.cover)
                  : (_existingCoverImage?.isNotEmpty ?? false)
                  ? _buildImageWidget(_existingCoverImage!, BoxFit.cover,
                  double.infinity, 220)
                  : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0A2E), Color(0xFF0D0D0D)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _accentGlow,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _accent.withOpacity(0.4),
                              width: 1.5),
                        ),
                        child: const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: _accent,
                            size: 32),
                      ),
                      const SizedBox(height: 10),
                      const Text('Tap to add cover photo',
                          style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                              letterSpacing: 0.3)),
                    ],
                  ),
                ),
              ),

              // Dark scrim at bottom for title legibility
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),

              // Cover remove button — top-left when image exists
              if (_coverImageFile != null ||
                  (_existingCoverImage?.isNotEmpty ?? false))
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _coverImageFile = null;
                      _existingCoverImage = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('Remove',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),

              // Edit / Add badge top-right
              Positioned(
                top: 16,
                right: 16,
                child: _PillBadge(
                  label: _coverImageFile != null ||
                      (_existingCoverImage?.isNotEmpty ?? false)
                      ? 'Change Cover'
                      : 'Add Cover',
                  icon: Icons.camera_alt_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Profile Image ───────────────────────────────────────────────────────────

  Widget _buildProfileImageSection() {
    final hasProfileImage = _profileImageFile != null ||
        (_existingProfileImage?.isNotEmpty ?? false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Profile image — tappable
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showPickerSheet(true),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surfaceElevated,
                  border: Border.all(color: _accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: _accent.withOpacity(0.25),
                        blurRadius: 18,
                        spreadRadius: 2),
                  ],
                ),
                child: ClipOval(
                  child: _profileImageFile != null
                      ? Image.file(_profileImageFile!, fit: BoxFit.cover)
                      : (_existingProfileImage?.isNotEmpty ?? false)
                      ? _buildImageWidget(
                      _existingProfileImage!, BoxFit.cover, 90, 90)
                      : const Icon(Icons.person_rounded,
                      color: _textSecondary, size: 38),
                ),
              ),
            ),

            // Pencil badge bottom-right — IgnorePointer so taps pass through
            Positioned(
              bottom: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 13),
                ),
              ),
            ),

            // Red remove button top-right — only when image exists
            if (hasProfileImage)
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _profileImageFile = null;
                    _existingProfileImage = null;
                  }),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _error,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 2),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 12),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(width: 20),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile Photo',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              const SizedBox(height: 4),
              const Text('Shown in search & community list',
                  style: TextStyle(color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showPickerSheet(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _accentGlow,
                    borderRadius: BorderRadius.circular(20),
                    border:
                    Border.all(color: _accent.withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_rounded, color: _accent, size: 14),
                      SizedBox(width: 6),
                      Text('Upload',
                          style: TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Text Field ──────────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasFocus,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus ? _accent : _border,
          width: hasFocus ? 1.5 : 1,
        ),
        boxShadow: hasFocus
            ? [
          BoxShadow(
              color: _accentGlow, blurRadius: 12, spreadRadius: 1)
        ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        style:
        const TextStyle(color: _textPrimary, fontSize: 15, height: 1.5),
        cursorColor: _accent,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          const TextStyle(color: _textSecondary, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon,
                color: hasFocus ? _accent : _textSecondary, size: 20),
          ),
          prefixIconConstraints:
          const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 16, vertical: maxLines > 1 ? 16 : 0),
          errorStyle: const TextStyle(color: _error, fontSize: 12),
        ),
      ),
    );
  }

  // ─── Privacy Toggle ──────────────────────────────────────────────────────────

  Widget _buildPrivacyToggle() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isPrivate = !_isPrivate);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: _isPrivate ? _accentGlow : _surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border:
          Border.all(color: _isPrivate ? _accent : _border, width: 1.5),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isPrivate ? _accentDim : _surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                color: _isPrivate ? Colors.white : _textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isPrivate
                        ? 'Private Community'
                        : 'Public Community',
                    style: TextStyle(
                      color:
                      _isPrivate ? _textPrimary : _textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isPrivate
                        ? 'Only approved members can join'
                        : 'Anyone can discover and join',
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Custom animated toggle
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 50,
              height: 28,
              decoration: BoxDecoration(
                color: _isPrivate ? _accent : _border,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: _isPrivate
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  margin:
                  const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Submit Button ───────────────────────────────────────────────────────────

  Widget _buildSubmitButton(bool isEdit, bool isSubCommunity) {
    final label = isEdit
        ? 'Save Changes'
        : isSubCommunity
        ? 'Create Sub-Community'
        : 'Create Community';

    final icon = isEdit
        ? Icons.check_circle_rounded
        : Icons.add_circle_rounded;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isSubmitting
              ? null
              : const LinearGradient(
            colors: [Color(0xFFB06FFF), Color(0xFF7C3FCC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          color: _isSubmitting ? _surfaceElevated : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isSubmitting
              ? []
              : [
            BoxShadow(
                color: _accent.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: TextButton(
          onPressed: _isSubmitting ? null : _submit,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: _isSubmitting
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _accent))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Cancel',
            style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 15)),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2));
  }

  /// Renders a network URL or local File image
  Widget _buildImageWidget(
      String src, BoxFit fit, double width, double height) {
    return Image.network(
      src,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) =>
      const Icon(Icons.broken_image_rounded, color: _textSecondary),
    );
  }
}

// ─── Picker Bottom Sheet ─────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PickerSheet({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Choose Photo Source',
              style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 20),
          _SheetOption(
            icon: Icons.camera_alt_rounded,
            label: 'Take a Photo',
            sub: 'Use your camera',
            onTap: () {
              Navigator.pop(context);
              onCamera();
            },
          ),
          Divider(color: _border, height: 1, indent: 20, endIndent: 20),
          _SheetOption(
            icon: Icons.photo_library_rounded,
            label: 'Choose from Gallery',
            sub: 'Pick from your photos',
            onTap: () {
              Navigator.pop(context);
              onGallery();
            },
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style:
                    TextStyle(color: _textSecondary, fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _SheetOption(
      {required this.icon,
        required this.label,
        required this.sub,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: _accentGlow,
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: _accent.withOpacity(0.3))),
              child: Icon(icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(sub,
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: _textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Pill Badge ──────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PillBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}