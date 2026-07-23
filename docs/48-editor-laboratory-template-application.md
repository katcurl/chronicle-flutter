# Applying laboratory templates in the note editor

Chronicle 0.24.5+58 adds an opt-in **Лабораторный шаблон** command to the
Markdown editor toolbar. It is represented by the science icon and is available
only while the editor pane is open.

The command opens a dialog containing the six built-in laboratory templates.
Selecting a template updates a complete read-only Markdown preview before any
note text changes.

For an empty note, Chronicle inserts the selected template directly. For a
non-empty note, the safe default is **В конец**: the existing Markdown is kept
byte-for-byte and the template is added after a blank line. **Заменить** is available as an explicit alternative.
Both operations require a second confirmation whenever the note already
contains text.

Applying a template changes only the Markdown body in the open editor. It does
not alter the note title, project, folder, type, tags or custom properties. The
change remains a normal editor modification and the snackbar action can restore
the exact previous text while no later edit has been made.

Cancelling either the picker or the confirmation dialog leaves the editor text
unchanged. The feature does not introduce a database migration and does not
change the visual theme, Vault configuration, synchronization, attachments or
other existing notes.
