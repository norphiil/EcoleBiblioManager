# EBM (Ecole Biblio Manager) - AI Coding Agent Guide

## Project Overview
EBM is a **cross-platform Flutter library management system** with barcode scanning for schools. It combines local SQLite data with Google Sheets synchronization and features real-time book borrowing/returning workflows.

**Key Tech Stack:** Flutter, Dart, Python FastAPI backend, SQLite, Google Sheets API, barcode detection (pyzbar)

---

## Architecture Overview

### Three-Tier Data Architecture
```
┌─────────────────────────────────────────────┐
│ Google Sheets (Remote Source of Truth)      │
│ - Books, Groups, Classes, Borrow History    │
└────────────────┬────────────────────────────┘
                 │ Sync
┌────────────────▼────────────────────────────┐
│ SQLite Local Database (Fast, Offline)       │
│ - Full replica with sync metadata           │
│ - Tracks dirty/synced status per entity     │
└────────────────┬────────────────────────────┘
                 │ Providers (Provider package)
┌────────────────▼────────────────────────────┐
│ Flutter UI Layer                            │
│ - Home, Scanner, Book Management Screens    │
└─────────────────────────────────────────────┘
```

### Key Service Layers (`lib/services/`)

1. **`InitializationService`** - Single orchestrator for app startup
   - Coordinates SQLite init → Google Sheets init → Data sync
   - Tracks 4 states: `notStarted`, `inProgress`, `completed`, `error`
   - Exposes `syncService` and `localDbService` only when `isCompleted`
   - Handles offline mode gracefully

2. **`LocalDatabaseService`** - Pure CRUD interface
   - Query Books/Groups/Classes from SQLite
   - Does NOT manage synchronization (delegates to `SyncService`)
   - Always returns fast results (local cache)

3. **`SyncService`** - Bidirectional sync orchestrator
   - Full sync on first launch: pulls all remote data into SQLite
   - Incremental sync: uploads dirty local changes back to Sheets
   - Tracks sync status per entity (`synced`, `pending`, `deleted`)
   - Implements conflict resolution via `Book.concat()` for merged updates

4. **`GoogleSheetsService`** - Remote API wrapper
   - Delegates to sheet-specific operations (`BooksOperations`, `GroupsOperations`, etc.)
   - Communicates via Google Apps Script endpoint (not native API)

5. **`BookApiService`** - Third-party integration (OpenLibrary API)
   - Fetches book metadata by ISBN when local data incomplete
   - Implements caching and validation (`_isPlausibleIsbn`)

6. **`PythonBackendService`** - Local FastAPI server
   - Auto-launches Python backend on app startup
   - Handles barcode detection via `/detect` endpoint
   - Manages virtual environment and dependency installation

### Data Models (`lib/models/`)

All models extend `Synchronizable` with metadata:
- **`Book`** - Primary entity: ISBN (unique), title, author, status (available/borrowed), borrowedBy, borrowerClassName
- **`BookGroup`** - Shelf categories: auto-generates `key` from title
- **`ClassRoom`** - Student classes: simple id/name pair
- **`BorrowHistory`** - Audit trail: isbn, borrower, classId, borrowedAt, returnedAt

Key pattern: Models track `isDirty`, `lastModified`, and `_changes` for sync detection.

---

## Critical Development Workflows

### 1. **Building & Running the App**
```bash
# Development (Windows/Linux desktop default)
flutter run -d windows

# iOS/Android build requires Xcode/Android Studio
flutter run -d ios        # macOS + Xcode required
flutter build android     # Generates APK

# Python backend starts automatically; verify at localhost:8000/health
```

