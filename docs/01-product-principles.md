# Product principles

These principles are binding. Features that violate them require an explicit architecture decision record.

## 1. Local-first, not local-only

The device contains a complete usable copy of the user's data. Synchronization is optional and additive. Losing network access must not disable editing, tracking, search, or reporting.

## 2. User-readable source of truth

Notes and durable metadata must be exportable into understandable files. SQLite may provide indexing, transactions, and fast queries, but it must not become an irreversible data prison.

## 3. One concept, one identity

A project, note, task, session, or attachment has a stable UUID. Renaming or moving a file must not break internal relationships.

## 4. Time records are evidence, not surveillance

Chronicle records what the user chooses to track. Automatic activity capture is opt-in, local, inspectable, and never silently converted into billable or official time.

## 5. Progressive disclosure

The default screen shows the next useful information, not every possible property. Advanced metadata remains available without dominating the interface.

## 6. No destructive magic

Bulk edits, merges, synchronization conflict resolution, and AI-assisted changes must be previewable and reversible.

## 7. Interoperability before novelty

Prefer Markdown, YAML, BibTeX, JSON, CSV, iCalendar, and ordinary attachments where practical.

## 8. Accessibility is a functional requirement

Core workflows must support screen readers, scalable text, keyboard navigation on desktop, high contrast, reduced motion, and touch targets of at least 48 logical pixels.

## 9. A build must stay usable

Every milestone must compile, pass tests, migrate existing data, and provide a complete vertical workflow. Half-integrated features do not enter the main branch.

## 10. Outcomes matter more than streaks

Chronicle may help users start and continue work, but it must avoid punitive streak mechanics, shame-inducing warnings, and misleading productivity scores.
