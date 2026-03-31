import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  RegisterScreen
// ══════════════════════════════════════════════════════════════════════════════

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  // ── Form ───────────────────────────────────────────────────────────────────
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  // step: 0=idle  1=generating-keys  2=securing  3=completing  4=done
  int _step = 0;

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _floatCtrl;
  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _checkCtrl;
  late final Animation<double>   _floatAnim;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _pulseAnim;
  late final Animation<double>   _checkAnim;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _checkAnim =
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _floatCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_step > 0) return;
    if (!_formKey.currentState!.validate()) return;

    // Kick off real registration concurrently with the animation
    final registerFuture = context.read<AuthProvider>().register(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    // ── Step 1: Generating keys ──────────────────────────────────────────────
    setState(() => _step = 1);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // ── Step 2: Securing account ─────────────────────────────────────────────
    setState(() => _step = 2);
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;

    // ── Step 3: Completing setup — await the real result ─────────────────────
    setState(() => _step = 3);
    final ok = await registerFuture;
    if (!mounted) return;

    if (ok) {
      // ── Step 4: Done ───────────────────────────────────────────────────────
      setState(() => _step = 4);
      _checkCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account created! Please sign in.'),
            backgroundColor: const Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      // Reset to form — error shown by auth provider
      setState(() => _step = 0);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ───────────────────────────────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
                colors: [
                  Color(0xFF0B0120),
                  Color(0xFF07091F),
                  Color(0xFF040610),
                  Color(0xFF120630),
                ],
                stops: [0.0, 0.3, 0.65, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // ── Glow orbs ────────────────────────────────────────────────────
          const Positioned(
            top: -100, left: -80,
            child: _GlowOrb(
                size: 380, color: Color(0xFF7C3AED), opacity: 0.22),
          ),
          const Positioned(
            bottom: -120, right: -100,
            child: _GlowOrb(
                size: 420, color: Color(0xFF4C1D95), opacity: 0.28),
          ),
          Positioned(
            top: size.height * 0.4, right: -60,
            child: const _GlowOrb(
                size: 220, color: Color(0xFF6D28D9), opacity: 0.1),
          ),
          Positioned(
            bottom: size.height * 0.25, left: -40,
            child: const _GlowOrb(
                size: 180, color: Color(0xFF8B5CF6), opacity: 0.08),
          ),

          // ── Floating glass card ──────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 32),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _floatAnim.value),
                      child: child,
                    ),
                    child: _buildCard(auth),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card shell (same geometry as login) ───────────────────────────────────
  Widget _buildCard(AuthProvider auth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.13),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                blurRadius: 60,
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _step == 0
                ? _buildForm(auth)
                : _buildProgress(),
          ),
        ),
      ),
    );
  }

  // ── Form content ──────────────────────────────────────────────────────────
  Widget _buildForm(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon ──────────────────────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [Color(0xFF9F67FF), Color(0xFF5B21B6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED)
                          .withValues(alpha: 0.55 + _pulseAnim.value * 0.15),
                      blurRadius: 24 + _pulseAnim.value * 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF7C3AED)
                          .withValues(alpha: 0.18),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: child,
              ),
              child: const Icon(Icons.person_add_rounded,
                  size: 34, color: Colors.white),
            ),
          ),
          const SizedBox(height: 22),

          // ── Title ─────────────────────────────────────────────────────────
          const Text(
            'Create Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Secure your encrypted gallery',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.48),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 30),

          // ── Email ─────────────────────────────────────────────────────────
          _GlassInput(
            controller: _emailCtrl,
            hint: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
          ),
          const SizedBox(height: 12),

          // ── Password ──────────────────────────────────────────────────────
          _GlassInput(
            controller: _passCtrl,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            onToggleObscure: () =>
                setState(() => _obscurePass = !_obscurePass),
            validator: (v) =>
                (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
          ),
          const SizedBox(height: 12),

          // ── Confirm password ──────────────────────────────────────────────
          _GlassInput(
            controller: _confirmCtrl,
            hint: 'Confirm password',
            icon: Icons.lock_rounded,
            obscure: _obscureConfirm,
            onToggleObscure: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (v) =>
                v != _passCtrl.text ? 'Passwords do not match' : null,
          ),

          // ── Error banner ──────────────────────────────────────────────────
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFFC8181), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.error!,
                      style: const TextStyle(
                          color: Color(0xFFFC8181), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),

          // ── Create account button ─────────────────────────────────────────
          _GlowButton(
            onPressed: auth.loading ? null : _submit,
            loading:   auth.loading,
            label:     'Create Account',
            icon:      Icons.person_add_rounded,
          ),
          const SizedBox(height: 20),

          // ── Divider ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Divider(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 12),
                ),
              ),
              Expanded(
                child: Divider(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Sign in link ──────────────────────────────────────────────────
          _OutlineButton(
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.42)),
                children: const [
                  TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Sign In',
                    style: TextStyle(
                      color: Color(0xFFA78BFA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Key gen security notice ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
              border: Border.all(
                  color: const Color(0xFF7C3AED)
                      .withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key_rounded,
                    color: Color(0xFFA78BFA), size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your encryption keys are generated securely on your device',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 12,
                      height: 1.4,
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

  // ── Progress content ──────────────────────────────────────────────────────
  Widget _buildProgress() {
    return _KeyGenProgress(
      key:       ValueKey(_step),
      step:      _step,
      pulseAnim: _pulseAnim,
      checkAnim: _checkAnim,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Key generation progress panel
// ══════════════════════════════════════════════════════════════════════════════

class _KeyGenProgress extends StatelessWidget {
  final int               step;
  final Animation<double> pulseAnim;
  final Animation<double> checkAnim;

  const _KeyGenProgress({
    super.key,
    required this.step,
    required this.pulseAnim,
    required this.checkAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),

        // ── Central orb ───────────────────────────────────────────────────
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
        const SizedBox(height: 24),

        // ── Label ─────────────────────────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _StepLabel(key: ValueKey(step), step: step),
        ),
        const SizedBox(height: 32),

        // ── Step list ─────────────────────────────────────────────────────
        _StepList(step: step),
        const SizedBox(height: 28),

        // ── Pill track ────────────────────────────────────────────────────
        _PillTrack(step: step),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Active animated orb ───────────────────────────────────────────────────────

class _ActiveOrb extends StatelessWidget {
  final int               step;
  final Animation<double> pulseAnim;
  const _ActiveOrb(
      {super.key, required this.step, required this.pulseAnim});

  IconData get _icon => switch (step) {
    1 => Icons.vpn_key_rounded,
    2 => Icons.shield_rounded,
    _ => Icons.cloud_done_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) => Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [Color(0xFF9F67FF), Color(0xFF5B21B6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED)
                  .withValues(alpha: 0.3 + pulseAnim.value * 0.4),
              blurRadius: 20 + pulseAnim.value * 20,
              spreadRadius: pulseAnim.value * 4,
            ),
          ],
        ),
        child: child,
      ),
      child: step == 3
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            )
          : Icon(_icon, color: Colors.white, size: 38),
    );
  }
}

// ── Done orb ─────────────────────────────────────────────────────────────────

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
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded,
              color: Color(0xFF10B981), size: 44),
        ),
      ),
    );
  }
}

