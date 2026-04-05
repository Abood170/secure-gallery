import 'dart:math' as math;
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/crypto_service.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF060918);
const _kPurple  = Color(0xFF7C3AED);
const _kPurpleL = Color(0xFFA78BFA);
const _kPurple2 = Color(0xFF4C1D95);
const _kGreen   = Color(0xFF10B981);
const _kAmber   = Color(0xFFF59E0B);
const _kRed     = Color(0xFFFC8181);
const _kWhite   = Colors.white;

// ══════════════════════════════════════════════════════════════════════════════
//  ProfileScreen
// ══════════════════════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {

  // ── Data ──────────────────────────────────────────────────────────────────
  UserProfile? _profile;
  bool   _loading   = true;
  String? _loadError;

  // ── Edit email ────────────────────────────────────────────────────────────
  final _newEmailCtrl    = TextEditingController();
  final _emailPassCtrl   = TextEditingController();
  final _emailFormKey    = GlobalKey<FormState>();
  bool  _emailSaving     = false;
  bool  _emailObscure    = true;

  // ── Change password ───────────────────────────────────────────────────────
  final _curPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _cfmPassCtrl  = TextEditingController();
  final _passFormKey  = GlobalKey<FormState>();
  bool  _passSaving   = false;
  bool  _curObscure   = true;
  bool  _newObscure   = true;
  bool  _cfmObscure   = true;

  // ── Key regen ─────────────────────────────────────────────────────────────
  bool _regenLoading = false;

  // ── Delete account ────────────────────────────────────────────────────────
  final _delPassCtrl = TextEditingController();

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _loadProfile();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _newEmailCtrl.dispose();
    _emailPassCtrl.dispose();
    _curPassCtrl.dispose();
    _newPassCtrl.dispose();
    _cfmPassCtrl.dispose();
    _delPassCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final p = await ProfileService.getProfile();
      if (mounted) {
        setState(() { _profile = p; _loading = false; });
        _newEmailCtrl.text = p.email;
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = _msg(e); });
    }
  }

  // ── Save email ────────────────────────────────────────────────────────────
  Future<void> _saveEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _emailSaving = true);
    try {
      await ProfileService.updateProfile(
        newEmail:        _newEmailCtrl.text.trim(),
        currentPassword: _emailPassCtrl.text,
      );
      _emailPassCtrl.clear();
      await _loadProfile();
      if (mounted) _toast('Email updated successfully', _kGreen);
    } catch (e) {
      if (mounted) _toast(_msg(e), _kRed);
    } finally {
      if (mounted) setState(() => _emailSaving = false);
    }
  }

  // ── Change password ───────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    setState(() => _passSaving = true);
    try {
      await ProfileService.updateProfile(
        newPassword:     _newPassCtrl.text,
        currentPassword: _curPassCtrl.text,
      );
      _curPassCtrl.clear();
      _newPassCtrl.clear();
      _cfmPassCtrl.clear();
      if (mounted) _toast('Password updated successfully', _kGreen);
    } catch (e) {
      if (mounted) _toast(_msg(e), _kRed);
    } finally {
      if (mounted) setState(() => _passSaving = false);
    }
  }

  // ── Regenerate RSA keys ───────────────────────────────────────────────────
  Future<void> _regenerateKeys() async {
    final confirmed = await _showConfirmDialog(
      title:   'Regenerate Encryption Keys',
      message: 'This will generate a new RSA key pair and upload the new public key.\n\n'
               'Previously received shares will no longer be decryptable on this device.\n\n'
               'Are you sure?',
      confirm: 'Regenerate',
      danger:  false,
    );
    if (confirmed != true) return;

    setState(() => _regenLoading = true);
    try {
      final kp     = await CryptoService.generateRsaKeyPair();
      final userId = await StorageService.getUserId();
      if (userId == null) throw Exception('Session expired. Please log in again.');

      await StorageService.saveKeyPair(userId, kp['privateKey']!, kp['publicKey']!);
      await ApiService.dio.put(
        ApiConfig.updatePublicKey,
        data: {'public_key': kp['publicKey']},
      );

      await _loadProfile();
      if (mounted) _toast('New key pair generated and uploaded', _kGreen);
    } catch (e) {
      if (mounted) _toast(_msg(e), _kRed);
    } finally {
      if (mounted) setState(() => _regenLoading = false);
    }
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirmed = await _showDeleteAccountDialog();
    if (confirmed != true || !mounted) return;

    try {
      await ProfileService.deleteAccount(password: _delPassCtrl.text);
      await StorageService.clearAll();
      if (mounted) {
        context.read<AuthProvider>().logout();
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) _toast(_msg(e), _kRed);
    } finally {
      _delPassCtrl.clear();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _msg(Object e) {
    if (e is DioException) {
      return (e.response?.data as Map?)?['error']?.toString() ?? e.message ?? 'Request failed.';
    }
    return e.toString();
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color == _kGreen ? _kPurple2 : Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirm,
    required bool   danger,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F0730),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _kPurple.withValues(alpha: 0.3)),
            ),
            title: Text(title,
                style: const TextStyle(color: _kWhite, fontSize: 16)),
            content: Text(message,
                style: TextStyle(
                    color: _kWhite.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.55)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style:
                        TextStyle(color: _kWhite.withValues(alpha: 0.5))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirm,
                    style: TextStyle(
                        color:       danger ? _kRed : _kPurpleL,
                        fontWeight:  FontWeight.w700)),
              ),
            ],
          ),
        ),
      );

  Future<bool?> _showDeleteAccountDialog() => showDialog<bool>(
        context: context,
        builder: (ctx) {
          bool obscure = true;
          return StatefulBuilder(
            builder: (ctx, setSt) => BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F0730),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _kRed.withValues(alpha: 0.35)),
                ),
                title: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: _kRed, size: 20),
                  const SizedBox(width: 8),
                  const Text('Delete Account',
                      style: TextStyle(color: _kRed, fontSize: 16)),
                ]),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This permanently deletes your account, all uploaded files, and all shared items. This cannot be undone.',
                      style: TextStyle(
                          color: _kWhite.withValues(alpha: 0.6),
                          fontSize: 13,
                          height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    _GlassField(
                      controller: _delPassCtrl,
                      label:      'Enter your password',
                      obscure:    obscure,
                      prefixIcon: Icons.lock_outline_rounded,
                      onToggleObscure: () => setSt(() => obscure = !obscure),
                    ),
                  ],
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
                    child: const Text('Delete Forever',
                        style: TextStyle(
                            color: _kRed, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _ProfileBackground()),
          SafeArea(
            child: Column(
              children: [
                _ProfileHeader(onBack: () => Navigator.pop(context)),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _kPurple.withValues(alpha: _pulseAnim.value * 0.5),
                blurRadius: 24,
              )],
            ),
            child: const CircularProgressIndicator(
                color: _kPurpleL, strokeWidth: 2),
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 52, color: _kRed.withValues(alpha: 0.8)),
            const SizedBox(height: 12),
            Text(_loadError!,
                style: TextStyle(
                    color: _kWhite.withValues(alpha: 0.5), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _NeonTextButton(label: 'RETRY', onTap: _loadProfile),
          ],
        ),
      );
    }

    final p = _profile!;
    return FadeTransition(
      opacity: _fadeAnim,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final hPad = constraints.maxWidth > 700
              ? (constraints.maxWidth - 680) / 2
              : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero
                _HeroCard(profile: p, pulseAnim: _pulseAnim),
                const SizedBox(height: 14),

                // Banned banner
                if (p.isBanned) ...[
                  _BannedBanner(),
                  const SizedBox(height: 14),
                ],

                // Stats
                _StatsCard(profile: p),
                const SizedBox(height: 14),

                // Edit email
                _SectionCard(
                  icon:  Icons.alternate_email_rounded,
                  title: 'EMAIL ADDRESS',
                  child: _EmailSection(
                    emailCtrl:   _newEmailCtrl,
                    passCtrl:    _emailPassCtrl,
                    formKey:     _emailFormKey,
                    saving:      _emailSaving,
                    obscure:     _emailObscure,
                    onToggle:    () => setState(() => _emailObscure = !_emailObscure),
                    onSave:      _saveEmail,
                    currentEmail: p.email,
                  ),
                ),
                const SizedBox(height: 14),

                // Change password
                _SectionCard(
                  icon:  Icons.lock_reset_rounded,
                  title: 'CHANGE PASSWORD',
                  child: _PasswordSection(
                    curCtrl:   _curPassCtrl,
                    newCtrl:   _newPassCtrl,
                    cfmCtrl:   _cfmPassCtrl,
                    formKey:   _passFormKey,
                    saving:    _passSaving,
                    curObs:    _curObscure,
                    newObs:    _newObscure,
                    cfmObs:    _cfmObscure,
                    onCurTog:  () => setState(() => _curObscure = !_curObscure),
                    onNewTog:  () => setState(() => _newObscure = !_newObscure),
                    onCfmTog:  () => setState(() => _cfmObscure = !_cfmObscure),
                    onSave:    _changePassword,
                  ),
                ),
                const SizedBox(height: 14),

                // Security / RSA keys
                _SectionCard(
                  icon:  Icons.vpn_key_rounded,
                  title: 'ENCRYPTION KEYS',
                  child: _SecuritySection(
                    hasPublicKey:  p.hasPublicKey,
                    regenLoading:  _regenLoading,
                    onRegen:       _regenerateKeys,
                  ),
                ),
                const SizedBox(height: 14),

                // Danger zone
                _DangerZone(
                  onLogout: _logout,
                  onDelete: _deleteAccount,
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Background
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.3, -0.5),
            radius: 1.4,
            colors: [Color(0xFF1A0A3E), Color(0xFF060918)],
          ),
        ),
      ),
      Positioned(top: -80, left: -60,
          child: _GlowOrb(size: 300, color: _kPurple2.withValues(alpha: 0.25))),
      Positioned(bottom: -60, right: -40,
          child: _GlowOrb(size: 240, color: _kPurple.withValues(alpha: 0.15))),
      Positioned.fill(child: CustomPaint(painter: _GridPainter())),
    ]);
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color  color;
  const _GlowOrb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x09A78BFA)..strokeWidth = 0.5;
    const step = 44.0;
    for (double x = 0; x < size.width;  x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  Header
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _ProfileHeader({required this.onBack});

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
              bottom: BorderSide(color: _kPurple.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(children: [
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile',
                      style: TextStyle(
                          color: _kWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                  Text('Manage your account and security',
                      style: TextStyle(
                          color: _kPurpleL,
                          fontSize: 10,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _kPurple.withValues(alpha: 0.15),
                border:
                    Border.all(color: _kPurple.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, color: _kPurpleL, size: 12),
                  SizedBox(width: 5),
                  Text('SECURE',
                      style: TextStyle(
                          color: _kPurpleL,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Hero card — avatar + identity
// ══════════════════════════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final UserProfile       profile;
  final Animation<double> pulseAnim;
  const _HeroCard({required this.profile, required this.pulseAnim});

  String get _initials {
    final parts = profile.email.split('@').first.split(RegExp(r'[._\-]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return profile.email.substring(0, math.min(2, profile.email.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = profile.role == 'admin';
    return _GlassPanel(
      child: Row(children: [
        // Avatar
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _kPurple.withValues(alpha: pulseAnim.value * 0.55),
                blurRadius: 20,
                spreadRadius: 2,
              )],
            ),
            child: child,
          ),
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_kPurple, _kPurple2],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              border: Border.all(
                  color: _kPurpleL.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(
              child: Text(_initials,
                  style: const TextStyle(
                      color: _kWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.email,
                  style: const TextStyle(
                      color: _kWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _Chip(
                  label: isAdmin ? 'ADMIN' : 'USER',
                  color: isAdmin ? _kAmber : _kPurpleL,
                  icon:  isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                ),
                _Chip(
                  label: 'E2E PROTECTED',
                  color: _kGreen,
                  icon:  Icons.verified_user_outlined,
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Banned banner
// ══════════════════════════════════════════════════════════════════════════════

class _BannedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: _kRed.withValues(alpha: 0.08),
      border: Border.all(color: _kRed.withValues(alpha: 0.4)),
    ),
    child: Row(children: [
      Icon(Icons.block_rounded, color: _kRed, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Account Suspended',
              style: TextStyle(
                  color: _kRed, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Your account has been suspended. Contact support for assistance.',
              style: TextStyle(
                  color: _kRed.withValues(alpha: 0.7), fontSize: 11, height: 1.4)),
        ]),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  Stats card
// ══════════════════════════════════════════════════════════════════════════════

class _StatsCard extends StatelessWidget {
  final UserProfile profile;
  const _StatsCard({required this.profile});

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: Icons.bar_chart_rounded, title: 'ACTIVITY'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _StatTile(
              icon:    Icons.lock_rounded,
              color:   _kPurpleL,
              value:   '${profile.mediaCount}',
              label:   'Uploaded',
            )),
            _VertDiv(),
            Expanded(child: _StatTile(
              icon:    Icons.share_outlined,
              color:   _kGreen,
              value:   '${profile.sharesSent}',
              label:   'Shared',
            )),
            _VertDiv(),
            Expanded(child: _StatTile(
              icon:    Icons.move_to_inbox_outlined,
              color:   _kAmber,
              value:   '${profile.sharesReceived}',
              label:   'Received',
            )),
          ]),
          const SizedBox(height: 14),
          _GlowLine(),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.calendar_today_rounded,
                size: 13, color: _kPurpleL.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text('Joined  ${_fmtDate(profile.createdAt)}',
                style: TextStyle(
                    color: _kWhite.withValues(alpha: 0.4), fontSize: 11)),
            const Spacer(),
            Icon(Icons.access_time_rounded,
                size: 13, color: _kPurpleL.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text('Last login  ${_fmtDate(profile.lastLogin)}',
                style: TextStyle(
                    color: _kWhite.withValues(alpha: 0.4), fontSize: 11)),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Email section
// ══════════════════════════════════════════════════════════════════════════════

class _EmailSection extends StatelessWidget {
  final TextEditingController  emailCtrl;
  final TextEditingController  passCtrl;
  final GlobalKey<FormState>   formKey;
  final bool                   saving;
  final bool                   obscure;
  final VoidCallback           onToggle;
  final VoidCallback           onSave;
  final String                 currentEmail;

  const _EmailSection({
    required this.emailCtrl,
    required this.passCtrl,
    required this.formKey,
    required this.saving,
    required this.obscure,
    required this.onToggle,
    required this.onSave,
    required this.currentEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(children: [
        _GlassField(
          controller: emailCtrl,
          label:      'New email address',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || !v.contains('@')) return 'Enter a valid email';
            if (v.trim().toLowerCase() == currentEmail.toLowerCase()) {
              return 'Same as current email';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _GlassField(
          controller: passCtrl,
          label:      'Current password to confirm',
          prefixIcon: Icons.lock_outline_rounded,
          obscure:    obscure,
          onToggleObscure: onToggle,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Password required' : null,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          label:   'Save Email',
          icon:    Icons.save_rounded,
          loading: saving,
          onTap:   onSave,
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Password section
// ══════════════════════════════════════════════════════════════════════════════

class _PasswordSection extends StatelessWidget {
  final TextEditingController curCtrl, newCtrl, cfmCtrl;
  final GlobalKey<FormState>  formKey;
  final bool saving, curObs, newObs, cfmObs;
  final VoidCallback onCurTog, onNewTog, onCfmTog, onSave;

  const _PasswordSection({
    required this.curCtrl, required this.newCtrl, required this.cfmCtrl,
    required this.formKey, required this.saving,
    required this.curObs,  required this.newObs,  required this.cfmObs,
    required this.onCurTog, required this.onNewTog, required this.onCfmTog,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(children: [
        _GlassField(
          controller: curCtrl,
          label:      'Current password',
          prefixIcon: Icons.lock_outline_rounded,
          obscure:    curObs,
          onToggleObscure: onCurTog,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Enter current password' : null,
        ),
        const SizedBox(height: 12),
        // New password with live strength indicator
        _PasswordWithStrength(controller: newCtrl, obscure: newObs, onToggle: onNewTog),
        const SizedBox(height: 12),
        _GlassField(
          controller: cfmCtrl,
          label:      'Confirm new password',
          prefixIcon: Icons.lock_rounded,
          obscure:    cfmObs,
          onToggleObscure: onCfmTog,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Confirm your password';
            if (v != newCtrl.text)      return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: 18),
        _ActionButton(
          label:   'Update Password',
          icon:    Icons.lock_reset_rounded,
          loading: saving,
          onTap:   onSave,
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Password + strength indicator
// ══════════════════════════════════════════════════════════════════════════════

class _PasswordWithStrength extends StatefulWidget {
  final TextEditingController controller;
  final bool                  obscure;
  final VoidCallback          onToggle;
  const _PasswordWithStrength({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  State<_PasswordWithStrength> createState() => _PasswordWithStrengthState();
}

class _PasswordWithStrengthState extends State<_PasswordWithStrength> {
  String _pass = '';

  int get _strength {
    int s = 0;
    if (_pass.length >= 8)                      s++;
    if (RegExp(r'[A-Z]').hasMatch(_pass))       s++;
    if (RegExp(r'[0-9]').hasMatch(_pass))       s++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(_pass)) s++;
    return s;
  }

  Color get _strengthColor => switch (_strength) {
    0 || 1 => _kRed,
    2      => _kAmber,
    3      => const Color(0xFF60A5FA),
    _      => _kGreen,
  };

  String get _strengthLabel => switch (_strength) {
    0 || 1 => 'Weak',
    2      => 'Fair',
    3      => 'Good',
    _      => 'Strong',
  };

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if (mounted) setState(() => _pass = widget.controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassField(
          controller: widget.controller,
          label:      'New password',
          prefixIcon: Icons.lock_rounded,
          obscure:    widget.obscure,
          onToggleObscure: widget.onToggle,
          validator: (v) {
            if (v == null || v.length < 8) return 'Minimum 8 characters';
            if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add an uppercase letter';
            if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add a number';
            return null;
          },
        ),
        if (_pass.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Row(
                children: List.generate(4, (i) {
                  final filled = i < _strength;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 3,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: filled
                            ? _strengthColor
                            : _kPurple.withValues(alpha: 0.2),
                        boxShadow: filled
                            ? [BoxShadow(
                                color: _strengthColor.withValues(alpha: 0.5),
                                blurRadius: 4)]
                            : [],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            Text(_strengthLabel,
                style: TextStyle(
                    color: _strengthColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _HintChip('8+ chars',    _pass.length >= 8),
            _HintChip('UPPERCASE',   RegExp(r'[A-Z]').hasMatch(_pass)),
            _HintChip('Number',      RegExp(r'[0-9]').hasMatch(_pass)),
            _HintChip('Symbol',      RegExp(r'[!@#\$%^&*]').hasMatch(_pass)),
          ]),
        ],
      ],
    );
  }
}

class _HintChip extends StatelessWidget {
  final String label;
  final bool   met;
  const _HintChip(this.label, this.met);

  @override
  Widget build(BuildContext context) {
    final color = met ? _kGreen : _kWhite.withValues(alpha: 0.3);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: met ? _kGreen.withValues(alpha: 0.1) : Colors.transparent,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(met ? Icons.check_rounded : Icons.remove_rounded,
            size: 9, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Security / encryption section
// ══════════════════════════════════════════════════════════════════════════════

class _SecuritySection extends StatelessWidget {
  final bool         hasPublicKey;
  final bool         regenLoading;
  final VoidCallback onRegen;

  const _SecuritySection({
    required this.hasPublicKey,
    required this.regenLoading,
    required this.onRegen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Key status rows
        _KeyStatusRow(
          label:  'Public Key',
          sub:    hasPublicKey ? 'Stored on server' : 'Not found on server',
          ok:     hasPublicKey,
          icon:   Icons.cloud_done_outlined,
        ),
        const SizedBox(height: 10),
        _KeyStatusRow(
          label: 'Private Key',
          sub:   'Stored locally on this device',
          ok:    true,
          icon:  Icons.phone_android_rounded,
        ),
        const SizedBox(height: 18),

        // Warning
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _kAmber.withValues(alpha: 0.06),
            border: Border.all(color: _kAmber.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: _kAmber, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Regenerating keys may affect access to previously received encrypted shares.',
                  style: TextStyle(
                      color: _kAmber.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _ActionButton(
          label:   'Regenerate Key Pair',
          icon:    Icons.refresh_rounded,
          loading: regenLoading,
          color:   _kAmber,
          onTap:   onRegen,
        ),
      ],
    );
  }
}

class _KeyStatusRow extends StatelessWidget {
  final String  label, sub;
  final bool    ok;
  final IconData icon;
  const _KeyStatusRow({
    required this.label,
    required this.sub,
    required this.ok,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color.withValues(alpha: 0.8), size: 18),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _kWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    color: _kWhite.withValues(alpha: 0.4), fontSize: 11)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(ok ? 'OK' : 'MISSING',
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Danger zone
// ══════════════════════════════════════════════════════════════════════════════

class _DangerZone extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onDelete;
  const _DangerZone({required this.onLogout, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _kWhite.withValues(alpha: 0.02),
            border: Border.all(color: _kRed.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(
                  icon: Icons.warning_amber_rounded,
                  title: 'ACCOUNT ACTIONS',
                  color: _kRed.withValues(alpha: 0.7)),
              const SizedBox(height: 16),
              _ActionButton(
                label:    'Logout',
                icon:     Icons.logout_rounded,
                color:    _kPurpleL,
                outlined: true,
                onTap:    onLogout,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                label:    'Delete Account',
                icon:     Icons.delete_forever_rounded,
                color:    _kRed,
                outlined: true,
                onTap:    onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared primitives
// ══════════════════════════════════════════════════════════════════════════════

/// Generic glass panel wrapping any content
class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _kWhite.withValues(alpha: 0.03),
            border: Border.all(color: _kPurple.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(
              color: _kPurple.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: -4,
            )],
          ),
          padding: const EdgeInsets.all(22),
          child: child,
        ),
      ),
    );
  }
}

/// Glass panel with a header label built in
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Widget   child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(icon: icon, title: title),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Small label used at the top of each section
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Color?   color;
  const _SectionLabel({
    required this.icon,
    required this.title,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kPurpleL.withValues(alpha: 0.6);
    return Row(children: [
      Icon(icon, color: c, size: 14),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6)),
    ]);
  }
}

/// Glass-style text field matching the share_screen pattern
class _GlassField extends StatefulWidget {
  final TextEditingController controller;
  final String                label;
  final IconData              prefixIcon;
  final bool                  obscure;
  final TextInputType?        keyboardType;
  final VoidCallback?         onToggleObscure;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscure         = false,
    this.keyboardType,
    this.onToggleObscure,
    this.validator,
  });

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _focusCtrl;
  late final Animation<double>   _focusAnim;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _focusAnim =
        CurvedAnimation(parent: _focusCtrl, curve: Curves.easeOut);
    _focusNode.addListener(() {
      _focusNode.hasFocus ? _focusCtrl.forward() : _focusCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _focusCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focusAnim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _kPurple.withValues(
                  alpha: 0.18 + _focusAnim.value * 0.52),
              width: 1 + _focusAnim.value * 0.5),
          color: _kPurple.withValues(
              alpha: 0.05 + _focusAnim.value * 0.05),
          boxShadow: [BoxShadow(
            color: _kPurple.withValues(alpha: _focusAnim.value * 0.20),
            blurRadius: 14,
            spreadRadius: -2,
          )],
        ),
        child: child,
      ),
      child: TextFormField(
        controller:   widget.controller,
        focusNode:    _focusNode,
        obscureText:  widget.obscure,
        keyboardType: widget.keyboardType,
        style:        const TextStyle(color: _kWhite, fontSize: 14),
        cursorColor:  _kPurpleL,
        validator:    widget.validator,
        decoration: InputDecoration(
          hintText:  widget.label,
          hintStyle: TextStyle(
              color: _kWhite.withValues(alpha: 0.25), fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(widget.prefixIcon,
                color: _kPurpleL.withValues(alpha: 0.6), size: 18),
          ),
          prefixIconConstraints: const BoxConstraints(),
          suffixIcon: widget.onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _kPurpleL.withValues(alpha: 0.45),
                    size: 18,
                  ),
                  onPressed: widget.onToggleObscure,
                )
              : null,
          border:           InputBorder.none,
          contentPadding:   const EdgeInsets.symmetric(
              horizontal: 16, vertical: 15),
          errorStyle: const TextStyle(
              color: _kRed, fontSize: 10),
        ),
      ),
    );
  }
}

/// Gradient purple action button
class _ActionButton extends StatefulWidget {
  final String    label;
  final IconData  icon;
  final bool      loading;
  final bool      outlined;
  final Color     color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading  = false,
    this.outlined = false,
    this.color    = _kPurple,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isOutlined = widget.outlined;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: isOutlined
                ? null
                : LinearGradient(colors: [
                    _hovered
                        ? widget.color.withValues(alpha: 0.85)
                        : widget.color,
                    _kPurple2,
                  ]),
            color: isOutlined ? Colors.transparent : null,
            border: isOutlined
                ? Border.all(
                    color: widget.color.withValues(
                        alpha: _hovered ? 0.8 : 0.45),
                    width: 1.2)
                : null,
            boxShadow: isOutlined
                ? []
                : [BoxShadow(
                    color: widget.color.withValues(
                        alpha: _hovered ? 0.45 : 0.22),
                    blurRadius: _hovered ? 24 : 14,
                    offset: const Offset(0, 3),
                    spreadRadius: -2,
                  )],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: widget.color, strokeWidth: 2),
                )
              else
                Icon(widget.icon,
                    size: 16,
                    color: isOutlined
                        ? widget.color
                        : _kWhite),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: TextStyle(
                    color: isOutlined ? widget.color : _kWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small colored chip / badge
class _Chip extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;
  const _Chip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   value;
  final String   label;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 6),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: _kWhite.withValues(alpha: 0.4),
              fontSize: 10,
              letterSpacing: 0.5)),
    ]);
  }
}

class _VertDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 44,
    color: _kPurple.withValues(alpha: 0.2),
  );
}

class _GlowLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        Colors.transparent,
        _kPurple.withValues(alpha: 0.35),
        Colors.transparent,
      ]),
    ),
  );
}

class _NeonTextButton extends StatelessWidget {
  final String   label;
  final VoidCallback onTap;
  const _NeonTextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(label,
          style: const TextStyle(
              color: _kPurpleL,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5)),
    );
  }
}
