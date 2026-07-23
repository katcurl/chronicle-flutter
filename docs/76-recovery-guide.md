# Chronicle recovery guide

This guide covers the safest recovery order after an accidental action, damaged import, Vault conflict or failed upgrade.

## First response

1. Stop editing the affected project.
2. Do not delete or rename the current Vault folder.
3. Do not repeatedly start synchronization or restore the same file.
4. Copy the Vault folder and any `.chronicle`/JSON backup to a separate location before manual intervention.
5. Open **Settings → Reliability and recovery** and run the audit.

## Accidental deletion or archiving

Use the undo button in Chronicle navigation immediately. Outside the text editor, `Ctrl+Z`/`Cmd+Z` invokes the shared workspace undo journal.

Session undo can restore deleted notes and tasks, deleted sources and project archive state. For older changes, use note version history or a validated backup.

## Note text was changed incorrectly

Open the note's version history. Compare the selected snapshot with the current text before restoring. Chronicle creates a new version around restoration, so returning to the pre-restore state remains possible.

## Vault reports external changes or conflicts

1. Open the Vault conflict/reconciliation screen.
2. Review additions, modifications, missing files and conflicts separately.
3. For conflicts, compare both versions; do not treat the newest timestamp as automatically correct.
4. Apply only the reviewed selection.
5. Keep the safety copy created before application until the project has been checked.

Chronicle never needs permission to delete the only copy of a conflicting note.

## Vault opens read-only

A read-only warning means its manifest requires a newer Chronicle format. Do not remove or downgrade the manifest to force writing.

Use a newer compatible Chronicle build, or copy/export the Markdown files manually. The running version intentionally refuses to overwrite the folder.

## Restoring a `.chronicle` or JSON backup

1. Keep the current Vault and backup files unchanged.
2. Preview the selected backup in Chronicle.
3. Confirm project/note/task counts and listed warnings.
4. Start restore once.
5. After completion, run the readiness audit and inspect several recent notes and attachments.

Chronicle creates an emergency copy before replacing the active dataset. If the replacement fails, it attempts an automatic rollback and records whether rollback succeeded.

## Application does not start after an update

1. Preserve the application data directory and Vault before reinstalling anything.
2. Download the last known-good GitHub Actions artifact.
3. Extract it into a new folder; do not overwrite the old portable directory.
4. Launch the old build against the preserved data only when its format is supported.
5. Export a portable backup before attempting another upgrade.

A future-format warning must be respected: use a compatible newer build rather than forcing an older build to write.

## Information to preserve for diagnosis

- Chronicle version and Git commit from the build;
- exact time of the failure;
- diagnostic/reliability journal export;
- backup preview result;
- whether automatic rollback was reported;
- a copy of `manifest.json` and `.chronicle/vault-index.json`;
- filenames of conflict copies;
- the failing GitHub Actions log for build/test problems.

Avoid sharing private note contents when metadata and diagnostics are sufficient.