// ── Step headline + sub-text ──────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  final int step;
  const _StepLabel({super.key, required this.step});

  (String, String) get _copy => switch (step) {
    1 => ('GENERATING KEYS', 'Creating your RSA-2048 key pair locally…'),
    2 => ('SECURING ACCOUNT', 'Encrypting credentials and public key…'),
    3 => ('COMPLETING SETUP', 'Registering your account on the server…'),
    _ => ('ACCOUNT READY', 'You\'re all set — signing you in now'),
  };

  @override
  Widget build(BuildContext context) {
    final (title, sub) = _copy;
    final color =
        step == 4 ? const Color(0xFF10B981) : const Color(0xFFA78BFA);

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.36),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ── Step list (3 rows with icon + label) ─────────────────────────────────────

class _StepList extends StatelessWidget {
  final int step;
  const _StepList({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.vpn_key_rounded,     'Generating encryption keys'),
      (Icons.shield_rounded,      'Securing account'),
      (Icons.cloud_done_outlined, 'Completing setup'),
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final done    = i + 1 < step;
        final current = i + 1 == step;
        final active  = done || current || step == 4;
        final (icon, label) = steps[i];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: (current && step < 4)
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: (current && step < 4)
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.45)
                    : (done || step == 4)
                        ? const Color(0xFF10B981).withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                // State icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: (done || step == 4)
                      ? const Icon(Icons.check_circle_rounded,
                          key: ValueKey('done'),
                          color: Color(0xFF10B981),
                          size: 18)
                      : current
                          ? Icon(Icons.radio_button_checked,
                              key: const ValueKey('active'),
                              color: const Color(0xFFA78BFA)
                                  .withValues(alpha: 0.9),
                              size: 18)
                          : Icon(Icons.radio_button_unchecked,
                              key: const ValueKey('idle'),
                              color: Colors.white.withValues(alpha: 0.18),
                              size: 18),
                ),
                const SizedBox(width: 12),
                Icon(icon,
                    size: 15,
                    color: active
                        ? (done || step == 4)
                            ? const Color(0xFF10B981)
                            : const Color(0xFFA78BFA)
                        : Colors.white.withValues(alpha: 0.2)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.25),
                    fontSize: 13,
                    fontWeight: current
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Pill progress track ───────────────────────────────────────────────────────

