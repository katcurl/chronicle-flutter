# Security and privacy

## Default privacy posture

- no account required;
- no telemetry by default;
- no note content sent off-device;
- no automatic upload of filenames, project names, citations, or time records;
- optional services require explicit consent and clear data boundaries.

## Sensitive data classes

Chronicle may contain unpublished research, student materials, personal schedules, and billing records. All are treated as private user content.

## Threats

- device loss;
- malicious or buggy sync provider;
- corrupted database;
- unintended content exposure through logs or crash reports;
- path traversal or unsafe attachment names;
- untrusted Markdown and HTML;
- dependency supply-chain compromise.

## Controls

- use Android application sandbox;
- sanitize attachment paths and generated filenames;
- disable arbitrary script execution in Markdown;
- restrict HTML rendering;
- verify backup integrity with hashes;
- use encrypted Android storage for credentials and sync keys;
- pin release dependencies through lockfiles;
- automated dependency auditing without uploading user data;
- optional vault encryption only after recovery and portability are designed.

## AI boundary

AI features must be opt-in per operation. The UI must show which content will leave the device, which provider receives it, and whether the result will modify files. Generated changes require preview and confirmation.
