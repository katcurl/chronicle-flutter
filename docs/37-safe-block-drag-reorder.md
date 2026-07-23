# Safe block drag-and-drop

Chronicle 0.22.2 adds drag-and-drop ordering through a separate block organizer. The Markdown text field itself remains unchanged: no gesture overlay, per-line widget tree, scroll listener, or cursor listener is added to the editor surface.

Opening the organizer parses the current note once and displays each recognized block as a compact card. Desktop users drag the dedicated handle directly. Android and iOS users hold the handle before dragging. The current caret block is highlighted, while the existing toolbar arrows remain available for precise one-step movement.

The organizer edits only an in-memory order list. Closing it with Cancel leaves the controller and note text untouched. Pressing Done performs one deterministic controller update and then offers an immediate Undo action.

Reordering treats paragraphs, headings, lists, checklists, quotes, image lines, display formulas, fenced code blocks, dividers, and complete Chronicle column groups as indivisible units. The implementation preserves each raw block byte for byte. Leading text, trailing text, and every existing separator sequence remain in their original document slots; only the block bodies change slots.

This deliberately conservative design avoids reintroducing the scrolling and cursor-navigation regression fixed in 0.22.1. Direct inline drag handles inside the source editor remain out of scope until they can be implemented without wrapping the Markdown text field in a competing gesture layer.
