'use strict';
const { Op }                          = require('sequelize');
const fs                               = require('fs');
const { User, Media, Share, AuditLog } = require('../models');

// ── GET /api/admin/stats ───────────────────────────────────────────────────────
const getStats = async (req, res, next) => {
  try {
    const [totalUsers, activeUsers, bannedUsers, totalUploads, totalShares] =
      await Promise.all([
        User.count(),
        User.count({ where: { is_banned: false } }),
        User.count({ where: { is_banned: true  } }),
        Media.count(),
        Share.count(),
      ]);

    return res.json({
      users:       totalUsers,
      activeUsers,
      bannedUsers,
      uploads:     totalUploads,
      shares:      totalShares,
    });
  } catch (err) {
    next(err);
  }
};

// ── GET /api/admin/users?page=1&limit=20&search=email ─────────────────────────
const listUsers = async (req, res, next) => {
  try {
    const page   = Math.max(1, parseInt(req.query.page)  || 1);
    const limit  = Math.min(100, parseInt(req.query.limit) || 20);
    const search = (req.query.search || '').trim();
    const offset = (page - 1) * limit;

    const where = search
      ? { email: { [Op.iLike]: `%${search}%` } }
      : {};

    const { count, rows } = await User.findAndCountAll({
      where,
      attributes: ['user_id', 'email', 'role', 'is_banned', 'created_at'],
      order:  [['created_at', 'DESC']],
      limit,
      offset,
    });

    return res.json({
      users:      rows,
      total:      count,
      page,
      totalPages: Math.ceil(count / limit),
    });
  } catch (err) {
    next(err);
  }
};

// ── DELETE /api/admin/users/:id ────────────────────────────────────────────────
const deleteUser = async (req, res, next) => {
  try {
    const userId = parseInt(req.params.id);

    // Prevent deleting the super-admin account
    const target = await User.findByPk(userId);
    if (!target) {
      return res.status(404).json({ error: 'User not found.' });
    }
    if (target.email === process.env.ADMIN_EMAIL) {
      return res.status(403).json({ error: 'Cannot delete the super-admin account.' });
    }
    if (target.user_id === req.user.userId) {
      return res.status(400).json({ error: 'Cannot delete your own account.' });
    }

    // Cascade: delete owned media files from disk + DB, shares, audit logs
    const mediaRecords = await Media.findAll({ where: { owner_id: userId } });
    for (const m of mediaRecords) {
      if (fs.existsSync(m.ciphertext_path)) {
        fs.unlinkSync(m.ciphertext_path);
      }
    }
    await Media.destroy({ where: { owner_id: userId } });
    await Share.destroy({
      where: { [Op.or]: [{ sender_id: userId }, { receiver_id: userId }] },
    });
    await AuditLog.destroy({ where: { user_id: userId } });
    await target.destroy();

    await AuditLog.create({
      user_id: req.user.userId,
      action:  'ADMIN_DELETE_USER',
      ip:      req.ip,
    });

    return res.json({ message: `User ${target.email} deleted.` });
  } catch (err) {
    next(err);
  }
};

// ── PATCH /api/admin/users/:id/role ───────────────────────────────────────────
// Body: { role: 'user' | 'admin' }
const updateRole = async (req, res, next) => {
  try {
    const userId  = parseInt(req.params.id);
    const { role } = req.body;

    if (!['user', 'admin'].includes(role)) {
      return res.status(400).json({ error: "role must be 'user' or 'admin'." });
    }

    const target = await User.findByPk(userId);
    if (!target) {
      return res.status(404).json({ error: 'User not found.' });
    }
    if (target.email === process.env.ADMIN_EMAIL) {
      return res.status(403).json({ error: 'Cannot change role of super-admin.' });
    }

    await target.update({ role });

    await AuditLog.create({
      user_id: req.user.userId,
      action:  `ADMIN_SET_ROLE:${role.toUpperCase()}`,
      ip:      req.ip,
    });

    return res.json({ message: `Role updated to '${role}'.`, user_id: userId, role });
  } catch (err) {
    next(err);
  }
};

