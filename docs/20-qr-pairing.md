# Chronicle v0.15: QR pairing and trusted LAN handshake

## Scope

Chronicle v0.15 establishes identity and trust between two native installations without an account, email address, cloud relay, or central server.

## Protocol

The host opens a temporary HTTP listener on all local IPv4 interfaces and publishes a QR offer containing:

- protocol version;
- local host and ephemeral port;
- session identifier;
- random one-time token;
- five-minute expiration time;
- host device metadata;
- host Ed25519 public key.

The joining device generates or loads its persistent Ed25519 identity, signs the pairing request, and sends only device metadata and its public key. The host verifies possession of the private key before displaying the request.

Both sides derive the same six-digit confirmation code from the session, request, token, and both public keys. The host approval is signed with the host private key and verified against the public key embedded in the QR offer.

## Storage

Private identity key material is stored in Chronicle's local `app_state` table and is not part of the portable data export. Trusted devices store only the peer public key and metadata.

## Security boundary

The transport is local cleartext HTTP in this pairing-only release, but all pairing messages are signed and no Chronicle content is transferred. The later data-sync transport must use authenticated encryption derived from the paired identities before sending journal entries or attachments.

## Platform behavior

- Windows/Linux/macOS and Android can host a QR pairing session.
- Android can scan the QR code with the camera.
- A copied `chronicle://pair/...` code is available as a fallback.
- Web does not host the local listener.
