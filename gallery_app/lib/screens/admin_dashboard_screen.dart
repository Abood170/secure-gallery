import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg = Color(0xFF060918);
const _kPurple = Color(0xFF7C3AED);
const _kPurpleL = Color(0xFFA78BFA);
const _kPurple2 = Color(0xFF4C1D95);
const _kGreen = Color(0xFF10B981);
const _kAmber = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kBlue = Color(0xFF3B82F6);
const _kWhite = Colors.white;

// ══════════════════════════════════════════════════════════════════════════════
//  AdminDashboardScreen
// ══════════════════════════════════════════════════════════════════════════════

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedTab = 0; // 0=stats 1=users 2=media 3=logs

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _AdminBackground()),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ────────────────────────────────────────────────
                _AdminHeader(
                  pulseAnim: _pulseAnim,
                  onRefresh: () => prov.loadAll(),
                  onLogout: _logout,
                ),

                // ── Tab bar ────────────────────────────────────────────────
                _TabBar(
                  selected: _selectedTab,
                  onSelect: (i) => setState(() => _selectedTab = i),
                ),

                // ── Body ───────────────────────────────────────────────────
                Expanded(
                  child: prov.loading && prov.stats == null
                      ? _LoadingView(pulseAnim: _pulseAnim)
                      : prov.error != null && prov.stats == null
                          ? _ErrorView(
                              message: prov.error!,
                              onRetry: () => prov.loadAll(),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _tabBody(prov),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBody(AdminProvider prov) {
    return switch (_selectedTab) {
      0 => _StatsTab(
          key: const ValueKey(0), stats: prov.stats, pulseAnim: _pulseAnim),
      1 => const _UsersTab(key: ValueKey(1)),
      2 => const _MediaTab(key: ValueKey(2)),
      _ => const _AuditTab(key: ValueKey(3)),
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Header
// ══════════════════════════════════════════════════════════════════════════════

class _AdminHeader extends StatelessWidget {
  final Animation<double> pulseAnim;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  const _AdminHeader(
      {required this.pulseAnim,
      required this.onRefresh,
      required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          decoration: BoxDecoration(
            color: _kWhite.withValues(alpha: 0.03),
            border: Border(
              bottom:
                  BorderSide(color: _kPurple.withValues(alpha: 0.22), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Shield icon
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            _kPurple.withValues(alpha: pulseAnim.value * 0.7),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: _kPurpleL, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADMIN PANEL',
                        style: TextStyle(
                            color: _kWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0)),
                    Text('Secure Gallery',
                        style: TextStyle(
                            color: _kPurpleL,
                            fontSize: 10,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
              _HeaderBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onTap: onRefresh),
              _HeaderBtn(
                  icon: Icons.logout_rounded,
                  tooltip: 'Logout',
                  onTap: onLogout,
                  color: _kPurpleL.withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  const _HeaderBtn(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color ?? _kPurpleL, size: 20),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Tab bar
// ══════════════════════════════════════════════════════════════════════════════

class _TabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (Icons.bar_chart_rounded, 'Stats'),
      (Icons.people_rounded, 'Users'),
      (Icons.photo_library_rounded, 'Media'),
      (Icons.history_rounded, 'Logs'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _kPurple.withValues(alpha: 0.07),
        border: Border.all(color: _kPurple.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          final (icon, label) = tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: active
                      ? _kPurple.withValues(alpha: 0.35)
                      : Colors.transparent,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _kPurple.withValues(alpha: 0.3),
                            blurRadius: 10,
                          )
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 18,
                        color: active
                            ? _kWhite
                            : _kPurpleL.withValues(alpha: 0.45)),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active
                            ? _kWhite
                            : _kPurpleL.withValues(alpha: 0.45),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Stats Tab
// ══════════════════════════════════════════════════════════════════════════════

class _StatsTab extends StatelessWidget {
  final AdminStats? stats;
  final Animation<double> pulseAnim;
  const _StatsTab({super.key, this.stats, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview',
              style: TextStyle(
                  color: _kWhite.withValues(alpha: 0.85),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('System-wide metrics',
              style: TextStyle(
                  color: _kPurpleL.withValues(alpha: 0.5),
                  fontSize: 11,
                  letterSpacing: 1)),
          const SizedBox(height: 20),

          // Row 1: Users
          Row(children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_rounded,
                label: 'Total Users',
                value: '${s.users}',
                color: _kPurpleL,
                sub: '${s.bannedUsers} banned',
                pulseAnim: pulseAnim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.verified_user_rounded,
                label: 'Active Users',
                value: '${s.activeUsers}',
                color: _kGreen,
                pulseAnim: pulseAnim,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Row 2: Content
          Row(children: [
            Expanded(
              child: _StatCard(
                icon: Icons.lock_rounded,
                label: 'Encrypted Files',
                value: '${s.uploads}',
                color: _kBlue,
                pulseAnim: pulseAnim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.share_rounded,
                label: 'Active Shares',
                value: '${s.shares}',
                color: _kAmber,
                pulseAnim: pulseAnim,
              ),
            ),
          ]),
          const SizedBox(height: 28),

          // Security notice
          const _GlassInfo(
            icon: Icons.security_rounded,
            color: _kGreen,
            title: 'All data is end-to-end encrypted',
            body: 'The server stores only ciphertext. '
                'Symmetric keys never leave the client device.',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;
  final Animation<double> pulseAnim;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.pulseAnim,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: pulseAnim.value * 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: _kWhite.withValues(alpha: 0.55),
                  fontSize: 11,
                  letterSpacing: 0.4)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                style: TextStyle(
                    color: color.withValues(alpha: 0.5), fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _GlassInfo extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _GlassInfo(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        color: _kWhite.withValues(alpha: 0.4),
                        fontSize: 11,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Users Tab
// ══════════════════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab({super.key});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();

    return Column(
      children: [
        // ── Search bar ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _SearchField(
            controller: _searchCtrl,
            hint: 'Search by email…',
            onSubmit: (v) => prov.loadUsers(page: 1, search: v),
          ),
        ),
        const SizedBox(height: 10),

        // ── User count chip ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _CountChip(label: '${prov.userTotal} users', color: _kPurpleL),
              const Spacer(),
              Text('Page ${prov.userPage} / ${prov.userTotalPages}',
                  style: TextStyle(
                      color: _kWhite.withValues(alpha: 0.3), fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: prov.loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: _kPurpleL, strokeWidth: 2))
              : prov.users.isEmpty
                  ? const _EmptyState(
                      icon: Icons.people_outline_rounded,
                      message: 'No users found')
                  : RefreshIndicator(
                      color: _kPurpleL,
                      backgroundColor: const Color(0xFF1A0A3E),
                      onRefresh: () => prov.loadUsers(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: prov.users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _UserCard(user: prov.users[i]),
                      ),
                    ),
        ),

        // ── Pagination ────────────────────────────────────────────────────
        if (prov.userTotalPages > 1)
          _Pagination(
            page: prov.userPage,
            totalPages: prov.userTotalPages,
            onPrev: () => prov.loadUsers(page: prov.userPage - 1),
            onNext: () => prov.loadUsers(page: prov.userPage + 1),
          ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminUser user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'admin';
    final isBanned = user.isBanned;
    final date = user.createdAt?.substring(0, 10) ?? '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isBanned
            ? _kRed.withValues(alpha: 0.05)
            : _kWhite.withValues(alpha: 0.03),
        border: Border.all(
          color: isBanned
              ? _kRed.withValues(alpha: 0.25)
              : _kPurple.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAdmin
                  ? _kPurple.withValues(alpha: 0.2)
                  : _kWhite.withValues(alpha: 0.05),
              border: Border.all(
                color: isAdmin
                    ? _kPurple.withValues(alpha: 0.5)
                    : _kWhite.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
              color: isAdmin ? _kPurpleL : _kWhite.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.email,
                        style: TextStyle(
                            color: isBanned
                                ? _kRed.withValues(alpha: 0.8)
                                : _kWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isBanned) const _Tag('BANNED', _kRed),
                    if (isAdmin) const _Tag('ADMIN', _kPurpleL),
                  ],
                ),
                const SizedBox(height: 3),
                Text('ID: ${user.userId}  ·  Joined: $date',
                    style: TextStyle(
                        color: _kWhite.withValues(alpha: 0.28), fontSize: 10)),
              ],
            ),
          ),

          // Actions
          _UserActions(user: user),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8)),
    );
  }
}

class _UserActions extends StatefulWidget {
  final AdminUser user;
  const _UserActions({required this.user});

  @override
  State<_UserActions> createState() => _UserActionsState();
}

class _UserActionsState extends State<_UserActions> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final err = await action();
    if (mounted) {
      setState(() => _busy = false);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red.shade900),
        );
      }
    }
  }

  void _showMenu(BuildContext context) {
    final prov = context.read<AdminProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserActionsSheet(
        user: widget.user,
        onDelete: () => _run(() => prov.deleteUser(widget.user.userId)),
        onBan: () => _run(() =>
            prov.toggleBan(widget.user.userId, ban: !widget.user.isBanned)),
        onRole: (r) => _run(() => prov.updateRole(widget.user.userId, r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kPurpleL));
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.more_vert_rounded,
              color: _kPurpleL.withValues(alpha: 0.6), size: 20),
        ),
      ),
    );
  }
}

class _UserActionsSheet extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onDelete;
  final VoidCallback onBan;
  final ValueChanged<String> onRole;

  const _UserActionsSheet({
    required this.user,
    required this.onDelete,
    required this.onBan,
    required this.onRole,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0730).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: _kPurple.withValues(alpha: 0.3), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: _kPurple.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                // User info
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.manage_accounts_rounded,
                          color: _kPurpleL, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(user.email,
                            style: const TextStyle(
                                color: _kWhite, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Divider(color: _kPurple.withValues(alpha: 0.15), height: 1),

                // Actions
                _SheetItem(
                  icon: user.isBanned
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
                  label: user.isBanned ? 'Unban User' : 'Ban User',
                  color: user.isBanned ? _kGreen : _kAmber,
                  onTap: () {
                    Navigator.pop(context);
                    onBan();
                  },
                ),
                _SheetItem(
                  icon: user.role == 'admin'
                      ? Icons.person_rounded
                      : Icons.admin_panel_settings_rounded,
                  label: user.role == 'admin'
                      ? 'Demote to User'
                      : 'Promote to Admin',
                  color: _kPurpleL,
                  onTap: () {
                    Navigator.pop(context);
                    onRole(user.role == 'admin' ? 'user' : 'admin');
                  },
                ),
                _SheetItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete User',
                  color: _kRed,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0730),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User?', style: TextStyle(color: _kWhite)),
        content: Text(
          'This will permanently delete ${user.email} and all their data.',
          style: TextStyle(color: _kWhite.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: _kWhite.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 14)),
      onTap: onTap,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Media Tab
// ══════════════════════════════════════════════════════════════════════════════

class _MediaTab extends StatefulWidget {
  const _MediaTab({super.key});

  @override
  State<_MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<_MediaTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _SearchField(
            controller: _searchCtrl,
            hint: 'Search by filename…',
            onSubmit: (v) => prov.loadMedia(page: 1, search: v),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _CountChip(label: '${prov.mediaTotal} files', color: _kBlue),
              const Spacer(),
              Text('Page ${prov.mediaPage} / ${prov.mediaTotalPages}',
                  style: TextStyle(
                      color: _kWhite.withValues(alpha: 0.3), fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: prov.loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: _kPurpleL, strokeWidth: 2))
              : prov.media.isEmpty
                  ? const _EmptyState(
                      icon: Icons.photo_library_outlined,
                      message: 'No media found')
                  : RefreshIndicator(
                      color: _kPurpleL,
                      backgroundColor: const Color(0xFF1A0A3E),
                      onRefresh: () => prov.loadMedia(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: prov.media.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) =>
                            _MediaCard(item: prov.media[i]),
                      ),
                    ),
        ),
        if (prov.mediaTotalPages > 1)
          _Pagination(
            page: prov.mediaPage,
            totalPages: prov.mediaTotalPages,
            onPrev: () => prov.loadMedia(page: prov.mediaPage - 1),
            onNext: () => prov.loadMedia(page: prov.mediaPage + 1),
          ),
      ],
    );
  }
}

