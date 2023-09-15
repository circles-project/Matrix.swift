# v0.4.0 - 2023-09-15

* Add support for encrypting and uploading files directly from the filesystem
* Add support for sending `m.video` messages
* Updated default room version 
* Add support for power levels override
* Add fallback support for threads
* Update MatrixSDKCrypto to v0.3.12
* Add support for event redaction
* Add support for event replacement
* Add support for detecting `@` mentions in message events
* Bug fixes in secret storage, room state management, avatars, and more

# v0.3.0 - 2023-08-18

* Add support for deactivating the user's account, for GDPR compliance
* Fix spec compliance of `m.room.encryption` events
* Better support for UIA sessions that fail, or are canceled
* More robust parsing of receipts
* More robust handling of events that we fail to or don't know how to parse
* E2EE fixes - Generate proper CTR mode "iv"s and use unpadded base64
* Allow redirect by default for media downloads
* Use better paths to store things on the local device
* Improvements to Secret Storage, especially for when another app has already created a default key

# v0.2.0 - 2023-08-04

* Bugfix: Use FileManager to get file storage paths that are allowed on real iOS devices
* Feature: Support for Matrix threads
* Bugfix: Only update the Room's account data from the main Actor
* Added piecewise constructor for the UserId type

# v0.1.0 - 2023-07-28 - Initial public alpha release

* Support for most of the Matrix client-server API
* Support for E2EE
* `ObservableObject`s for the `Session`, `Room`, `User`, `Message`, and other basic Matrix entities, for use in building SwiftUI views
