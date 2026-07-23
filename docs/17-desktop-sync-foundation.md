# Chronicle v0.12 — Desktop & Sync Foundation

This release deliberately does **not** transmit data over the network yet. It creates the persistence and UI required for safe account-free synchronization later.

## Product decision

Chronicle will not require email authentication or cloud storage. Supported data movement will be:

1. automatic synchronization between previously paired devices on the same local network;
2. manual backup export and restore;
3. optional direct connection methods for networks with client isolation.

A shared Wi‑Fi network is used for discovery only. Trust is established separately by QR pairing and cryptographic device keys in a later release.

## Added database records

- `device_identity` — stable identity for the current installation;
- `trusted_devices` — paired peers and revocation state;
- `change_records` — append-only local change journal;
- `sync_cursors` — per-peer sent/received progress;
- `sync_preferences` in `app_state` — local-only discovery settings.

The Drift schema is upgraded from version 3 to version 4. Existing projects, tasks, notes and time entries are preserved.

## Change journal

Mutations to projects, tasks, notes, note versions and time entries create ordered records with:

- local sequence;
- globally unique change ID;
- entity type and ID;
- operation;
- monotonically increasing entity revision;
- origin device ID;
- timestamp;
- JSON payload.

Existing data receives a one-time `snapshot` journal record after migration. This enables the first future peer to receive a complete state rather than only post-upgrade edits.

## Security boundary

v0.12 contains no LAN server and opens no network port. The pairing button is intentionally informational. Network discovery, QR pairing and authenticated encryption will be implemented in separate releases and tested independently.

## Planned continuation

- v0.13: native Markdown Vault and file backup;
- v0.14: cryptographic device identity and QR pairing;
- v0.15: mDNS/NSD discovery on local networks;
- v0.16: incremental LAN synchronization;
- v0.17: conflict resolution and attachments.