class _MediaCard extends StatefulWidget {
  final AdminMediaItem item;
  const _MediaCard({required this.item});

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  bool _busy = false;

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0730),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete File?', style: TextStyle(color: _kWhite)),
        content: Text(
          'Permanently delete "${widget.item.filename}"?',
          style: TextStyle(color: _kWhite.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: _kWhite.withValues(alpha: 0.5)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: _kRed))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final err =
        await context.read<AdminProvider>().deleteMedia(widget.item.mediaId);
    if (mounted) {
      setState(() => _busy = false);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red.shade900),
        );
      }
    }
  }

  Color get _algoColor => widget.item.algo == 'AES-GCM' ? _kGreen : _kAmber;
  String get _algoLabel => widget.item.algo == 'AES-GCM' ? 'AES-256' : 'CC20';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _kWhite.withValues(alpha: 0.03),
        border: Border.all(color: _kPurple.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kBlue.withValues(alpha: 0.1),
              border:
                  Border.all(color: _kBlue.withValues(alpha: 0.3), width: 0.8),
            ),
            child: const Icon(Icons.lock_rounded, color: _kBlue, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.item.filename,
                          style: const TextStyle(
                              color: _kWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    _Tag(_algoLabel, _algoColor),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Owner: ${widget.item.ownerEmail ?? 'unknown'}  ·  #${widget.item.mediaId}',
                  style: TextStyle(
                      color: _kWhite.withValues(alpha: 0.28), fontSize: 10),
                ),
              ],
            ),
          ),
          _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: _kRed))
              : Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _delete,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline_rounded,
                          color: _kRed.withValues(alpha: 0.7), size: 20),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Audit Log Tab
