'use strict';
const { User } = require('../models');

/**
 * Grants admin access if the authenticated user:
 *   1. Matches the ADMIN_EMAIL env var (legacy / super-admin), OR
 *   2. Has role = 'admin' in the database.
 * Also blocks banned accounts from admin access.
 */
const requireAdmin = async (req, res, next) => {
  try {
    if (!process.env.ADMIN_EMAIL) {
      return res.status(500).json({ error: 'Admin not configured.' });
    }

    // Super-admin: always allowed (email match, no DB lookup needed)
    if (req.user.email === process.env.ADMIN_EMAIL) {
      return next();
    }

    // Role-based admin: look up the user record
    const user = await User.findByPk(req.user.userId, {
      attributes: ['role', 'is_banned'],
    });

    if (!user) {
      return res.status(401).json({ error: 'User not found.' });
    }
    if (user.is_banned) {
      return res.status(403).json({ error: 'Account is banned.' });
    }
    if (user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required.' });
    }

    next();
  } catch (err) {
    next(err);
  }
};

module.exports = requireAdmin;
