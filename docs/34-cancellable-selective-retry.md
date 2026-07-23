# Cancellable LAN sync and selective retry

Chronicle 0.21.7 makes manual attachment synchronization interruptible and retry-safe without changing the signed `chronicle-sync-v3` wire format.

The scanning device owns a `LanSyncCancellationToken`. Pressing **Cancel synchronization** closes the active HTTP client and converts the resulting network interruption into a dedicated cancellation result. The host can also close its one-time session from the progress screen.

Attachment commands use a bounded retry helper. Only transient connection failures are retried, at most three times, and the current filename plus attempt number are shown in the progress UI. Integrity, trust, protocol, and checksum failures are never silently retried.

Host-side upload, metadata, and tombstone handlers are idempotent. If the host applied a command but its response was lost, the repeated signed command returns success instead of reporting a false conflict.

Completed files are stored atomically in the Vault. If the exchange is cancelled or the connection fails after some files completed, pressing **Retry** with the same unexpired offer rebuilds both manifests and transfers only the remaining files. A partially transmitted individual file is restarted from byte zero; byte-range continuation is intentionally deferred to a later chunked protocol.
