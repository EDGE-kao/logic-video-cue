<div align="center">
  <img src="Artwork/LogicVideoCue-AppIcon-1024.png" width="144" alt="Logic Video Cue icon">

# Logic Video Cue

An open-source multi-video sync player for Logic Pro on macOS

[Getting Started](Docs/Getting-Started.md) · [Contributing](CONTRIBUTING.md) · [Support](SUPPORT.md) · [Support on Ko-fi](https://ko-fi.com/edgekao)

**Original creator & maintainer: [Kao Ko Feng](AUTHORS.md)**
</div>

Logic Video Cue keeps multiple MOV/MP4 files as independent cues and follows
Logic Pro transport and position using MIDI Time Code (MTC) and MIDI Machine
Control (MMC). It removes the need to concatenate many short reference videos
into a single long movie.

> [!IMPORTANT]
> This is currently a source-only beta. No official Developer ID-signed and
> Apple-notarized binary is provided. Build the app locally from source.
> This project is independent from and not endorsed by Apple Inc.

## Who it is for

- Composers and sound designers working on games, advertising, short films, or
  multiple picture versions.
- Logic Pro users who want video playback handled by a separate app.
- Projects that need several short video cues instead of one concatenated
  reference movie.
- Dual-display workflows that need a separate always-on-top or fullscreen
  output window.

## Highlights

- Standalone macOS app with an embedded `Logic Video Cue: Link` AUv3.
- The AU stores the `.lvcue` project link inside the Logic project and requests
  it automatically when the Logic project is reopened.
- Multi-file Finder drag and drop.
- Fixed-interval or back-to-back cue arrangement.
- Native English and Traditional Chinese UI, following the macOS or per-app
  language setting.
- Appending a clip preserves all existing cue positions.
- Replacing a clip preserves its timeline start.
- MTC Quarter Frame/Full Frame and MMC Locate/Play/Pause/Stop.
- 24, 25, 29.97 DF, 30, 50, and 60 fps timeline display.
- Video audio, sync offset, dual-display output, always-on-top, and fullscreen.
- Output-window timeline display in `HH:MM:SS.mmm`.
- Local-only operation with no network access, analytics, or telemetry.

## Requirements

- macOS 14 Sonoma or later.
- Xcode 16 or a compatible version for local builds.
- Logic Pro 11/12. Older versions may work through conventional MTC/MMC setup,
  but are not fully tested.

The app interface supports English and Traditional Chinese and follows the
macOS system language automatically. To change only Logic Video Cue, use
`System Settings → General → Language & Region → Applications`; no in-app
language switch is required.

## Build from source

1. Download or clone this repository.
2. Install Xcode from the Mac App Store and launch it once.
3. Double-click `Build_Logic_Video_Cue.command`.
4. Move `Build/LogicVideoCue.app` to `/Applications`.
5. Launch Logic Video Cue before launching Logic Pro.

Alternatively, open `LogicVideoCue.xcodeproj`, select
`LogicVideoCue > My Mac`, and press `Command-R`.

A paid Apple Developer account is not required for a local build. See
[Getting Started](Docs/Getting-Started.md) for the complete installation,
Logic synchronization, and AU project-link workflow.

## Quick Logic Pro setup

1. Open `File → Project Settings → Synchronization → MIDI`.
2. Choose `Logic Video Cue Sync In` as the destination.
3. Enable MTC and MMC for that destination.
4. Enable `Transmit MIDI Machine Control (MMC)`.
5. Keep `Synchronization → General → Sync Mode` set to `Internal`.
6. Insert the following plug-in on an unused Aux channel:
   `Audio Units → Logic Video Cue → Logic Video Cue: Link`
7. Save a `.lvcue` project, click `Link Current Cue Project` in the app, then
   return to Logic and press `Command-S`.

The MTC/MMC destination and Link AU are both stored per Logic project. Save
them in a Logic Project Template if you create projects frequently.

## Project data and privacy

- `.lvcue` files are JSON documents containing cues, timecodes, settings, and
  absolute paths to local video files.
- The app does not upload media, project data, or usage information.
- Remove private filenames and local paths before attaching a `.lvcue` file to
  a public issue.
- If a video is moved or renamed, use Replace in the app to relink it while
  preserving its timecode.

## Known scope

This project does not provide movie export, Blackmagic/AJA/NDI output, HDR,
MXF, multi-machine network playback, genlock, or overlapping video tracks.
AVFoundation handles decoding. Long-GOP H.264/HEVC references can seek slowly;
ProRes Proxy is recommended for demanding spotting workflows.

The Link AU identifiers and bundle identifiers are fixed for project
compatibility. Changing the AU subtype, manufacturer code, or bundle
identifiers in a fork can prevent existing Logic projects from locating the
original plug-in.

## Development and verification

Run the portable structural checks on any system with Python 3:

```bash
python3 Tests/verify_project.py
```

A complete build still requires macOS and Xcode.

## Repository layout

- `LogicVideoCue/`: SwiftUI app, cue management, and AVPlayer playback.
- `LogicVideoCueAU/`: zero-latency audio pass-through AUv3 link.
- `Shared/`: bridge protocol and the English/Traditional Chinese String
  Catalog shared by the app and AU.
- `Docs/`: installation, Logic setup, and maintainer publishing guidance.
- `Tests/`: portable structural checks that do not require Xcode.

## Support the project

If Logic Video Cue saves you time, you can support the original creator and
ongoing development on [Ko-fi](https://ko-fi.com/edgekao). Sponsorship is
entirely optional; the source code remains available under the GPL and all
features remain available without payment.

## Contributing and support

Issues and pull requests are welcome. Read
[CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes. See
[SUPPORT.md](SUPPORT.md) for support scope and [SECURITY.md](SECURITY.md) for
vulnerability reporting.

## License

The source code is Copyright © 2026 Kao Ko Feng and is available under the
[GNU General Public License v3.0 or later](LICENSE). Distributed modifications
must retain the original authorship notices, identify their changes, provide
the corresponding source, and remain under the GPL. The software is provided
as-is, without warranty.

See [AUTHORS.md](AUTHORS.md) for the permanent original-creator credit and
[TRADEMARKS.md](TRADEMARKS.md) for use of the project name and original app
icon. Unofficial modified distributions must use a different name and icon
and must not imply endorsement by the original project.

`Logic Pro`, `macOS`, and related marks are trademarks of Apple Inc. Logic
Video Cue is an independent open-source project and is not affiliated with,
sponsored by, or endorsed by Apple Inc.
