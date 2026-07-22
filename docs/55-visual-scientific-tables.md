# Visual scientific table editor

Chronicle 0.25.1+65 adds a visual editor for the existing portable scientific-table Markdown format.

## Create and edit

The table command creates a new scientific table when the cursor is outside a table. When the cursor or selection is inside an existing `chronicle-table` block, the same command opens that table for editing.

The editor provides separate header and body cells, row and column controls, and per-column left, center or right alignment. Reducing the grid is always an explicit action; Chronicle does not silently remove existing cells.

## Spreadsheet paste

**Paste from Excel/CSV** reads plain text from the clipboard. Tab-separated ranges from Excel, LibreOffice and Google Sheets are preferred. Quoted comma-separated and semicolon-separated rows are also supported.

The first pasted row becomes the table header. The remaining rows become the body. Clipboard insertion replaces only the grid shown in the dialog and does not modify the system clipboard.

## Portable storage

Tables remain standard GitHub-Flavored Markdown with the existing readable marker:

```markdown
<!-- chronicle-table id=nmr-conditions caption=Условия%20ЯМР -->
| Параметр | Значение | Комментарий |
| :--- | :---: | ---: |
| Температура | 298 K | основной спектр |
```

No database migration or hidden binary table format is introduced. Existing numbered tables and `@tbl(id)` references remain compatible.

## Safety boundaries

- Existing tables are changed only after the user opens and saves the table editor.
- Tables that cannot be parsed safely are left untouched and produce a visible warning.
- The feature does not change Vault layout, attachments, synchronization payloads, themes, templates or existing notes automatically.
