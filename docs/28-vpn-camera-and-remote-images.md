# Chronicle v0.21.1 — remote image refresh and VPN-safe QR retry

## Remote images

A note journal record may be applied before its attachment transfer finishes. An
already open preview now listens to the application store and resolves managed
Vault images again after the completed sync report. This removes the stale
broken-image placeholder without requiring the note or application to be
reopened.

## QR camera retry

The QR scanner is deliberately stopped while Chronicle attempts a local
connection. If that connection fails, both pairing and synchronization screens
now start the camera again after returning to scan mode.

## VPN interfaces

QR host offers order physical Wi-Fi and Ethernet interfaces before VPN, tunnel,
WSL, Docker and other virtual adapters. This avoids advertising a VPN address
when a reachable local-network address exists. A VPN that explicitly blocks
local-network traffic may still need its LAN-access option enabled.
