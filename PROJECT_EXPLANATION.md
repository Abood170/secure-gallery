# Secure Gallery — Complete Project Explanation

---

## What Is This Application?

**Secure Gallery** is a full-stack encrypted photo storage and sharing application.
Users can upload images that are **encrypted on the client device** before being sent
to the server. The server **never sees the raw image** — it only stores ciphertext
(scrambled data). Images can also be shared securely between users using RSA encryption.

---

## How to Start the Application

### Step 1 — Start the Backend (Node.js API)

```
cd "Qusai Project/app"
npm install          ← only needed once
node src/app.js      ← or: npx nodemon src/app.js (auto-restart on changes)
```

The server starts on **http://localhost:4000**

You need a running PostgreSQL database. The connection settings are in `app/.env`:
```
DB_NAME=gallery_db
DB_USER=postgres
DB_PASSWORD=yazan03
DB_HOST=localhost
DB_PORT=3000
JWT_SECRET=your_secret_key
JWT_EXPIRES_IN=7d
ADMIN_EMAIL=admin@gallery.com
UPLOAD_DIR=uploads
MAX_FILE_SIZE_MB=20
```

On first run, Sequelize automatically creates all database tables (`alter: true`).

### Step 2 — Start the Frontend (Flutter Web)

```
cd "Qusai Project/gallery_app"
flutter pub get      ← only needed once
flutter run -d chrome --web-port 8080
```

The app opens in Chrome at **http://localhost:8080**

---

## Project Folder Structure

```
Qusai Project/
├── app/                          ← Backend (Node.js + Express)
│   ├── src/
│   │   ├── app.js                ← Entry point — starts the server
│   │   ├── config/
│   │   │   ├── database.js       ← PostgreSQL connection via Sequelize
│   │   │   └── multer.js         ← File upload handler
│   │   ├── models/
│   │   │   └── index.js          ← Database tables (User, Media, Share, AuditLog)
│   │   ├── middleware/
│   │   │   ├── authenticate.js   ← JWT verification for protected routes
│   │   │   ├── requireAdmin.js   ← Admin-only route guard
│   │   │   └── errorHandler.js   ← Global error handler
│   │   ├── controllers/
│   │   │   ├── authController.js    ← Register, Login, Update public key
│   │   │   ├── mediaController.js   ← Upload, Download, Delete media
│   │   │   ├── shareController.js   ← Create/view/delete shares
│   │   │   ├── userController.js    ← Look up user by email
│   │   │   └── adminController.js   ← Admin dashboard data
│   │   └── routes/
│   │       ├── auth.js           ← /api/auth/*
│   │       ├── media.js          ← /api/media/*
│   │       ├── share.js          ← /api/share/*
│   │       ├── user.js           ← /api/users/*
│   │       └── admin.js          ← /api/admin/*
│   └── uploads/                  ← Encrypted files stored here on disk
│
└── gallery_app/                  ← Frontend (Flutter Web)
    ├── lib/
    │   ├── main.dart             ← App entry point
    │   ├── config/
    │   │   └── api_config.dart   ← All API URLs in one place
    │   ├── models/
    │   │   ├── media_item.dart   ← Dart class for a media record
    │   │   ├── share_item.dart   ← Dart class for a share record
    │   │   └── admin_models.dart ← Admin stats/user/media/log models
    │   ├── providers/
    │   │   ├── auth_provider.dart    ← Login/register/logout state
    │   │   ├── gallery_provider.dart ← Media list + inbox state
    │   │   └── admin_provider.dart   ← Admin dashboard state
    │   ├── services/
    │   │   ├── api_service.dart      ← Dio HTTP client + JWT interceptor
    │   │   ├── crypto_service.dart   ← AES-GCM, ChaCha20, RSA encryption
    │   │   ├── media_service.dart    ← Upload/download API calls
    │   │   ├── share_service.dart    ← Share API calls
    │   │   ├── storage_service.dart  ← Local key/token storage
    │   │   └── admin_service.dart    ← Admin API calls
    │   └── screens/
    │       ├── login_screen.dart         ← Login UI
    │       ├── register_screen.dart      ← Register UI + key generation
    │       ├── gallery_screen.dart       ← Main gallery grid
    │       ├── upload_screen.dart        ← Upload + encrypt image
    │       ├── view_image_screen.dart    ← Owner views their own image
    │       ├── share_screen.dart         ← Share image with another user
    │       ├── inbox_screen.dart         ← "Shared with Me" + decrypt view
    │       └── admin_dashboard_screen.dart ← Admin panel
    └── web/
        └── index.html            ← RSA crypto bridge (SubtleCrypto JS functions)
```

