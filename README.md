# Matrix.swift - A native Matrix client SDK in Swift

This package provides a native Swift implementation of the [Matrix](https://matrix.org/)
client-server SDK.

It wraps the [Matrix Rust Crypto SDK](https://github.com/matrix-org/matrix-rust-sdk/tree/main/bindings/apple)
to provide support for end-to-end encryption (E2EE).

## Status
This project is **alpha** (ie, pre-beta) quality software.
It is **NOT READY** for production use by 3rd parties.
Moreover, it has not yet undergone any kind of security audit.
Use it at your own risk.


## Features
That said, the library currently supports most of the core features needed to build an
E2EE Matrix client.

Accounts and Authentication
* Login and logout
* Registering new accounts
* User-interactive authentication
* Deactivate account

Messaging
* Sending and receiving text, image, and video messages
* Sync

Rooms
* Enumerating rooms
* Traversing Space hierarchies
* Sending, accepting, and rejecting invites
* Knocking, joining, and leaving rooms
* Kicking and banning users
* Adding and removing Space parent/child relationships

Encryption
* Encrypting and decrypting E2EE messages
* Encrypting and decrypting media attachments
* Secret storage
* Cross signing
* Encrypted key backup and recovery

