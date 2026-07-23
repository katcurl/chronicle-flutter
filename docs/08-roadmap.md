# Chronicle roadmap after 1.0

Chronicle 1.0 freezes the first stable data-safety contract. Future releases may add capabilities, but they may not weaken documented Vault, backup, conflict and recovery guarantees.

## 1.0 stable baseline

Completed release criteria:

- documented and versioned Vault format;
- backward-compatible structured backups and future-format refusal;
- emergency backup and automatic rollback around restore;
- explicit Vault conflict review without silent data loss;
- common session undo for principal destructive operations;
- note version history and bounded large-document comparison;
- regression coverage for large-note parse/serialize behavior;
- reversible project/note export paths including DOCX and PDF;
- pinned Windows analyzer, tests and release build;
- in-app readiness audit and recovery documentation.

## 1.1 hardening

- embed figures and richer tables directly in DOCX/PDF;
- expand undo to more metadata edits and batch operations;
- add accessible keyboard navigation and screen-reader audit;
- publish measured performance baselines for very large Vaults;
- improve repair previews for integrity findings without automatic mutation.

## 1.2 local intelligence quality

- optional local embedding backend with explicit model/download controls;
- multilingual term normalization;
- better evidence grouping for contradictions and sourced answers;
- evaluation fixtures that measure retrieval quality without uploading notes;
- project-specific exclusions and index diagnostics.

## 1.3 portability and collaboration

- richer LaTeX export for publication workspaces;
- reproducible import/export compatibility fixtures;
- clearer multi-device conflict provenance;
- optional encrypted peer synchronization;
- signed release metadata and checksums.

## Later, only after format review

- plugin API;
- calendar integration;
- Android companion application and widgets;
- optional controlled cloud services;
- additional platform builds.

Any future schema or format change requires a new version, migration tests and a documented rollback/export path.
