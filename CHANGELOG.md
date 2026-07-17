# Changelog

## 0.20.0+33

- added portable two- and three-column blocks to Markdown notes;
- added column insertion and layout controls to the editor toolbar;
- added draggable column dividers in note preview;
- preserved images, captions, formulas, links and Markdown inside columns;
- stacked columns vertically on narrow windows;
- kept column syntax readable outside Chronicle through HTML comments.

## 0.19.3+32

- fixed image size, alignment and caption settings being lost after switching between editor and preview;
- image presentation metadata is now persisted immediately after attachment, resizing or configuration;
- switching editor modes now safely flushes the current note buffer without creating a history version.

## 0.19.3

- added responsive image sizing from 20% to 100%;
- added quick image sizes at 25%, 50%, 75% and 100%;
- added left, center and right image alignment;
- added optional captions below images;
- added direct mouse resizing in note preview;
- kept original attachment binaries unchanged and stored only presentation metadata in Markdown.

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