// ══════════════════════════════════════════════════════════════════════════════

class _AuditTab extends StatelessWidget {
  const _AuditTab({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              _CountChip(label: '${prov.logTotal} events', color: _kAmber),
              const Spacer(),
              Text('Page ${prov.logPage} / ${prov.logTotalPages}',
                  style: TextStyle(
                      color: _kWhite.withValues(alpha: 0.3), fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: prov.loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: _kPurpleL, strokeWidth: 2))
              : prov.auditLogs.isEmpty
                  ? const _EmptyState(
                      icon: Icons.history_rounded, message: 'No logs found')
                  : RefreshIndicator(
                      color: _kPurpleL,
                      backgroundColor: const Color(0xFF1A0A3E),
                      onRefresh: () => prov.loadLogs(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: prov.auditLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) =>
                            _LogCard(log: prov.auditLogs[i]),
                      ),
                    ),
        ),
        if (prov.logTotalPages > 1)
          _Pagination(
            page: prov.logPage,
            totalPages: prov.logTotalPages,
            onPrev: () => prov.loadLogs(page: prov.logPage - 1),
            onNext: () => prov.loadLogs(page: prov.logPage + 1),
          ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final AuditLogEntry log;
  const _LogCard({required this.log});

  (IconData, Color) get _meta => switch (log.action) {
        'LOGIN' => (Icons.login_rounded, _kGreen),
        'UPLOAD' => (Icons.cloud_upload_rounded, _kBlue),
        'DOWNLOAD' => (Icons.download_rounded, _kAmber),
        'SHARE' => (Icons.share_rounded, _kPurpleL),
        'ADMIN_DELETE_USER' => (Icons.person_remove_rounded, _kRed),
        'ADMIN_DELETE_MEDIA' => (Icons.delete_rounded, _kRed),
        'ADMIN_BAN_USER' => (Icons.block_rounded, _kRed),
        'ADMIN_UNBAN_USER' => (Icons.lock_open_rounded, _kGreen),
        _ when log.action.startsWith('ADMIN_SET_ROLE') => (
            Icons.manage_accounts_rounded,
            _kPurpleL
          ),
        _ => (Icons.info_outline_rounded, Colors.grey),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _meta;
    final time = log.timestamp != null
        ? log.timestamp!.substring(0, 19).replaceFirst('T', ' ')
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.04),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(log.action,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                    Text(time,
                        style: TextStyle(
                            color: _kWhite.withValues(alpha: 0.25),
                            fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.userEmail ?? 'unknown'}  ·  IP: ${log.ip ?? '—'}',
                  style: TextStyle(
                      color: _kWhite.withValues(alpha: 0.3), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared helper widgets
// ══════════════════════════════════════════════════════════════════════════════

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmit;
  const _SearchField(
      {required this.controller, required this.hint, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _kPurple.withValues(alpha: 0.06),
        border: Border.all(color: _kPurple.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: _kWhite, fontSize: 13),
        cursorColor: _kPurpleL,
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: _kWhite.withValues(alpha: 0.25), fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: _kPurpleL.withValues(alpha: 0.5), size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: _kPurpleL.withValues(alpha: 0.5), size: 18),
                  onPressed: () {
                    controller.clear();
                    onSubmit('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CountChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _Pagination(
      {required this.page,
      required this.totalPages,
      required this.onPrev,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageBtn(
            icon: Icons.chevron_left_rounded,
            enabled: page > 1,
            onTap: onPrev,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$page / $totalPages',
                style: TextStyle(
                    color: _kWhite.withValues(alpha: 0.5), fontSize: 12)),
          ),
          _PageBtn(
            icon: Icons.chevron_right_rounded,
            enabled: page < totalPages,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color:
                enabled ? _kPurple.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
              color: enabled
                  ? _kPurple.withValues(alpha: 0.35)
                  : _kPurple.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(icon,
              color: enabled ? _kPurpleL : _kPurpleL.withValues(alpha: 0.25),
              size: 20),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: _kPurpleL.withValues(alpha: 0.25)),
          const SizedBox(height: 14),
          Text(message,
              style: TextStyle(
                  color: _kWhite.withValues(alpha: 0.3), fontSize: 13)),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _LoadingView({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPurple.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(alpha: pulseAnim.value * 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: child,
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child:
                  CircularProgressIndicator(color: _kPurpleL, strokeWidth: 2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Loading dashboard…',
              style: TextStyle(
                  color: _kPurpleL.withValues(alpha: 0.6),
                  fontSize: 13,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 52, color: _kRed.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  color: _kWhite.withValues(alpha: 0.45), fontSize: 13)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _kPurple.withValues(alpha: 0.15),
                border: Border.all(color: _kPurple.withValues(alpha: 0.4)),
              ),
              child: const Text('Retry',
                  style:
                      TextStyle(color: _kPurpleL, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Background
// ══════════════════════════════════════════════════════════════════════════════

class _AdminBackground extends StatelessWidget {
  const _AdminBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.2, -0.6),
              radius: 1.4,
              colors: [Color(0xFF1A0A3E), Color(0xFF060918)],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: _Orb(size: 300, color: _kPurple2.withValues(alpha: 0.22)),
        ),
        Positioned(
          bottom: -80,
          left: -60,
          child: _Orb(size: 260, color: _kPurple.withValues(alpha: 0.14)),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _GridPainter()),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x07A78BFA)
      ..strokeWidth = 0.5;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
