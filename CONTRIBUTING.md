# Contributing to Logic Video Cue

Thank you for helping improve Logic Video Cue. This project is intentionally
kept focused: synchronization reliability, a clear production workflow, and
backward compatibility take priority over adding many features quickly.

## Before filing an issue

1. Confirm that you are using the current `main` branch or the latest release.
2. Read the troubleshooting section in
   [Getting Started](Docs/Getting-Started.md).
3. Verify Logic Pro's MTC, MMC, frame-rate, and Sync Mode settings.
4. Reproduce the problem with test media that contains no confidential or
   unlicensed material.

Do not attach the following to a public issue:

- Client media or unreleased videos.
- `.lvcue` files containing private filenames, usernames, or local paths.
- Commercial audio, sample libraries, or third-party content from a Logic
  project.

## Development setup

- macOS 14 or later.
- Xcode 16 or a compatible version.
- Logic Pro 11/12 for complete synchronization testing.
- Python 3 for the portable checks.

Open `LogicVideoCue.xcodeproj` and select
`LogicVideoCue > My Mac`.

## Before submitting changes

Run:

```bash
python3 Tests/verify_project.py
```

On macOS, also verify:

- The standalone app and embedded AUv3 both build.
- `auval -v aufx LvCB LVCu` passes.
- Logic Play, Pause, Stop, Locate, and playhead dragging work correctly.
- Existing `.lvcue` projects still open.
- Dual-display and output-window behavior have not regressed.

## Pull request guidelines

- Keep each pull request focused on one problem.
- Explain the workflow, the change, and the tests actually performed.
- Any `.lvcue` format change must include a backward-compatible migration.
- Do not casually change the AU subtype `LvCB`, manufacturer code `LVCu`, or
  bundle identifiers.
- Add both English and Traditional Chinese entries for new user-interface text
  in the shared String Catalog.
- Keep repository documentation in English.
- Do not add telemetry, advertising, tracking, or undisclosed network access.

## License

By submitting a pull request, you confirm that you have the right to provide
the contribution and agree to license it under this repository's
`GPL-3.0-or-later` terms. The original creator remains identified in
`AUTHORS.md`; later contributors are credited through Git history, pull
requests, and release notes.
