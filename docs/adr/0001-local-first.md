# ADR 0001: Local-first operation

Status: Accepted

## Context

Chronicle stores private, long-lived intellectual work. Network dependence would reduce reliability and create avoidable lock-in.

## Decision

Every core workflow operates from a complete local copy. Cloud services are optional adapters.

## Consequences

- conflict handling and backups become first-class engineering concerns;
- server outages cannot block ordinary use;
- features cannot assume immediate global consistency;
- the application must expose data locations and export options clearly.
