# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2026-10-01

### Documentation

- Added example phoenix app using LiveDelegate under example/dashboard

## [0.1.1] - 2026-09-30

### Added

- Exposed `delegate_mount/3` as a documented public macro so it appears in the
  generated API reference.

### Documentation

- Clarified delegated submodule mount ordering, socket threading, callback
  return values, and the uses of the `mount: false` option.

## [0.1.0] - 2026-09-29

### Added

- Initial release with mount, event, message, and assign delegation for Phoenix
  LiveView.

[Unreleased]: https://github.com/danielres/live_delegate/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/danielres/live_delegate/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/danielres/live_delegate/releases/tag/v0.1.0
