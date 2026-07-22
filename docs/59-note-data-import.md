# Note data import

Chronicle 0.26.3 adds a dedicated data-import workflow to the Markdown note
editor. It complements the ordinary single-file attachment action and the
clipboard table editor without introducing a second Vault format.

## Import modes

### CSV or TSV as a scientific table

When exactly one `.csv` or `.tsv` file is selected, Chronicle offers
**Table + source**. The first row becomes the table header and the remaining
rows become the body. Delimiters are detected using the same parser as the
visual table editor: tab first, then semicolon or comma.

The generated table uses the existing `chronicle-table` marker and therefore
keeps automatic numbering and `@tbl(id)` cross-references. Its ID is derived
from the source file name and receives a numeric suffix when the note already
contains the same ID. The original data file is always stored in
`Attachments` and linked immediately below the table.

The portable Markdown table remains bounded by the established table limits:
up to eight columns and forty body rows. The source attachment preserves all
original rows and columns.

### A group of files

One or many files can be imported as a named data bundle. Chronicle inserts a
normal Markdown heading and links to every stored attachment. Images can be
shown inline or inserted as ordinary links. No hidden database entity or
special bundle syntax is created.

## Safety and performance

All files use the existing content-addressed attachment pipeline. Identical
content reuses the existing SHA-256 attachment instead of creating another
binary copy. Backups, the attachment catalog and LAN synchronization continue
to work without changes.

A single import is limited to 24 files, 100 MB per file and 120 MB in total.
The limits are checked before Vault writes begin. Attachment refresh is emitted
once after the complete batch, avoiding repeated image reloads during a large
import.

The operation changes only the currently edited note after explicit
confirmation. Themes, projects, templates, synchronization formats, database
schema and existing notes are not migrated.
