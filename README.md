# 🔐 Secure Gallery

A full-stack encrypted photo storage and sharing application built with **Flutter Web** and **Node.js**.

Images are encrypted **on the client device** before being uploaded — the server never sees raw image data.

---

## ✨ Features

- 🔒 **Client-side encryption** — AES-256-GCM or ChaCha20-Poly1305
- 🔑 **Secure sharing** — RSA-2048 key wrapping (only the recipient can decrypt)
- 👤 **User accounts** — JWT authentication, bcrypt password hashing
- 🛡️ **Admin dashboard** — manage users, media, and audit logs
- 📋 **Audit trail** — every login, upload, and download is logged
- 🚫 **Rate limiting** — 100 requests per 15 minutes per IP

---

## 🛠️ Tech Stack

| Layer     | Technology                          |
|-----------|-------------------------------------|
| Frontend  | Flutter Web (Dart)                  |
| Backend   | Node.js + Express                   |
| Database  | PostgreSQL + Sequelize ORM          |
| Auth      | JWT (jsonwebtoken) + bcrypt         |
| Crypto    | AES-GCM, ChaCha20, RSA via Web Crypto API |
| HTTP      | Dio (Flutter)                       |
| Storage   | flutter_secure_storage              |

---

## 📁 Project Structure

```
Qusai Project/
├── app/                  ← Node.js Backend
│   ├── src/
│   │   ├── app.js        ← Server entry point
│   │   ├── config/       ← Database + file upload config
│   │   ├── models/       ← User, Media, Share, AuditLog
│   │   ├── middleware/   ← JWT auth + admin guard
│   │   ├── controllers/  ← Business logic
│   │   └── routes/       ← API route definitions
│   ├── uploads/          ← Encrypted files (auto-created)
│   └── .env              ← Environment variables (not in git)
│
└── gallery_app/          ← Flutter Frontend
    └── lib/
        ├── main.dart
        ├── config/       ← API URLs
        ├── models/       ← Dart data classes
        ├── providers/    ← State management
        ├── services/     ← API + crypto + storage
        └── screens/      ← All UI screens
```

---

## 🚀 Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) v18+
- [PostgreSQL](https://www.postgresql.org/) v14+
- [Flutter](https://flutter.dev/) v3.x (with Chrome)
- [Git](https://git-scm.com/)

---

### 1. Clone the Repository

```bash
git clone https://github.com/YourUsername/secure-gallery.git
cd secure-gallery
```

---

### 2. Set Up the Backend

```bash
cd app
npm install
```

Create a `.env` file (copy from the example):

```bash
copy .env.example .env
```

Edit `.env` with your real values:

```env
PORT=4000
DB_NAME=gallery_db
DB_USER=postgres
DB_PASSWORD=your_postgres_password
DB_HOST=localhost
DB_PORT=5432
JWT_SECRET=any_long_random_string_here
JWT_EXPIRES_IN=7d
ADMIN_EMAIL=admin@yourdomain.com
UPLOAD_DIR=uploads
MAX_FILE_SIZE_MB=20
```

Create the PostgreSQL database:

```sql
CREATE DATABASE gallery_db;
```

Start the server:

```bash
node src/app.js
```

The API will be running at **http://localhost:4000**
Tables are created automatically on first run.

---

### 3. Set Up the Frontend

```bash
cd gallery_app
flutter pub get
flutter run -d chrome --web-port 8080
```

The app opens at **http://localhost:8080**

---

## 🔑 Admin Access

To access the Admin Dashboard, either:

1. Set `ADMIN_EMAIL=your@email.com` in `.env` — that account becomes super-admin automatically
2. Or promote any user to admin via the database:
   ```sql
   UPDATE users SET role = 'admin' WHERE email = 'user@example.com';
   ```

---

## 📡 API Endpoints

| Method | Endpoint                      | Description                  | Auth     |
|--------|-------------------------------|------------------------------|----------|
| POST   | `/api/auth/register`          | Create account               | None     |
| POST   | `/api/auth/login`             | Login, get JWT               | None     |
| PUT    | `/api/auth/public-key`        | Update RSA public key        | Required |
| GET    | `/api/media`                  | List own images              | Required |
| POST   | `/api/media/upload`           | Upload encrypted image       | Required |
| GET    | `/api/media/:id`              | Download own image           | Required |
| DELETE | `/api/media/:id`              | Delete own image             | Required |
| POST   | `/api/share`                  | Share image with user        | Required |
| GET    | `/api/share/inbox`            | View received shares         | Required |
| GET    | `/api/share/:id/key`          | Get encrypted AES key        | Required |
| GET    | `/api/share/:id/download`     | Download shared image        | Required |
| DELETE | `/api/share/:id`              | Delete a share               | Required |
| GET    | `/api/users/by-email`         | Look up user by email        | Required |
| GET    | `/api/admin/stats`            | Dashboard stats              | Admin    |
| GET    | `/api/admin/users`            | List all users               | Admin    |
| DELETE | `/api/admin/users/:id`        | Delete a user                | Admin    |
| PATCH  | `/api/admin/users/:id/role`   | Change user role             | Admin    |
| PATCH  | `/api/admin/users/:id/ban`    | Ban / unban user             | Admin    |
| GET    | `/api/admin/media`            | List all media               | Admin    |
| DELETE | `/api/admin/media/:id`        | Force delete any media       | Admin    |
| GET    | `/api/admin/audit-logs`       | View audit logs              | Admin    |

---

## 🔐 How Encryption Works

### Uploading an Image
```
Image bytes
  → AES-256-GCM encrypt (random key + IV generated per image)
  → Ciphertext uploaded to server
  → AES key saved ONLY on your device (never sent to server)
```

### Sharing an Image
```
Recipient's RSA public key (fetched from server)
  → RSA-OAEP encrypt the AES key
  → Encrypted key stored on server
  → Only recipient's private key can unlock it
```

### Viewing a Shared Image
```
Fetch RSA-encrypted AES key from server
  → Decrypt with your local RSA private key
  → Download ciphertext from server
  → AES-GCM decrypt → original image
  (Server never had the AES key)
```

---

## 🗄️ Database Schema

```
users         → user_id, email, password_hash, public_key, role, is_banned
media         → media_id, owner_id, filename, algo, iv, ciphertext_path
shares        → share_id, media_id, sender_id, receiver_id, encrypted_key, expires_at
audit_logs    → log_id, user_id, action, ip, timestamp
```

---

## 🔒 Security Notes

- The server stores **only ciphertext** — it cannot decrypt any image
- RSA private keys are stored on the **client device only**
- AES symmetric keys are stored on the **owner's device only**
- Passwords are hashed with **bcrypt (12 rounds)**
- JWT tokens expire after **7 days**
- All sensitive files are excluded from this repository via `.gitignore`

---

## 📸 Screens

| Screen | Description |
|---|---|
| Login | JWT authentication with glassmorphism UI |
| Register | Account creation + RSA key generation animation |
| Gallery | Encrypted image grid with lock icons |
| Upload | Pick image → choose algorithm → encrypt → upload |
| View Image | Download + decrypt + display with pinch-to-zoom |
| Safe Share | RSA-encrypt AES key → share with another user |
| Shared With Me | Inbox of received shares + decrypt-to-view |
| Admin Dashboard | Stats, user management, media moderation, audit logs |

---

## 📄 License

This project is for educational purposes.
