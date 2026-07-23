# Chronicle v0.17 — automatic trusted LAN sync

Chronicle advertises a short signed presence packet on the local network while
the app is running. Only previously paired devices whose Ed25519 public key is
stored locally are accepted.

A discovered device requests a short-lived v0.16 sync offer over HTTP. The
request and response are signed, after which the existing acknowledged journal
exchange is reused unchanged. This keeps QR sync available as a fallback.

Automatic sync runs when both Chronicle instances are open, after app startup,
after returning to the app, and while trusted-device announcements continue.
The operating system is not woken after Chronicle has been fully closed.

UDP discovery uses port 45891. The HTTP port is dynamic. Windows Firewall and
VPN software must permit private/LAN traffic for Chronicle.
