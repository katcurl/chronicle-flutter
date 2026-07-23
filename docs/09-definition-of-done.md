# Definition of done

A feature is done only when all applicable conditions are met.

## Product

- The user problem and expected behavior are documented.
- Empty, loading, success, and failure states are designed.
- Destructive actions are reversible or explicitly confirmed.
- Offline behavior is defined.

## Engineering

- Code is formatted and statically analyzed.
- Domain logic has unit tests.
- Persistence changes include migration tests.
- Existing user data remains readable.
- Errors are typed and surfaced meaningfully.
- No secrets or user content are written to logs.

## Android

- Works on the minimum supported Android version.
- Handles process death where applicable.
- Supports system back navigation.
- Touch targets and text scaling meet accessibility requirements.
- Battery-intensive behavior is disclosed and justified.

## Data safety

- Import/export behavior is tested.
- A failed operation cannot silently lose the original content.
- New file formats are documented.
- Backups remain restorable after the migration.

## Release

- CI is green.
- APK is installable on a physical device.
- Release notes list user-visible changes and migration considerations.
- Version is tagged in Git.
