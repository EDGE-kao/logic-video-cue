# Getting Started with Logic Pro

## 1. Build and install the standalone app

### Option A: Develop and test in Xcode

1. Install Xcode from the Mac App Store and launch it once.
2. Open `LogicVideoCue.xcodeproj`.
3. Select `LogicVideoCue > My Mac` in the scheme menu.
4. Click Run or press `Command-R`.
5. Xcode builds both the standalone app and the embedded
   `LogicVideoCueLink.appex`.

Use this method for development and debugging. Normal day-to-day operation
does not require launching the app from Xcode.

### Option B: Build a standalone `.app`

Double-click `Build_Logic_Video_Cue.command` in the repository root. The script
creates a Release build at:

```text
Build/LogicVideoCue.app
```

Quit Logic Pro, move the complete app to `/Applications`, and launch it once.
The app already contains the Link AUv3; do not extract or move the `.appex`
separately. Xcode is not required after the build is complete.

Because the current source-only beta is not Developer ID-signed or notarized,
macOS may block the first launch. In Finder, Control-click the app, choose
Open, and confirm the prompt.

### Interface language

The standalone app and Link AU support English and Traditional Chinese and
follow macOS by default. To change only the standalone app, open
`System Settings → General → Language & Region → Applications`, add Logic
Video Cue, choose a language, and relaunch the app.

The Link AU runs inside Logic and normally follows the Logic/macOS language.
Restart Logic after changing it. Language selection does not change `.lvcue`
data or synchronization settings.

## 2. Add the Link AU

1. Quit Logic Pro.
2. Confirm that the complete `LogicVideoCue.app` is in `/Applications`, then
   launch it once.
3. Relaunch Logic.
4. Create an unused Aux channel outside the production mix path and name it
   `Logic Video Cue Link`.
5. Insert:

   `Audio Units → Logic Video Cue → Logic Video Cue: Link`

The AU passes audio through without latency or processing. It only stores the
associated `.lvcue` project inside the Logic project; it does not play video.
The plug-in window does not need to remain open. You can hide the Aux channel
and save it in a Logic Project Template.

## 3. Configure MTC and MMC

Launch Logic Video Cue before Logic so the virtual MIDI port is available when
Logic builds its destination list.

Open:

`File → Project Settings → Synchronization → MIDI`

On an unused destination row:

- Destination: `Logic Video Cue Sync In`
- MTC: on
- MMC: on
- `Transmit MIDI Machine Control (MMC)`: on
- `Listen to MIDI Machine Control (MMC) input`: off

If an older Logic version uses the legacy synchronization interface, enable
Transmit MTC, choose `Logic Video Cue Sync In`, and enable
`Transmit MIDI Machine Control (MMC)`.

Under `Synchronization → General`:

- Sync Mode: `Internal`
- Project Frame Rate: match the reference-video standard

Logic is the master and Logic Video Cue is the slave. Do not set Logic to
follow external MTC. These synchronization settings belong to the Logic
project, so save them in a Logic Project Template if you create projects
frequently.

## 4. Create and link a cue project

1. Drag one or more MOV/MP4 files from Finder into Logic Video Cue, or use the
   `Add Videos` button and select multiple files.
2. Choose fixed-interval or back-to-back arrangement.
3. The default start timecode is `01:00:00:00`.
4. Use `Auto Arrange Again` if you want the app to position every cue according
   to the current arrangement rule.
5. Create matching markers in Logic if useful for the session.
6. Start Logic playback and confirm that the app status changes from orange to
   green.
7. Press `Command-S` in the app to save the `.lvcue` project.
8. Click `Link Current Cue Project` in the Logic project-link section.
9. Return to Logic and press `Command-S`.

The final Logic save is required because the AU state lives inside the Logic
project.

## 5. Daily workflow and automatic recall

1. Launch the standalone Logic Video Cue app. It may remain on an empty
   project.
2. Open a previously linked Logic project.
3. Logic loads the Link AU, which requests the associated `.lvcue` project.
4. Enable Follow Logic and begin playback.

After the first link and final Logic save, you normally do not need to open the
AU window or manually locate the cue project again.

## 6. Add or replace media

### Add a new clip

