class UserProfile {
  final int      userId;
  final String   email;
  final String   role;
  final bool     isBanned;
  final bool     hasPublicKey;
  final DateTime? createdAt;
  final int      mediaCount;
  final int      sharesSent;
  final int      sharesReceived;
  final DateTime? lastLogin;

  const UserProfile({
    required this.userId,
    required this.email,
    required this.role,
    required this.isBanned,
    required this.hasPublicKey,
    required this.mediaCount,
    required this.sharesSent,
    required this.sharesReceived,
    this.createdAt,
    this.lastLogin,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId:         json['user_id']         as int,
    email:          json['email']           as String,
    role:           json['role']            as String,
    isBanned:       json['is_banned']       as bool,
    hasPublicKey:   json['has_public_key']  as bool,
    mediaCount:     json['media_count']     as int,
    sharesSent:     json['shares_sent']     as int,
    sharesReceived: json['shares_received'] as int,
    createdAt:  json['created_at']  != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
    lastLogin:  json['last_login'] != null
        ? DateTime.tryParse(json['last_login'] as String)
        : null,
  );
}
