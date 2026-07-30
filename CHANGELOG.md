# Changelog

All notable changes to Logic Video Cue are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses semantic versioning for public releases.

## [Unreleased]

### Planned

- Community testing across more Logic Pro and macOS versions.
- Optional signed and notarized release workflow.

## [0.5.0] - 2026-07-30

### Added

- Native English and Traditional Chinese localization for the standalone app
  and embedded Link AU.
- Shared Xcode String Catalog with automatic macOS and per-app language
  selection.
- macOS GitHub Actions build verification for the app and embedded AUv3.

### Changed

- Updated the app and AU to version 0.5.0 while preserving compatibility with
  existing v0.4.0 `.lvcue` arrangement values.

## [0.4.0] - 2026-07-29

### Added

- Embedded `Logic Video Cue: Link` AUv3.
- Automatic `.lvcue` recall from saved Logic project state.
- Stable project identifiers and migration for earlier `.lvcue` files.
- Output-window timeline display down to milliseconds.
- Multi-display window dragging and Logic fullscreen Space support.
- Complete Retina app icon assets.

### Changed

- Continuous AVPlayer clock during normal playback to reduce audio and video
  interruptions.
- Output-window always-on-top behavior across macOS Spaces.
- Adopted `GPL-3.0-or-later` for the first public source release.
- Added permanent original-creator credit for Kao Ko Feng and a separate
  project-name and artwork policy.

### Fixed

- Logic Pause/MMC Pause now stops video playback.
- Pending seeks no longer resume playback after Logic has stopped.
- AU parameter tree compatibility and bridge protocol build errors.
- Audio Unit component metadata and validation.

## Earlier prototypes

Versions before 0.4.0 were private workflow prototypes and were not published
as open-source releases.
