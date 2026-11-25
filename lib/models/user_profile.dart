class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final bool isPaid;
  final String appVersion;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.isPaid = true,
    this.appVersion = '1.0.0',
    this.createdAt,
    this.lastLoginAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String? ?? (json['email'] as String? ?? '').split('@').first,
      isPaid: json['is_paid'] as bool? ?? true,
      appVersion: json['app_version'] as String? ?? '1.0.0',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      lastLoginAt: json['last_login_at'] != null ? DateTime.tryParse(json['last_login_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'is_paid': isPaid,
      'app_version': appVersion,
      'last_login_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    bool? isPaid,
    String? appVersion,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isPaid: isPaid ?? this.isPaid,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
