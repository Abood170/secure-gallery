'use strict';
const { User } = require('../models');

// ── GET /api/users/by-email?email=... ─────────────────────────────────────────
// Returns the user_id and public_key for a given email.
// Used by the Flutter client to look up a recipient before Safe Share.
const getUserByEmail = async (req, res, next) => {
  try {
    const { email } = req.query;

    if (!email) {
      return res.status(400).json({ error: 'email query param is required.' });
    }

    const user = await User.findOne({
      where: { email },
      attributes: ['user_id', 'public_key'],
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    return res.json({ user_id: user.user_id, public_key: user.public_key });
  } catch (err) {
    next(err);
  }
};

module.exports = { getUserByEmail };
