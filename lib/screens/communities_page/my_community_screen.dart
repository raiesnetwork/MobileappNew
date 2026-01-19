import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
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
  Set<String> expandedCommunities = {};

  Widget _buildImageWidget(String? imageData, {bool isProfileImage = false}) {
    if (imageData == null || imageData.isEmpty) {
      return isProfileImage
          ? const Icon(Icons.person, color: Colors.white, size: 24)
          : Container();
    }

    try {
      // Handle base64 data with or without prefix
      String base64String;
      if (imageData.startsWith('data:')) {
        base64String = imageData.split(',')[1];
      } else if (imageData.contains('base64,')) {
        base64String = imageData.split('base64,')[1];
      } else {
        // Assume it's already base64 or a URL
        if (imageData.startsWith('http') || imageData.startsWith('/')) {
          final processedImage = imageData.startsWith('/')
              ? 'https://api.ixes.ai$imageData'
              : imageData;
          return Image.network(
            processedImage,
            fit: BoxFit.cover,
            width: isProfileImage ? double.infinity : double.infinity,
            height: isProfileImage ? double.infinity : 300,
            errorBuilder: (context, error, stackTrace) {
              return isProfileImage
                  ? const Icon(Icons.person, color: Colors.white, size: 24)
                  : Container();
            },
          );
        }
        base64String = imageData;
      }

      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.cover,
        width: isProfileImage ? double.infinity : double.infinity,
        height: isProfileImage ? double.infinity : 300,
        errorBuilder: (context, error, stackTrace) {
          print('Image decode error: $error');
          return isProfileImage
              ? const Icon(Icons.person, color: Colors.white, size: 24)
              : Container();
        },
      );
    } catch (e) {
      print('Error processing image: $e');
      return isProfileImage
          ? const Icon(Icons.person, color: Colors.white, size: 24)
          : Container();
    }
  }

  Widget _buildCommunityTile({
    required Map<String, dynamic> community,
    required int level,
    bool isLastInGroup = false,
  }) {
    final communityId = (community['_id'] ?? community['id'])?.toString() ?? '';
    final communityName = community['name']?.toString() ?? 'Unnamed Community';
    final subCommunities = community['subCommunities'] as List? ?? [];
    final hasSubCommunities = subCommunities.isNotEmpty;
    final isExpanded = expandedCommunities.contains(communityId);

    final double leftPadding = level == 0 ? 16.0 : 16.0 + (level * 24.0);
    final double avatarSize = level == 0 ? 24.0 : 20.0;
    final double fontSize = level == 0 ? 14.0 : 13.0;

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(
            left: leftPadding,
            right: 16,
            top: level == 0 ? 8 : 6,
            bottom: level == 0 ? 8 : 6,
          ),
          leading: level == 0
              ? CircleAvatar(
            radius: avatarSize,
            backgroundColor: Colors.grey[800],
            child: ClipOval(
              child: community['profileImage'] != null &&
                  community['profileImage'].toString().isNotEmpty
                  ? SizedBox(
                width: avatarSize * 2,
                height: avatarSize * 2,
                child: _buildImageWidget(
                  community['profileImage'].toString(),
                  isProfileImage: true,
                ),
              )
                  : Text(
                communityName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          )
              : SizedBox(
            width: avatarSize * 2,
            height: avatarSize * 2,
            child: Center(
              child: Text(
                communityName[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
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
          subtitle: level == 0
              ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                community['isPrivate'] == true ? Icons.lock : Icons.public,
                color: Colors.grey[500],
                size: 14,
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  community['isPrivate'] == true ? 'Private' : 'Public',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasSubCommunities) ...[
                SizedBox(width: 8),
                Icon(
                  Icons.folder,
                  color: Colors.grey[500],
                  size: 14,
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${subCommunities.length} sub${subCommunities.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          )
              : Text(
            'Subcommunity',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
          trailing: hasSubCommunities
              ? InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  expandedCommunities.remove(communityId);
                } else {
                  expandedCommunities.add(communityId);
                }
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(8),
              child: Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white70,
                size: 20,
              ),
            ),
          )
              : Icon(
            Icons.arrow_forward_ios,
            color: Colors.white70,
            size: 12,
          ),
          onTap: () {
            widget.onCommunityTapped();

            if (communityId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommunityInfoScreen(
                    communityId: communityId,
                  ),
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
            final subCommunity = entry.value as Map<String, dynamic>;
            return _buildCommunityTile(
              community: subCommunity,
              level: level + 1,
              isLastInGroup: entry.key == subCommunities.length - 1,
            );
          }).toList(),

        if (level == 0 && !isLastInGroup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: Colors.grey[800],
              height: 1,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildCommunityList(List<dynamic> communities) {
    final searchQuery = widget.searchController.text.toLowerCase();

    List<dynamic> filteredCommunities = [];
    if (searchQuery.isEmpty) {
      filteredCommunities = communities;
    } else {
      for (var community in communities) {
        if (_communityMatchesSearch(community, searchQuery)) {
          filteredCommunities.add(community);
        }
      }
    }

    return filteredCommunities.asMap().entries.map((entry) {
      final index = entry.key;
      final community = entry.value as Map<String, dynamic>;
      final isLast = index == filteredCommunities.length - 1;

      return _buildCommunityTile(
        community: community,
        level: 0,
        isLastInGroup: isLast,
      );
    }).toList();
  }

  bool _communityMatchesSearch(Map<String, dynamic> community, String query) {
    final name = community['name']?.toString().toLowerCase() ?? '';
    if (name.contains(query)) return true;

    final subCommunities = community['subCommunities'] as List? ?? [];
    for (var subCommunity in subCommunities) {
      if (_communityMatchesSearch(subCommunity as Map<String, dynamic>, query)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.group_outlined,
                color: Colors.white70,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
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
              SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    if (expandedCommunities.isEmpty) {
                      final provider = Provider.of<CommunityProvider>(context, listen: false);
                      final communityList = provider.myCommunities['data'] as List? ?? [];
                      _expandAllCommunitiesWithSubs(communityList);
                    } else {
                      expandedCommunities.clear();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    expandedCommunities.isEmpty ? 'Expand All' : 'Collapse All',
                    style: TextStyle(
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

        // Search Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: TextField(
            controller: widget.searchController,
            focusNode: widget.searchFocusNode,
            style: TextStyle(color: Colors.white),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            ),
            onTap: () {
              widget.searchFocusNode.requestFocus();
            },
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),

        // Communities List
        Expanded(
          child: Consumer<CommunityProvider>(
            builder: (context, provider, child) {
              if (provider.isLoadingMy) {
                return Center(
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
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[300],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading communities',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${provider.myCommunitiesError}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red[300],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.fetchMyCommunities();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final communityList = provider.myCommunities['data'] as List? ?? [];

              if (communityList.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          color: Colors.grey[600],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No communities found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final communityWidgets = _buildCommunityList(communityList);

              if (communityWidgets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          color: Colors.grey[600],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matching communities for "${widget.searchController.text}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                children: communityWidgets,
              );
            },
          ),
        ),
      ],
    );
  }

  void _expandAllCommunitiesWithSubs(List<dynamic> communities) {
    for (var community in communities) {
      final communityData = community as Map<String, dynamic>;
      final communityId = (communityData['_id'] ?? communityData['id'])?.toString() ?? '';
      final subCommunities = communityData['subCommunities'] as List? ?? [];
      if (subCommunities.isNotEmpty && communityId.isNotEmpty) {
        expandedCommunities.add(communityId);
        _expandAllCommunitiesWithSubs(subCommunities);
      }
    }
  }
}