# Safe block controls

Chronicle 0.22.0 introduces block-aware editing while keeping each note as ordinary portable Markdown. It does not replace the source editor with a proprietary document model.

The editor identifies the block containing the caret and shows its type in the toolbar. Paragraphs, headings, lists, checklists, quotes, single-image lines, display formulas, fenced code blocks, horizontal dividers, and complete Chronicle column groups are handled as distinct units.

The up and down controls exchange only the selected block and its neighboring block. Existing Markdown text and the separator between those blocks are preserved byte for byte. Fenced code and managed column groups move as one unit even when they contain blank lines.

The block menu can duplicate a block, copy its raw Markdown, or delete it. Deletion exposes an immediate undo action. Text-oriented blocks can be converted between paragraph, level-one heading, level-two heading, bulleted list, checklist, and quote. Structural blocks such as images, display formulas, fenced code, and columns cannot be converted through this menu because doing so could discard metadata or internal formatting.

This release deliberately uses explicit toolbar commands instead of drag-and-drop. The deterministic operations establish a data-safe foundation for visual block dragging in a later release.
