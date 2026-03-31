'use strict';
const { Router }                              = require('express');
const { createShare, inbox, getEncryptedKey, downloadShared, deleteShare } = require('../controllers/shareController');
const authenticate = require('../middleware/authenticate');

const router = Router();

// All share routes require a valid JWT
router.use(authenticate);

// POST /api/share  — create a new Safe Share record
router.post('/', createShare);

// GET /api/share/inbox  — list shares received by the authenticated user
router.get('/inbox', inbox);

// GET /api/share/:id/key       — get the encrypted symmetric key for a share
router.get('/:id/key', getEncryptedKey);

// GET /api/share/:id/download  — download the shared ciphertext (receiver only)
router.get('/:id/download', downloadShared);

// DELETE /api/share/:id  — sender deletes their own share
router.delete('/:id', deleteShare);

module.exports = router;