// ── PATCH /api/admin/users/:id/ban ────────────────────────────────────────────
// Body: { ban: true | false }
const toggleBan = async (req, res, next) => {
  try {
    const userId = parseInt(req.params.id);
    const ban    = req.body.ban === true || req.body.ban === 'true';

    const target = await User.findByPk(userId);
    if (!target) {
      return res.status(404).json({ error: 'User not found.' });
    }
    if (target.email === process.env.ADMIN_EMAIL) {
      return res.status(403).json({ error: 'Cannot ban the super-admin account.' });
    }
    if (target.user_id === req.user.userId) {
      return res.status(400).json({ error: 'Cannot ban your own account.' });
    }

    await target.update({ is_banned: ban });

    await AuditLog.create({
      user_id: req.user.userId,
      action:  ban ? 'ADMIN_BAN_USER' : 'ADMIN_UNBAN_USER',
      ip:      req.ip,
    });

    return res.json({
      message:   ban ? 'User banned.' : 'User unbanned.',
      user_id:   userId,
      is_banned: ban,
    });
  } catch (err) {
    next(err);
  }
};

// ── GET /api/admin/media?page=1&limit=20&search=filename ──────────────────────
const listAllMedia = async (req, res, next) => {
  try {
    const page   = Math.max(1, parseInt(req.query.page)  || 1);
    const limit  = Math.min(100, parseInt(req.query.limit) || 20);
    const search = (req.query.search || '').trim();
    const offset = (page - 1) * limit;

    const where = search
      ? { filename: { [Op.iLike]: `%${search}%` } }
      : {};

    const { count, rows } = await Media.findAndCountAll({
      where,
      include: [{
        model: User,
        as:    'owner',
        attributes: ['email'],
      }],
      order:  [['media_id', 'DESC']],
      limit,
      offset,
    });

    return res.json({
      media:      rows,
      total:      count,
      page,
      totalPages: Math.ceil(count / limit),
    });
  } catch (err) {
    next(err);
  }
};

// ── DELETE /api/admin/media/:id ───────────────────────────────────────────────
const deleteMedia = async (req, res, next) => {
  try {
    const mediaId = parseInt(req.params.id);
    const media   = await Media.findByPk(mediaId);

    if (!media) {
      return res.status(404).json({ error: 'Media not found.' });
    }

    // Remove ciphertext file from disk
    if (fs.existsSync(media.ciphertext_path)) {
      fs.unlinkSync(media.ciphertext_path);
    }

    // Remove associated shares
    await Share.destroy({ where: { media_id: mediaId } });
    await media.destroy();

    await AuditLog.create({
      user_id: req.user.userId,
      action:  'ADMIN_DELETE_MEDIA',
      ip:      req.ip,
    });

    return res.json({ message: 'Media deleted.' });
  } catch (err) {
    next(err);
  }
};

// ── GET /api/admin/audit-logs?limit=50&page=1 ─────────────────────────────────
const getAuditLogs = async (req, res, next) => {
  try {
    const limit  = Math.min(200, parseInt(req.query.limit) || 50);
    const page   = Math.max(1,   parseInt(req.query.page)  || 1);
    const offset = (page - 1) * limit;

    const { count, rows } = await AuditLog.findAndCountAll({
      limit,
      offset,
      order: [['timestamp', 'DESC']],
      include: [{
        model:      User,
        as:         'user',
        attributes: ['email'],
      }],
    });

    return res.json({
      logs:       rows,
      total:      count,
      page,
      totalPages: Math.ceil(count / limit),
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getStats,
  listUsers,
  deleteUser,
  updateRole,
  toggleBan,
  listAllMedia,
  deleteMedia,
  getAuditLogs,
};