---

## Backend — Detailed Explanation

### `app/src/app.js` — Server Entry Point

This is where the backend starts. It:
1. Loads environment variables from `.env`
2. Creates an Express app
3. Enables **CORS** — allows the Flutter web app (port 8080) to call the API (port 4000).
   The `exposedHeaders` line lets the browser read custom response headers
   (`X-Algo`, `X-IV`, `X-Filename`, `X-Media-Id`) that carry encryption metadata.
4. Applies a **rate limiter** — each IP can make max 100 requests per 15 minutes
5. Registers all route groups under `/api/...`
6. Connects to PostgreSQL and auto-creates/updates tables (`sequelize.sync({ alter: true })`)
7. Starts listening on port 4000

---

### `app/src/config/database.js` — Database Connection

Creates the Sequelize ORM instance connected to PostgreSQL.
Settings come from environment variables (DB_NAME, DB_USER, DB_PASSWORD, etc.).
Uses a connection pool (max 10 simultaneous connections).

---

### `app/src/config/multer.js` — File Upload Handler

Configures how uploaded files are saved to disk:
- Saved to the `uploads/` folder
- Each file gets a unique name: `timestamp-randomnumber.bin`
- Max file size: 20 MB (configurable via `MAX_FILE_SIZE_MB`)
- Accepts any file type (because clients upload encrypted binary data, not raw images)

---

### `app/src/models/index.js` — Database Tables

Defines 4 database tables using Sequelize:

#### `users` table
| Column        | Type    | Description                              |
|---------------|---------|------------------------------------------|
| user_id       | integer | Primary key, auto-increment              |
| email         | string  | Unique, must be valid email format       |
| password_hash | string  | bcrypt hash of the password (never plain)|
| public_key    | text    | RSA public key (PEM format) for sharing  |
| role          | string  | 'user' (default) or 'admin'              |
| is_banned     | boolean | true = cannot log in                     |
| created_at    | date    | When account was created                 |

#### `media` table
| Column          | Type    | Description                           |
|-----------------|---------|---------------------------------------|
| media_id        | integer | Primary key                           |
| owner_id        | integer | Foreign key → users.user_id           |
| filename        | string  | Original filename (e.g. photo.jpg)    |
| algo            | string  | 'AES-GCM' or 'ChaCha20-Poly1305'     |
| iv              | string  | Base64 IV/nonce used for encryption   |
| ciphertext_path | string  | Path on disk to the encrypted file    |

#### `shares` table
| Column        | Type    | Description                               |
|---------------|---------|-------------------------------------------|
| share_id      | integer | Primary key                               |
| media_id      | integer | Which image is being shared               |
| sender_id     | integer | Who shared it                             |
| receiver_id   | integer | Who receives it                           |
| encrypted_key | text    | AES key encrypted with receiver's RSA key |
| expires_at    | date    | Optional expiry (null = never expires)    |

#### `audit_logs` table
| Column    | Type    | Description                          |
|-----------|---------|--------------------------------------|
| log_id    | integer | Primary key                          |
| user_id   | integer | Who performed the action             |
| action    | string  | 'LOGIN', 'UPLOAD', 'DOWNLOAD', etc.  |
| ip        | string  | IP address of the request            |
| timestamp | date    | When it happened                     |

**Associations** (relationships between tables):
- A User has many Media (owner)
- A User has many Shares (as sender and as receiver)
- A Media has many Shares
- A User has many AuditLogs

