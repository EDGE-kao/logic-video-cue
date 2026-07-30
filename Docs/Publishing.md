# Publishing Guide

This document is for repository maintainers. It is not an end-user installation
guide.

## Repository presentation

- Repository name: `logic-video-cue`
- Visibility: Public
- Description:
  `A lightweight open-source multi-video sync player for Logic Pro using MTC/MMC and an AUv3 project link.`
- Suggested topics:
  `macos`, `swift`, `swiftui`, `logic-pro`, `midi-timecode`, `mtc`, `mmc`,
  `audio-unit`, `video-playback`, `film-scoring`, `game-audio`

English is the canonical language for repository documentation, issue
templates, pull requests, and release notes. The app and Link AU remain
localized in English and Traditional Chinese.

## License and project identity

The repository source code is licensed under `GPL-3.0-or-later`. The original
creator and copyright holder is:

`Kao Ko Feng`

Distributed modifications must retain the authorship notices, clearly identify
their changes, provide the complete corresponding source, and remain under the
GPL. The GPL permits charging for distribution, but recipients retain the same
rights to modify and redistribute the software.

`AUTHORS.md` permanently distinguishes the original creator from later
contributors. `TRADEMARKS.md` separately covers the Logic Video Cue name and
original app icon. Unofficial modified distributions must use a different name
and icon and clearly state that they are unofficial.

## Release policy

Until an official Developer ID-signed and Apple-notarized build is available,
publish source-only pre-releases. Do not attach an unsigned `.app`; doing so
creates unnecessary Gatekeeper friction and can be mistaken for a formally
supported binary.

Use semantic tags such as `v0.5.0`. Release notes should include:

- A clear source-only beta or pre-release notice.
- The supported macOS, Xcode, and Logic Pro versions.
- A concise list of changes and compatibility notes.
- A link to [Getting Started](Getting-Started.md).
- Known limitations and the `GPL-3.0-or-later` license.
- `Original creator: Kao Ko Feng`.

GitHub automatically provides source-code ZIP and tar.gz archives for every
release.

## Pre-release checklist

1. Run `python3 Tests/verify_project.py`.
2. Complete an Xcode Release build.
3. Confirm that `auval -v aufx LvCB LVCu` passes.
4. Verify Logic Play, Pause, Stop, Locate, and playhead dragging.
5. Open and save an existing `.lvcue` project.
6. Confirm Link AU connection and automatic cue-project recall.
7. Test dual-display and fullscreen output behavior.
8. Search the repository for private paths, credentials, customer media, and
   confidential project names.
9. Confirm that the app version, build number, README, CHANGELOG, tag, and
   release notes agree.
10. Confirm that the public documentation is written in English.

## Pull request and release flow

1. Create a focused branch from `main`.
2. Commit only the intended release changes.
3. Open a pull request and wait for the portable and macOS build checks.
4. Review the final diff and merge to `main`.
5. Create the version tag from the merged commit.
6. Publish a source-only pre-release with English release notes.
7. Verify that the release page points to the expected commit and exposes both
   source archives.

Never rewrite or delete an earlier public tag to publish a new version.

## Future signed binary releases

Before publishing an installable `.app` for general users, complete:

- Apple Developer Program membership.
- Stable bundle identifiers and Developer ID signing for the app and AUv3.
- Hardened Runtime configuration.
- Apple Notary Service submission and ticket stapling.
- Installation, AU scan, and Logic synchronization tests in a clean macOS user
  account.

Never commit private Apple certificates, notary credentials, provisioning
profiles, tokens, or other secrets to the repository.
