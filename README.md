# 🔐 Secure Gallery

A full-stack **end-to-end encrypted** photo storage and sharing app built with **Flutter (Web + Android)** and **Node.js**.

Images are encrypted **on the client device** before upload — the server never sees raw image data or encryption keys.

---

## ✨ Features

- 🔒 **Client-side AES-256-GCM / ChaCha20-Poly1305** encryption before upload
- 🔑 **RSA-OAEP secure sharing** — only the recipient can decrypt
- 📱 **Cross-platform** — Flutter Web + Android
- 👤 **JWT authentication** + bcrypt password hashing
- 🛡️ **Admin dashboard** — manage users, media, and audit logs
- 📋 **Audit trail** — every login, upload, and share is logged
- 🚫 **Rate limiting** — 100 requests / 15 minutes per IP
- 👤 **User profile** — change email, password, regenerate RSA keys

---

## 🛠️ Tech Stack

| Layer     | Technology                                          |
|-----------|-----------------------------------------------------|
| Frontend  | Flutter (Dart) — Web + Android                     |
| Backend   | Node.js + Express                                   |
| Database  | PostgreSQL + Sequelize ORM                          |
| Auth      | JWT + bcrypt                                        |
| Crypto    | AES-GCM, ChaCha20, RSA-OAEP (Web Crypto + fast_rsa)|
| HTTP      | Dio                                                 |
| Storage   | flutter_secure_storage                              |

---

## 📁 Project Structure

```
secure-gallery/
├── app/                        ← Node.js Backend
│   ├── src/
│   │   ├── app.js              ← Server entry point
│   │   ├── controllers/        ← Business logic
│   │   ├── models/             ← User, Media, Share, AuditLog
│   │   ├── middleware/         ← JWT auth + admin guard
│   │   └── routes/             ← API route definitions
│   ├── uploads/                ← Encrypted files (auto-created)
│   ├── .env.example            ← Environment variables template
│   └── package.json
│
└── gallery_app/                ← Flutter Frontend
    ├── lib/
    │   ├── main.dart
    │   ├── config/             ← API base URL
    │   ├── models/             ← Dart data classes
    │   ├── providers/          ← State management
    │   ├── services/           ← API + crypto + storage
    │   └── screens/            ← All UI screens
    ├── android/                ← Android build config
    ├── web/                    ← Web build config + JS crypto
    └── pubspec.yaml
```

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Download |
|------|---------|----------|
| Node.js | v18+ | https://nodejs.org |
| PostgreSQL | v14+ | https://www.postgresql.org |
| Flutter SDK | v3.3+ | https://flutter.dev/docs/get-started/install |
| Android Studio | Latest | https://developer.android.com/studio (for Android) |
| Git | Any | https://git-scm.com |

---

### Step 1 — Clone the Repository

```bash
git clone https://github.com/YourUsername/secure-gallery.git
cd secure-gallery
```

---

### Step 2 — Set Up the Backend

```bash
cd app
npm install
```

Create your `.env` file:

```bash
# Windows
copy .env.example .env

# Mac / Linux
cp .env.example .env
```

Edit `.env` with your values:

```env
PORT=4000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=gallery_db
DB_USER=postgres
DB_PASSWORD=your_postgres_password
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

Start the backend server:

```bash
node src/app.js
```

You should see:
```
✅ Database connected.
✅ Models synced.
🚀 Server running on http://localhost:4000
```

> Tables are created automatically on first run. Leave this terminal open.

---

## 🌐 Running on Web

Make sure the backend is running first (Step 2), then:

```bash
cd gallery_app
flutter pub get
flutter run -d chrome
```

Or use web-server mode (open the URL manually):

```bash
flutter run -d web-server --web-port 8080
```

Then open **http://localhost:8080** in Chrome.

---

## 📱 Running on Android (USB / Physical Device)

### Prerequisites for Android

1. Install **Android Studio** from https://developer.android.com/studio
2. Open Android Studio → **SDK Manager** → install:
   - Android SDK Platform 34
   - Android SDK Build-Tools
   - NDK (Side by side) `27.0.12077973`

### Steps

**1. Enable Developer Mode on your phone:**
- Go to **Settings → About phone**
- Tap **Build number** 7 times
- Go back to **Settings → Developer options**
- Enable **USB debugging**

**2. Connect your phone via USB:**
- Plug in the cable
- Tap **Allow** on any USB debugging popup on the phone

**3. Verify Flutter sees the device:**
```bash
flutter devices
```
Your phone should appear in the list.

**4. Update the API URL for your network:**

Open `gallery_app/lib/config/api_config.dart` and set your PC's local IP:

```dart
static String get baseUrl =>
    kIsWeb ? 'http://YOUR_PC_IP:4000' : 'http://YOUR_PC_IP:4000';
