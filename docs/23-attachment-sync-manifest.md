# Chronicle v0.19.2 — attachment sync manifest

Chronicle now includes the managed attachment catalog in every signed LAN sync
exchange. This release intentionally transfers metadata only; binary payloads
remain local until the next guarded transport stage is implemented.

## Protocol

The signed journal protocol is now `chronicle-sync-v2`. A request contains the
requesting device's attachment manifest. The response contains the responder's
manifest and two deterministic plans:

- actions the requester would need to apply from the responder;
- actions the responder would need to apply from the requester.

A manifest entry contains the managed relative path, original display name,
SHA-256, MIME type, byte length, creation time and optional deletion time.
Only paths below `Attachments/`, valid SHA-256 values and files up to 100 MiB
are accepted. A manifest is limited to 10,000 records.

## Planning rules

- Missing content hashes are classified as binary files to transfer later.
- Content already present under another managed path is classified as a
  metadata-only record, preventing duplicate binary transfer.
- Tombstones are propagated as deletion work and are never silently undone by
  an older active record.
- The same path with different active content is reported as a conflict; no
  automatic overwrite is allowed.
- An indexed active file that is missing from the local Vault is not advertised.
  This allows a healthy peer to offer the binary back in the next stage.

The plans are retained in the internal sync report for diagnostics and the
next transport stage. This release does not alter the application theme or
copy, replace or delete attachment bytes during LAN synchronization.
