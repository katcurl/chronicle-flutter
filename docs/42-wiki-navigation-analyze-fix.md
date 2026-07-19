# Wiki navigation analyzer fixture fix

Chronicle 0.23.3+51 fixes two incomplete `Project` fixtures in `test/notes_core_test.dart`.

`Project.emoji` is a required string in the application model. The wiki-navigation tests created two projects without that argument, so Flutter analysis stopped before tests and builds could run. The fixtures now use ordinary Unicode emoji values. This does not restrict which emoji users may choose and does not change production data or behavior.

No Markdown, note, Vault, synchronization, knowledge-map, theme, or database logic is modified.
