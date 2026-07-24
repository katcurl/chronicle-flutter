# Security policy

## Supported versions

Chronicle is currently maintained as a single release line. Security fixes are
provided for the latest published version only. Older binaries and development
artifacts should be upgraded before reporting a problem.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability.

If this repository is hosted on GitHub, use **Security → Report a
vulnerability** to create a private security advisory. If private reporting is
not enabled, contact the repository owner through the private contact channel
shown on the project's distribution page and ask for a secure reporting
channel. Do not include secrets, private notes, databases, or unredacted backup
archives in the first message.

Please include:

- the affected Chronicle version and operating system;
- a concise description of the impact and threat model;
- reproducible steps or a minimal proof of concept;
- whether user interaction, LAN access, or a malicious note/backup is required;
- any suggested mitigation, if known.

The maintainers should acknowledge a complete report within seven days, provide
status updates at least every fourteen days, and coordinate disclosure after a
fix is available. These are response targets, not a service-level agreement.

## Release integrity

Pull-request and branch workflows produce deliberately unsigned artifacts and
never receive signing secrets. Only a `v*` tag can enter the protected
`release-signing` GitHub environment. Configure that environment with required
reviewers before publishing the first release.

Published releases contain:

- signed Android APK and AAB artifacts;
- a signed Windows portable ZIP;
- `SHA256SUMS.txt`;
- an SPDX 2.3 dependency SBOM;
- GitHub artifact attestations for the checksums and SBOM.

Verify checksums before installing:

```shell
sha256sum --check SHA256SUMS.txt
```

Verify an APK with Android build tools:

```shell
apksigner verify --verbose --print-certs chronicle-*.apk
```

Verify a Windows executable in PowerShell:

```powershell
Get-AuthenticodeSignature .\chronicle.exe
```

The expected Authenticode status is `Valid`. A checksum only proves that a file
matches the release manifest; the platform signature establishes publisher
identity.

## Sensitive local data

Chronicle is local-first, but its vault, backups, attachments, logs, and
screenshots can contain private information. Redact or replace those files
before sharing a reproduction. LAN synchronization should be enabled only
between trusted, authenticated devices.
