'use strict';
const { Router }                           = require('express');
const { register, login, updatePublicKey } = require('../controllers/authController');
const authenticate                         = require('../middleware/authenticate');

const router = Router();

// POST /api/auth/register
router.post('/register', register);

// POST /api/auth/login
router.post('/login', login);

// PUT /api/auth/public-key  (requires JWT)
router.put('/public-key', authenticate, updatePublicKey);

module.exports = router;
