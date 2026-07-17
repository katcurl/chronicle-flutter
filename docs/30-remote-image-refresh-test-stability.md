# Remote image refresh test stability

The open-note image refresh path uses asynchronous `dart:io` reads from the
Vault. Flutter widget test `pumpAndSettle()` only waits while frames are
scheduled; it can therefore return before a real file-system future completes.

The regression test now performs a bounded wait on the real asynchronous event
loop and pumps the widget tree between attempts. The production refresh logic
remains unchanged: each Vault-backed image listens for attachment-store
notifications and replaces its cached read future when synchronized data
arrives.
