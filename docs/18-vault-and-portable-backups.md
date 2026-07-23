# Chronicle v0.13 — Markdown Vault and portable backups

Chronicle v0.13 adds a native filesystem layer without changing the primary
SQLite/Drift data model.

## Markdown Vault

The database remains the source of truth in v0.13. Chronicle writes an open,
readable mirror with the following structure:

```text
Chronicle Vault/
├── Notes/
├── Attachments/
├── Templates/
├── manifest.json
└── .chronicle/
    ├── vault-index.json
    └── Backups/
```

Each note is exported as UTF-8 Markdown with stable `chronicle_id`, project ID,
folder, tags, revision and timestamps in YAML front matter. Writes are atomic:
a temporary file is flushed and then renamed into place.

Only files listed in the previous Chronicle-managed index are eligible for
cleanup. User-created Markdown files are not deleted.

## Portable `.chronicle` backup

A backup contains:

- all projects, tasks, notes, note versions, links and time entries;
- the generated Markdown Vault files;
- source device metadata;
- SHA-256 checksums for the database payload and every mirrored file.

Before a restore replaces current workspace data, Chronicle writes an emergency
backup to `.chronicle/Backups` inside the current Vault.

## Deliberate boundaries

- No cloud service or account is introduced.
- No LAN listener or network transfer is enabled yet.
- Attachments and external Markdown changes are not imported in v0.13.
- Bidirectional file watching is deferred to the next Vault stage.