class _PillTrack extends StatelessWidget {
  final int step;
  const _PillTrack({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final done    = i + 1 < step;
        final current = i + 1 == step;
        final active  = done || current;
        final color   = step == 4
            ? const Color(0xFF10B981)
            : const Color(0xFF7C3AED);

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
                    : Colors.white.withValues(alpha: 0.12),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.55),
                          blurRadius: 8,
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
//  Shared UI atoms  (mirrors login_screen.dart private classes)
// ══════════════════════════════════════════════════════════════════════════════

// ── Glass text input ──────────────────────────────────────────────────────────

class _GlassInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;

  const _GlassInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
  });

  @override
  State<_GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<_GlassInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white
              .withValues(alpha: _focused ? 0.08 : 0.05),
          border: Border.all(
            color: _focused
                ? const Color(0xFF7C3AED).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.11),
            width: _focused ? 1.5 : 1.0,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED)
                        .withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: -3,
                  ),
                ]
              : [],
        ),
        child: TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscure,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: const Color(0xFFA78BFA),
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.28),
                fontSize: 15),
            prefixIcon: Icon(widget.icon,
                color: Colors.white.withValues(alpha: 0.4), size: 20),
            suffixIcon: widget.onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      widget.obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white.withValues(alpha: 0.35),
                      size: 20,
                    ),
                    onPressed: widget.onToggleObscure,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            errorStyle: const TextStyle(
                color: Color(0xFFFC8181), fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// ── Gradient glow button ──────────────────────────────────────────────────────

class _GlowButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;
  final IconData icon;

  const _GlowButton({
    required this.onPressed,
    required this.loading,
    required this.label,
    required this.icon,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double>   _pressAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
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
    final disabled = widget.onPressed == null;
    return MouseRegion(
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:   (_) => _pressCtrl.forward(),
        onTapUp:     (_) { _pressCtrl.reverse(); widget.onPressed?.call(); },
        onTapCancel: () => _pressCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _pressCtrl,
          builder: (_, child) =>
              Transform.scale(scale: _pressAnim.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: disabled
                    ? const [Color(0xFF4C1D95), Color(0xFF3B1472)]
                    : _hovered
                        ? const [
                            Color(0xFFAB76FF),
                            Color(0xFF8B5CF6),
                            Color(0xFF5B21B6),
                          ]
                        : const [
                            Color(0xFF9F67FF),
                            Color(0xFF7C3AED),
                            Color(0xFF5B21B6),
                          ],
              ),
              boxShadow: disabled
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(
                            alpha: _hovered ? 0.75 : 0.45),
                        blurRadius: _hovered ? 32 : 18,
                        spreadRadius: _hovered ? 2 : -2,
                      ),
                    ],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
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

// ── Outline link button ───────────────────────────────────────────────────────

class _OutlineButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _OutlineButton({required this.onTap, required this.child});

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white
                .withValues(alpha: _hovered ? 0.05 : 0.02),
            border: Border.all(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.09),
            ),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Glow orb ──────────────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color  color;
  final double opacity;
  const _GlowOrb(
      {required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dot-grid background ───────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 36.0;
    final line = Paint()
      ..color = const Color(0x05FFFFFF)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    final dot = Paint()
      ..color = const Color(0x0BFFFFFF)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
