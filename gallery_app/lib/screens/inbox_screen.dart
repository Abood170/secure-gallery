import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/share_item.dart';
import '../providers/gallery_provider.dart';
import '../services/crypto_service.dart';
import '../services/media_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';

// ── Design tokens (mirrors dashboard) ─────────────────────────────────────────
const _kBg      = Color(0xFF060918);
const _kPurple  = Color(0xFF7C3AED);
const _kPurpleL = Color(0xFFA78BFA);
const _kPurple2 = Color(0xFF4C1D95);
const _kGreen   = Color(0xFF10B981);
const _kAmber   = Color(0xFFF59E0B);
const _kRed     = Color(0xFFEF4444);
const _kWhite   = Colors.white;

// ══════════════════════════════════════════════════════════════════════════════
//  InboxScreen
// ══════════════════════════════════════════════════════════════════════════════

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _pulseAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GalleryProvider>().loadInbox();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GalleryProvider>();
    final count    = provider.inbox.length;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _InboxBackground()),
          SafeArea(
            child: Column(
              children: [
                // ── Glass header ───────────────────────────────────────────
                _InboxHeader(
                  count:     count,
                  pulseAnim: _pulseAnim,
                  onBack:    () => Navigator.pop(context),
                ),

                // ── Body ──────────────────────────────────────────────────
                Expanded(
                  child: provider.loading
                      ? _LoadingView(pulseAnim: _pulseAnim)
                      : provider.inbox.isEmpty
                          ? const _EmptyState()
                          : FadeTransition(
                              opacity: _fadeAnim,
                              child: RefreshIndicator(
                                color: _kPurpleL,
                                backgroundColor: const Color(0xFF1A0A3E),
                                onRefresh: () =>
                                    context.read<GalleryProvider>().loadInbox(),
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 16, 16, 32),
                                  itemCount: provider.inbox.length,
                                  itemBuilder: (ctx, i) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: _ShareCard(
                                      share: provider.inbox[i],
                                      index: i,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
//  Glass header
// ══════════════════════════════════════════════════════════════════════════════

class _InboxHeader extends StatelessWidget {
  final int               count;
  final Animation<double> pulseAnim;
  final VoidCallback      onBack;

  const _InboxHeader({
    required this.count,
    required this.pulseAnim,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
          decoration: BoxDecoration(
            color: _kWhite.withValues(alpha: 0.03),
            border: Border(
              bottom: BorderSide(
                  color: _kPurple.withValues(alpha: 0.22), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Back button
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: _kPurpleL, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Icon + title
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kPurple.withValues(
                            alpha: pulseAnim.value * 0.65),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: const Icon(Icons.move_to_inbox_rounded,
                    color: _kPurpleL, size: 22),
              ),
              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared with Me',
                      style: TextStyle(
                        color: _kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'End-to-end encrypted sharing',
                      style: TextStyle(
                          color: _kPurpleL,
                          fontSize: 10,
                          letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),

              // "Secure Share" badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _kGreen.withValues(alpha: 0.08),
                  border: Border.all(
                      color: _kGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kGreen,
                        boxShadow: [
                          BoxShadow(
                              color: _kGreen.withValues(alpha: 0.7),
                              blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SECURE SHARE',
                      style: TextStyle(
                        color: _kGreen.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Share card
// ══════════════════════════════════════════════════════════════════════════════

class _ShareCard extends StatefulWidget {
  final ShareItem share;
  final int       index;
  const _ShareCard({required this.share, required this.index});

  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl;
  late final Animation<double>   _hoverAnim;
  bool _loading = false;
  // decrypt animation: 0=idle 1=decrypting 2=done
  int  _decryptStep = 0;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _hoverAnim =
        CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  Color get _algoColor =>
      widget.share.algo == 'AES-GCM' ? _kGreen : _kAmber;
  String get _algoLabel =>
      widget.share.algo == 'AES-GCM' ? 'AES-256' : 'ChaCha20';

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0730),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove share?',
            style: TextStyle(color: _kWhite)),
        content: Text(
          'This will remove "${widget.share.filename}" from your inbox.',
          style: TextStyle(color: _kWhite.withValues(alpha: 0.55)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style:
                    TextStyle(color: _kWhite.withValues(alpha: 0.45))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await ShareService.deleteShare(widget.share.shareId);
      if (mounted) context.read<GalleryProvider>().loadInbox();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Decrypt & view ─────────────────────────────────────────────────────────
  Future<void> _view() async {
    setState(() { _loading = true; _decryptStep = 1; });
    try {
      final encryptedKey =
          await ShareService.getEncryptedKey(widget.share.shareId);

      final privateKey = await StorageService.getPrivateKey();
      if (privateKey == null) {
        throw Exception(
            'RSA private key not found. Please log in again.');
      }
      final keyBase64 =
          await CryptoService.rsaDecryptKey(encryptedKey, privateKey);

      final dl =
          await MediaService.downloadShared(widget.share.shareId);

      final plaintext = await CryptoService.decrypt(
        ciphertextWithMac: dl.ciphertext,
        ivBase64:  dl.iv.isNotEmpty   ? dl.iv   : widget.share.iv,
        keyBase64: keyBase64,
        algo:      dl.algo.isNotEmpty ? dl.algo : widget.share.algo,
      );

      setState(() => _decryptStep = 2);
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        Navigator.push(
          context,
          _fadeSlideRoute(
            _DecryptedImageView(
              imageBytes:  plaintext,
              filename:    widget.share.filename,
              algo:        widget.share.algo,
              senderEmail: widget.share.senderEmail,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('OperationError')
            ? 'Key mismatch — delete this share and ask the sender to reshare.'
            : 'Failed to decrypt: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _loading = false; _decryptStep = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverCtrl.forward(),
      onExit:  (_) => _hoverCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _hoverAnim,
        builder: (_, child) => Transform.scale(
          scale: 1.0 + _hoverAnim.value * 0.015,
          child: child,
        ),
        child: AnimatedBuilder(
          animation: _hoverAnim,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _kPurple.withValues(
                  alpha: 0.05 + _hoverAnim.value * 0.06),
              border: Border.all(
                color: _kPurple.withValues(
                    alpha: 0.15 + _hoverAnim.value * 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kPurple.withValues(
                      alpha: _hoverAnim.value * 0.22),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // ── Lock icon ────────────────────────────────────────
                    _LockIndicator(
                        step: _decryptStep, algoColor: _algoColor),
                    const SizedBox(width: 14),

                    // ── File info ────────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Filename + algo badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.share.filename,
                                  style: const TextStyle(
                                    color: _kWhite,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _AlgoBadge(
                                  label: _algoLabel,
                                  color: _algoColor),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Sender
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 11,
                                  color:
                                      _kWhite.withValues(alpha: 0.3)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.share.senderEmail,
                                  style: TextStyle(
                                      color:
                                          _kWhite.withValues(alpha: 0.42),
                                      fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Decrypt step text
                          if (_decryptStep > 0) ...[
                            const SizedBox(height: 6),
                            _DecryptStatus(step: _decryptStep),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ── Action buttons ───────────────────────────────────
                    if (_loading)
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kPurpleL),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionBtn(
                            icon:    Icons.visibility_outlined,
                            color:   _kPurpleL,
                            tooltip: 'Decrypt & View',
                            onTap:   _view,
                          ),
                          const SizedBox(width: 4),
                          _ActionBtn(
                            icon:    Icons.delete_outline_rounded,
                            color:   _kRed,
                            tooltip: 'Remove',
                            onTap:   _delete,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Lock indicator (idle / decrypting / done) ─────────────────────────────────

class _LockIndicator extends StatelessWidget {
  final int   step;
  final Color algoColor;
  const _LockIndicator({required this.step, required this.algoColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(step),
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: step == 2
              ? _kGreen.withValues(alpha: 0.12)
              : _kPurple.withValues(alpha: 0.12),
          border: Border.all(
            color: step == 2
                ? _kGreen.withValues(alpha: 0.45)
                : _kPurple.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (step == 2 ? _kGreen : _kPurple)
                  .withValues(alpha: step > 0 ? 0.35 : 0.0),
              blurRadius: 12,
            ),
          ],
        ),
        child: step == 1
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kPurpleL))
            : Icon(
                step == 2
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                color: step == 2
                    ? _kGreen
                    : _kPurpleL,
                size: 20,
              ),
      ),
    );
  }
}

// ── Decrypt status label ──────────────────────────────────────────────────────

class _DecryptStatus extends StatelessWidget {
  final int step;
  const _DecryptStatus({required this.step});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (step) {
      1 => ('Decrypting…', _kPurpleL),
      _ => ('Decrypted ✓', _kGreen),
    };
    return Text(
      text,
      style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w600),
    );
  }
}

// ── Algo badge ────────────────────────────────────────────────────────────────

class _AlgoBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _AlgoBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: color.withValues(alpha: 0.1),
        border: Border.all(
            color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Action icon button ────────────────────────────────────────────────────────

class _ActionBtn extends StatefulWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(
                  alpha: _hovered ? 0.16 : 0.06),
              border: Border.all(
                color: widget.color.withValues(
                    alpha: _hovered ? 0.5 : 0.18),
                width: 0.8,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Icon(widget.icon,
                color: widget.color.withValues(
                    alpha: _hovered ? 1.0 : 0.65),
                size: 16),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Empty state
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 36),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _kWhite.withValues(alpha: 0.03),
                border: Border.all(
                    color: _kPurple.withValues(alpha: 0.18)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kPurple.withValues(alpha: 0.08),
                      border: Border.all(
                          color: _kPurple.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.move_to_inbox_rounded,
                        color: _kPurpleL, size: 32),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No shared files yet',
                    style: TextStyle(
                      color: _kWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Securely shared files will appear here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kWhite.withValues(alpha: 0.35),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _kGreen.withValues(alpha: 0.07),
                      border: Border.all(
                          color: _kGreen.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            color: _kGreen.withValues(alpha: 0.7),
                            size: 12),
                        const SizedBox(width: 6),
                        Text(
                          'End-to-end encrypted sharing',
                          style: TextStyle(
                            color: _kGreen.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Loading view
// ══════════════════════════════════════════════════════════════════════════════

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
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPurple.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(
                        alpha: pulseAnim.value * 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: child,
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: _kPurpleL, strokeWidth: 2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading shared files…',
            style: TextStyle(
              color: _kPurpleL.withValues(alpha: 0.6),
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Decrypted image viewer
// ══════════════════════════════════════════════════════════════════════════════

class _DecryptedImageView extends StatefulWidget {
  final Uint8List imageBytes;
  final String    filename;
  final String    algo;
  final String    senderEmail;

  const _DecryptedImageView({
    required this.imageBytes,
    required this.filename,
    required this.algo,
    required this.senderEmail,
  });

  @override
  State<_DecryptedImageView> createState() => _DecryptedImageViewState();
}

class _DecryptedImageViewState extends State<_DecryptedImageView> {
  @override
  Widget build(BuildContext context) {
    final algoColor = widget.algo == 'AES-GCM' ? _kGreen : _kAmber;
    final algoLabel = widget.algo == 'AES-GCM' ? 'AES-256' : 'ChaCha20';
    final size      = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen image ──────────────────────────────────────────
          // LayoutBuilder captures bounded screen dimensions BEFORE entering
          // InteractiveViewer (which gives unbounded constraints).
          // SizedBox pins those dimensions so BoxFit.contain works correctly.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth  == double.infinity
                    ? size.width  : constraints.maxWidth;
                final h = constraints.maxHeight == double.infinity
                    ? size.height : constraints.maxHeight;
                return InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.5,
                  maxScale: 8.0,
                  child: SizedBox(
                    width:  w,
                    height: h,
                    child: Center(
                      child: Image.memory(
                        widget.imageBytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, __) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.broken_image_rounded,
                                    color: _kRed, size: 56),
                                const SizedBox(height: 12),
                                const Text(
                                  'Failed to display image',
                                  style: TextStyle(
                                      color: _kWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: _kWhite.withValues(alpha: 0.5),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Glass top bar ──────────────────────────────────────────────
          // Must be Positioned so it only occupies its content height.
          // Without Positioned, SafeArea in a Stack gets full-screen tight
          // constraints and Container fills them — covering the whole image.
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border(
                        bottom: BorderSide(
                            color: _kPurple.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: _kWhite, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.filename,
                            style: const TextStyle(
                                color: _kWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _AlgoBadge(label: algoLabel, color: algoColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Glass sender banner (bottom) ───────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    border: Border(
                      top: BorderSide(
                          color: _kPurple.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: _kGreen, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        'Shared by: ${widget.senderEmail}',
                        style: TextStyle(
                            color: _kWhite.withValues(alpha: 0.65),
                            fontSize: 12),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _kGreen.withValues(alpha: 0.1),
                          border: Border.all(
                              color: _kGreen.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'E2E ENCRYPTED',
                          style: TextStyle(
                            color: _kGreen.withValues(alpha: 0.85),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

class _InboxBackground extends StatelessWidget {
  const _InboxBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.3, -0.5),
              radius: 1.4,
              colors: [Color(0xFF1A0A3E), Color(0xFF060918)],
            ),
          ),
        ),
        Positioned(
          top: -80, left: -60,
          child: _Orb(size: 300,
              color: _kPurple2.withValues(alpha: 0.22)),
        ),
        Positioned(
          bottom: -60, right: -40,
          child: _Orb(size: 240,
              color: _kPurple.withValues(alpha: 0.14)),
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
  final Color  color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
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
      ..color = const Color(0x08A78BFA)
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

// ══════════════════════════════════════════════════════════════════════════════
//  Route transition helper
// ══════════════════════════════════════════════════════════════════════════════

Route<T> _fadeSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}
