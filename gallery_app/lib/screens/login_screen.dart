import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool _obscure    = true;

  late final AnimationController _floatCtrl;
  late final Animation<double>   _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthProvider>().login(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (ok && mounted) {
      final dest = context.read<AuthProvider>().isAdmin ? '/admin' : '/gallery';
      Navigator.pushReplacementNamed(context, dest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Dark gradient background ────────────────────────────────────
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

          // ── Subtle grid lines ───────────────────────────────────────────
          const Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // ── Glow orbs ───────────────────────────────────────────────────
          const Positioned(
            top: -100, right: -80,
            child: _GlowOrb(size: 380, color: Color(0xFF7C3AED), opacity: 0.25),
          ),
          const Positioned(
            bottom: -120, left: -100,
            child: _GlowOrb(size: 420, color: Color(0xFF4C1D95), opacity: 0.3),
          ),
          Positioned(
            top: size.height * 0.35, left: -60,
            child: const _GlowOrb(size: 220, color: Color(0xFF6D28D9), opacity: 0.12),
          ),
          Positioned(
            bottom: size.height * 0.2, right: -40,
            child: const _GlowOrb(size: 180, color: Color(0xFF8B5CF6), opacity: 0.1),
          ),

          // ── Floating glass card ──────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
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
        ],
      ),
    );
  }

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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Lock icon ─────────────────────────────────────────────
                Center(
                  child: Container(
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
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.65),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_rounded, size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 22),

                // ── Title ─────────────────────────────────────────────────
                const Text(
                  'Secure Gallery',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'End-to-end encrypted image storage',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Email ─────────────────────────────────────────────────
                _GlassInput(
                  controller: _emailCtrl,
                  hint: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 14),

                // ── Password ──────────────────────────────────────────────
                _GlassInput(
                  controller: _passCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                ),

                // ── Error banner ──────────────────────────────────────────
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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

                // ── Sign In button ────────────────────────────────────────
                _GlowButton(
                  onPressed: auth.loading ? null : _submit,
                  loading:   auth.loading,
                  label:     'Sign In',
                ),
                const SizedBox(height: 20),

                // ── Divider ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Register link ─────────────────────────────────────────
                _OutlineButton(
                  onTap: () => Navigator.pushNamed(context, '/register'),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.45)),
                      children: const [
                        TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Register',
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

                // ── Security notice ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Color(0xFFA78BFA), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your images are encrypted locally before upload',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
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
    );
  }
}

// ── Glass text input ───────────────────────────────────────────────────────────

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
          color: Colors.white.withValues(alpha: _focused ? 0.08 : 0.05),
          border: Border.all(
            color: _focused
                ? const Color(0xFF7C3AED).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.11),
            width: _focused ? 1.5 : 1.0,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
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
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.28), fontSize: 15),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            errorStyle: const TextStyle(color: Color(0xFFFC8181), fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// ── Gradient glow button ───────────────────────────────────────────────────────

class _GlowButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  const _GlowButton({
    required this.onPressed,
    required this.loading,
    required this.label,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _hovered = false;

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
        onTap: widget.onPressed,
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
                      color: const Color(0xFF7C3AED)
                          .withValues(alpha: _hovered ? 0.75 : 0.45),
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
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Outline button (register) ──────────────────────────────────────────────────

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
            color: Colors.white.withValues(alpha: _hovered ? 0.05 : 0.02),
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

// ── Radial glow orb ────────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
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
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

// ── Subtle dot-grid background ─────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 36.0;
    final linePaint = Paint()
      ..color = const Color(0x05FFFFFF) // white @ 2% opacity (withValues equivalent)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dotPaint = Paint()
      ..color = const Color(0x0BFFFFFF) // white @ ~4.5% opacity
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