---

### `app/src/middleware/authenticate.js` — JWT Guard

Runs before any protected route. It:
1. Reads the `Authorization: Bearer <token>` header
2. Verifies the JWT using `JWT_SECRET`
3. If valid → attaches `{ userId, email }` to `req.user` and continues
4. If expired or invalid → returns 401 error

---

### `app/src/middleware/requireAdmin.js` — Admin Guard

Runs after `authenticate` on admin-only routes. It:
1. Checks if `req.user.email` matches the `ADMIN_EMAIL` env var → instant admin access
2. Otherwise → looks up the user in the DB and checks `role === 'admin'`
3. Also blocks banned accounts
4. If not admin → returns 403 error

---

### `app/src/controllers/authController.js` — Auth Logic

**register**
- Validates email + password
- Checks email is not already taken
- Hashes the password with bcrypt (12 rounds = very secure)
- Creates the user record with their RSA public key
- Returns the new `user_id`

**login**
- Finds the user by email
- Rejects banned accounts before checking password (security best practice)
- Verifies password with bcrypt
- Creates a JWT token with `{ userId, email }` — expires in 7 days
- Records a LOGIN audit log entry
- Returns `{ token, user_id, is_admin }`

**updatePublicKey**
- Lets an authenticated user update their stored public key
- Used when a user logs in on a new device and generates a new key pair

---

### `app/src/controllers/mediaController.js` — Media Logic

**listMedia** — Returns metadata of all images owned by the logged-in user (no files)

**upload**
- Receives the encrypted file via multipart form data (multer saves it to disk)
- Saves metadata (filename, algo, iv, disk path) to the `media` table
- Records an UPLOAD audit log entry
- Returns the new `media_id`

**download**
- Checks the requester owns the media
- Sends the file binary with custom headers:
  - `X-Algo` — encryption algorithm
  - `X-IV` — the IV needed to decrypt
  - `X-Filename` — the original filename
- Records a DOWNLOAD audit log entry

**deleteMedia** — Deletes the file from disk AND removes the database record

---

### `app/src/controllers/shareController.js` — Share Logic

**createShare** — Saves a share record. The sender has already RSA-encrypted the
AES key client-side before calling this. The server just stores the encrypted key blob.

**inbox** — Returns all shares where `receiver_id` = current user, including the
media metadata (filename, algo, iv) and sender email. Filters out expired shares.

**getEncryptedKey** — Returns the RSA-encrypted symmetric key for a specific share.
Only the intended receiver can call this.

**downloadShared** — Same as `download` but for a receiver, not the owner.
Checks the share belongs to the requester before sending the file.

**deleteShare** — Either the sender or receiver can delete a share.

---

### `app/src/controllers/adminController.js` — Admin Logic

**getStats** — Returns counts: total users, total media, total shares, active users, banned users

**listUsers** — Paginated list of all users with optional email search

**deleteUser** — Cascade deletes: disk files → media rows → share rows → audit logs → user row.
Guards: cannot delete `ADMIN_EMAIL` account or yourself.

**updateRole** — Promotes/demotes a user between 'user' and 'admin'

**toggleBan** — Bans or unbans a user. Cannot ban the super-admin.

**listAllMedia** — Paginated list of ALL media across all users (for moderation)

**deleteMedia** — Admin force-deletes any image (disk + DB)

**getAuditLogs** — Paginated audit log viewer

---

### `app/src/controllers/userController.js` — User Lookup

**getUserByEmail** — Looks up a user by email and returns their `user_id` and `public_key`.
Used by the Share screen to find the recipient before RSA-encrypting the key.

---

## Frontend — Detailed Explanation

### `gallery_app/web/index.html` — RSA Bridge

Because `fast_rsa` (the Dart RSA package) does not work on Flutter web, this file
defines three JavaScript functions that use the **browser's built-in SubtleCrypto API**:

