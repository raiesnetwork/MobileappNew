class Post {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final String mediaType;
  final String postContent;
  final List<String>? postImages;
  final String? postVideo;
  final String? communityId;
  final List<String> likes;
 
  final DateTime createdAt;
  final int shareCount;
  final bool isLiked;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.mediaType,
    required this.postContent,
    this.postImages,
    this.postVideo,
    this.communityId,
    required this.likes,
 
    required this.createdAt,
    required this.shareCount,
    required this.isLiked,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      userAvatar: json['userAvatar']?.toString(),
      mediaType: json['mediaType']?.toString() ?? '',
      postContent: json['postContent']?.toString() ?? '',
      
      // Proper handling of postImages - convert List<dynamic> to List<String>
      postImages: json['postImages'] != null 
          ? (json['postImages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList()
          : null,
      
      postVideo: json['postVideo']?.toString(),
      communityId: json['communityId']?.toString(),
      
      // Proper handling of likes list
      likes: json['likes'] != null
          ? (json['likes'] as List<dynamic>)
              .map((e) => e.toString())
              .toList()
          : <String>[],
      
      // Proper handling of comments list
       
      
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      
      shareCount: json['shareCount'] is int 
          ? json['shareCount'] 
          : int.tryParse(json['shareCount']?.toString() ?? '0') ?? 0,
      
      isLiked: json['isLiked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'mediaType': mediaType,
      'postContent': postContent,
      'postImages': postImages,
      'postVideo': postVideo,
      'communityId': communityId,
      'likes': likes,
    
      'createdAt': createdAt.toIso8601String(),
      'shareCount': shareCount,
      'isLiked': isLiked,
    };
  }
}