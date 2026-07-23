# Chronicle v0.16 — trusted LAN sync

Chronicle exchanges the local change journal between already paired devices.
The desktop opens a five-minute one-time sync offer; Android scans it and both
sides exchange signed batches over the local network.

Security properties:

- the offer is targeted to one trusted device;
- every exchange request, response and acknowledgement is signed with Ed25519;
- stored public keys are checked again before data is accepted;
- batches are idempotent by `changeId`;
- cursors advance only after an acknowledged transfer;
- interrupted transfers can safely resend the same changes.

The current release uses a manual QR sync session. Automatic peer discovery and
background synchronization remain a separate follow-up because Android and
Windows require different lifecycle and firewall handling.
