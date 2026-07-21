# Custom note templates

Chronicle 0.24.6+59 adds opt-in user-created templates alongside the immutable built-in templates.

## Creating templates

A template can be created from **Мои шаблоны** in the new-note sheet or editor toolbar. The editor accepts a name, emoji or short icon, note type, comma-separated default tags and Markdown content.

The Markdown editor also provides **Сохранить заметку как шаблон**. It opens the same editor prefilled with the current title, type, tags and Markdown body. The current custom properties are copied as hidden template defaults so a note created from that template receives the same metadata. Saving a template does not save or otherwise modify the open note.

## Using templates

Custom templates appear after the built-in templates in the new-note sheet. Creating a note from one applies its Markdown, note type, tags and saved custom properties.

The editor command **Применить шаблон заметки** now lists ordinary built-in templates, laboratory templates and custom templates. Applying a template to an existing note still changes only the Markdown body and retains the existing title, project, folder, type, tags and properties. Safe append remains the default for a non-empty note, replacement requires confirmation, and immediate undo remains available.

## Editing and deletion

**Мои шаблоны** allows custom templates to be edited or deleted. Built-in templates are not shown in the management list and cannot be overwritten. Deleting or editing a template does not affect notes previously created from it.

## Storage and boundaries

Custom templates are stored in Chronicle local preferences under a versioned key. Invalid or damaged preference data is ignored safely at startup. This feature introduces no database migration and does not write to the Vault, synchronize templates between devices, change attachments, alter the visual theme or modify existing notes.
