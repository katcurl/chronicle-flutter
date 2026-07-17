# Changelog

## 0.19.2

- added signed attachment manifests to trusted LAN sync;
- added deterministic plans for missing binaries, metadata-only records,
  tombstones and path conflicts;
- prevented missing local binaries from being advertised to peers;
- added attachment work counters to sync reports and reliability events;
- updated the signed journal protocol to `chronicle-sync-v2`;
- kept binary transfer disabled until atomic write and checksum verification
  are implemented.

## 0.7.0

- migrated structured data from SharedPreferences to SQLite;
- added one-time legacy data import;
- added repository abstraction and in-memory test repository;
- persisted active timer state between app restarts;
- added JSON backup and restore through the clipboard;
- added soft deletion support for notes;
- added database error recovery screen;
- added model, store and widget tests;
- updated Android APK workflow for API 36.

## 0.6.0

- added Chronicle Foundation documentation;
- established product, architecture, data and design specifications.
