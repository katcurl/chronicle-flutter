# Deterministic remote-image refresh test

Chronicle Vault images continue to read production bytes through the platform-specific Vault loader. The note preview now accepts that loader as an injectable dependency for widget tests.

The regression test therefore verifies the state transition directly: the first load returns no bytes, a store notification is emitted, the second load returns image bytes, and the placeholder is replaced. It does not enter `tester.runAsync`, perform real disk I/O, or wait on the image decoder. This prevents the previous ten-minute CI timeout while preserving the behavioral assertion.

Attachment notifications are consumed by each Vault image independently. The whole Markdown preview is no longer rebuilt by the same notification, avoiding duplicate listeners and disposal/recreation races.
