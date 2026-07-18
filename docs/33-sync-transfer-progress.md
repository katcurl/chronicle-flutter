# Sync transfer progress

Chronicle 0.21.6 adds user-visible progress for manual trusted LAN sync.

The progress model reports the current phase, journal round, attachment name, completed work items, and transferred bytes. The scanning device receives progress through a callback from `LanSyncClient`; the host exposes a broadcast progress stream from `LanSyncHostSession`.

The final report distinguishes journal records from attachment files and includes sent/received bytes, applied tombstones, and path conflicts. A failed manual exchange can be retried with the same unexpired offer without reopening the camera.

This release does not yet provide cancellation or per-file selective retry. Those require a resumable transfer protocol and are intentionally deferred rather than simulated in the UI.