1. Stop Logic.
2. Drag the new video into the app or use the `Add Videos` button.
3. The new cue is appended after the existing final cue; existing cue
   timecodes do not move.
4. Select the new cue and edit its start timecode if it belongs elsewhere.

Do not use `Auto Arrange Again` after manual spotting unless you intend to
reposition every cue.

### Replace a revised clip

1. Select the old video.
2. Click Replace.
3. Choose the revised file.

The replacement keeps the original timeline start, so downstream music and
sound-effect positions do not move. Use the same process to relink media after
a file has been moved or renamed.

## 7. Frame-rate guidance

- For 24, 25, 29.97 DF, or 30 fps, select the same standard in Logic and the
  app.
- For 50 fps video, Logic may transmit 25 fps MTC while the app displays a
  50 fps timeline.
- For 60 fps video, Logic may transmit 30 fps MTC while the app displays a
  60 fps timeline.

Synchronization uses absolute seconds, so half-rate MTC still positions 50/60
fps video correctly. Frame-number displays can differ because each side uses
its own nominal frame rate.

## 8. Sync offset

Sync Offset is measured in milliseconds:

- Positive values advance the video.
- Negative values delay the video.

The app already applies the standard two-frame compensation for MTC Quarter
Frame messages. Use Sync Offset only for additional delay introduced by the
display, video codec, or audio device. Start with 10 ms steps, then refine in
1 ms steps.

## 9. Dual displays and Logic fullscreen

1. Click `Video Output` to open the output window.
2. Drag its title bar or the video image to move it to another display.
3. Keep `Keep Output Window on Top` enabled if required.
4. When Logic enters macOS fullscreen, the output window joins that fullscreen
   Space and restores its topmost position.
5. The lower center of the output window displays the Logic timeline in
   `HH:MM:SS.mmm`.

The output window can join all Spaces so it does not remain behind on another
desktop. While an always-on-top output is active, the app temporarily switches
to accessory mode and its Dock icon may disappear. Closing the output window
or disabling `Keep Output Window on Top` restores the normal Dock icon.

## 10. Troubleshooting

### Logic cannot find Logic Video Cue: Link

1. Quit Logic.
2. Confirm that the complete `LogicVideoCue.app` is in `/Applications`, not
   just the Xcode source folder.
3. Launch Logic Video Cue once.
4. Reopen Logic and check the Audio Units menu.

The AUv3 is embedded at `LogicVideoCue.app/Contents/PlugIns`. Do not move the
`.appex` separately.

### The app reports that no Link AU is detected

Confirm that `Logic Video Cue: Link` is inserted in the current Logic project,
then use the refresh control in the app. Restart Logic after installing a new
app build.

### The cue project is not recalled after reopening Logic

The link button saves the `.lvcue` file, but Logic must write the AU state into
its own project. After the first link, return to Logic and press `Command-S`.

### Logic cannot find the virtual MIDI port

1. Keep Logic Video Cue running.
2. Quit and reopen Logic.
3. Return to `Synchronization → MIDI`.

### The status remains orange

Orange means that the virtual port exists but no MTC is arriving. Confirm that
the MTC destination is `Logic Video Cue Sync In` and that MTC is enabled.

### Playback works, but moving the playhead does not locate the video

Enable MMC on the same destination. Locate operations while stopped primarily
use MMC Locate or MTC Full Frame.

### Logic pauses, but the video keeps playing

Confirm that MMC is still enabled for the destination and that you are running
the current app build. The current version handles MMC Pause and locks playback
when incoming timecode stops.

### Video audio stutters

The current player avoids repeated seeks for small MTC differences during
normal playback. If stuttering remains, check whether the picture and the
millisecond timeline also stop. Keep reference video on a healthy local or
external SSD and test a ProRes Proxy file.

### The video is consistently early or late

Adjust Sync Offset in the app. Start with 10 ms steps, then refine in 1 ms
steps.

### H.264/HEVC scrubbing is slow

Long-GOP media is inefficient for repeated frame-accurate seeking. Transcode
the working reference to ProRes Proxy.

### A project opens with missing media

`.lvcue` stores absolute file paths. Select the missing cue and use Replace to
relink the file while preserving its timecode.
