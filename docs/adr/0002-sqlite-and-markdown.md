# ADR 0002: SQLite plus Markdown vault

Status: Accepted

## Context

A pure file model is portable but weak for transactions, timers, dependencies, and reporting. A pure database model is robust but opaque and difficult to use outside Chronicle.

## Decision

Use SQLite for structured entities, indexing, and event history. Store notes and attachments as ordinary files. Stable UUIDs connect both layers.

## Consequences

- reconciliation is required after external file changes;
- operations spanning database and filesystem need a journal;
- users retain readable documents and reliable structured queries.
