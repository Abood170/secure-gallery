import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/auth_provider.dart';
import '../providers/gallery_provider.dart';
import '../services/media_service.dart';
import '../services/storage_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF060918);
const _kPurple   = Color(0xFF7C3AED);
const _kPurpleL  = Color(0xFFA78BFA);
const _kPurple2  = Color(0xFF4C1D95);
const _kGreen    = Color(0xFF10B981);
const _kAmber    = Color(0xFFF59E0B);
const _kWhite    = Colors.white;

// ══════════════════════════════════════════════════════════════════════════════
//  GalleryScreen
// ══════════════════════════════════════════════════════════════════════════════

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _scanCtrl;
  late final Animation<double>   _pulseAnim;

  // ── Selection mode ─────────────────────────────────────────────────────────
  bool       _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();

    // FAB + header pulse
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Scan-line across grid
    _scanCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GalleryProvider>().loadMedia();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ── Selection helpers ──────────────────────────────────────────────────────
  void _enterSelection(int mediaId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(mediaId);
    });
  }

  void _toggleSelect(int mediaId) {
    setState(() {
      if (_selectedIds.contains(mediaId)) {
        _selectedIds.remove(mediaId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(mediaId);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _shareSelected(GalleryProvider provider) {
    final items = provider.mediaList
        .where((m) => _selectedIds.contains(m.mediaId))
        .toList();
    if (items.isEmpty) return;
    _cancelSelection();
    Navigator.pushNamed(context, '/share', arguments: items);
  }

  Future<void> _deleteSelected(GalleryProvider provider) async {
    final toDelete = provider.mediaList
        .where((m) => _selectedIds.contains(m.mediaId))
        .toList();
    if (toDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F0730),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _kPurple.withValues(alpha: 0.3)),
          ),
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFC8181), size: 22),
            const SizedBox(width: 10),
            Text('Delete ${toDelete.length} File${toDelete.length == 1 ? '' : 's'}',
                style: const TextStyle(color: _kWhite, fontSize: 16)),
          ]),
          content: Text(
            'Permanently delete ${toDelete.length} encrypted file${toDelete.length == 1 ? '' : 's'}? Their keys will also be destroyed.',
            style: TextStyle(
                color: _kWhite.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: _kWhite.withValues(alpha: 0.5))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Destroy All',
                  style: TextStyle(
                      color: Color(0xFFFC8181),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    _cancelSelection();
    int deleted = 0;
    for (final item in toDelete) {
      try {
        await MediaService.deleteMedia(item.mediaId);
        await StorageService.deleteSymmetricKey(item.mediaId);
        if (mounted) provider.removeMedia(item.mediaId);
        deleted++;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '$deleted file${deleted == 1 ? '' : 's'} destroyed from vault.'),
        backgroundColor: _kPurple2,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GalleryProvider>();
    final count    = provider.mediaList.length;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Background ────────────────────────────────────────────────────
          const Positioned.fill(child: _CyberBackground()),

          // ── Main layout ───────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header OR selection action bar
                if (_selectionMode)
                  _SelectionBar(
                    count:    _selectedIds.length,
                    onShare:  () => _shareSelected(provider),
                    onDelete: () => _deleteSelected(provider),
                    onCancel: _cancelSelection,
                  )
                else
                  _GlassHeader(
                    count:    count,
                    pulseAnim: _pulseAnim,
                    onInbox:  () => Navigator.pushNamed(context, '/inbox'),
                    onLogout: _logout,
                  ),
                _StatsBar(count: count),
                Expanded(
                  child: _GridArea(
                    provider:       provider,
                    scanCtrl:       _scanCtrl,
                    pulseAnim:      _pulseAnim,
                    selectionMode:  _selectionMode,
                    selectedIds:    _selectedIds,
                    onEnterSelect:  _enterSelection,
                    onToggleSelect: _toggleSelect,
                  ),
                ),
              ],
            ),
          ),

          // ── FAB (hidden in selection mode) ────────────────────────────────
          if (!_selectionMode)
            Positioned(
              right: 20, bottom: 28,
              child: _NeonFab(
                pulseAnim: _pulseAnim,
                onPressed: () async {
                  final gallery = context.read<GalleryProvider>();
                  await Navigator.pushNamed(context, '/upload');
                  if (mounted) gallery.loadMedia();
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Glass header
// ══════════════════════════════════════════════════════════════════════════════

class _GlassHeader extends StatelessWidget {
  final int count;
  final Animation<double> pulseAnim;
  final VoidCallback onInbox;
  final VoidCallback onLogout;

  const _GlassHeader({
    required this.count,
    required this.pulseAnim,
    required this.onInbox,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          decoration: BoxDecoration(
            color: _kWhite.withValues(alpha: 0.03),
            border: Border(
              bottom: BorderSide(
                color: _kPurple.withValues(alpha: 0.25), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Shield icon with pulse glow
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kPurple.withValues(alpha: pulseAnim.value * 0.8),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: const Icon(Icons.shield_rounded, color: _kPurpleL, size: 28),
              ),
              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SECURE GALLERY',
                      style: TextStyle(
                        color: _kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                      ),
                    ),
                    Text(
                      'AES-256 · ChaCha20-Poly1305',
                      style: TextStyle(
                        color: _kPurpleL.withValues(alpha: 0.7),
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Inbox
              _HeaderIcon(
                icon: Icons.move_to_inbox_outlined,
                tooltip: 'Shared with me',
                onTap: onInbox,
              ),
              // Logout
              _HeaderIcon(
                icon: Icons.logout_rounded,
                tooltip: 'Logout',
                onTap: onLogout,
                color: _kPurpleL.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color ?? _kPurpleL, size: 22),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Selection action bar
// ══════════════════════════════════════════════════════════════════════════════

class _SelectionBar extends StatelessWidget {
  final int          count;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _SelectionBar({
    required this.count,
    required this.onShare,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: BoxDecoration(
            color: _kPurple.withValues(alpha: 0.14),
            border: Border(
              bottom: BorderSide(
                  color: _kPurple.withValues(alpha: 0.4), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Cancel
              _HeaderIcon(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel',
                  onTap: onCancel),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count selected',
                  style: const TextStyle(
                    color: _kPurpleL,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Delete
              _HeaderIcon(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete selected',
                onTap: onDelete,
                color: const Color(0xFFFC8181),
              ),
              // Share
              _HeaderIcon(
                icon: Icons.share_outlined,
                tooltip: 'Safe Share selected',
                onTap: onShare,
                color: _kGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Stats bar
// ══════════════════════════════════════════════════════════════════════════════

class _StatsBar extends StatelessWidget {
  final int count;
  const _StatsBar({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _kPurple.withValues(alpha: 0.08),
        border: Border.all(color: _kPurple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.lock_rounded,
            label: '$count',
            caption: 'ENCRYPTED',
            color: _kPurpleL,
          ),
          const SizedBox(width: 20),
          const _StatChip(
            icon: Icons.security_rounded,
            label: 'E2E',
            caption: 'PROTECTED',
            color: _kGreen,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _kGreen.withValues(alpha: 0.1),
              border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kGreen,
                    boxShadow: [
                      BoxShadow(color: _kGreen.withValues(alpha: 0.6),
                          blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'SECURE',
                  style: TextStyle(
                    color: _kGreen, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(caption,
                style: TextStyle(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 9, letterSpacing: 0.8)),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Grid area
// ══════════════════════════════════════════════════════════════════════════════

class _GridArea extends StatelessWidget {
  final GalleryProvider    provider;
  final AnimationController scanCtrl;
  final Animation<double>  pulseAnim;
  final bool               selectionMode;
  final Set<int>           selectedIds;
  final void Function(int) onEnterSelect;
  final void Function(int) onToggleSelect;

  const _GridArea({
    required this.provider,
    required this.scanCtrl,
    required this.pulseAnim,
    required this.selectionMode,
    required this.selectedIds,
    required this.onEnterSelect,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(
                color: _kPurpleL,
                strokeWidth: 2,
                backgroundColor: _kPurple.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scanning vault…',
              style: TextStyle(
                  color: _kPurpleL.withValues(alpha: 0.7),
                  fontSize: 13, letterSpacing: 1.2),
            ),
          ],
        ),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 52, color: Colors.red.withValues(alpha: 0.8)),
            const SizedBox(height: 12),
            Text(provider.error!,
                style: TextStyle(
                    color: _kWhite.withValues(alpha: 0.5), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _NeonTextButton(
              label: 'RETRY',
              onTap: () => context.read<GalleryProvider>().loadMedia(),
            ),
          ],
        ),
      );
    }

    if (provider.mediaList.isEmpty) {
      return _EmptyVault(pulseAnim: pulseAnim);
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w       = constraints.maxWidth;
            final cols    = w >= 1400 ? 5 : w >= 1050 ? 4 : w >= 680 ? 3 : 2;
            final spacing = w > 600 ? 10.0 : 7.0;
            final hPad    = w > 1400 ? (w - 1400) / 2 + 16 : 14.0;

            return RefreshIndicator(
              color: _kPurpleL,
              backgroundColor: const Color(0xFF1A0A3E),
              onRefresh: () => context.read<GalleryProvider>().loadMedia(),
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 96),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 1.0,
                ),
                itemCount: provider.mediaList.length,
                itemBuilder: (context, i) {
                  final item = provider.mediaList[i];
                  return _MediaTile(
                    item:             item,
                    index:            i,
                    isSelectionMode:  selectionMode,
                    isSelected:       selectedIds.contains(item.mediaId),
                    onLongPressSelect: () => onEnterSelect(item.mediaId),
                    onToggleSelect:   () => onToggleSelect(item.mediaId),
                  );
                },
              ),
            );
          },
        ),
        // Scan-line overlay
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: scanCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ScanLinePainter(scanCtrl.value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Empty vault state
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyVault extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _EmptyVault({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPurple.withValues(alpha: 0.08),
                border: Border.all(
                    color: _kPurple.withValues(alpha: pulseAnim.value * 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(alpha: pulseAnim.value * 0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: child,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                size: 40, color: _kPurpleL),
          ),
          const SizedBox(height: 20),
          const Text(
            'VAULT IS EMPTY',
            style: TextStyle(
              color: _kPurpleL,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your first file to begin\nend-to-end encryption',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kWhite.withValues(alpha: 0.35),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Media tile — glass card with unlock animation
// ══════════════════════════════════════════════════════════════════════════════

class _MediaTile extends StatefulWidget {
  final MediaItem    item;
  final int          index;
  final bool         isSelectionMode;
  final bool         isSelected;
  final VoidCallback onLongPressSelect;
  final VoidCallback onToggleSelect;

  const _MediaTile({
    required this.item,
    required this.index,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onLongPressSelect,
    required this.onToggleSelect,
  });

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile>
    with TickerProviderStateMixin {
  late final AnimationController _unlockCtrl;
  late final AnimationController _hoverCtrl;
  late final Animation<double>   _scaleAnim;
  late final Animation<double>   _glowAnim;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    _unlockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _unlockCtrl, curve: Curves.easeOut),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _unlockCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _unlockCtrl.dispose();
    _hoverCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (widget.isSelectionMode) {
      widget.onToggleSelect();
      return;
    }
    if (_unlocking) return;
    setState(() => _unlocking = true);
    await _unlockCtrl.forward();
    if (mounted) {
      await Navigator.pushNamed(context, '/view', arguments: widget.item);
    }
    if (mounted) {
      _unlockCtrl.reverse();
      setState(() => _unlocking = false);
    }
  }

  Color get _algoColor =>
      widget.item.algo == 'AES-GCM' ? _kGreen : _kAmber;
  String get _algoLabel =>
      widget.item.algo == 'AES-GCM' ? 'AES-256' : 'CC20';

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverCtrl.forward(),
      onExit:  (_) => _hoverCtrl.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_unlockCtrl, _hoverCtrl]),
        builder: (_, __) => Transform.scale(
          scale: _scaleAnim.value * (1.0 + _hoverCtrl.value * 0.025),
          child: GestureDetector(
            onTap: _onTap,
            onLongPress: widget.isSelectionMode
                ? widget.onToggleSelect
                : widget.onLongPressSelect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _kPurple.withValues(
                        alpha: widget.isSelected
                            ? 0.22
                            : 0.07 + _hoverCtrl.value * 0.06),
                    border: Border.all(
                      color: widget.isSelected
                          ? _kPurpleL.withValues(alpha: 0.9)
                          : _kPurple.withValues(
                              alpha: 0.15 +
                                  _hoverCtrl.value * 0.2 +
                                  _glowAnim.value * 0.5),
                      width: widget.isSelected ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isSelected
                            ? _kPurpleL.withValues(alpha: 0.4)
                            : _kPurple.withValues(
                                alpha: _hoverCtrl.value * 0.28 +
                                    _glowAnim.value * 0.45),
                        blurRadius: widget.isSelected ? 18 : 20,
                        spreadRadius: widget.isSelected ? 1 : -2 + _hoverCtrl.value * 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // ── Circuit pattern ──────────────────────────────
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CircuitPainter(widget.index),
                        ),
                      ),

                      // ── Content ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Lock / unlock icon
                            Expanded(
                              child: Center(
                                child: _LockIcon(
                                  glowAnim: _glowAnim,
                                  unlocking: _unlocking,
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Filename
                            Text(
                              widget.item.filename,
                              style: const TextStyle(
                                color: _kWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Bottom row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: _algoColor.withValues(alpha: 0.12),
                                    border: Border.all(
                                        color: _algoColor.withValues(alpha: 0.4),
                                        width: 0.8),
                                  ),
                                  child: Text(
                                    _algoLabel,
                                    style: TextStyle(
                                      color: _algoColor,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // ··· menu — always opens options sheet
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showOptions(context),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(Icons.more_horiz_rounded,
                                        size: 14,
                                        color: _kWhite.withValues(alpha: 0.4)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── Glow sweep on unlock ────────────────────────
                      if (_glowAnim.value > 0)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _kPurple.withValues(
                                      alpha: _glowAnim.value * 0.15),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                      // ── Selection checkmark overlay ─────────────────
                      if (widget.isSelected)
                        Positioned(
                          top: 6, right: 6,
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kPurple,
                              border: Border.all(
                                  color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: _kPurpleL.withValues(alpha: 0.6),
                                    blurRadius: 8),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OptionsSheet(item: widget.item),
    );
  }
}

// ── Animated lock icon ─────────────────────────────────────────────────────────

class _LockIcon extends StatelessWidget {
  final Animation<double> glowAnim;
  final bool unlocking;
  const _LockIcon({required this.glowAnim, required this.unlocking});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (_, __) {
        final glow = glowAnim.value;
        return Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kPurple.withValues(alpha: 0.1 + glow * 0.15),
            border: Border.all(
              color: _kPurple.withValues(alpha: 0.25 + glow * 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _kPurple.withValues(alpha: glow * 0.6),
                blurRadius: 16 + glow * 16,
                spreadRadius: glow * 3,
              ),
            ],
          ),
          child: Icon(
            unlocking && glow > 0.5
                ? Icons.lock_open_rounded
                : Icons.lock_rounded,
            size: 18,
            color: _kPurpleL.withValues(alpha: 0.7 + glow * 0.3),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Options bottom sheet — glass style
// ══════════════════════════════════════════════════════════════════════════════

class _OptionsSheet extends StatelessWidget {
  final MediaItem item;
  const _OptionsSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0730).withValues(alpha: 0.92),
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
                // Handle bar
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: _kPurple.withValues(alpha: 0.4),
                    ),
                  ),
                ),

                // File name header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kPurple.withValues(alpha: 0.15),
                          border: Border.all(
                              color: _kPurple.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: _kPurpleL, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.filename,
                              style: const TextStyle(
                                  color: _kWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.algo,
                              style: TextStyle(
                                  color: _kPurpleL.withValues(alpha: 0.6),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(color: _kPurple.withValues(alpha: 0.15), height: 1),

                // Actions
                _SheetAction(
                  icon: Icons.visibility_outlined,
                  label: 'Decrypt & View',
                  color: _kPurpleL,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/view', arguments: item);
                  },
                ),
                _SheetAction(
                  icon: Icons.share_outlined,
                  label: 'Safe Share',
                  sublabel: 'RSA-OAEP encrypted key exchange',
                  color: _kGreen,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/share', arguments: [item]);
                  },
                ),
                _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete from Vault',
                  color: const Color(0xFFFC8181),
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
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F0730),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _kPurple.withValues(alpha: 0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFC8181), size: 22),
              SizedBox(width: 10),
              Text('Delete File',
                  style: TextStyle(color: _kWhite, fontSize: 16)),
            ],
          ),
          content: Text(
            'Permanently delete "${item.filename}"?\n\nThe encrypted file and its key will be destroyed.',
            style: TextStyle(
                color: _kWhite.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: _kWhite.withValues(alpha: 0.5))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await MediaService.deleteMedia(item.mediaId);
                  await StorageService.deleteSymmetricKey(item.mediaId);
                  if (context.mounted) {
                    context.read<GalleryProvider>().removeMedia(item.mediaId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('File destroyed from vault.'),
                        backgroundColor: _kPurple2,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Delete failed: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Destroy',
                  style: TextStyle(
                      color: Color(0xFFFC8181), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color color;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (sublabel != null)
                  Text(sublabel!,
                      style: TextStyle(
                          color: _kWhite.withValues(alpha: 0.35),
                          fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Neon FAB
// ══════════════════════════════════════════════════════════════════════════════

class _NeonFab extends StatefulWidget {
  final Animation<double> pulseAnim;
  final VoidCallback onPressed;
  const _NeonFab({required this.pulseAnim, required this.onPressed});

  @override
  State<_NeonFab> createState() => _NeonFabState();
}

class _NeonFabState extends State<_NeonFab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: widget.pulseAnim,
          builder: (_, child) => Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFF9F67FF), _kPurple, _kPurple2],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kPurple.withValues(
                      alpha: widget.pulseAnim.value * (_hovered ? 0.9 : 0.6)),
                  blurRadius: _hovered ? 36 : 24,
                  spreadRadius: _hovered ? 4 : 0,
                ),
              ],
            ),
            child: child,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: _kWhite, size: 22),
              SizedBox(width: 8),
              Text(
                'ENCRYPT & UPLOAD',
                style: TextStyle(
                  color: _kWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small neon text button ─────────────────────────────────────────────────────

class _NeonTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NeonTextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kPurple.withValues(alpha: 0.4)),
          color: _kPurple.withValues(alpha: 0.08),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: _kPurpleL,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Painters
// ══════════════════════════════════════════════════════════════════════════════

/// Full-screen cyber background: gradient + hex dots + floating orbs.
class _CyberBackground extends StatelessWidget {
  const _CyberBackground();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        // Deep dark gradient
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF07031A),
                Color(0xFF060918),
                Color(0xFF040612),
                Color(0xFF0C0424),
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
        // Hex dot pattern
        Positioned.fill(
          child: CustomPaint(painter: _HexDotPainter()),
        ),
        // Glow orbs
        Positioned(
          top: -80, right: -60,
          child: _Orb(size: 320, color: _kPurple, opacity: 0.18),
        ),
        Positioned(
          bottom: -100, left: -80,
          child: _Orb(size: 380, color: _kPurple2, opacity: 0.22),
        ),
        Positioned(
          top: 200, left: -40,
          child: _Orb(size: 200, color: _kPurple, opacity: 0.08),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Orb({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// Hexagonal dot grid background pattern.
class _HexDotPainter extends CustomPainter {
  const _HexDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 28.0;
    const r       = 1.4;

    final linePaint = Paint()
      ..color      = const Color(0xFF7C3AED).withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Glowing dots at intersections
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Vary opacity with pseudo-random pattern
        final phase = (x * 7 + y * 13) % 100;
        final alpha = phase < 40 ? 0.08 : (phase < 70 ? 0.18 : 0.06);
        canvas.drawCircle(
          Offset(x, y), r,
          Paint()
            ..color = Color.fromRGBO(167, 139, 250, alpha)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

/// Per-card subtle circuit-board background.
class _CircuitPainter extends CustomPainter {
  final int seed;
  const _CircuitPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = math.Random(seed * 31 + 7);
    final paint = Paint()
      ..color      = const Color(0xFF7C3AED).withValues(alpha: 0.06)
      ..strokeWidth = 0.8
      ..style       = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final x1 = rng.nextDouble() * size.width;
      final y1 = rng.nextDouble() * size.height;
      final x2 = x1 + (rng.nextDouble() - 0.5) * 60;
      final y2 = y1 + (rng.nextDouble() - 0.5) * 60;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y1), paint);
      canvas.drawLine(Offset(x2, y1), Offset(x2, y2), paint);
      canvas.drawCircle(Offset(x2, y2), 2, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter old) => old.seed != seed;
}

/// Animated horizontal scan line for the grid area.
class _ScanLinePainter extends CustomPainter {
  final double progress;
  const _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * (size.height + 60) - 30;

    // Glow band
    final bandRect = Rect.fromLTWH(0, y - 20, size.width, 40);
    canvas.drawRect(
      bandRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF7C3AED).withValues(alpha: 0.04),
            const Color(0xFF7C3AED).withValues(alpha: 0.07),
            const Color(0xFF7C3AED).withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ).createShader(bandRect),
    );

    // Sharp scan line
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color      = const Color(0xFFA78BFA).withValues(alpha: 0.25)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => old.progress != progress;
}
