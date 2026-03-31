import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/crypto_service.dart';
import '../services/media_service.dart';
import '../services/storage_service.dart';

class ViewImageScreen extends StatefulWidget {
  const ViewImageScreen({super.key});

  @override
  State<ViewImageScreen> createState() => _ViewImageScreenState();
}

class _ViewImageScreenState extends State<ViewImageScreen> {
  Uint8List? _imageBytes;
  bool    _loading = true;
  String? _error;
  bool    _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      final item =
          ModalRoute.of(context)!.settings.arguments as MediaItem;
      _loadImage(item);
    }
  }

  Future<void> _loadImage(MediaItem item) async {
    try {
      // 1. Retrieve the locally-stored symmetric key
      final keyBase64 = await StorageService.getSymmetricKey(item.mediaId);
      if (keyBase64 == null) {
        _setError(
            'Decryption key not found on this device.\n'
            'Keys are stored locally and cannot be recovered\n'
            'if the app is reinstalled.');
        return;
      }

      // 2. Download ciphertext from server
      final dl = await MediaService.downloadMedia(item.mediaId);

      // 3. Decrypt — fall back to item metadata if response headers are empty
      final plaintext = await CryptoService.decrypt(
        ciphertextWithMac: dl.ciphertext,
        ivBase64:          dl.iv.isNotEmpty ? dl.iv : item.iv,
        keyBase64:         keyBase64,
        algo:              dl.algo.isNotEmpty ? dl.algo : item.algo,
      );

      if (mounted) setState(() { _imageBytes = plaintext; _loading = false; });
    } catch (e) {
      _setError('Decryption failed: $e');
    }
  }

  void _setError(String msg) {
    if (mounted) setState(() { _error = msg; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final item =
        ModalRoute.of(context)!.settings.arguments as MediaItem;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(item.filename,
            style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(item.algo,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white)),
              backgroundColor: Colors.deepPurple,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Downloading & decrypting…',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 56, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(child: Image.memory(_imageBytes!)),
                ),
    );
  }
}
