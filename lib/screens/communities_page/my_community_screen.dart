import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/providers/communities_provider.dart';
import 'package:ixes.app/screens/communities_page/community_info_screen.dart';
import 'package:provider/provider.dart';

class CommunitiesListWidget extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onCommunityTapped;

  const CommunitiesListWidget({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onCommunityTapped,
  });

  @override
  State<CommunitiesListWidget> createState() => _CommunitiesListWidgetState();
}

class _CommunitiesListWidgetState extends State<CommunitiesListWidget> {
  final Set<String> _expandedCommunities = {};

  Widget _buildImageWidget(String? imageData, {bool isProfileImage = false}) {
    final fallback = isProfileImage
        ? const Icon(Icons.person, color: Colors.white, size: 20)
        : const SizedBox.shrink();

    if (imageData == null || imageData.isEmpty) return fallback;

    try {
      if (imageData.startsWith('http') || imageData.startsWith('/')) {
        final url = imageData.startsWith('/')
            ? 'https://api.ixes.ai$imageData'
            : imageData;
        return Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => fallback,
        );
      }

      final base64String = imageData.contains(',')
          ? imageData.split(',').last
          : imageData;

      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildCommunityTile({
    required Map<String, dynamic> community,
    required int level,
    bool isLastInGroup = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final communityId = (community['_id'] ?? community['id'])?.toString() ?? '';
    final communityName = community['name']?.toString() ?? 'Unnamed Community';
    final subCommunities = community['subCommunities'] as List? ?? [];
    final hasSubCommunities = subCommunities.isNotEmpty;
    final isExpanded = _expandedCommunities.contains(communityId);

    final double leftPadding =
    (level == 0 ? 16.0 : 16.0 + (level * 20.0)).clamp(16.0, screenWidth * 0.4);
    final double avatarRadius = screenWidth < 360 ? 18.0 : (level == 0 ? 22.0 : 18.0);
    final double fontSize = screenWidth < 360 ? 12.0 : (level == 0 ? 14.0 : 13.0);

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(
            left: leftPadding,
            right: 4, // reduced so trailing has room
            top: level == 0 ? 6 : 4,
            bottom: level == 0 ? 6 : 4,
          ),
          leading: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.grey[800],
            child: ClipOval(
              child: community['profileImage'] != null &&
                  community['profileImage'].toString().isNotEmpty
                  ? SizedBox(
                width: avatarRadius * 2,
                height: avatarRadius * 2,
                child: _buildImageWidget(
                  community['profileImage'].toString(),
                  isProfileImage: true,
                ),
              )
                  : Text(
                communityName[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: level == 0 ? 13.0 : 11.0,
                ),
              ),
            ),
          ),
          title: Text(
            communityName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: level == 0 ? FontWeight.w600 : FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
          subtitle: _buildSubtitle(community, level, hasSubCommunities, subCommunities),
          // Large 48×48 tap target for expand/collapse and forward arrow
          trailing: SizedBox(
            width: 48,
            height: 48,
            child: hasSubCommunities
                ? InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCommunities.remove(communityId);
                  } else {
                    _expandedCommunities.add(communityId);
                  }
                });
              },
              borderRadius: BorderRadius.circular(24),
              child: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white70,
                size: 24,
              ),
            )
                : const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ),
          onTap: () {
            widget.onCommunityTapped();
            if (communityId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityInfoScreen(communityId: communityId),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid community ID'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),

        if (hasSubCommunities && isExpanded)
          ...subCommunities.asMap().entries.map((entry) {
            return _buildCommunityTile(
              community: entry.value as Map<String, dynamic>,
              level: level + 1,
              isLastInGroup: entry.key == subCommunities.length - 1,
            );
          }),

        if (level == 0 && !isLastInGroup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.grey[800], height: 1),
          ),
      ],
    );
  }

  Widget _buildSubtitle(
      Map<String, dynamic> community,
      int level,
      bool hasSubCommunities,
      List subCommunities,
      ) {
    if (level != 0) {
      return Text(
        'Subcommunity',
        style: TextStyle(color: Colors.grey[500], fontSize: 11),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          community['isPrivate'] == true ? Icons.lock : Icons.public,
          color: Colors.grey[500],
          size: 13,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            community['isPrivate'] == true ? 'Private' : 'Public',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasSubCommunities) ...[
          const SizedBox(width: 6),
          Icon(Icons.folder_outlined, color: Colors.grey[500], size: 13),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '${subCommunities.length} sub${subCommunities.length == 1 ? '' : 's'}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  bool _communityMatchesSearch(Map<String, dynamic> community, String query) {
    if ((community['name']?.toString().toLowerCase() ?? '').contains(query)) return true;
    final subs = community['subCommunities'] as List? ?? [];
    return subs.any((s) => _communityMatchesSearch(s as Map<String, dynamic>, query));
  }

  List<Widget> _buildCommunityList(List<dynamic> communities) {
    final query = widget.searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? communities
        : communities
        .where((c) => _communityMatchesSearch(c as Map<String, dynamic>, query))
        .toList();

    return filtered.asMap().entries.map((entry) {
      return _buildCommunityTile(
        community: entry.value as Map<String, dynamic>,
        level: 0,
        isLastInGroup: entry.key == filtered.length - 1,
      );
    }).toList();
  }

  void _expandAllWithSubs(List<dynamic> communities) {
    for (final c in communities) {
      final community = c as Map<String, dynamic>;
      final id = (community['_id'] ?? community['id'])?.toString() ?? '';
      final subs = community['subCommunities'] as List? ?? [];
      if (subs.isNotEmpty && id.isNotEmpty) {
        _expandedCommunities.add(id);
        _expandAllWithSubs(subs);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.group_outlined, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'My Communities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    if (_expandedCommunities.isEmpty) {
                      final provider =
                      Provider.of<CommunityProvider>(context, listen: false);
                      final list =
                          provider.myCommunities['data'] as List? ?? [];
                      _expandAllWithSubs(list);
                    } else {
                      _expandedCommunities.clear();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    _expandedCommunities.isEmpty ? 'Expand all' : 'Collapse all',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: TextField(
            controller: widget.searchController,
            focusNode: widget.searchFocusNode,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search communities...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[600]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey[900],
              contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        Expanded(
          child: Consumer<CommunityProvider>(
            builder: (context, provider, _) {
              if (provider.isLoadingMy) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                );
              }

              if (provider.myCommunitiesError != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading communities',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.myCommunitiesError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red[300], fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: provider.fetchMyCommunities,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final communityList =
                  provider.myCommunities['data'] as List? ?? [];

              if (communityList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off, color: Colors.grey[600], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No communities found',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final communityWidgets = _buildCommunityList(communityList);

              if (communityWidgets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, color: Colors.grey[600], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No results for "${widget.searchController.text}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                children: communityWidgets,
              );
            },
          ),
        ),
      ],
    );
  }
}