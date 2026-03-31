'use strict';
const path = require('path');
const fs   = require('fs');
const { Share, Media, User, AuditLog } = require('../models');

// ── POST /api/share ────────────────────────────────────────────────────────────
// Body: { media_id, receiver_id, encrypted_key, expires_at? }
// The client has already RSA-encrypted the symmetric key with the receiver's
// public key before calling this endpoint.
const createShare = async (req, res, next) => {
  try {
    const { media_id, receiver_id, encrypted_key, expires_at } = req.body;

    if (!media_id || !receiver_id || !encrypted_key) {
      return res.status(400).json({
        error: 'media_id, receiver_id, and encrypted_key are required.',
      });
    }

    // Verify the media belongs to the sender
    const media = await Media.findByPk(media_id);
    if (!media) {
      return res.status(404).json({ error: 'Media not found.' });
    }
    if (media.owner_id !== req.user.userId) {
      return res.status(403).json({ error: 'You do not own this media.' });
    }

    // Verify the receiver exists
    const receiver = await User.findByPk(receiver_id);
    if (!receiver) {
      return res.status(404).json({ error: 'Receiver not found.' });
    }

    const share = await Share.create({
      media_id,
      sender_id:   req.user.userId,
      receiver_id,
      encrypted_key,
      expires_at:  expires_at || null,
    });

    await AuditLog.create({
      user_id: req.user.userId,
      action:  'SHARE',
      ip:      req.ip,
    });

    return res.status(201).json({
      message:  'Share created successfully.',
      share_id: share.share_id,
    });
  } catch (err) {
    next(err);
  }
};

// ── GET /api/share/inbox ───────────────────────────────────────────────────────
// Returns all shares sent TO the authenticated user that have not expired.
const inbox = async (req, res, next) => {
  try {
    const now = new Date();

    const shares = await Share.findAll({
      where: { receiver_id: req.user.userId },
      include: [
        {
          model: Media,
          as: 'media',
          attributes: ['media_id', 'filename', 'algo', 'iv', 'ciphertext_path'],
        },
        {
          model: User,
          as: 'sender',
          attributes: ['user_id', 'email'],
        },
      ],
    });

    // Filter out expired shares in JS (simple approach)
    const active = shares.filter(
      (s) => !s.expires_at || new Date(s.expires_at) > now
    );

    return res.json({ shares: active });
  } catch (err) {
    next(err);
  }
};

// ── GET /api/share/:id/key ─────────────────────────────────────────────────────
// Returns the RSA-encrypted symmetric key for a specific share.
// Only the intended receiver can call this.
const getEncryptedKey = async (req, res, next) => {
  try {
    const share = await Share.findByPk(req.params.id);

    if (!share) {
      return res.status(404).json({ error: 'Share not found.' });
    }

    if (share.receiver_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied.' });
    }

    if (share.expires_at && new Date(share.expires_at) < new Date()) {
      return res.status(410).json({ error: 'This share has expired.' });
    }

    return res.json({ encrypted_key: share.encrypted_key });
  } catch (err) {
    next(err);
  }
};

// ── GET /api/share/:id/download ───────────────────────────────────────────────
// Lets the receiver download the ciphertext of a shared image.
const downloadShared = async (req, res, next) => {
  try {
    const share = await Share.findByPk(req.params.id, {
      include: [{ model: Media, as: 'media' }],
    });

    if (!share) {
      return res.status(404).json({ error: 'Share not found.' });
    }
    if (share.receiver_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied.' });
    }
    if (share.expires_at && new Date(share.expires_at) < new Date()) {
      return res.status(410).json({ error: 'This share has expired.' });
    }

    const media = share.media;
    if (!fs.existsSync(media.ciphertext_path)) {
      return res.status(404).json({ error: 'Ciphertext file not found on server.' });
    }

    await AuditLog.create({
      user_id: req.user.userId,
      action:  'DOWNLOAD',
      ip:      req.ip,
    });

    res.set('X-Media-Id',  media.media_id.toString());
    res.set('X-Algo',      media.algo);
    res.set('X-IV',        media.iv);
    res.set('X-Filename',  encodeURIComponent(media.filename));

    res.download(media.ciphertext_path, path.basename(media.ciphertext_path));
  } catch (err) {
    next(err);
  }
};

// ── DELETE /api/share/:id ─────────────────────────────────────────────────────
// Lets the SENDER delete a share they created (e.g. to reshare with fresh keys).
const deleteShare = async (req, res, next) => {
  try {
    const share = await Share.findByPk(req.params.id);
    if (!share) return res.status(404).json({ error: 'Share not found.' });
    if (share.sender_id !== req.user.userId && share.receiver_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied.' });
    }
    await share.destroy();
    return res.json({ message: 'Share deleted.' });
  } catch (err) {
    next(err);
  }
};

module.exports = { createShare, inbox, getEncryptedKey, downloadShared, deleteShare };
