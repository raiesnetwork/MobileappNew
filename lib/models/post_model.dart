class Post {
  final String id;
  final String username;
  final String postContent;
  final List<String> postImages;
  final List<String>? postVideo;
  final DateTime createdAt;
  int likes;
  int shares;
  int commentsCount;
  bool isLikedByUser;
  final bool isAdmin;
  final String profileImage;
  final List<Comment> comments;

  Post({
    required this.id,
    required this.username,
    required this.postContent,
    required this.postImages,
    required this.postVideo,
    required this.createdAt,
    required this.likes,
    required this.shares,
    required this.commentsCount,
    required this.isLikedByUser,
    required this.isAdmin,
    required this.profileImage,
    required this.comments,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? '',
      username: json['user']?['profile']?['name'] ?? 'Unknown',
      postContent: json['postContent'] ?? '',
      postImages:
      (json['postImages'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      postVideo:
      (json['postVideo'] as List?)?.map((e) => e.toString()).toList(),
      createdAt:
      DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      likes: json['likes'] ?? 0,
      shares: json['shares'] ?? 0,
      commentsCount: (json['comments'] as List?)?.length ?? 0,
      isLikedByUser: json['isLikedByUser'] ?? false,
      isAdmin: json['isAdmin'] ?? false,
      profileImage: json['user']?['profile']?['profileImage'] ?? '',
      comments: (json['comments'] as List?)
          ?.map((e) => Comment.fromJson(e))
          .toList() ??
          [],
    );
  }

  factory Post.empty() {
    return Post(
      id: '',
      username: 'Unknown',
      postContent: '',
      postImages: [],
      postVideo: [],
      createdAt: DateTime.now(),
      likes: 0,
      shares: 0,
      commentsCount: 0,
      isLikedByUser: false,
      isAdmin: false,
      profileImage: '',
      comments: [],
    );
  }
}



class Comment {
  final String id;
  final String content;
  final String createdAt;
  final String userName;
  final String profileImage; // Added profile image field

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.userName,
    required this.profileImage, // Added to constructor
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? '',
      content: json['commentContent'] ?? '',
      createdAt: json['createdAt'] ?? '',
      userName: json['userId']?['profile']?['name'] ?? 'Unknown',
      profileImage: json['userId']?['profile']?['profileImage'] ?? '', // Extract profile image
    );
  }
}