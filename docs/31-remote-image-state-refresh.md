# Remote image state refresh

Chronicle 0.21.4 replaces the `FutureBuilder`-owned Vault image request with explicit state owned by each image widget.

When attachment synchronization notifies the note preview, the widget starts a new guarded read. Only the newest generation may update the UI. After `dart:io` completes, `setState` schedules the repaint directly. This avoids stale completed futures and makes an image appear in an already-open note without reopening it.

The previous image or fallback remains visible while a refresh is in progress, preventing flicker.
