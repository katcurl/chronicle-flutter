# Chronicle 1.0 — local-first research workspace

Chronicle is a local-first Windows workspace for research projects, tasks, Markdown notes, scientific sources, time tracking, publication assembly and explainable local search.

The 1.0 release marks a stability contract rather than the end of development. Chronicle keeps the primary database and optional Markdown Vault on the user's device, never silently resolves conflicts, and provides explicit recovery paths before risky operations.

## Core workspace

- flexible research-project homes with goals, questions, findings, open checks, pinned results and timelines;
- Markdown/LaTeX notes, tables, figures, attachments, columns, stable wiki-links, backlinks and knowledge graph;
- note templates, note history and reversible imports;
- tasks, subtasks and time tracking linked to projects and notes;
- bibliography, citation keys and project source libraries;
- article/report/presentation assembly from live note fragments;
- Markdown, HTML, portable ZIP, DOCX and PDF export;
- fully local TF-IDF search, related-note suggestions, sourced answers, term extraction and contradiction candidates;
- per-workspace and per-project appearance, wallpapers and image/GIF project icons.

## Chronicle 1.0 guarantees

- **Stable Vault contract.** Vault manifest v2, UUID identity, preserved unknown frontmatter and documented conflict files.
- **Future-format protection.** A Vault written by an incompatible newer Chronicle version opens read-only instead of being overwritten.
- **Backward-compatible backups.** Legacy backup JSON without an explicit version remains readable; unknown future versions are refused.
- **No silent conflict loss.** Divergent external edits become explicit conflict candidates and the existing content is backed up before resolution.
- **Verified recovery path.** Restore creates an emergency copy first and rolls back automatically when applying the replacement fails.
- **Session undo.** Deleting a note or task, deleting a source and archiving a project can be undone from the common undo journal.
- **Large-note regression coverage.** CI verifies parse/serialize stability for a note larger than 1 MB and coalesced preview updates.
- **Release-readiness audit.** Settings → Reliability and recovery checks data relationships, backup round-trip, Vault compatibility, conflicts and valid safety backups without modifying user data.

The complete contract is documented in [`docs/75-v1-stability-contract.md`](docs/75-v1-stability-contract.md). Recovery instructions are in [`docs/76-recovery-guide.md`](docs/76-recovery-guide.md).

## Data layers

```text
Flutter UI
   ↓
AppStore
   ↓
AppRepository
   ├── DriftAppRepository — production SQLite
   └── InMemoryAppRepository — deterministic tests
   ↓
chronicle.db

Optional open mirror:
AppStore → VaultService → Markdown Vault + manifest/index
```

The SQLite database is the structured local source of truth. The optional Vault is an open Markdown mirror with reviewed two-way reconciliation. Visual preferences and the local intelligence index remain separate from note contents.

## GitHub validation and Windows build

The pinned Windows workflow uses Flutter 3.44.7 and runs:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build windows --release
```

Run it from:

```text
Actions → Build Windows desktop → Run workflow
```

Download the artifact:

```text
chronicle-windows-x64
```

The ZIP contains the complete portable Windows release directory. Launch `chronicle.exe` from the extracted folder.

## Local verification

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build windows --release
```

## Documentation

- [`docs/04-vault-format.md`](docs/04-vault-format.md) — stable Vault specification;
- [`docs/74-local-intelligence-and-document-export.md`](docs/74-local-intelligence-and-document-export.md) — local intelligence and document export;
- [`docs/75-v1-stability-contract.md`](docs/75-v1-stability-contract.md) — 1.0 compatibility and reliability guarantees;
- [`docs/76-recovery-guide.md`](docs/76-recovery-guide.md) — recovery procedures;
- [`docs/08-roadmap.md`](docs/08-roadmap.md) — post-1.0 direction.
