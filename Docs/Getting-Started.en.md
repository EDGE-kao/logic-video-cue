# Getting Started with Logic Pro

## 1. Build and install

1. Install Xcode from the Mac App Store and launch it once.
2. Double-click `Build_Logic_Video_Cue.command`.
3. Move `Build/LogicVideoCue.app` to `/Applications`.
4. Quit Logic Pro, launch Logic Video Cue once, then relaunch Logic.

The app contains the `Logic Video Cue: Link` AUv3 extension. Do not extract or
move the `.appex` separately.

## 2. Add the Link AU

Create an unused Aux channel in Logic and insert:

`Audio Units → Logic Video Cue → Logic Video Cue: Link`

The AU passes audio through without latency or processing. It only stores the
associated `.lvcue` project inside the Logic project.

## 3. Configure MTC and MMC

Open:

`File → Project Settings → Synchronization → MIDI`

On an unused destination row:

- Destination: `Logic Video Cue Sync In`
- MTC: on
- MMC: on
- `Transmit MIDI Machine Control (MMC)`: on
- `Listen to MIDI Machine Control (MMC) input`: off

Under `Synchronization → General`:

- Sync Mode: `Internal`
- Project Frame Rate: match the reference-video standard

Logic is the master; Logic Video Cue is the slave.

## 4. Create and link a cue project

1. Drag one or more MOV/MP4 files into Logic Video Cue.
2. Choose fixed-interval or back-to-back arrangement.
3. Save the cue project with `Command-S`.
4. Click `Link Current Cue Project` in the Logic project-link section.
5. Return to Logic and press `Command-S`.

The final Logic save is required because the AU state lives inside the Logic
project.

## 5. Daily workflow

1. Launch the standalone Logic Video Cue app.
2. Open the linked Logic project.
3. The AU requests the corresponding `.lvcue` project.
4. Enable Follow Logic and start playback.

MTC/MMC routing and the Link AU are both per-project Logic settings. Save them
in a Logic Project Template if you create projects frequently.

## 6. Adding or replacing media

- Add a new clip while Logic is stopped. Existing cue timecodes are preserved.
- Use Replace for a revised movie. Its existing timeline start is preserved.
- Avoid Auto Rearrange after manual spotting; it repositions all cues.
- `.lvcue` stores absolute media paths. Use Replace to relink moved files.

## 7. Troubleshooting

- AU missing: quit Logic, confirm the complete app is in `/Applications`,
  launch the app once, then reopen Logic.
- Sync port missing: keep the app running and restart Logic.
- Orange status: no MTC is arriving; check the destination and MTC checkbox.
- Playback works but locate does not: enable MMC on the same destination.
- Slow seeking: test a ProRes Proxy reference with frequent keyframes.
- Missing media: select the cue and use Replace to preserve its timecode.
