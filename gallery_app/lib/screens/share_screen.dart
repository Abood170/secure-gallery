import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/crypto_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF060918);
const _kPurple  = Color(0xFF7C3AED);
const _kPurpleL = Color(0xFFA78BFA);
const _kPurple2 = Color(0xFF4C1D95);
const _kGreen   = Color(0xFF10B981);
const _kAmber   = Color(0xFFF59E0B);
const _kWhite   = Colors.white;

// ══════════════════════════════════════════════════════════════════════════════
//  ShareScreen
// ══════════════════════════════════════════════════════════════════════════════

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  // step: 0=idle 1=lookup 2=encrypting 3=sending 4=done
  int _step = 0;

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _checkCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _floatAnim;
  late final Animation<double>   _pulseAnim;
  late final Animation<double>   _checkAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -5.0, end: 5.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _checkAnim =
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _checkCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Share logic ────────────────────────────────────────────────────────────
  Future<void> _share(MediaItem item) async {
    if (!_formKey.currentState!.validate() || _step > 0) return;

    setState(() => _step = 1); // looking up recipient

    try {
      final userData =
          await ShareService.getUserByEmail(_emailCtrl.text.trim());
      final receiverId        = userData['user_id'] as int;
      final receiverPublicKey = userData['public_key'] as String?;

      if (receiverPublicKey == null || receiverPublicKey.isEmpty) {
        throw Exception(
            'The recipient has no public key on file.\n'
            'They must register from the app first.');
      }

      final keyBase64 = await StorageService.getSymmetricKey(item.mediaId);
      if (keyBase64 == null) {
        throw Exception(
            'Symmetric key not found on this device.\n'
            'You can only share images uploaded from this device.');
      }

      setState(() => _step = 2); // encrypting key with RSA

      final encryptedKey =
          await CryptoService.rsaEncryptKey(keyBase64, receiverPublicKey);

      setState(() => _step = 3); // sending to server

      await ShareService.createShare(
        mediaId:      item.mediaId,
        receiverId:   receiverId,
        encryptedKey: encryptedKey,
      );

      setState(() => _step = 4); // done
      _checkCtrl.forward();

      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _step = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final item =
        ModalRoute.of(context)!.settings.arguments as MediaItem;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _ShareBackground()),
          SafeArea(
            child: Column(
              children: [
                _ShareHeader(onBack: () => Navigator.pop(context)),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: AnimatedBuilder(
                          animation: _floatAnim,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: child,
                          ),
                          child: _MainCard(
                            item:      item,
                            step:      _step,
                            formKey:   _formKey,
                            emailCtrl: _emailCtrl,
                            pulseAnim: _pulseAnim,
                            checkAnim: _checkAnim,
                            onShare:   () => _share(item),
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
//  Main card
// ══════════════════════════════════════════════════════════════════════════════

class _MainCard extends StatelessWidget {
  final MediaItem             item;
  final int                   step;
  final GlobalKey<FormState>  formKey;
  final TextEditingController emailCtrl;
  final Animation<double>     pulseAnim;
  final Animation<double>     checkAnim;
  final VoidCallback          onShare;

  const _MainCard({
    required this.item,
    required this.step,
    required this.formKey,
    required this.emailCtrl,
    required this.pulseAnim,
    required this.checkAnim,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: _kWhite.withValues(alpha: 0.03),
            border: Border.all(
                color: _kPurple.withValues(alpha: 0.22), width: 1),
            boxShadow: [
              BoxShadow(
                color: _kPurple.withValues(alpha: 0.10),
                blurRadius: 50,
                spreadRadius: -4,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: step == 0
                ? _IdleContent(
                    key:       const ValueKey('idle'),
                    item:      item,
                    formKey:   formKey,
                    emailCtrl: emailCtrl,
                    pulseAnim: pulseAnim,
                    onShare:   onShare,
                  )
                : _ShareProgress(
                    key:       const ValueKey('progress'),
                    step:      step,
                    pulseAnim: pulseAnim,
                    checkAnim: checkAnim,
                    email:     emailCtrl.text.trim(),
                  ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Idle content
// ══════════════════════════════════════════════════════════════════════════════

class _IdleContent extends StatelessWidget {
  final MediaItem             item;
  final GlobalKey<FormState>  formKey;
  final TextEditingController emailCtrl;
  final Animation<double>     pulseAnim;
  final VoidCallback          onShare;

  const _IdleContent({
    super.key,
    required this.item,
    required this.formKey,
    required this.emailCtrl,
    required this.pulseAnim,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── E2E label ──────────────────────────────────────────────────────
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _kPurple.withValues(alpha: 0.1),
                border: Border.all(
                    color: _kPurple.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, color: _kPurpleL, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'End-to-end encrypted sharing',
                    style: TextStyle(
                      color: _kPurpleL,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── File info ──────────────────────────────────────────────────────
          _FileInfoCard(item: item),
          const SizedBox(height: 22),

          _GlowDivider(),
          const SizedBox(height: 22),

          // ── Recipient input ────────────────────────────────────────────────
          Text(
            'SHARE WITH',
            style: TextStyle(
              color: _kPurpleL.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          _GlassEmailField(controller: emailCtrl),
          const SizedBox(height: 22),

          _GlowDivider(),
          const SizedBox(height: 22),

          // ── How it works ───────────────────────────────────────────────────
          _HowItWorksCard(),
          const SizedBox(height: 28),

          // ── Send button ────────────────────────────────────────────────────
          _SendButton(pulseAnim: pulseAnim, onTap: onShare),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  File info card
// ══════════════════════════════════════════════════════════════════════════════

class _FileInfoCard extends StatelessWidget {
  final MediaItem item;
  const _FileInfoCard({required this.item});

  Color get _algoColor =>
      item.algo == 'AES-GCM' ? _kGreen : _kAmber;
  String get _algoLabel =>
      item.algo == 'AES-GCM' ? 'AES-256' : 'ChaCha20';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _kPurple.withValues(alpha: 0.07),
        border: Border.all(color: _kPurple.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          // Lock icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPurple.withValues(alpha: 0.12),
              border: Border.all(
                  color: _kPurple.withValues(alpha: 0.3), width: 1),
            ),
            child:
                const Icon(Icons.lock_rounded, color: _kPurpleL, size: 18),
          ),
          const SizedBox(width: 14),

          // Filename + algo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.filename,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Encrypted · ',
                      style: TextStyle(
                        color: _kWhite.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: _algoColor.withValues(alpha: 0.1),
                        border: Border.all(
                            color: _algoColor.withValues(alpha: 0.4),
                            width: 0.8),
                      ),
                      child: Text(
                        _algoLabel,
                        style: TextStyle(
                          color: _algoColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
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
//  Glass email input
// ══════════════════════════════════════════════════════════════════════════════

class _GlassEmailField extends StatefulWidget {
  final TextEditingController controller;
  const _GlassEmailField({required this.controller});

  @override
  State<_GlassEmailField> createState() => _GlassEmailFieldState();
}

class _GlassEmailFieldState extends State<_GlassEmailField>
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
      _focusNode.hasFocus
          ? _focusCtrl.forward()
          : _focusCtrl.reverse();
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
            width: 1 + _focusAnim.value * 0.5,
          ),
          color: _kPurple.withValues(
              alpha: 0.05 + _focusAnim.value * 0.05),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withValues(
                  alpha: _focusAnim.value * 0.22),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: child,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: _kWhite, fontSize: 14),
        cursorColor: _kPurpleL,
        decoration: InputDecoration(
          hintText: 'Enter recipient email',
          hintStyle: TextStyle(
              color: _kWhite.withValues(alpha: 0.25), fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.person_search_outlined,
                color: _kPurpleL.withValues(alpha: 0.6), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
          helperText:
              '  Must be a registered Secure Gallery user',
          helperStyle: TextStyle(
              color: _kWhite.withValues(alpha: 0.22), fontSize: 10),
        ),
        validator: (v) =>
            (v == null || !v.contains('@'))
                ? 'Enter a valid email'
                : null,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  How it works info card
// ══════════════════════════════════════════════════════════════════════════════

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _kPurple.withValues(alpha: 0.05),
        border: Border.all(color: _kPurple.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: _kPurpleL, size: 14),
              const SizedBox(width: 8),
              Text(
                'HOW SAFE SHARE WORKS',
                style: TextStyle(
                  color: _kPurpleL.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _HowStep(
            icon:  Icons.lock_rounded,
            color: _kPurpleL,
            label: 'Key encrypted with recipient\'s RSA public key',
          ),
          const SizedBox(height: 10),
          const _HowStep(
            icon:  Icons.vpn_key_rounded,
            color: _kAmber,
            label: 'Only recipient\'s private key can unlock it',
          ),
          const SizedBox(height: 10),
          const _HowStep(
            icon:  Icons.shield_outlined,
            color: _kGreen,
            label: 'Server stores ciphertext only — never the key',
          ),
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  const _HowStep(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
            border:
                Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Icon(icon, color: color, size: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: _kWhite.withValues(alpha: 0.5),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Send button
// ══════════════════════════════════════════════════════════════════════════════

class _SendButton extends StatefulWidget {
  final Animation<double> pulseAnim;
  final VoidCallback      onTap;
  const _SendButton({required this.pulseAnim, required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double>   _pressAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _pressAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:    (_) => _pressCtrl.forward(),
        onTapUp:      (_) { _pressCtrl.reverse(); widget.onTap(); },
        onTapCancel:  () => _pressCtrl.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.pulseAnim, _pressCtrl]),
          builder: (_, child) => Transform.scale(
            scale: _pressAnim.value * (_hovered ? 1.02 : 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    _hovered
                        ? const Color(0xFF9333EA)
                        : _kPurple,
                    _hovered
                        ? const Color(0xFF6D28D9)
                        : _kPurple2,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(
                      alpha: _hovered
                          ? 0.65
                          : widget.pulseAnim.value * 0.45,
                    ),
                    blurRadius: _hovered ? 32 : 20,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: child,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send_rounded, color: _kWhite, size: 18),
              SizedBox(width: 10),
              Text(
                'Send Securely',
                style: TextStyle(
                  color: _kWhite,
                  fontSize: 14,
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

// ══════════════════════════════════════════════════════════════════════════════
//  Share progress (steps 1–4)
// ══════════════════════════════════════════════════════════════════════════════

class _ShareProgress extends StatelessWidget {
  final int               step;
  final Animation<double> pulseAnim;
  final Animation<double> checkAnim;
  final String            email;

  const _ShareProgress({
    super.key,
    required this.step,
    required this.pulseAnim,
    required this.checkAnim,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // Central animated icon
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: step == 4
              ? _DoneOrb(key: const ValueKey(4), checkAnim: checkAnim)
              : _ActiveOrb(
                  key:       ValueKey(step),
                  step:      step,
                  pulseAnim: pulseAnim,
                ),
        ),

        const SizedBox(height: 20),

        // Label + sub-label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _StepLabel(
              key: ValueKey(step), step: step, email: email),
        ),

        const SizedBox(height: 28),

        // Step pill track
        _StepTrack(step: step),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Central orb (active) ──────────────────────────────────────────────────────

class _ActiveOrb extends StatelessWidget {
  final int               step;
  final Animation<double> pulseAnim;
  const _ActiveOrb({super.key, required this.step, required this.pulseAnim});

  IconData get _icon => switch (step) {
    1 => Icons.manage_search_rounded,
    2 => Icons.vpn_key_rounded,
    _ => Icons.cloud_upload_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) => Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kPurple.withValues(alpha: 0.1),
          border: Border.all(
            color: _kPurple.withValues(
                alpha: 0.2 + pulseAnim.value * 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withValues(
                  alpha: pulseAnim.value * 0.4),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: step == 3
          ? const Padding(
              padding: EdgeInsets.all(22),
              child: CircularProgressIndicator(
                  color: _kPurpleL, strokeWidth: 2.5),
            )
          : Icon(_icon, color: _kPurpleL, size: 36),
    );
  }
}

// ── Central orb (done) ────────────────────────────────────────────────────────

class _DoneOrb extends StatelessWidget {
  final Animation<double> checkAnim;
  const _DoneOrb({super.key, required this.checkAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: checkAnim,
      builder: (_, child) => Transform.scale(
        scale: checkAnim.value,
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kGreen.withValues(alpha: 0.1),
            border: Border.all(
                color: _kGreen.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _kGreen.withValues(alpha: 0.35),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded,
              color: _kGreen, size: 40),
        ),
      ),
    );
  }
}

// ── Step label ────────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  final int    step;
  final String email;
  const _StepLabel({super.key, required this.step, required this.email});

  (String, String) get _texts => switch (step) {
    1 => ('LOOKING UP RECIPIENT', 'Fetching public key for $email…'),
    2 => ('ENCRYPTING KEY', 'RSA-OAEP encrypting symmetric key…'),
    3 => ('SENDING', 'Transmitting encrypted share to server…'),
    _ => ('SHARE SENT!', 'Delivered securely to $email'),
  };

  @override
  Widget build(BuildContext context) {
    final (title, sub) = _texts;
    final color = step == 4 ? _kGreen : _kPurpleL;

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kWhite.withValues(alpha: 0.38),
            fontSize: 11,
          ),
        ),
        if (step == 3) ...[
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: _kPurple.withValues(alpha: 0.15),
              color: _kPurpleL,
              minHeight: 4,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Step pill track ───────────────────────────────────────────────────────────

class _StepTrack extends StatelessWidget {
  final int step;
  const _StepTrack({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final done    = i + 1 < step;
        final current = i + 1 == step;
        final active  = done || current;
        final color   = (i + 1 == 4 && step == 4) ? _kGreen : _kPurple;

        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:  current ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: active
                    ? color
                    : _kPurple.withValues(alpha: 0.18),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ]
                    : [],
              ),
            ),
            if (i < 3) const SizedBox(width: 4),
          ],
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared widgets
// ══════════════════════════════════════════════════════════════════════════════

class _GlowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _kPurple.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Header
// ══════════════════════════════════════════════════════════════════════════════

class _ShareHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _ShareHeader({required this.onBack});

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
                  color: _kPurple.withValues(alpha: 0.2), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Back
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
                    Text(
                      'Safe Share',
                      style: TextStyle(
                        color: _kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'RSA-OAEP key exchange',
                      style: TextStyle(
                        color: _kPurpleL,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // RSA badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _kAmber.withValues(alpha: 0.08),
                  border: Border.all(
                      color: _kAmber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.vpn_key_rounded,
                        color: _kAmber.withValues(alpha: 0.85), size: 12),
                    const SizedBox(width: 5),
                    Text(
                      'RSA-OAEP',
                      style: TextStyle(
                        color: _kAmber.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
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
//  Background
// ══════════════════════════════════════════════════════════════════════════════

class _ShareBackground extends StatelessWidget {
  const _ShareBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.4, -0.4),
              radius: 1.3,
              colors: [Color(0xFF1A0A3E), Color(0xFF060918)],
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -80,
          child: _Orb(
              size: 320,
              color: _kPurple2.withValues(alpha: 0.25)),
        ),
        Positioned(
          bottom: -70,
          left: -50,
          child: _Orb(
              size: 260,
              color: _kPurple.withValues(alpha: 0.15)),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _EncryptionPatternPainter()),
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

// Hex dot grid — same visual language as dashboard
class _EncryptionPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08A78BFA)
      ..strokeWidth = 0.5;

    const col = 42.0;
    const row = 42.0;

    for (double x = 0; x < size.width; x += col) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += row) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Dot accents at intersections
    final dotPaint = Paint()
      ..color = const Color(0x12A78BFA)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += col * 2) {
      for (double y = 0; y < size.height; y += row * 2) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_EncryptionPatternPainter _) => false;
}
