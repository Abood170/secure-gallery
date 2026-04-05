'use strict';
const { Router }   = require('express');
const authenticate = require('../middleware/authenticate');
const {
  getProfile,
  updateProfile,
  deleteAccount,
} = require('../controllers/profileController');

const router = Router();

// All profile routes require a valid JWT
router.use(authenticate);

router.get('/',    getProfile);     // GET  /api/profile
router.patch('/',  updateProfile);  // PATCH /api/profile
router.delete('/', deleteAccount);  // DELETE /api/profile

module.exports = router;
