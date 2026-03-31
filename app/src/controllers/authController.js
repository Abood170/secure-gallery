'use strict';
const bcrypt = require('bcryptjs');
const jwt    = require('jsonwebtoken');
const { User, AuditLog } = require('../models');

// ── POST /api/auth/register ────────────────────────────────────────────────────
const register = async (req, res, next) => {
  try {
    const { email, password, public_key } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'email and password are required.' });
    }

    const existing = await User.findOne({ where: { email } });
    if (existing) {
      return res.status(409).json({ error: 'Email already in use.' });
    }

    const password_hash = await bcrypt.hash(password, 12);

    const user = await User.create({ email, password_hash, public_key: public_key || null });

    return res.status(201).json({
      message: 'User registered successfully.',
      user_id: user.user_id,
    });
  } catch (err) {
    next(err);
  }
};

// ── POST /api/auth/login ───────────────────────────────────────────────────────
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'email and password are required.' });
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials.' });
    }

    // Reject banned accounts before password check (avoids timing leak)
    if (user.is_banned) {
      return res.status(403).json({ error: 'This account has been banned.' });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials.' });
    }

    const token = jwt.sign(
      { userId: user.user_id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    // Record login in audit log
    await AuditLog.create({
      user_id: user.user_id,
      action:  'LOGIN',
      ip:      req.ip,
    });

    // Admin if: matches ADMIN_EMAIL env var (super-admin) OR has role='admin'
    const isAdmin =
      user.email === process.env.ADMIN_EMAIL || user.role === 'admin';

    return res.json({
      token,
      user_id:  user.user_id,
      is_admin: isAdmin,
    });
  } catch (err) {
    next(err);
  }
};

// ── PUT /api/auth/public-key ───────────────────────────────────────────────────
// Authenticated user updates their stored public key (e.g. after key regeneration).
const updatePublicKey = async (req, res, next) => {
  try {
    const { public_key } = req.body;
    if (!public_key) {
      return res.status(400).json({ error: 'public_key is required.' });
    }
    await User.update(
      { public_key },
      { where: { user_id: req.user.userId } }
    );
    return res.json({ message: 'Public key updated.' });
  } catch (err) {
    next(err);
  }
};

module.exports = { register, login, updatePublicKey };
