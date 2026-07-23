# Knowledge map analyze fix

Chronicle 0.23.1 removes a redundant `dart:ui` import from the knowledge-map
layout test. `flutter_test` already exposes the required UI types, and Flutter
3.44 reports the duplicate import as `unnecessary_import`.

This is a build-only correction. It does not change the graph layout, note
links, Markdown, Vault files, synchronization, themes, or persisted data.
