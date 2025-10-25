class User {
  final String id;
  final String username;
  final String mobile;
  final bool isFamilyHead;
  final bool guidStatus;
  final String? token;

  User({
    required this.id,
    required this.username,
    required this.mobile,
    required this.isFamilyHead,
    required this.guidStatus,
    this.token,
  });

  // Convert User object to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'mobile': mobile,
      'isFamilyHead': isFamilyHead,
      'guidStatus': guidStatus,
      'token': token,
    };
  }

  // Create User object from JSON Map
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      isFamilyHead: json['isFamilyHead'] == true || json['isFamilyHead'] == 'true',
      guidStatus: json['guidStatus'] == true || json['guidStatus'] == 'true',
      token: json['token']?.toString(),
    );
  }

  // Optional: toString method for debugging
  @override
  String toString() {
    return 'User(id: $id, username: $username, mobile: $mobile, isFamilyHead: $isFamilyHead, guidStatus: $guidStatus, hasToken: ${token != null})';
  }

  // Optional: copyWith method for creating modified copies
  User copyWith({
    String? id,
    String? username,
    String? mobile,
    bool? isFamilyHead,
    bool? guidStatus,
    String? token,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      mobile: mobile ?? this.mobile,
      isFamilyHead: isFamilyHead ?? this.isFamilyHead,
      guidStatus: guidStatus ?? this.guidStatus,
      token: token ?? this.token,
    );
  }
}