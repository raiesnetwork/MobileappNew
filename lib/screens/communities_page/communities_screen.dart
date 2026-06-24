import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/communities_provider.dart';
import 'community_info_screen.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  int _currentPage = 1;
  bool _isLoadingMore = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // ✅ Always fetch fresh data on screen entry (not just "if not loaded")
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      // Reset to page 1 and fetch fresh
      _currentPage = 1;
      provider.fetchCommunities(page: _currentPage);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });

      // ✅ When search is active, load ALL pages to search across all communities
      if (_searchQuery.isNotEmpty) {
        _loadAllPagesForSearch();
      }
    });
  }

  // ✅ NEW METHOD: Load all pages when searching
  Future<void> _loadAllPagesForSearch() async {
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    final totalPages = provider.communities['totalPages'] ?? 1;

    print('🔍 Loading all $totalPages pages for search...');

    // Load all remaining pages
    for (int page = _currentPage + 1; page <= totalPages; page++) {
      if (!mounted) return;
      await provider.fetchCommunities(page: page);
    }

    print('✅ All pages loaded for search');
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _currentPage = 1;  // ✅ Reset to page 1 when clearing search
    });
  }

  void _loadMoreCommunities() async {
    if (_isLoadingMore) return;  // ← Keep only this check

    final provider = Provider.of<CommunityProvider>(context, listen: false);
    if (provider.isLoading) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;
    await provider.fetchCommunities(page: _currentPage);
    setState(() => _isLoadingMore = false);
  }

  Widget _buildImageWidget(String? imageData, {bool isProfileImage = false}) {
    if (imageData == null || imageData.isEmpty) {
      return isProfileImage
          ? CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[400],
        child: const Icon(Icons.person, color: Colors.white, size: 28),
      )
          : const SizedBox();
    }

    if (isProfileImage) {
      ImageProvider? imageProvider;
      try {
        if (imageData.startsWith('data:')) {
          final base64Data = imageData.split(',')[1];
          imageProvider = MemoryImage(base64Decode(base64Data));
        } else {
          imageProvider = NetworkImage(imageData);
        }
      } catch (e) {
        imageProvider = null;
      }

      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[300],
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? const Icon(Icons.person, color: Colors.white, size: 28)
            : null,
      );
    } else {
      if (imageData.startsWith('data:')) {
        final base64Data = imageData.split(',')[1];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(base64Data),
            fit: BoxFit.cover,
            width: double.infinity,
            height: 300,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 300,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            ),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageData,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 300,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 300,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
            ),
          ),
        ),
      );
    }
  }

  String _getActionText(Map<String, dynamic> community) {
    final isJoined = community['isJoined'] ?? false;
    final isPrivate = community['isPrivate'] ?? false;
    final requestStatus = community['requestStatus'];

    if (isJoined) return 'Joined';
    if (isPrivate) {
      switch (requestStatus) {
        case 'pending':
          return 'Requested';
        case 'rejected':
          return 'Request';
        default:
          return 'Request';
      }
    }
    return 'Join';
  }

  Color _getActionTextColor(Map<String, dynamic> community) {
    final isJoined = community['isJoined'] ?? false;
    final requestStatus = community['requestStatus'];

    if (isJoined) return Colors.green;
    if (requestStatus == 'pending') return Colors.orange;
    return Primary;
  }

  bool _isActionEnabled(Map<String, dynamic> community) {
    final isJoined = community['isJoined'] ?? false;
    final requestStatus = community['requestStatus'];
    return !isJoined && requestStatus != 'pending';
  }

  Future<void> _handleCommunityAction(Map<String, dynamic> community) async {
    if (!_isActionEnabled(community)) return;

    final provider = Provider.of<CommunityProvider>(context, listen: false);

    // ✅ Read isPrivate BEFORE the call — from community object
    final isPrivate = community['isPrivate'] == true;

    print('🔍 isPrivate: $isPrivate | community: ${community['name']}');
    print('🔍 isPrivate raw value: ${community['isPrivate']} | type: ${community['isPrivate'].runtimeType}');

    final result = await provider.joinCommunity(community['_id'] as String);

    if (!mounted) return;

    final message = result['message']?.toString() ?? '';

    final needsOnboarding = message.toLowerCase().contains('onboarding') ||
        message.toLowerCase().contains('finish your onboarding') ||
        message.toLowerCase().contains('complete your onboarding');
    print('🔍 message: $message | needsOnboarding: $needsOnboarding | isSuccess: ${result['success']}');

    if (needsOnboarding) {
      _showOnboardingDialog();
      return;
    }

    // Check already joined
    if (message.toLowerCase().contains('already')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already a member of this community'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final isSuccess = result['success'] == true;

    if (isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPrivate
                ? 'Join request sent successfully'
                : 'Joined successfully',
          ),
          // ✅ Green for both — orange for private if you prefer
          backgroundColor: isPrivate ? Colors.orange : Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isNotEmpty ? message : 'Failed to join'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOnboardingDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_outlined,
                    color: Primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Complete Onboarding First',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'You need to complete your onboarding steps before joining a community. It only takes a few minutes!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _launchOnboarding();
                  },
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: const Text(
                    'Complete Onboarding',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchOnboarding() async {
    final uri = Uri.parse('https://ixes.ai/onboarding/');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open onboarding page'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CommunityProvider>(context);
    final communityList =
        (provider.communities['data'] as List<dynamic>?) ?? [];
    final totalPages = provider.communities['totalPages'] ?? 1;

    // ✅ Filter directly from provider data — no local cache needed
    final displayList = _searchQuery.isEmpty
        ? communityList
        : communityList.where((community) {
      final name =
          (community['name'] as String?)?.toLowerCase() ?? '';
      final description =
          (community['description'] as String?)?.toLowerCase() ?? '';
      return name.contains(_searchQuery) ||
          description.contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text(
            'All Communities',
            style: TextStyle(
              color: Primary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateCommunityScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search ...',
                prefixIcon:
                const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: _clearSearch,
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: provider.isLoading && communityList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && communityList.isEmpty
                ? Center(child: Text('Error: ${provider.error}'))
                : provider.communities['error'] == true
                ? Center(
              child: Text(
                provider.communities['message'] ??
                    'Error loading communities',
              ),
            )
                : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _currentPage = 1;
                  _searchQuery = '';
                  _searchController.clear();
                });
                await provider.fetchCommunities(page: 1);
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 100 &&
                      !_isLoadingMore &&
                      !provider.isLoading &&
                      _currentPage < totalPages) {
                    _loadMoreCommunities();
                  }
                  return false;
                },
                child: displayList.isEmpty
                    ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No communities found matching "$_searchQuery"'
                        : 'No communities found',
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  itemCount: displayList.length +
                      (_isLoadingMore &&
                          _searchQuery.isEmpty
                          ? 1
                          : 0),
                  itemBuilder: (context, index) {
                    if (index == displayList.length &&
                        _isLoadingMore &&
                        _searchQuery.isEmpty) {
                      return const Center(
                        child:
                        CircularProgressIndicator(),
                      );
                    }

                    final community = displayList[index]
                    as Map<String, dynamic>;

                    return GestureDetector(
                      onTap: () {
                        _searchFocusNode.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CommunityInfoScreen(
                                  communityId: community[
                                  '_id'] as String,
                                ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(
                            bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.05),
                              blurRadius: 8,
                              offset:
                              const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding:
                          const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              community['profileImage']
                                  ?.isNotEmpty ??
                                  false
                                  ? _buildImageWidget(
                                community[
                                'profileImage'],
                                isProfileImage:
                                true,
                              )
                                  : CircleAvatar(
                                radius: 30,
                                backgroundColor:
                                Primary,
                                child: Text(
                                  community['name']
                                      ?.isNotEmpty ??
                                      false
                                      ? community[
                                  'name']
                                  [0]
                                      .toUpperCase()
                                      : 'C',
                                  style:
                                  const TextStyle(
                                    color: Colors
                                        .white,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            community[
                                            'name'] ??
                                                'Unnamed Community',
                                            style:
                                            const TextStyle(
                                              fontSize:
                                              16,
                                              fontWeight:
                                              FontWeight
                                                  .w600,
                                              color: Colors
                                                  .black87,
                                            ),
                                            overflow:
                                            TextOverflow
                                                .ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              _handleCommunityAction(
                                                  community),
                                          child: Text(
                                            _getActionText(
                                                community),
                                            style:
                                            TextStyle(
                                              color: _isActionEnabled(
                                                  community)
                                                  ? _getActionTextColor(
                                                  community)
                                                  : Colors
                                                  .grey,
                                              fontSize:
                                              14,
                                              fontWeight:
                                              FontWeight
                                                  .w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                        height: 4),
                                    if (community['description']
                                        ?.isNotEmpty ??
                                        false)
                                      Text(
                                        community[
                                        'description'],
                                        style:
                                        const TextStyle(
                                          color:
                                          Colors.grey,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow:
                                        TextOverflow
                                            .ellipsis,
                                      ),
                                    const SizedBox(
                                        height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration:
                                          BoxDecoration(
                                            color: community[
                                            'isPrivate'] ==
                                                true
                                                ? Colors
                                                .orange
                                                .withOpacity(
                                                0.1)
                                                : Colors
                                                .green
                                                .withOpacity(
                                                0.1),
                                            borderRadius:
                                            BorderRadius
                                                .circular(
                                                8),
                                          ),
                                          child: Text(
                                            community['isPrivate'] ==
                                                true
                                                ? 'Private'
                                                : 'Public',
                                            style:
                                            TextStyle(
                                              color: community[
                                              'isPrivate'] ==
                                                  true
                                                  ? Colors
                                                  .orange[700]
                                                  : Colors
                                                  .green[700],
                                              fontSize:
                                              11,
                                              fontWeight:
                                              FontWeight
                                                  .w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}