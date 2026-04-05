'use strict';
const bcrypt              = require('bcryptjs');
const { User, Media, Share, AuditLog } = require('../models');
const { Op }              = require('sequelize');

// ── GET /api/profile ───────────────────────────────────────────────────────────
const getProfile = async (req, res, next) => {
  try {
    const user = await User.findOne({
      where:      { user_id: req.user.userId },
      attributes: ['user_id', 'email', 'role', 'is_banned', 'public_key', 'created_at'],
    });

    if (!user) return res.status(404).json({ error: 'User not found.' });

    const [mediaCount, sharesSent, sharesReceived] = await Promise.all([
      Media.count({ where: { owner_id: req.user.userId } }),
      Share.count({ where: { sender_id: req.user.userId } }),
      Share.count({ where: { receiver_id: req.user.userId } }),
    ]);

    // Last login from audit log
    const lastLogin = await AuditLog.findOne({
      where:   { user_id: req.user.userId, action: 'LOGIN' },
      order:   [['timestamp', 'DESC']],
      attributes: ['timestamp'],
    });

    return res.json({
      user_id:          user.user_id,
      email:            user.email,
      role:             user.role,
      is_banned:        user.is_banned,
      has_public_key:   !!user.public_key,
      created_at:       user.created_at,
      media_count:      mediaCount,
      shares_sent:      sharesSent,
      shares_received:  sharesReceived,
      last_login:       lastLogin?.timestamp ?? null,
    });
  } catch (err) {
    next(err);
  }
};

// ── PATCH /api/profile ─────────────────────────────────────────────────────────
const updateProfile = async (req, res, next) => {
  try {
    const { current_password, new_email, new_password } = req.body;

    if (!current_password) {
      return res.status(400).json({ error: 'current_password is required to confirm changes.' });
    }
    if (!new_email && !new_password) {
      return res.status(400).json({ error: 'Provide new_email or new_password to update.' });
    }

    const user = await User.findOne({ where: { user_id: req.user.userId } });
    if (!user) return res.status(404).json({ error: 'User not found.' });

    if (user.is_banned) {
      return res.status(403).json({ error: 'Your account has been suspended.' });
    }

    // Verify current password before any mutation
    const valid = await bcrypt.compare(current_password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Current password is incorrect.' });
    }

    const updates = {};

    if (new_email) {
      const trimmed = new_email.trim().toLowerCase();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
        return res.status(400).json({ error: 'Invalid email format.' });
      }
      if (trimmed === user.email.toLowerCase()) {
        return res.status(400).json({ error: 'New email is the same as current email.' });
      }
      const taken = await User.findOne({ where: { email: trimmed } });
      if (taken) return res.status(409).json({ error: 'Email is already in use.' });
      updates.email = trimmed;
    }

    if (new_password) {
      if (new_password.length < 8) {
        return res.status(400).json({ error: 'Password must be at least 8 characters.' });
      }
      if (!/[A-Z]/.test(new_password)) {
        return res.status(400).json({ error: 'Password must contain at least one uppercase letter.' });
      }
      if (!/[0-9]/.test(new_password)) {
        return res.status(400).json({ error: 'Password must contain at least one number.' });
      }
      updates.password_hash = await bcrypt.hash(new_password, 12);
    }

    await User.update(updates, { where: { user_id: req.user.userId } });

    await AuditLog.create({
      user_id: req.user.userId,
      action:  'PROFILE_UPDATED',
      ip:      req.ip,
    });

    return res.json({ message: 'Profile updated successfully.' });
  } catch (err) {
    next(err);
  }
};

// ── DELETE /api/profile ────────────────────────────────────────────────────────
const deleteAccount = async (req, res, next) => {
  try {
    const { password } = req.body;

    if (!password) {
      return res.status(400).json({ error: 'Password is required to delete your account.' });
    }

    const user = await User.findOne({ where: { user_id: req.user.userId } });
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return res.status(401).json({ error: 'Incorrect password.' });

    // Hard-delete: cascades to media and shares via DB constraints / Sequelize
    await Share.destroy({
      where: {
        [Op.or]: [
          { sender_id:   req.user.userId },
          { receiver_id: req.user.userId },
        ],
      },
    });
    await Media.destroy({ where: { owner_id: req.user.userId } });
    await AuditLog.destroy({ where: { user_id: req.user.userId } });
    await User.destroy({ where: { user_id: req.user.userId } });

    return res.json({ message: 'Account deleted.' });
  } catch (err) {
    next(err);
  }
};

module.exports = { getProfile, updateProfile, deleteAccount };