- `nativeGenerateRsaKeyPair()` — generates RSA-2048 key pair, exports as PEM
- `nativeRsaEncrypt(publicKeyPem, dataB64)` — RSA-OAEP encrypt (SHA-256)
- `nativeRsaDecrypt(privateKeyPem, dataB64)` — RSA-OAEP decrypt (SHA-256)

Dart calls these via `@JS()` annotations in `crypto_service.dart`.

---

### `lib/main.dart` — App Entry Point

1. `WidgetsFlutterBinding.ensureInitialized()` — required before using Flutter
2. `ApiService.init()` — sets up the Dio HTTP client with the JWT interceptor
3. `runApp(SecureGalleryApp())` — starts the Flutter app

**`SecureGalleryApp`** wraps everything in:
- `MultiProvider` — makes `AuthProvider`, `GalleryProvider`, `AdminProvider`
  available anywhere in the widget tree
- `MaterialApp` with named routes for every screen

**`_SplashGate`** — the first screen shown:
- Checks if a JWT token is stored on the device
- If yes → goes to `/gallery` (or `/admin` if admin)
- If no → goes to `/login`

---

### `lib/config/api_config.dart` — API URLs

Central place for all API endpoint URLs. Automatically picks the right base URL:
- Flutter Web (`kIsWeb = true`) → `http://localhost:4000`
- Android emulator → `http://10.0.2.2:4000`

---

### `lib/services/api_service.dart` — HTTP Client

Creates a single Dio instance used by all services. The interceptor:
- Before every request → reads the JWT from storage and adds `Authorization: Bearer <token>`
- This means every API call is automatically authenticated

---

### `lib/services/storage_service.dart` — Local Storage

Uses `flutter_secure_storage` to persist data locally (encrypted on native, localStorage on web):

| Key                      | What is stored                        |
|--------------------------|---------------------------------------|
| `jwt_token`              | The JWT from the server               |
| `user_id`                | The logged-in user's ID               |
| `is_admin`               | Admin flag (true/false)               |
| `rsa_private_key_{id}`   | RSA private key (PEM) for user ID     |
| `rsa_public_key_{id}`    | RSA public key (PEM) for user ID      |
| `sym_key_{media_id}`     | AES key for each uploaded image       |

The RSA keys are **kept on logout** so that old shares remain decryptable when you log back in.

---

### `lib/services/crypto_service.dart` — Encryption Engine

**RSA (key wrapping)**
- `generateRsaKeyPair()` → RSA-2048 PKCS8/SPKI key pair
- `rsaEncryptKey(keyBase64, publicKeyPem)` → encrypts an AES key with recipient's public key
- `rsaDecryptKey(encryptedKeyBase64, privateKeyPem)` → recovers the AES key

On web: calls the JavaScript bridge functions (`nativeRsaEncrypt`, `nativeRsaDecrypt`)
On native: uses the `fast_rsa` package

**AES-256-GCM (`encryptAesGcm` / `decryptAesGcm`)**
- Generates a random 256-bit key and 12-byte nonce for every encryption
- Output: `ciphertext + 16-byte authentication tag` combined in one byte array
- The auth tag guarantees the data was not tampered with

**ChaCha20-Poly1305 (`encryptChaCha20` / `decryptChaCha20`)**
- Alternative algorithm — faster on devices without AES hardware acceleration
- Same output format: `ciphertext + 16-byte tag`

---

### `lib/services/media_service.dart` — Media API Calls

- `uploadMedia()` — sends the encrypted bytes + metadata as multipart form
- `downloadMedia(id)` — downloads ciphertext for owner; reads `X-Algo` and `X-IV` from headers
- `downloadShared(id)` — same but for a share recipient
- The response headers carry the encryption metadata needed to decrypt

---

### `lib/services/share_service.dart` — Share API Calls

- `getUserByEmail(email)` — finds a recipient's user_id and public_key
- `createShare(...)` — sends the share to the server
- `getInbox()` — fetches all shares sent to the current user
- `getEncryptedKey(shareId)` — fetches the RSA-encrypted AES key for decryption
- `deleteShare(shareId)` — removes a share

---

