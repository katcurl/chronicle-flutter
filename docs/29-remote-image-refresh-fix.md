# Remote image refresh fix

Chronicle 0.21.2 makes each Vault-backed image listen directly to the
application store. When LAN sync writes a previously missing attachment and
notifies listeners, the image widget replaces its cached future and reads the
file again.

This avoids relying on an ancestor rebuild to reset `FutureBuilder` state and
keeps an already open note in sync with the Vault on Windows and Android.
