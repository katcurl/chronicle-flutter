# Citation library analyze fix

Chronicle 0.24.1+54 is a build-only compatibility update for the local citation library.

- The file picker dependency is the 12.0.0 beta API, where file selection is invoked through `FilePicker.pickFiles` rather than `FilePicker.platform.pickFiles`.
- The BibTeX parser now wraps its three one-line `while` loops in braces to satisfy the project's strict lint rules.
- No citation records, note Markdown, wiki links, Vault files, attachment synchronization, database schema, or visual theme are changed.
