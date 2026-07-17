# Chronicle v0.21 — guarded attachment binary sync

Chronicle now transfers managed attachment binaries during trusted LAN sync.
The journal exchange still begins with signed manifests and deterministic plans,
but planned file, record and tombstone actions are now executed before the
journal round is acknowledged.

## Transfer rules

- Only devices that are already paired and trusted may request attachment work.
- Every attachment command is signed and bound to the active one-time sync
  session.
- The signed metadata contains the managed path, SHA-256, MIME type, byte length
  and lifecycle timestamps.
- Received bytes are rejected unless both the byte length and SHA-256 match the
  signed manifest entry.
- Vault writes remain atomic through a temporary file followed by rename.
- A remote active file never overwrites a local active file with different
  content; the path remains a reported conflict.
- Tombstones remove the managed binary and retain the deletion record so older
  devices cannot silently resurrect it.
- If the same content already exists under another managed path, Chronicle
  copies the verified local content instead of transferring the bytes again.

## Protocol

The LAN protocol is now `chronicle-sync-v3`. Attachment commands use the same
short-lived session token and the same device signing keys as the journal
exchange. Binary payloads are represented as Base64 inside the local HTTP
exchange and are limited by the existing 100 MiB attachment limit.

## Reports

Sync reports now include files and bytes sent and received, metadata-only
records applied, tombstones applied and unresolved path conflicts. The Windows
UI reports transferred attachment counts after a successful manual sync.
