'use strict';
const { Router } = require('express');
const { getUserByEmail } = require('../controllers/userController');
const authenticate = require('../middleware/authenticate');

const router = Router();

// All user lookup routes require a valid JWT
router.use(authenticate);

// GET /api/users/by-email?email=...  — look up a user's public key by email
router.get('/by-email', getUserByEmail);

module.exports = router;
