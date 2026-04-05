'use strict';
require('dotenv').config();

const express      = require('express');
const cors         = require('cors');
const rateLimit    = require('express-rate-limit');
const { sequelize } = require('./models');
const errorHandler = require('./middleware/errorHandler');

const authRoutes    = require('./routes/auth');
const mediaRoutes   = require('./routes/media');
const shareRoutes   = require('./routes/share');
const userRoutes    = require('./routes/user');
const adminRoutes   = require('./routes/admin');
const profileRoutes = require('./routes/profile');

const app  = express();
const PORT = process.env.PORT || 4000;

app.use(cors({
  exposedHeaders: ['X-Algo', 'X-IV', 'X-Filename', 'X-Media-Id'],
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});
app.use(limiter);

app.use('/api/auth',    authRoutes);
app.use('/api/media',   mediaRoutes);
app.use('/api/share',   shareRoutes);
app.use('/api/users',   userRoutes);
app.use('/api/admin',   adminRoutes);
app.use('/api/profile', profileRoutes);

app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use((_req, res) => res.status(404).json({ error: 'Route not found.' }));
app.use(errorHandler);

const start = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected.');
    await sequelize.sync({ alter: true });
    console.log('✅ Models synced.');
    app.listen(PORT, () => {
      console.log(`🚀 Server running on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('❌ Failed to start server:', err);
    process.exit(1);
  }
};

start();