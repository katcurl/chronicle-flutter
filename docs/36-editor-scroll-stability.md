# Editor scroll and navigation stability

Chronicle 0.22.1 removes the repeated full-document work that was introduced with block-aware controls.

## Problem

`TextEditingController` notifies listeners for both text changes and selection changes. The first block-toolbar implementation reparsed the entire Markdown document for every notification and rebuilt the whole note workspace even when only the cursor or selection moved. On longer notes this could feel like a pause, a stuck scroll gesture, or a toolbar that visibly shifted between frames.

## Fix

- Text and title snapshots distinguish real edits from selection-only notifications.
- Once a note is dirty, further edits update only the preview, statistics, and block toolbar that depend on the text.
- The block toolbar caches parsed block ranges. Cursor movement uses those cached ranges; full parsing is delayed until typing pauses for 90 ms.
- Current-block lookup uses binary search.
- The current-block chip has a fixed width, so the remaining toolbar controls keep their positions.

The portable Markdown format, Vault data, theme, and GitHub Actions build process are unchanged.
