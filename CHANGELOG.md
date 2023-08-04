# v0.2.0 - 2023-08-04

* Bugfix: Use FileManager to get file storage paths that are allowed on real iOS devices
* Feature: Support for Matrix threads
* Bugfix: Only update the Room's account data from the main Actor
* Added piecewise constructor for the UserId type

# v0.1.0 - 2023-07-28 - Initial public alpha release

* Support for most of the Matrix client-server API
* Support for E2EE
* `ObservableObject`s for the `Session`, `Room`, `User`, `Message`, and other basic Matrix entities, for use in building SwiftUI views