### `lib/providers/auth_provider.dart` — Auth State

`ChangeNotifier` that holds `isLoggedIn`, `isAdmin`, `loading`, `error`.

**register()** flow:
1. Generates RSA key pair (via SubtleCrypto on web)
2. Sends email + password + public key to `/api/auth/register`
3. Saves userId + key pair to local storage

**login()** flow:
1. Sends credentials to `/api/auth/login`
2. Saves JWT, userId, isAdmin flag to local storage
3. Ensures the device has an RSA key pair (migrates legacy keys or generates new)

**logout()** — deletes JWT and session data but keeps RSA keys

---

### `lib/providers/gallery_provider.dart` — Gallery State

Holds the list of the user's media and their inbox.
`loadMedia()` and `loadInbox()` call the respective services and notify the UI.
`prependMedia()` and `removeMedia()` update the list without a full reload.

---

### `lib/providers/admin_provider.dart` — Admin State

Manages all admin dashboard data: stats, paginated users, media, audit logs.
All action methods (`toggleBan`, `updateRole`, `deleteUser`, `deleteMedia`) do
optimistic UI updates (remove/update immediately) then refresh stats from server.

---

## Screens — What Each Screen Does

### `login_screen.dart` — Login
- Email + password fields with glassmorphism design
- Calls `AuthProvider.login()`
- On success → navigates to `/gallery` or `/admin`

### `register_screen.dart` — Register
- Email + password + confirm password fields
- On submit: shows a 3-step animation (Generating Keys → Securing → Completing)
  while the real registration happens concurrently in the background
- On success → navigates to `/login`

### `gallery_screen.dart` — Main Gallery
- Shows all the user's encrypted images as a grid
- Each tile shows a lock icon (images are stored encrypted, no preview)
- Clicking a tile → opens the image (downloads + decrypts)
- FAB → goes to `/upload`
- Top bar buttons → share inbox (`/inbox`) and logout

### `upload_screen.dart` — Upload Image
- User picks an image from their device
- Chooses encryption algorithm (AES-256-GCM or ChaCha20-Poly1305)
- On upload: encrypts the image in the browser, then uploads the ciphertext
- The AES key is saved locally by `media_id`
- Shows a 3-step animation: Encrypting → Uploading → Done

### `view_image_screen.dart` — View Own Image
- Navigated to from the gallery grid
- Downloads the ciphertext from the server
- Retrieves the AES key from local storage (by media_id)
- Decrypts locally and displays with `Image.memory`
- Uses `InteractiveViewer` for pinch-to-zoom

### `share_screen.dart` — Share Image
- Enter recipient's email address
- Fetches recipient's RSA public key from the server
- RSA-encrypts the AES key with the recipient's public key (client-side only)
- Sends the encrypted key + media reference to the server
- Shows 4-step animation: Looking Up → Encrypting Key → Sending → Done

### `inbox_screen.dart` — Shared With Me
- Lists all images others have shared with the user
- Each card shows: filename, sender email, encryption algorithm
- Click the eye icon → decrypts and displays the image:
  1. Fetches the RSA-encrypted AES key from server
  2. Uses the user's RSA private key (stored locally) to decrypt it
  3. Downloads the ciphertext
  4. Decrypts with the recovered AES key
  5. Displays in a full-screen viewer

### `admin_dashboard_screen.dart` — Admin Panel
- Accessible at `/admin` for users with `role = 'admin'` or matching `ADMIN_EMAIL`
- 4 tabs:
  - **Stats** — user counts, media counts, share counts
  - **Users** — searchable list; can ban/unban, promote/demote, delete users
  - **Media** — browse and delete any image in the system
  - **Logs** — view all audit log entries

---

## Complete Data Flow — Upload an Image

