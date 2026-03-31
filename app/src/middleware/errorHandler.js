'use strict';

/**
 * Central error handler — must be registered LAST in app.js (after all routes).
 * Catches any error passed via next(err).
 */
const errorHandler = (err, req, res, _next) => {
  // Multer file-too-large error
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      error: `File exceeds the ${process.env.MAX_FILE_SIZE_MB || 20} MB limit.`,
    });
  }

  // Sequelize validation errors
  if (err.name === 'SequelizeValidationError' || err.name === 'SequelizeUniqueConstraintError') {
    const messages = err.errors.map((e) => e.message);
    return res.status(400).json({ error: messages.join(', ') });
  }

  // Default: 500
  console.error('[ERROR]', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error.',
  });
};

module.exports = errorHandler;
