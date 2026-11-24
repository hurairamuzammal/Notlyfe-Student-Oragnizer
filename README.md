# Notlyfe

Open-source, end-to-end encrypted student workspace built with Flutter for Android, Linux, and Windows. Organize courses, tasks, calendar events, study files, and rich-text notes with pluggable cloud or self-hosted storage.

## Features

- **Courses & Study Files**: Create color-coded course cards, upload lecture PDFs/slides, download for offline reading, and manage local files safely.
- **Rich-Text Notes (E2EE)**: Write formatted notes (headings, highlights, checklists, typography, paper themes) encrypted client-side with AES-256-CBC + HMAC-SHA256 (`enc:v2:`) before leaving your device.
- **Persistent Google Drive Setup**: Connect Google Drive once during onboarding or in Settings; tokens are encrypted locally (`SecureStorageService` v3) and automatically refreshed across restarts.
- **Pluggable Storage Backends**: Store files and notes in Google Drive, Nextcloud/WebDAV, a self-hosted HTTP server, a local directory, or Supabase. See [`docs/CUSTOM_STORAGE.md`](docs/CUSTOM_STORAGE.md).
- **Offline-First Sync**: Local SQLite (`sqflite` on mobile, `sqflite_common_ffi` on Linux/Windows) keeps courses, notes, and todos available offline and merges changes safely when reconnected.
- **Tasks, Calendar & Focus Tools**: Draggable todo sheet, Gregorian/Hijri calendar, study clock, and optional BYOK Gemini AI assistant.

## Security & Minimum Version Policy

- **Client-Side E2EE (`enc:v2:`)**: Notes and todos are encrypted with domain-separated AES-256 and HMAC-SHA256 keys derived from each user's 256-bit vault key. Encryption fails closed if the vault is not initialized, and keys are scrubbed from memory on sign-out.
- **Encrypted Local Secrets (`v3:`)**: API keys, Drive OAuth tokens, and vault keys are encrypted with AES-256-CBC + HMAC-SHA256 bound to their storage slot name, with the master key stored in an app-private `0600` file outside `SharedPreferences`.
- **Android Backup Disabled**: `android:allowBackup="false"` prevents cloud backup extraction of local databases and keys.
- **Minimum Version Gate**: Builds older than `v2.1.0+3` are rejected by Supabase RLS (`public.is_client_version_supported()`) and gated on startup/resume via `version_policy.json` with an offline-cached floor.

## Releases

Pre-built binaries are published on [GitHub Releases](https://github.com/hurairamuzammal/Notlyfe-Student-Oragnizer/releases/latest):

- **Android**: Split APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and Universal APK
- **Linux (x64)**: `notlyfe-v2.1.0-linux-x64.tar.gz` (extract and run `./notlyfe`)
- **Windows (x64)**: `notlyfe-v2.1.0-windows-x64.zip` (extract and run `notlyfe.exe`)

## Building from Source

### Prerequisites

- Flutter SDK (Dart `^3.6.0`)
- Android SDK (for APK builds) or Linux GTK3/Clang/CMake toolchain (for Linux desktop) or Visual Studio C++ Desktop workload (for Windows)

### Setup & Run

```bash
flutter pub get
flutter test
flutter run
```

Optionally override Supabase credentials at build time via `--dart-define`:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Release Builds

```bash
# Android
flutter build apk --release --split-per-abi
flutter build apk --release

# Linux desktop
flutter build linux --release

# Windows desktop (run on Windows)
flutter build windows --release
```

### Supabase Migrations

Apply the SQL policies in `supabase/migrations/20261124_enforce_min_version.sql` and `supabase/enable_rls.sql` to enforce Row Level Security and block legacy client builds (`< 2.1.0+3`) server-side.

## Project Layout

```text
lib/
  data/         Course icons and launcher shortcuts
  database/     Supabase & local SQLite repositories
  models/       Domain models (Course, Note, Todo, UserProfile, styles)
  providers/    Riverpod state, connectivity, theme, and sync providers
  screens/      App screens (Home, Courses, Notes, Auth, Drive Setup, Settings)
  services/     Auth, E2EE, SecureStorage, Google Drive, Version gate, Storage providers
  utils/        Note codec, cross-platform toasts, helpers
  widgets/      Material 3 expressive components and cards
supabase/       RLS policies, migrations, and reset-password Edge Function
test/           Unit and storage contract tests
```

## License

See [LICENSE](LICENSE).
