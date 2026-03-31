'use strict';
const { Router }           = require('express');
const { listMedia, upload, download, deleteMedia } = require('../controllers/mediaController');
const authenticate  = require('../middleware/authenticate');
const multerUpload  = require('../config/multer');
const router = Router();

// All media routes require a valid JWT
router.use(authenticate);

router.post('/test', multerUpload.single('file'), (req, res) => {
  console.log('FILE:', req.file);
  console.log('BODY:', req.body);
  res.json({ file: req.file, body: req.body });
});

// GET /api/media  — list all media owned by the authenticated user
router.get('/', listMedia);

// POST /api/media/upload  — multipart/form-data (ciphertext + metadata)
router.post('/upload', multerUpload.single('file'), upload);

// GET /api/media/:id  — download ciphertext + metadata headers
router.get('/:id', download);

// DELETE /api/media/:id  — delete media and its encrypted file
router.delete('/:id', deleteMedia);

module.exports = router;
