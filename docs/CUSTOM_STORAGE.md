# Custom Storage & Open-Source Extensibility Guide

Notlyfe is designed so the project maintainer's Supabase instance or Google Drive integration never becomes a cost or scaling bottleneck for self-hosters, forks, or power users.

Both **Course Files** and **E2EE Notes + Default Note Styles** run through a pluggable registry: `StorageBackendRegistry` (`lib/services/storage/storage_provider.dart`).

---

## 1. Built-In Storage Backends (No Code Needed)

Open **Settings → Storage & Custom Locations** in the app to configure, select, and **test** any of these built-in backends:

### Course Files Storage
1. **Google Drive (`Notlyfe/<Course>`)** — Default. Uses strict `drive.file` scope (only accesses Notlyfe's own folder).
2. **WebDAV / Nextcloud** — Works with Nextcloud, OwnCloud, Synology NAS, Koofr, Hetzner Storage Box, etc.
3. **Custom REST / Self-Hosted API** — Works with any Cloudflare Worker, MinIO/S3 proxy, or self-hosted HTTP server.
4. **Custom Local / Synced Folder** — Saves files to any local directory (e.g., Syncthing, Nextcloud folder, SD card).

### Notes Storage & Sync Location
1. **Notlyfe Cloud (Supabase • Default)** — Built-in E2EE cloud sync.
2. **Google Drive (`Notlyfe/Notes`)** — Zero-cost E2EE JSON sync inside your own Google Drive.
3. **WebDAV / Nextcloud Notes** — Syncs E2EE note JSON + `default_style.json` to your WebDAV server.
4. **Custom REST / Self-Hosted Notes** — Syncs E2EE note JSON + `default_style.json` to your own API.
5. **Custom Local Folder** — Stores E2EE note JSON + `default_style.json` locally / via external sync.

All secrets (WebDAV passwords, Bearer tokens, vault keys) are encrypted on-device with AES-256-CBC + HMAC-SHA256 via `SecureStorageService`. Remote endpoints require `https://` (plain `http://` is permitted only for `localhost`, `127.0.0.1`, or private RFC1918 LAN IPs).

---

## 2. Custom REST API Contract (For Self-Hosting)

If you select **Custom REST / Self-Hosted API**, implement these endpoints:

- `GET /health` → `200 OK`
- `POST /files` (multipart form: `file`, `courseId`, `courseTitle`, `userId`, `fileName`, `mimeType`) → `{ "id": "...", "fileName": "...", "fileType": "...", "fileSize": 123 }`
- `GET /files?courseId=<id>&userId=<uid>` → `[ { "id": "...", "fileName": "...", "fileType": "...", "fileSize": 123, "courseId": "..." } ]`
- `GET /files/<id>` → raw file bytes
- `DELETE /files/<id>` → `200` / `204`
- `GET /notes?userId=<uid>` → `[ { ...noteMap } ]`
- `PUT /notes/<id>` (JSON body: encrypted `Note.toSupabaseMap()`) → `200 OK`
- `DELETE /notes/<id>` → `200` / `204`
- `GET /notes/style/<uid>` → `NoteStyleSettings` JSON
- `PUT /notes/style/<uid>` → `200 OK`

---

## 3. Implementing & Registering Your Own Storage Provider in Dart

Implement `CustomFileStorageProvider` and/or `CustomNotesStorageProvider`:

```dart
class MyCustomNotesProvider extends CustomNotesStorageProvider {
  @override String get typeId => 'my_s3_notes';
  @override String get displayName => 'My S3 Bucket Notes';
  @override String get description => 'Encrypted notes in my personal S3 bucket.';

  @override Future<bool> isConfigured() async => true;
  @override Future<StorageTestResult> testConnection() async =>
      const StorageTestResult(success: true, message: 'OK');
  @override Future<List<Note>> fetchNotes(String userId) async => [];
  @override Future<void> upsertNote(Note note) async {}
  @override Future<void> deleteNote(Note note) async {}
}
```

Register it during startup (before `runApp`):

```dart
StorageBackendRegistry.instance.registerNotesProvider(MyCustomNotesProvider());
```

---

## 4. Running the Storage Provider Contract Tests

Any custom provider can be verified against Notlyfe's contract test helpers in `test/custom_storage_test.dart`:

```bash
flutter test test/custom_storage_test.dart
```

Reuse `runCustomFileStorageContractTests(...)` and `runCustomNotesStorageContractTests(...)` directly with your own provider implementation to guarantee full compatibility with Notlyfe.
