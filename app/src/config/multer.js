'use strict';
const multer = require('multer');
const path   = require('path');
const fs     = require('fs');

// Ensure upload directory exists
const uploadDir = process.env.UPLOAD_DIR || 'uploads';
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  // Keep original extension; prefix with timestamp to avoid collisions
  filename: (_req, file, cb) => {
    const ext      = path.extname(file.originalname);
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, uniqueName);
  },
});

const maxSize = (parseInt(process.env.MAX_FILE_SIZE_MB) || 20) * 1024 * 1024;

// Accept any file — the client uploads ciphertext blobs, not raw images
const upload = multer({
  storage,
  limits: { fileSize: maxSize },
});

module.exports = upload;
