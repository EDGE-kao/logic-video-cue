<div align="center">
  <img src="Artwork/LogicVideoCue-AppIcon-1024.png" width="144" alt="Logic Video Cue icon">

# Logic Video Cue

An open-source multi-video sync player for Logic Pro on macOS

[繁體中文](README.md) · [English setup guide](Docs/Getting-Started.en.md) · [Contributing](CONTRIBUTING.md)

**Original creator & maintainer: [Kao Ko Feng](AUTHORS.md)**
</div>

Logic Video Cue keeps multiple MOV/MP4 files as independent cues and follows
Logic Pro transport and position using MIDI Time Code (MTC) and MIDI Machine
Control (MMC). It removes the need to concatenate many short references into a
single long movie.

> [!IMPORTANT]
> This is currently a source-only beta. No official Developer ID-signed and
> Apple-notarized binary is provided. Build the app locally from source.
> This project is independent from and not endorsed by Apple Inc.

## Highlights

- Standalone macOS app with an embedded `Logic Video Cue: Link` AUv3.
- The AU stores the `.lvcue` project link inside the Logic project.
- Multi-file Finder drag and drop.
- Fixed-interval or back-to-back cue arrangement.
- Appending a clip preserves existing cue positions.
- Replacing a clip preserves its timeline start.
- MTC Quarter Frame/Full Frame and MMC Locate/Play/Pause/Stop.
- 24, 25, 29.97 DF, 30, 50 and 60 fps timeline display.
- Video audio, sync offset, dual-display output, always-on-top and fullscreen.
- Local-only operation with no network access, analytics or telemetry.

## Requirements

- macOS 14 Sonoma or later.
- Xcode 16 or a compatible version for local builds.
- Logic Pro 11/12. Older versions may work through conventional MTC/MMC setup,
  but are not fully tested.

The current app interface is primarily in Traditional Chinese.

## Build from source

1. Download or clone this repository.
2. Install Xcode from the Mac App Store and launch it once.
3. Double-click `Build_Logic_Video_Cue.command`.
4. Move `Build/LogicVideoCue.app` to `/Applications`.
5. Launch Logic Video Cue before launching Logic Pro.

Alternatively, open `LogicVideoCue.xcodeproj`, select
`LogicVideoCue > My Mac`, and press `Command-R`.

A paid Apple Developer account is not required for a local build. See
[Getting Started](Docs/Getting-Started.en.md) for Logic synchronization and AU
project-link setup.

## Project data and privacy

`.lvcue` files are JSON documents containing cue positions, settings and
absolute paths to local video files. The app does not upload media, project
data or usage information. Remove private filenames and paths before attaching
a project to a public issue.

## Known scope

This project does not provide movie export, Blackmagic/AJA/NDI output, HDR,
MXF, network playback, genlock or overlapping video tracks. AVFoundation
handles decoding. Long-GOP H.264/HEVC references can seek slowly; ProRes Proxy
is recommended for demanding spotting workflows.

Changing the AU subtype, manufacturer code or bundle identifiers in a fork can
prevent existing Logic projects from locating the original plug-in.

## Development

Run portable structural checks on any system with Python 3:

```bash
python3 Tests/verify_project.py
```

A complete build still requires macOS and Xcode.

## Contributing and support

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md)
before submitting changes. See [SUPPORT.md](SUPPORT.md) for support scope and
[SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

The source code is Copyright © 2026 Kao Ko Feng and is available under the
[GNU General Public License v3.0 or later](LICENSE). Distributed modifications
must retain the original authorship notices, identify their changes, provide
the corresponding source, and remain under the GPL.

See [AUTHORS.md](AUTHORS.md) for the permanent original-creator credit and
[TRADEMARKS.md](TRADEMARKS.md) for use of the project name and original app
icon. Unofficial modified distributions must use a different name and icon
and must not imply endorsement by the original project.

`Logic Pro`, `macOS`, and related marks are trademarks of Apple Inc. Logic
Video Cue is an independent open-source project and is not affiliated with,
sponsored by, or endorsed by Apple Inc.
