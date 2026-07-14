# Chronicle v0.8 — Cross-platform Data Core

## Purpose

Chronicle now uses Drift as the typed database layer over SQLite. The same
repository and schema can run on Android, Windows, Linux and macOS.

## Existing Android data

The previous Android releases stored `chronicle.db` in the directory returned
by `sqflite.getDatabasesPath()`. On the first v0.8 launch, Chronicle copies that
database into the application-support directory as `chronicle.sqlite` and opens
it with Drift. The old database is intentionally retained as a recovery copy.

## Transitional dependency

`sqflite` remains temporarily as a migration bridge used only to locate the old
Android database. It is no longer used for reads or writes. It can be removed
after the migration has shipped in a stable release.

## Code generation

After changing a Drift table, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generated `chronicle_database.g.dart` is committed to Git so release builds
do not depend on generation at runtime.

Before future schema changes, establish the initial migration snapshot:

```bash
dart run drift_dev make-migrations
```

Then increment `schemaVersion`, implement the generated migration step and run
the generated migration tests.

## Desktop

The database is stored under the platform application-support directory. The
Flutter UI and domain layer remain shared; only responsive layout and platform
integrations differ between mobile and desktop.