```

Find your PC's IP by running:
```bash
# Windows
ipconfig
# Look for: IPv4 Address under Wi-Fi
```

> Make sure your phone and PC are on the **same Wi-Fi network**.

**5. Allow port 4000 through Windows Firewall** (run as Administrator):
```cmd
netsh advfirewall firewall add rule name="Node.js Port 4000" dir=in action=allow protocol=TCP localport=4000
```

**6. Run the app on your phone:**
```bash
cd gallery_app
flutter run
```

---

## 📦 Building the Android APK

To generate an installable `.apk` file:

```bash
cd gallery_app
flutter build apk --debug
```

The APK will be at:
```
gallery_app/build/app/outputs/flutter-apk/app-debug.apk
```

**Install it on your phone:**
- Copy the `.apk` file to your phone (USB, Google Drive, etc.)
- On the phone: open the file → tap **Install**
- If blocked: **Settings → Security → Allow install from unknown sources**

For a release (production) APK:
```bash
flutter build apk --release
```

---

## 📲 Running on Both Web + Android Simultaneously

**Terminal 1 — Backend:**
```bash
cd app
node src/app.js
```

**Terminal 2 — Web:**
```bash
cd gallery_app
flutter run -d chrome
```

**Terminal 3 — Android (phone connected via USB):**
```bash
cd gallery_app
flutter run -d <your-device-id>
```

Get your device ID with `flutter devices`.

Or run on all devices at once:
```bash
flutter run -d all
```

---

## 🔑 Admin Access

Set `ADMIN_EMAIL=your@email.com` in `.env` before starting the server.
That account becomes super-admin automatically after registering.

Or promote any user via SQL:
```sql
UPDATE users SET role = 'admin' WHERE email = 'user@example.com';
```

---

## 🔐 How Encryption Works

### Upload
```
Image bytes
  → AES-256-GCM encrypt (random key + IV per image)
  → Ciphertext uploaded to server
  → AES key saved ONLY on your device
```

### Share
```
Recipient's RSA public key (from server)
  → RSA-OAEP wraps the AES key
  → Encrypted key stored on server
  → Only recipient's private key can unlock it
```

### View Shared Image
```
Fetch RSA-encrypted AES key from server
  → Decrypt with your local RSA private key
  → Download encrypted image
  → AES-GCM decrypt → original image
```

---

## 📡 API Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/auth/register` | Create account | None |
| POST | `/api/auth/login` | Login, get JWT | None |
| PUT | `/api/auth/public-key` | Update RSA public key | Required |
| GET | `/api/media` | List own images | Required |
| POST | `/api/media/upload` | Upload encrypted image | Required |
| GET | `/api/media/:id` | Download own image | Required |
| DELETE | `/api/media/:id` | Delete image | Required |
| POST | `/api/share` | Share with another user | Required |
| GET | `/api/share/inbox` | View received shares | Required |
| GET | `/api/share/:id/key` | Get encrypted AES key | Required |
| GET | `/api/share/:id/download` | Download shared image | Required |
| DELETE | `/api/share/:id` | Delete share | Required |
| GET | `/api/users/by-email` | Look up user | Required |
| GET | `/api/profile` | Get profile + stats | Required |
| PATCH | `/api/profile` | Update email/password | Required |
| DELETE | `/api/profile` | Delete account | Required |
| GET | `/api/admin/stats` | Dashboard stats | Admin |
| GET | `/api/admin/users` | List all users | Admin |
| DELETE | `/api/admin/users/:id` | Delete user | Admin |
| PATCH | `/api/admin/users/:id/role` | Change role | Admin |
| PATCH | `/api/admin/users/:id/ban` | Ban / unban user | Admin |
| GET | `/api/admin/media` | List all media | Admin |
| DELETE | `/api/admin/media/:id` | Force delete media | Admin |
| GET | `/api/admin/audit-logs` | View audit logs | Admin |

---

## 🗄️ Database Schema

```
users       → user_id, email, password_hash, public_key, role, is_banned, created_at
media       → media_id, owner_id, filename, algo, iv, ciphertext_path
shares      → share_id, media_id, sender_id, receiver_id, encrypted_key, expires_at
audit_logs  → log_id, user_id, action, ip, timestamp
```

---

## 🖥️ Screens

| Screen | Description |
|--------|-------------|
| Login | JWT auth with glassmorphism UI |
| Register | Account creation + RSA key generation |
| Gallery | Encrypted image grid with selection mode |
| Upload | Multi-image pick → encrypt → upload |
| View Image | Download + decrypt + display |
| Safe Share | RSA-encrypt AES key → share with user |
| Inbox | Received shares → decrypt and view |
| Profile | Edit account, change password, manage keys |
| Admin Dashboard | Stats, users, media, audit logs |

---

## 🔒 Security Notes

- Server stores **only ciphertext** — cannot decrypt any image
- RSA private keys stored on **client device only** (never sent to server)
- AES keys stored on **owner's device only**
- Passwords hashed with **bcrypt (12 rounds)**
- JWT tokens expire after **7 days**
- `.env` and `uploads/` are excluded from git via `.gitignore`

---

## 📄 License

This project is for educational purposes.