### 2. **Setting Up Google Sheets Integration**
1. Copy `google_apps_script_api.js` to [script.google.com](https://script.google.com/)
2. Modify SPREADSHEET_ID in the script
3. Deploy as "Application web" with "Everyone" access
4. Create `.env` file:
   ```
   GOOGLE_APPS_SCRIPT_URL=https://script.google.com/macros/s/{YOUR_ID}/exec
   BOOKS_SHEET_NAME=Books
   GROUPS_SHEET_NAME=Groupes
   CLASSES_SHEET_NAME=Classes
   BORROW_HISTORY_SHEET_NAME=Historique
   ```

### 3. **Python Backend (Auto-managed)**
- Location: `python_backend/main.py`
- FastAPI endpoints:
  - `GET /health` - server status
  - `POST /detect` - barcode detection from image
  - `POST /detect_base64` - barcode detection from base64
- Auto-managed by `PythonBackendService`:
  - Detects Python environment
  - Creates venv if needed
  - Installs deps from `requirements_minimal.txt`
  - Retries with exponential backoff

### 4. **Database Migrations**
Current version: 5. Add migrations to `DatabaseHelper._upgradeDatabase()`:
```dart
if (oldVersion < 6) {
  // Your migration SQL
  await db.execute('ALTER TABLE books ADD COLUMN newField TEXT');
}
```
Schema located in `_createDatabase()` method.

---

## Project-Specific Patterns & Conventions

### Data Synchronization Pattern
```dart
// ALWAYS use this pattern when syncing data:
1. Mark local change as dirty: entity.markAsDirty()
2. Let SyncService detect and upload automatically
3. SyncService calls entity.getChanges() (returns only modified fields)
4. After successful sync: SyncService calls entity.markAsSynced()
5. If conflict: use Book.concat() to merge remote + local
```

### Navigation Architecture (GoRouter)
- All routes defined in `lib/core/router/app_router.dart`
- Prefix paths with `/` (e.g., `/book-info`)
- Pass complex objects via `state.extra` parameter
- Example: `context.pushNamed('book-info', extra: bookObject)`

### State Management (Provider)
- Use `Provider` for stateless services (singletons)
- Use `ChangeNotifierProvider` for observable state (e.g., `InitializationService`)
- Use `ProxyProvider` to defer service creation until dependencies ready
- Example in `main.dart`: `LocalDatabaseService` only accessible after init completes

### Logger Usage
Every service should have:
```dart
final Logger _logger = Logger('ClassName');
_logger.info('Message');
_logger.error('Error', exception);
```
Logs written to `logs/` directory via `LogService`.

### Environment Variables (`.env` file)
Required variables defined in `AppConstants`:
- `GOOGLE_APPS_SCRIPT_URL` - Google Sheets integration endpoint
- `DEBUG_MODE` - Enable verbose logging
- Sheet names (BOOKS_SHEET_NAME, etc.)

### Error Handling
Custom exception hierarchy via `AppException`:
```dart
// Define: class MyException extends AppException { }
// Use: throw MyException('message', code: 'ERROR_CODE');
```

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point; sets up Provider graph |
| `lib/services/initialization_service.dart` | App lifecycle orchestrator |
| `lib/services/database/database_helper.dart` | SQLite schema & CRUD |
| `lib/services/database/sync_service.dart` | Bi-directional sync logic |
| `lib/services/google_sheets/google_sheets_service.dart` | Remote API wrapper |
| `lib/models/book.dart` | Primary domain model with sync tracking |
| `lib/core/router/app_router.dart` | Navigation configuration |
| `google_apps_script_api.js` | Google Sheets backend script |
| `python_backend/main.py` | Barcode detection API |
| `pubspec.yaml` | Dart dependencies |

---

## Common Troubleshooting

**Issue:** App stuck on initialization screen
- Check `InitializationService.initialize()` logs (errors surfaced via Provider state)
- Verify `.env` file exists with valid `GOOGLE_APPS_SCRIPT_URL`
- Confirm Python backend started: `curl http://localhost:8000/health`

**Issue:** Books not syncing to Google Sheets
- Check `SyncService._syncToRemote()` - inspect dirty entities flagging
- Verify entity `markAsDirty()` called before changes
- Confirm `lastModified` timestamp updated (used for conflict detection)

**Issue:** Barcode detection fails
- Python backend must be running; check `PythonBackendService` logs
- Verify image format supported (JPEG/PNG); base64 encoding if using camera feed
- Check `python_backend/requirements_minimal.txt` installed (pyzbar, opencv-python)

---

## Development Conventions

1. **French-first language** - UI strings, comments, and error messages in French by default
2. **ISBN as unique key** - Always use `book.isbn` as primary identifier (never duplicate ISBNs)
3. **Timestamp precision** - Use `DateTime.now().toIso8601String()` for all sync metadata
4. **Offline-first mindset** - All screens work with local SQLite; sync is background operation
5. **Test keys** - Use `AppKeys` constants for widget testing (defined in `app_constants.dart`)

---

## Integration Points

- **Barcode scanning** → `PythonBackendService.detectBarcode()` → FastAPI backend
- **Book enrichment** → `BookApiService.getBookByIsbn()` → OpenLibrary API (free, no auth)
- **Data persistence** → `LocalDatabaseService` → SQLite local file
- **Remote sync** → `GoogleSheetsService` → Google Apps Script → Google Sheets

All are fallback-tolerant: app works offline, retries sync when online.
