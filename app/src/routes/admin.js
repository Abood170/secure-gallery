'use strict';
const { Router }   = require('express');
const authenticate = require('../middleware/authenticate');
const requireAdmin = require('../middleware/requireAdmin');
const {
  getStats,
  listUsers,
  deleteUser,
  updateRole,
  toggleBan,
  listAllMedia,
  deleteMedia,
  getAuditLogs,
} = require('../controllers/adminController');

const router = Router();

// All admin routes require a valid JWT + admin privileges
router.use(authenticate);
router.use(requireAdmin);

// ── Stats ──────────────────────────────────────────────────────────────────────
router.get('/stats', getStats);

// ── User management ────────────────────────────────────────────────────────────
router.get   ('/users',         listUsers);
router.delete('/users/:id',     deleteUser);
router.patch ('/users/:id/role', updateRole);
router.patch ('/users/:id/ban',  toggleBan);

// ── Content moderation ─────────────────────────────────────────────────────────
router.get   ('/media',     listAllMedia);
router.delete('/media/:id', deleteMedia);

// ── Audit logs ─────────────────────────────────────────────────────────────────
router.get('/audit-logs', getAuditLogs);

module.exports = router;
