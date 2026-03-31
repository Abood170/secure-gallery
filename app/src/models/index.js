'use strict';
const { DataTypes } = require('sequelize');
const sequelize     = require('../config/database');

// ── Model definitions ──────────────────────────────────────────────────────────

const User = sequelize.define('User', {
  user_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    validate: { isEmail: true },
  },
  password_hash: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  public_key: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  // Role-based access control: 'user' (default) or 'admin'
  role: {
    type: DataTypes.STRING,
    allowNull: false,
    defaultValue: 'user',
    validate: { isIn: [['user', 'admin']] },
  },
  // Ban flag: banned users cannot authenticate
  is_banned: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
}, { tableName: 'users', timestamps: false });

// ──────────────────────────────────────────────────────────────────────────────

const Media = sequelize.define('Media', {
  media_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  owner_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  filename: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  algo: {
    type: DataTypes.STRING,
    allowNull: false,
    validate: { isIn: [['AES-GCM', 'ChaCha20-Poly1305']] },
  },
  iv: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  ciphertext_path: {
    type: DataTypes.STRING,
    allowNull: false,
  },
}, { tableName: 'media', timestamps: false });

// ──────────────────────────────────────────────────────────────────────────────

const Share = sequelize.define('Share', {
  share_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  media_id:    { type: DataTypes.INTEGER, allowNull: false },
  sender_id:   { type: DataTypes.INTEGER, allowNull: false },
  receiver_id: { type: DataTypes.INTEGER, allowNull: false },
  // RSA-encrypted symmetric key (Base64)
  encrypted_key: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  expires_at: {
    type: DataTypes.DATE,
    allowNull: true,
    defaultValue: null,
  },
}, { tableName: 'shares', timestamps: false });

// ──────────────────────────────────────────────────────────────────────────────

const AuditLog = sequelize.define('AuditLog', {
  log_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  user_id:   { type: DataTypes.INTEGER, allowNull: false },
  action:    { type: DataTypes.STRING,  allowNull: false },
  ip:        { type: DataTypes.STRING,  allowNull: true  },
  timestamp: { type: DataTypes.DATE,   defaultValue: DataTypes.NOW },
}, { tableName: 'audit_logs', timestamps: false });

// ── Associations ───────────────────────────────────────────────────────────────

User.hasMany(Media,    { foreignKey: 'owner_id',    as: 'media'          });
Media.belongsTo(User,  { foreignKey: 'owner_id',    as: 'owner'          });

User.hasMany(Share,    { foreignKey: 'sender_id',   as: 'sentShares'     });
User.hasMany(Share,    { foreignKey: 'receiver_id', as: 'receivedShares' });
Share.belongsTo(User,  { foreignKey: 'sender_id',   as: 'sender'         });
Share.belongsTo(User,  { foreignKey: 'receiver_id', as: 'receiver'       });

Media.hasMany(Share,   { foreignKey: 'media_id',    as: 'shares'         });
Share.belongsTo(Media, { foreignKey: 'media_id',    as: 'media'          });

User.hasMany(AuditLog,      { foreignKey: 'user_id', as: 'auditLogs' });
AuditLog.belongsTo(User,    { foreignKey: 'user_id', as: 'user'      });

module.exports = { sequelize, User, Media, Share, AuditLog };
