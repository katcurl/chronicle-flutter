# Synchronization and backup

## Backup before synchronization

Reliable backup is mandatory before multi-device synchronization is introduced.

## Backup modes

1. Automatic local rotating snapshots.
2. User-triggered ZIP export.
3. Export to Android Storage Access Framework location.
4. Optional Git repository for Markdown and attachments.

Recommended retention:

- 7 daily snapshots;
- 4 weekly snapshots;
- 6 monthly snapshots.

## Synchronization phases

### Phase A: external folder sync

The vault can be placed in a directory synchronized by Syncthing, Nextcloud, Dropbox, or another user-chosen tool. Chronicle detects and reconciles changes.

### Phase B: Chronicle sync protocol

Optional encrypted synchronization service with:

- per-entity version vectors or hybrid logical clocks;
- operation log;
- end-to-end encrypted payloads;
- deterministic conflict handling for structured entities;
- explicit merge UI for Markdown conflicts.

## Conflict policy

- Time sessions: preserve both unless they have the same stable event ID.
- Tasks: field-level merge where changes do not overlap; otherwise create conflict record.
- Notes: three-way text merge where a common ancestor exists; never discard either version.
- Deletions: tombstones retained until all known devices acknowledge them.

## Disaster recovery

Settings must expose:

- last successful backup;
- backup location;
- database integrity check;
- restore preview;
- export before reset.
