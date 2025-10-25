import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
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
  List<dynamic> _filteredCommunities = [];
  List<dynamic> _allLoadedCommunities = [];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    if (provider.communities['message'] == 'Not loaded') {
      provider.fetchCommunities(page: _currentPage);
    }
    _searchController.addListener(_onSearchChanged);
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
        _filterCommunities();
      });
    });
  }

  void _filterCommunities() {
    if (_searchQuery.isEmpty) {
      _filteredCommunities = List.from(_allLoadedCommunities);
    } else {
      _filteredCommunities = _allLoadedCommunities.where((community) {
        final communityName = (community['name'] as String?)?.toLowerCase() ?? '';
        return communityName.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadMoreCommunities() async {
    if (_isLoadingMore || _searchQuery.isNotEmpty) return; // Don't load more during search
    setState(() => _isLoadingMore = true);
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    _currentPage++;
    await provider.fetchCommunities(page: _currentPage);
    setState(() => _isLoadingMore = false);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _filterCommunities();
    });
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
        height: isProfileImage ? 60 : 300,
        errorBuilder: (context, error, stackTrace) => isProfileImage
            ? const Icon(Icons.person, color: Colors.white, size: 20)
            : const SizedBox(),
      );
    }
    return Image.network(
      imageData,
      fit: BoxFit.cover,
      width: isProfileImage ? 50 : double.infinity,
      height: isProfileImage ? 50 : 300,
      errorBuilder: (context, error, stackTrace) => isProfileImage
          ? const Icon(Icons.person, color: Colors.white, size: 20)
          : const SizedBox(),
    );
  }

  String _getActionText(Map<String, dynamic> community) {
    final isJoined = community['isJoined'] ?? false;
    final isPrivate = community['isPrivate'] ?? false;
    final requestStatus = community['requestStatus'];

    if (isJoined) {
      return 'Joined';
    }
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

    if (isJoined) {
      return Colors.green;
    }
    if (requestStatus == 'pending') {
      return Colors.orange;
    }
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
    final isPrivate = community['isPrivate'] ?? false;

    Map<String, dynamic> result;

    if (isPrivate) {
      // For private communities, send join request
      result = await provider.joinCommunity(community['_id'] as String);
    } else {
      // For public communities, join directly
      result = await provider.joinCommunity(community['_id'] as String);
    }

    if (mounted) {
      String message;
      if (result['error'] == true) {
        message = result['message'] ?? 'Failed to perform action';
      } else {
        if (isPrivate) {
          message = result['message'] ?? 'Request sent successfully';
        } else {
          message = result['message'] ?? 'Joined successfully';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result['error'] == true ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CommunityProvider>(context);
    final communityList = (provider.communities['data'] as List<dynamic>?) ?? [];
    final totalPages = provider.communities['totalPages'] ?? 1;

    // Update all loaded communities when provider data changes
    if (communityList.isNotEmpty) {
      _allLoadedCommunities = List.from(communityList);
      if (_filteredCommunities.isEmpty && _searchQuery.isEmpty) {
        _filteredCommunities = List.from(_allLoadedCommunities);
      } else if (_searchQuery.isNotEmpty) {
        _filterCommunities();
      }
    }

    // Use filtered communities for display
    final displayList = _searchQuery.isNotEmpty ? _filteredCommunities : communityList;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: GestureDetector(
              onTap: () {
                _searchFocusNode.requestFocus();
              },
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search ...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
          ),
          Expanded(
            child: provider.isLoading && communityList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
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
                setState(() => _currentPage = 1);
                await provider.fetchCommunities(page: _currentPage);
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (scrollInfo.metrics.pixels ==
                      scrollInfo.metrics.maxScrollExtent &&
                      !_isLoadingMore &&
                      _currentPage < totalPages &&
                      _searchQuery.isEmpty) { // Only load more when not searching
                    _loadMoreCommunities();
                  }
                  return false;
                },
                child: displayList.isEmpty
                    ? Center(
                  child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No communities found matching "$_searchQuery"'
                          : 'No communities found'
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayList.length +
                      (_isLoadingMore && _searchQuery.isEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayList.length &&
                        _isLoadingMore && _searchQuery.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final community =
                    displayList[index] as Map<String, dynamic>;

                    return GestureDetector(
                      onTap: () {
                        _searchFocusNode.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CommunityInfoScreen(
                                  communityId:
                                  community['_id'] as String,
                                ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: community['profileImage']?.isNotEmpty ?? false
                                      ? _buildImageWidget(
                                    community['profileImage'],
                                    isProfileImage: true,
                                  )
                                      : Container(
                                    decoration: BoxDecoration(
                                      color: Primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        community['name']?.isNotEmpty ?? false
                                            ? community['name'][0].toUpperCase()
                                            : 'C',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            community['name'] ?? 'Unnamed Community',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _handleCommunityAction(community),
                                          child: Text(
                                            _getActionText(community),
                                            style: TextStyle(
                                              color: _isActionEnabled(community)
                                                  ? _getActionTextColor(community)
                                                  : Colors.grey,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (community['description']?.isNotEmpty ?? false)
                                      Text(
                                        community['description'],
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: community['isPrivate'] == true
                                            ? Colors.orange.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        community['isPrivate'] == true
                                            ? 'Private'
                                            : 'Public',
                                        style: TextStyle(
                                          color: community['isPrivate'] == true
                                              ? Colors.orange[700]
                                              : Colors.green[700],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
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