# Chronicle 1.0 stability contract

Chronicle 1.0 is defined by data-safety and compatibility guarantees, not by a claim that every possible feature has been implemented. This document records the contract that later releases must preserve or migrate explicitly.

## 1. Versioned formats

### Structured backup JSON

- format identifier: `chronicle-backup`;
- current format version: `5`;
- minimum readable version: `1`;
- a missing version is interpreted as legacy version `1`;
- an unknown format identifier is rejected;
- a version newer than the running application supports is rejected before replacement begins.

Fields introduced after an older backup version use safe defaults during decoding. Exporting and re-importing a current backup must preserve projects, tasks, notes, time entries, note links, note versions and citation sources.

### Markdown Vault

- manifest identifier: `chronicle-vault`;
- stable manifest/index version: `2`;
- minimum reader version: `1`;
- stable since Chronicle `1.0.0`;
- stable UUIDs, not paths or titles, are the identity model;
- unknown frontmatter keys are preserved;
- conflicts are never silently overwritten.

When either the Vault format or its `minimumReaderVersion` is newer than the running Chronicle supports, automatic Vault writes are disabled. The folder remains available for inspection and manual copying.

### Portable `.chronicle` backup

The portable backup package keeps its existing package format and includes structured data plus referenced attachments. Package preview and validation happen before applying it. Replacement never starts solely because a file has the expected extension.

## 2. Compatibility rules

Chronicle may add optional fields to existing entities when old readers can safely ignore them. A change that removes, renames or changes the meaning of persisted data requires:

1. a new format or schema version;
2. an explicit migration;
3. tests starting from the previous stable representation;
4. a documented rollback or export path.

The application must not “repair” an unsupported future format by rewriting it as the current format.

## 3. Conflict rules

External Vault changes are scanned before import. Chronicle distinguishes additions, modifications, missing files and divergent edits. A divergent edit must be shown as a candidate requiring an explicit user choice.

Before applying reviewed Vault changes Chronicle creates a safety snapshot. A conflicting file may be preserved with a timestamp/device suffix. No conflict resolution may silently discard either side.

## 4. Backup and restore rules

Before replacing the active dataset Chronicle creates an emergency backup of the current state. The candidate backup is decoded and validated before replacement. If replacement fails after it starts, Chronicle attempts to restore the emergency backup automatically and records the outcome in the reliability journal.

A release-readiness audit verifies a structured export/import round-trip without replacing current data.

## 5. Undo and history

The shared session undo journal covers the principal destructive workspace operations:

- soft-deleting a note, including task links and rebuilt wiki-link relationships;
- soft-deleting a task, including child hierarchy restoration;
- deleting a citation source;
- archiving or unarchiving a project.

The journal is intentionally session-scoped. Persistent recovery is provided by note versions, automatic backups, Vault snapshots and portable backups. Text editing continues to use the editor's native undo stack and note-version history.

## 6. Large-note behavior

Chronicle coalesces expensive preview/statistics updates instead of rebuilding them for every keystroke. CI includes a note larger than 1 MB and verifies that Markdown content survives parse, serialization and reparsing without truncation. History comparison retains its bounded fallback for unusually large documents.

This is a regression guarantee, not a promise that every machine renders arbitrarily large documents at the same frame rate. Performance regressions that cause data loss, editor hangs in ordinary use or unbounded comparison work are release blockers.

## 7. Release gate

The pinned Windows workflow must pass all of the following on every release candidate:

```text
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build windows --release
```

The workflow verifies that `chronicle.exe` exists before packaging the complete release directory. A failing analyzer diagnostic or test blocks the artifact.

## 8. In-app readiness audit

Settings → Reliability and recovery performs a read-only audit of:

- duplicate and missing identifiers;
- orphaned project/task/note relationships;
- damaged task hierarchy and time-entry references;
- stale note-link/version references;
- missing pinned notes and linked sources;
- duplicate citation keys;
- structured backup round-trip;
- Vault format compatibility;
- unresolved Vault conflicts;
- availability of a valid safety backup.

The audit reports findings and never rewrites user data automatically.