```
User picks image
    │
    ▼
Flutter reads file bytes
    │
    ▼
CryptoService.encrypt(bytes, algo)
    ├── Generates random 256-bit AES key
    ├── Generates random 12-byte IV/nonce
    ├── AES-GCM encrypts → ciphertext + auth tag
    └── Returns { ciphertext, iv, keyBase64 }
    │
    ▼
StorageService.saveSymmetricKey(mediaId, keyBase64)
  ← saves AES key locally (never sent to server)
    │
    ▼
MediaService.uploadMedia(ciphertext, filename, algo, iv)
    │
    ▼
POST /api/media/upload  (multipart)
    ├── multer saves ciphertext to uploads/xxx.bin
    └── DB: INSERT INTO media (owner_id, filename, algo, iv, ciphertext_path)
    │
    ▼
Server returns { media_id }
```

---

## Complete Data Flow — Share an Image

```
Sender enters recipient email
    │
    ▼
GET /api/users/by-email?email=...
    └── Returns { user_id, public_key }
    │
    ▼
StorageService.getSymmetricKey(mediaId)
    └── Retrieves local AES key for this image
    │
    ▼
CryptoService.rsaEncryptKey(keyBase64, recipientPublicKey)
    └── Browser SubtleCrypto: RSA-OAEP encrypt the AES key
    │
    ▼
POST /api/share
    └── DB: INSERT INTO shares (media_id, sender_id, receiver_id, encrypted_key)
    ← Server stores ONLY the encrypted key blob (cannot decrypt it — no private key)
```

---

## Complete Data Flow — View a Shared Image

```
Receiver opens Inbox, clicks view
    │
    ▼
GET /api/share/{id}/key
    └── Returns { encrypted_key } — the RSA-encrypted AES key
    │
    ▼
StorageService.getPrivateKey()
    └── Retrieves recipient's RSA private key from local storage
    │
    ▼
CryptoService.rsaDecryptKey(encryptedKey, privateKey)
    └── Browser SubtleCrypto: RSA-OAEP decrypt → recovers AES key
    │
    ▼
GET /api/share/{id}/download
    └── Server sends ciphertext file
        Response headers: X-Algo, X-IV, X-Filename
    │
    ▼
CryptoService.decrypt(ciphertext, iv, aesKey, algo)
    └── AES-GCM decrypt + auth tag verification → original image bytes
    │
    ▼
Image.memory(plainBytes) — displayed in-browser
    Server never had the AES key — it cannot decrypt the image
```

---

## Security Design Summary

| Concern               | How it is handled                                          |
|-----------------------|------------------------------------------------------------|
| Passwords             | bcrypt with 12 rounds — never stored plain                 |
| Authentication        | JWT tokens, 7-day expiry, verified on every request        |
| Image confidentiality | AES-256-GCM or ChaCha20-Poly1305 — encrypted client-side  |
| Key management        | AES keys stored only on the owner's device                 |
| Secure sharing        | AES key wrapped with recipient's RSA-2048 public key       |
| Data integrity        | AES-GCM auth tag prevents tampering                        |
| Admin access          | DB role check + super-admin env var, checked per request   |
| Abuse prevention      | Rate limiting (100 req/15 min per IP)                      |
| Audit trail           | Every login/upload/download recorded with timestamp + IP   |

---

## Key Technical Decisions

**Why encrypt on the client?**
The server is a "dumb" storage backend. Even if the server is compromised,
the attacker gets only encrypted blobs — they cannot recover any image.

**Why two algorithms (AES-GCM and ChaCha20)?**
AES-256-GCM is the standard; ChaCha20-Poly1305 is faster on devices without
dedicated AES hardware (common in some Android phones).

**Why RSA for key sharing?**
RSA-OAEP allows the sender to encrypt the AES key using only the recipient's
public key. Only the recipient's private key (never uploaded to the server)
can decrypt it. The server stores the encrypted key but cannot use it.

**Why SubtleCrypto for RSA on web?**
The `fast_rsa` Dart package requires native binaries that do not run in a
browser. The browser's own SubtleCrypto API provides the same RSA-OAEP
functionality and is faster.

**Why keep RSA keys on logout?**
If keys were deleted on logout, all received shares would become permanently
undecryptable. The session (JWT) is cleared but keys persist so the user
can still decrypt old shared images after logging back in.
