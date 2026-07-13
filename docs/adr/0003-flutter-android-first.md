# ADR 0003: Flutter, Android first

Status: Accepted

## Context

The first requested platform is Android, while future desktop support is desirable. The app requires native background timers, filesystem access, notifications, and a rich editor.

## Decision

Use Flutter for the application shell and shared domain implementation, with native Android integrations where platform services require them.

## Consequences

- browser-only limitations are avoided;
- platform channels or plugins are required for advanced Android services;
- editor feasibility must be validated early;
- desktop support remains possible without claiming immediate parity.
