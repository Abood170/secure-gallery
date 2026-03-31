'use strict';
const path     = require('path');
const fs       = require('fs');
const { Media, AuditLog } = require('../models');

// ── GET /api/media ─────────────────────────────────────────────────────────────
// Returns all media owned by the authenticated user (metadata only, no file).
const listMedia = async (req, res, next) => {
  try {
    const mediaList = await Media.findAll({
      where: { owner_id: req.user.userId },
      attributes: ['media_id', 'filename', 'algo', 'iv'],
      order: [['media_id', 'DESC']],
    });
    return res.json({ media: mediaList });
  } catch (err) {
    next(err);
  }
};

// ── POST /api/media/upload ─────────────────────────────────────────────────────
// Expects multipart/form-data:
//   - file:     the ciphertext blob
//   - filename: original filename (for display purposes)
//   - algo:     'AES-GCM' | 'ChaCha20-Poly1305'
//   - iv:       Base64-encoded IV / nonce
const upload = async (req, res, next) => {
  console.log('FILES:', req.file);
  console.log('BODY:', req.body);
  try {
    // multer already saved the file; req.file holds its info
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded.' });
    }

    const { filename, algo, iv } = req.body;

    if (!filename || !algo || !iv) {
      // Clean up the orphaned file
      fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: 'filename, algo, and iv are required.' });
    }

    const media = await Media.create({
      owner_id:       req.user.userId,
      filename,
      algo,
      iv,
      ciphertext_path: req.file.path,
    });

    await AuditLog.create({
      user_id: req.user.userId,
      action:  'UPLOAD',
      ip:      req.ip,
    });

    return res.status(201).json({
      message:  'Encrypted image uploaded successfully.',
      media_id: media.media_id,
    });
  } catch (err) {
    // Remove the uploaded file if DB insert fails
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    next(err);
  }
};

// ── GET /api/media/:id ────────────────────────────────────────────────────────
// Returns the metadata + the ciphertext file as a binary download.
const download = async (req, res, next) => {
  try {
    const media = await Media.findByPk(req.params.id);

    if (!media) {
      return res.status(404).json({ error: 'Media not found.' });
    }

    // Only the owner can download their own media directly
    if (media.owner_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied.' });
    }

    if (!fs.existsSync(media.ciphertext_path)) {
      return res.status(404).json({ error: 'Ciphertext file not found on server.' });
    }

    await AuditLog.create({
      user_id: req.user.userId,
      action:  'DOWNLOAD',
      ip:      req.ip,
    });

    // Send metadata in headers so the client can decrypt
    res.set('X-Media-Id',   media.media_id.toString());
    res.set('X-Algo',       media.algo);
    res.set('X-IV',         media.iv);
    res.set('X-Filename',   encodeURIComponent(media.filename));

    res.download(media.ciphertext_path, path.basename(media.ciphertext_path));
  } catch (err) {
    next(err);
  }
};

// ── DELETE /api/media/:id ─────────────────────────────────────────────────────
const deleteMedia = async (req, res, next) => {
  try {
    const media = await Media.findByPk(req.params.id);

    if (!media) {
      return res.status(404).json({ error: 'Media not found.' });
    }

    if (media.owner_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied.' });
    }

    // Delete the encrypted file from disk
    if (fs.existsSync(media.ciphertext_path)) {
      fs.unlinkSync(media.ciphertext_path);
    }

    await media.destroy();

    return res.json({ message: 'Media deleted successfully.' });
  } catch (err) {
    next(err);
  }
};

module.exports = { listMedia, upload, download, deleteMedia };
