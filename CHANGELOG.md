# Changelog

## 0.21.6+42

- Added live LAN sync progress for journal rounds and attachment transfers.
- Both host and scanning devices show the current attachment name, item count, and transferred bytes.
- Expanded the final sync report with attachment counts, bytes, deletions, and conflicts.
- Added a retry action that reuses the current QR offer after transient Wi-Fi or VPN failures.
- Added clearer local-network, timeout, and checksum error messages.
- Added deterministic tests for sync progress calculations.

## 0.21.5+41

- removed the duplicate whole-preview rebuild when attachment storage changes; each Vault image now refreshes independently;
- added an injectable attachment-byte loader so the refresh widget test is deterministic on Linux and Windows runners;
- replaced the real file-I/O and `runAsync` loop that could deadlock until the ten-minute test timeout;
- kept production Vault reads, checksum validation and LAN synchronization unchanged.

## 0.21.4+40

- Remote Vault images now keep their own byte state instead of depending on `FutureBuilder` completion timing.
- A completed `dart:io` read explicitly schedules the widget rebuild, so a synchronized image replaces the placeholder in an already-open note.
- The cross-platform widget test now targets the exact remote image and fallback widgets.

## 0.21.3+39

- made the remote-image widget test wait for asynchronous Vault file I/O before asserting the refreshed preview;
- kept the production image refresh listener from 0.21.2 unchanged;
- prevented GitHub Actions from reporting a false failure when the file read completes after `pumpAndSettle` has already stopped.

## 0.21.2+38

- fixed reloading of Vault images received through LAN sync while a note is already open;
- made each Vault-backed image listen directly for store notifications and replace its cached read future;
- kept the remote-image widget regression test enabled on both Windows and Linux runners.

## 0.21.1+37

- refreshed open note previews after synchronized attachment files arrive;
- made remote images re-resolve from the local Vault after the final sync report;
- restarted the Android QR camera after a failed pairing or sync attempt;
- preferred physical Wi-Fi and Ethernet interfaces over VPN and virtual adapters in QR offers;
- added regression tests for Vault image refresh and VPN-aware LAN address ordering.

## 0.21.0+36

- added two-way LAN transfer of missing attachment binaries between trusted devices;
- verified every received file against the signed SHA-256 and byte length before atomic Vault storage;
- synchronized attachment tombstones and metadata-only deduplicated records;
- prevented automatic overwrite when a managed path contains different content;
- added attachment byte and file counters to sync reports and reliability diagnostics;
- updated the signed LAN protocol to `chronicle-sync-v3`;
- added integration tests for bidirectional attachment transfer and Vault checksum enforcement.

## 0.20.1+35

- added column content reordering from the existing layout dialog;
- added safe conversion of a column block back to ordinary Markdown;
- kept two-to-three column expansion and three-to-two merging in one dialog;
- added clearer management controls and a preview tooltip;
- preserved images, captions, formulas and links while columns are reordered or unwrapped;
- added tests for content order validation and Markdown conversion.

## 0.20.0+34

- fixed the Windows build failure in the three-column layout editor;
- declared the right-column width before redistributing space between columns;
- restored GitHub Actions analysis, tests and Windows packaging for note columns.

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
