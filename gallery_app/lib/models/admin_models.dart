// ── Admin dashboard data models ────────────────────────────────────────────────

class AdminStats {
  final int users;
  final int activeUsers;
  final int bannedUsers;
  final int uploads;
  final int shares;

  const AdminStats({
    required this.users,
    required this.activeUsers,
    required this.bannedUsers,
    required this.uploads,
    required this.shares,
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        users:       j['users']       as int,
        activeUsers: j['activeUsers'] as int,
        bannedUsers: j['bannedUsers'] as int,
        uploads:     j['uploads']     as int,
        shares:      j['shares']      as int,
      );
}

class AdminUser {
  final int    userId;
  final String email;
  final String role;       // 'user' | 'admin'
  final bool   isBanned;
  final String? createdAt;

  const AdminUser({
    required this.userId,
    required this.email,
    required this.role,
    required this.isBanned,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        userId:    j['user_id']   as int,
        email:     j['email']     as String,
        role:      j['role']      as String? ?? 'user',
        isBanned:  j['is_banned'] as bool?   ?? false,
        createdAt: j['created_at'] as String?,
      );

  AdminUser copyWith({String? role, bool? isBanned}) => AdminUser(
        userId:    userId,
        email:     email,
        role:      role    ?? this.role,
        isBanned:  isBanned ?? this.isBanned,
        createdAt: createdAt,
      );
}

class AdminMediaItem {
  final int    mediaId;
  final String filename;
  final String algo;
  final String? ownerEmail;

  const AdminMediaItem({
    required this.mediaId,
    required this.filename,
    required this.algo,
    this.ownerEmail,
  });

  factory AdminMediaItem.fromJson(Map<String, dynamic> j) {
    final owner = j['owner'] as Map<String, dynamic>?;
    return AdminMediaItem(
      mediaId:    j['media_id'] as int,
      filename:   j['filename'] as String,
      algo:       j['algo']     as String,
      ownerEmail: owner?['email'] as String?,
    );
  }
}

class AuditLogEntry {
  final int     logId;
  final String  action;
  final String? ip;
  final String? timestamp;
  final String? userEmail;

  const AuditLogEntry({
    required this.logId,
    required this.action,
    this.ip,
    this.timestamp,
    this.userEmail,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) {
    final userMap = j['user'] as Map<String, dynamic>?;
    return AuditLogEntry(
      logId:     j['log_id']    as int,
      action:    j['action']    as String,
      ip:        j['ip']        as String?,
      timestamp: j['timestamp'] as String?,
      userEmail: userMap?['email'] as String?,
    );
  }
}

// Paginated response wrapper
class PagedResult<T> {
  final List<T> items;
  final int     total;
  final int     page;
  final int     totalPages;

  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}
