import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/gallery_provider.dart';
import '../services/crypto_service.dart';
import '../services/media_service.dart';
import '../services/storage_service.dart';

// ── Design tokens (mirrors gallery_screen.dart) ────────────────────────────
const _kBg      = Color(0xFF060918);
const _kPurple  = Color(0xFF7C3AED);
const _kPurpleL = Color(0xFFA78BFA);
const _kPurple2 = Color(0xFF4C1D95);
const _kGreen   = Color(0xFF10B981);
const _kAmber   = Color(0xFFF59E0B);
const _kWhite   = Colors.white;

// ══════════════════════════════════════════════════════════════════════════════
//  UploadScreen
// ══════════════════════════════════════════════════════════════════════════════

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  // ── Data ───────────────────────────────────────────────────────────────────
  List<XFile>    _selectedFiles = [];
  List<Uint8List> _thumbnails   = [];
  String      _selectedAlgo  = 'AES-GCM';
  int         _step          = 0; // 0=idle 1=encrypting 2=uploading 3=done
  int         _currentUpload = 0;

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
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _checkAnim =
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  // ── Pick images (multi-select) ─────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (_step > 0) return;
    final files = await ImagePicker().pickMultiImage();
    if (files.isNotEmpty) {
      final thumbs = await Future.wait(files.map((f) => f.readAsBytes()));
      setState(() {
        _selectedFiles = files;
        _thumbnails    = thumbs;
      });
    }
  }

  // ── Remove one file from selection ────────────────────────────────────────
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _thumbnails.removeAt(index);
    });
  }

  // ── Upload all selected files ──────────────────────────────────────────────
  Future<void> _upload() async {
    if (_selectedFiles.isEmpty || _step > 0) return;

    try {
      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        setState(() { _step = 1; _currentUpload = i + 1; });

        final bytes    = await file.readAsBytes();
        final filename = file.name;

        final result = await CryptoService.encrypt(
            Uint8List.fromList(bytes), _selectedAlgo);

        setState(() => _step = 2);
        final mediaId = await MediaService.uploadMedia(
          ciphertext: result.ciphertext,
          filename:   filename,
          algo:       _selectedAlgo,
          iv:         result.iv,
        );

        await StorageService.saveSymmetricKey(mediaId, result.keyBase64);

        if (mounted) {
          context.read<GalleryProvider>().prependMedia(MediaItem(
            mediaId:  mediaId,
            filename: filename,
            algo:     _selectedAlgo,
            iv:       result.iv,
          ));
        }
      }

      setState(() => _step = 3);
      _checkCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _step = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _UploadBackground()),
          SafeArea(
            child: Column(
              children: [
                _UploadHeader(onBack: () => Navigator.pop(context)),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      child: AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: child,
                        ),
                        child: _GlassCard(
                          step:          _step,
                          files:         _selectedFiles,
                          thumbnails:    _thumbnails,
                          currentUpload: _currentUpload,
                          selectedAlgo:  _selectedAlgo,
                          pulseAnim:     _pulseAnim,
                          checkAnim:     _checkAnim,
                          onPickImage:   _pickImage,
                          onRemoveFile:  _removeFile,
                          onSelectAlgo:  (v) =>
                              setState(() => _selectedAlgo = v),
                          onUpload:      _upload,
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
//  Glass card — main container
// ══════════════════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final int                  step;
  final List<XFile>          files;
  final List<Uint8List>      thumbnails;
  final int                  currentUpload;
  final String               selectedAlgo;
  final Animation<double>    pulseAnim;
  final Animation<double>    checkAnim;
  final VoidCallback         onPickImage;
  final void Function(int)   onRemoveFile;
  final ValueChanged<String> onSelectAlgo;
  final VoidCallback         onUpload;

  const _GlassCard({
    required this.step,
    required this.files,
    required this.thumbnails,
    required this.currentUpload,
    required this.selectedAlgo,
    required this.pulseAnim,
    required this.checkAnim,
    required this.onPickImage,
    required this.onRemoveFile,
    required this.onSelectAlgo,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: _kWhite.withValues(alpha: 0.03),
            border: Border.all(
                color: _kPurple.withValues(alpha: 0.22), width: 1),
            boxShadow: [
              BoxShadow(
                color: _kPurple.withValues(alpha: 0.12),
                blurRadius: 50,
                spreadRadius: -4,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Security notice
              _SecurityBadge(),
              const SizedBox(height: 22),

              // Upload zone
              _UploadZone(
                files:        files,
                thumbnails:   thumbnails,
                pulseAnim:    pulseAnim,
                enabled:      step == 0,
                onTap:        onPickImage,
                onRemoveFile: onRemoveFile,
              ),
              const SizedBox(height: 24),

              // Algo + button OR progress
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: step == 0
                    ? _IdleSection(
                        key:           const ValueKey('idle'),
                        selectedAlgo:  selectedAlgo,
                        hasFile:       files.isNotEmpty,
                        fileCount:     files.length,
                        pulseAnim:     pulseAnim,
                        onSelectAlgo:  onSelectAlgo,
                        onUpload:      onUpload,
                      )
                    : _ProgressSteps(
                        key:           const ValueKey('progress'),
                        step:          step,
                        currentUpload: currentUpload,
                        totalUploads:  files.length,
                        pulseAnim:     pulseAnim,
                        checkAnim:     checkAnim,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Idle section (algo selector + button) ─────────────────────────────────────

class _IdleSection extends StatelessWidget {
  final String  selectedAlgo;
  final bool    hasFile;
  final int     fileCount;
  final Animation<double> pulseAnim;
  final ValueChanged<String> onSelectAlgo;
  final VoidCallback onUpload;

  const _IdleSection({
    super.key,
    required this.selectedAlgo,
    required this.hasFile,
    required this.fileCount,
    required this.pulseAnim,
    required this.onSelectAlgo,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fileCount > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _kPurple.withValues(alpha: 0.1),
                border: Border.all(color: _kPurple.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_rounded, color: _kPurpleL, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$fileCount photos selected',
                    style: const TextStyle(color: _kPurpleL, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        _AlgoSelector(
          selected:  selectedAlgo,
          onSelect:  onSelectAlgo,
        ),
        const SizedBox(height: 28),
        _UploadButton(
          enabled:   hasFile,
          fileCount: fileCount,
          pulseAnim: pulseAnim,
          onTap:     onUpload,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Background
// ══════════════════════════════════════════════════════════════════════════════

class _UploadBackground extends StatelessWidget {
  const _UploadBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.3, -0.5),
              radius: 1.4,
              colors: [Color(0xFF1A0A3E), Color(0xFF060918)],
            ),
          ),
        ),
        Positioned(
          top: -80, left: -60,
          child: _GlowOrb(
              size: 300,
              color: _kPurple2.withValues(alpha: 0.28)),
        ),
        Positioned(
          bottom: -60, right: -40,
          child: _GlowOrb(
              size: 240,
              color: _kPurple.withValues(alpha: 0.18)),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _GridPainter()),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color  color;
  const _GlowOrb({required this.size, required this.color});

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
      ..color = const Color(0x09A78BFA)
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
//  Header
// ══════════════════════════════════════════════════════════════════════════════

class _UploadHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _UploadHeader({required this.onBack});

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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Image',
                      style: TextStyle(
                        color: _kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'End-to-end encrypted',
                      style: TextStyle(
                        color: _kPurpleL,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _kPurple.withValues(alpha: 0.15),
                  border: Border.all(
                      color: _kPurple.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, color: _kPurpleL, size: 12),
                    SizedBox(width: 5),
                    Text(
                      'E2E',
                      style: TextStyle(
                        color: _kPurpleL,
                        fontSize: 10,
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
//  Security badge
// ══════════════════════════════════════════════════════════════════════════════

class _SecurityBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _kGreen.withValues(alpha: 0.06),
        border:
            Border.all(color: _kGreen.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: _kGreen, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your image is encrypted locally before upload',
              style: TextStyle(
                color: _kGreen.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Upload zone
// ══════════════════════════════════════════════════════════════════════════════

class _UploadZone extends StatefulWidget {
  final List<XFile>        files;
  final List<Uint8List>    thumbnails;
  final Animation<double>  pulseAnim;
  final bool               enabled;
  final VoidCallback        onTap;
  final void Function(int) onRemoveFile;

  const _UploadZone({
    required this.files,
    required this.thumbnails,
    required this.pulseAnim,
    required this.enabled,
    required this.onTap,
    required this.onRemoveFile,
  });

  @override
  State<_UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends State<_UploadZone> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.thumbnails.isNotEmpty) return _buildPreviewGrid();
    return _buildDropZone();
  }

  // ── Drop zone (no files selected yet) ────────────────────────────────────
  Widget _buildDropZone() {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: widget.pulseAnim,
          builder: (_, __) {
            final borderAlpha =
                _hovered ? 0.7 : 0.2 + widget.pulseAnim.value * 0.3;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _kPurple.withValues(alpha: _hovered ? 0.1 : 0.04),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DashedBorderPainter(
                        color: _kPurple.withValues(alpha: borderAlpha),
                      ),
                    ),
                  ),
                  _DropPrompt(hovered: _hovered, pulseAnim: widget.pulseAnim),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Preview grid (files selected) ────────────────────────────────────────
  Widget _buildPreviewGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _kPurple.withValues(alpha: 0.04),
        border: Border.all(color: _kPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.photo_library_rounded,
                  color: _kPurpleL, size: 14),
              const SizedBox(width: 6),
              Text(
                '${widget.files.length} image${widget.files.length == 1 ? '' : 's'} selected',
                style: const TextStyle(
                    color: _kPurpleL,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (widget.enabled)
                GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _kPurple.withValues(alpha: 0.15),
                      border: Border.all(
                          color: _kPurple.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            color: _kPurpleL, size: 13),
                        SizedBox(width: 4),
                        Text('Add more',
                            style: TextStyle(
                                color: _kPurpleL,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Thumbnail grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              widget.thumbnails.length,
              (i) => _ThumbCard(
                bytes:    widget.thumbnails[i],
                filename: _shortName(widget.files[i].name),
                onRemove: widget.enabled
                    ? () => widget.onRemoveFile(i)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortName(String path) {
    final name = path.split('/').last.split('\\').last;
    return name.length > 13 ? '${name.substring(0, 11)}…' : name;
  }
}

// ── Thumbnail mini-card ───────────────────────────────────────────────────────

class _ThumbCard extends StatelessWidget {
  final Uint8List      bytes;
  final String         filename;
  final VoidCallback?  onRemove;
  const _ThumbCard(
      {required this.bytes, required this.filename, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(bytes,
                width: 82, height: 82, fit: BoxFit.cover),
          ),
          // Bottom gradient + filename
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(10)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.transparent
                  ],
                ),
              ),
              child: Text(
                filename,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Remove button
          if (onRemove != null)
            Positioned(
              top: 3, right: 3,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.75),
                    border: Border.all(
                        color: _kPurpleL.withValues(alpha: 0.6), width: 1),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DropPrompt extends StatelessWidget {
  final bool              hovered;
  final Animation<double> pulseAnim;
  const _DropPrompt({required this.hovered, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPurple.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(
                        alpha:
                            (hovered ? 0.6 : pulseAnim.value) * 0.5),
                    blurRadius: hovered ? 28 : 16,
                    spreadRadius: hovered ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                size: 30,
                color: _kPurpleL.withValues(
                    alpha: hovered ? 1.0 : 0.7),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tap or drag an image to upload',
              style: TextStyle(
                color: _kWhite.withValues(
                    alpha: hovered ? 0.9 : 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PNG · JPG · WEBP',
              style: TextStyle(
                color: _kPurpleL.withValues(alpha: 0.4),
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Dashed border painter
// ══════════════════════════════════════════════════════════════════════════════

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashW = 8.0;
    const dashG = 5.0;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(16),
      ));

    for (final metric in path.computeMetrics()) {
      double d = 0;
      bool drawing = true;
      while (d < metric.length) {
        final len = drawing ? dashW : dashG;
        if (drawing) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + len, metric.length)),
            paint,
          );
        }
        d += len;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
//  Algorithm selector
// ══════════════════════════════════════════════════════════════════════════════

class _AlgoSelector extends StatelessWidget {
  final String              selected;
  final ValueChanged<String> onSelect;
  const _AlgoSelector(
      {required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ENCRYPTION ALGORITHM',
          style: TextStyle(
            color: _kPurpleL.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AlgoCard(
                name:        'AES-GCM',
                displayName: 'AES-GCM',
                description: 'Hardware-accelerated\nstandard cipher',
                badge:       'STANDARD',
                badgeColor:  _kGreen,
                selected:    selected == 'AES-GCM',
                onTap: () => onSelect('AES-GCM'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AlgoCard(
                name:        'ChaCha20-Poly1305',
                displayName: 'ChaCha20',
                description: 'Software-efficient\nalternative cipher',
                badge:       'POLY1305',
                badgeColor:  _kAmber,
                selected:    selected == 'ChaCha20-Poly1305',
                onTap: () => onSelect('ChaCha20-Poly1305'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AlgoCard extends StatefulWidget {
  final String    name;
  final String    displayName;
  final String    description;
  final String    badge;
  final Color     badgeColor;
  final bool      selected;
  final VoidCallback onTap;

  const _AlgoCard({
    required this.name,
    required this.displayName,
    required this.description,
    required this.badge,
    required this.badgeColor,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AlgoCard> createState() => _AlgoCardState();
}

class _AlgoCardState extends State<_AlgoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scaleAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    if (widget.selected) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_AlgoCard old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected) {
      widget.selected ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (_, child) =>
              Transform.scale(scale: _scaleAnim.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: widget.selected
                  ? _kPurple.withValues(alpha: 0.14)
                  : _kWhite.withValues(alpha: 0.03),
              border: Border.all(
                color: widget.selected
                    ? _kPurple.withValues(alpha: 0.7)
                    : _hovered
                        ? _kPurple.withValues(alpha: 0.35)
                        : _kPurple.withValues(alpha: 0.14),
                width: widget.selected ? 1.5 : 1,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: _kPurple.withValues(alpha: 0.28),
                        blurRadius: 18,
                        spreadRadius: -2,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Radio dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.selected
                            ? _kPurple
                            : Colors.transparent,
                        border: Border.all(
                          color: widget.selected
                              ? _kPurple
                              : _kPurpleL.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: widget.selected
                            ? [
                                BoxShadow(
                                  color:
                                      _kPurple.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ]
                            : [],
                      ),
                    ),
                    const Spacer(),
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: widget.badgeColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: widget.badgeColor
                              .withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.badge,
                        style: TextStyle(
                          color: widget.badgeColor,
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.displayName,
                  style: TextStyle(
                    color: widget.selected
                        ? _kWhite
                        : _kWhite.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: TextStyle(
                    color: _kWhite.withValues(alpha: 0.32),
                    fontSize: 10,
                    height: 1.55,
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

// ══════════════════════════════════════════════════════════════════════════════
//  Upload button
// ══════════════════════════════════════════════════════════════════════════════

class _UploadButton extends StatefulWidget {
  final bool              enabled;
  final int               fileCount;
  final Animation<double> pulseAnim;
  final VoidCallback      onTap;

  const _UploadButton({
    required this.enabled,
    required this.fileCount,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  State<_UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends State<_UploadButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: widget.pulseAnim,
          builder: (_, child) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: widget.enabled
                    ? [
                        _hovered
                            ? const Color(0xFF9333EA)
                            : _kPurple,
                        _hovered
                            ? const Color(0xFF6D28D9)
                            : _kPurple2,
                      ]
                    : [
                        _kPurple.withValues(alpha: 0.22),
                        _kPurple2.withValues(alpha: 0.22),
                      ],
              ),
              boxShadow: widget.enabled
                  ? [
                      BoxShadow(
                        color: _kPurple.withValues(
                          alpha: _hovered
                              ? 0.6
                              : widget.pulseAnim.value * 0.45,
                        ),
                        blurRadius: _hovered ? 32 : 20,
                        offset: const Offset(0, 4),
                        spreadRadius: -2,
                      ),
                    ]
                  : [],
            ),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 18,
                color: widget.enabled
                    ? _kWhite
                    : _kWhite.withValues(alpha: 0.28),
              ),
              const SizedBox(width: 10),
              Text(
                widget.fileCount > 1
                    ? 'Encrypt & Upload ${widget.fileCount} Images'
                    : 'Encrypt & Upload',
                style: TextStyle(
                  color: widget.enabled
                      ? _kWhite
                      : _kWhite.withValues(alpha: 0.28),
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
//  Progress steps
// ══════════════════════════════════════════════════════════════════════════════

class _ProgressSteps extends StatelessWidget {
  final int               step;
  final int               currentUpload;
  final int               totalUploads;
  final Animation<double> pulseAnim;
  final Animation<double> checkAnim;
  const _ProgressSteps({
    super.key,
    required this.step,
    required this.currentUpload,
    required this.totalUploads,
    required this.pulseAnim,
    required this.checkAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: switch (step) {
        1 => _EncryptingStep(key: ValueKey('enc_$currentUpload'), pulseAnim: pulseAnim, current: currentUpload, total: totalUploads),
        2 => _UploadingStep(key: ValueKey('upl_$currentUpload'), current: currentUpload, total: totalUploads),
        _ => _DoneStep(key: const ValueKey(3), checkAnim: checkAnim, total: totalUploads),
      },
    );
  }
}

// ── Step: Encrypting ──────────────────────────────────────────────────────────

class _EncryptingStep extends StatelessWidget {
  final Animation<double> pulseAnim;
  final int current;
  final int total;
  const _EncryptingStep({super.key, required this.pulseAnim, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return _StepWrapper(
      stepIndex: 1,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPurple.withValues(alpha: 0.1),
                border: Border.all(
                    color: _kPurple.withValues(
                        alpha: 0.2 + pulseAnim.value * 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(
                        alpha: pulseAnim.value * 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: child,
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: _kPurpleL, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ENCRYPTING',
            style: TextStyle(
              color: _kPurpleL,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total > 1 ? 'Encrypting image $current of $total…' : 'Applying local encryption to your image…',
            style: TextStyle(
              color: _kWhite.withValues(alpha: 0.38),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step: Uploading ───────────────────────────────────────────────────────────

class _UploadingStep extends StatelessWidget {
  final int current;
  final int total;
  const _UploadingStep({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return _StepWrapper(
      stepIndex: 2,
      child: Column(
        children: [
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPurple.withValues(alpha: 0.1),
              border: Border.all(
                  color: _kPurple.withValues(alpha: 0.3)),
            ),
            child: const Icon(
                Icons.cloud_upload_outlined,
                color: _kPurpleL,
                size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'UPLOADING',
            style: TextStyle(
              color: _kPurpleL,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total > 1 ? 'Uploading image $current of $total…' : 'Sending encrypted ciphertext to server…',
            style: TextStyle(
              color: _kWhite.withValues(alpha: 0.38),
              fontSize: 11,
            ),
          ),
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
      ),
    );
  }
}

// ── Step: Done ────────────────────────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  final Animation<double> checkAnim;
  final int total;
  const _DoneStep({super.key, required this.checkAnim, required this.total});

  @override
  Widget build(BuildContext context) {
    return _StepWrapper(
      stepIndex: 3,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: checkAnim,
            builder: (_, child) => Transform.scale(
              scale: checkAnim.value,
              child: child,
            ),
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGreen.withValues(alpha: 0.1),
                border: Border.all(
                    color: _kGreen.withValues(alpha: 0.5),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _kGreen.withValues(alpha: 0.3),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: _kGreen, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'UPLOAD COMPLETE',
            style: TextStyle(
              color: _kGreen,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total > 1 ? '$total images encrypted and stored securely.' : 'Image encrypted and stored securely.',
            style: TextStyle(
              color: _kWhite.withValues(alpha: 0.38),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step wrapper with dot-pill indicator ──────────────────────────────────────

class _StepWrapper extends StatelessWidget {
  final int    stepIndex;
  final Widget child;
  const _StepWrapper({required this.stepIndex, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 28),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final active  = i + 1 <= stepIndex;
            final current = i + 1 == stepIndex;
            return Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width:  current ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active
                        ? _kPurple
                        : _kPurple.withValues(alpha: 0.2),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _kPurple.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : [],
                  ),
                ),
                if (i < 2) const SizedBox(width: 4),
              ],
            );
          }),
        ),
      ],
    );
  }
}
