// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView()
                Divider()

                HSplitView {
                    ClipSidebarView()
                        .frame(minWidth: 250, idealWidth: 280, maxWidth: 360)

                    VStack(spacing: 14) {
                        PlayerSurfaceView(
                            player: model.timelinePlayer.player,
                            activeClipName: model.timelinePlayer.activeClipName,
                            statusMessage: model.timelinePlayer.statusMessage
                        )
                        .padding([.top, .horizontal], 16)

                        PlayerControlsView()
                            .padding(.horizontal, 16)

                        Divider()

                        CueStripView()
                            .frame(height: 132)
                            .padding([.horizontal, .bottom], 16)
                    }
                    .frame(minWidth: 560)

                    InspectorPanelView()
                        .frame(minWidth: 280, idealWidth: 310, maxWidth: 380)
                }
            }

            if isDropTargeted {
                DropImportOverlay()
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .frame(minWidth: 1_120, minHeight: 720)
        .dropDestination(for: URL.self) { urls, _ in
            model.importDroppedVideos(urls)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .animation(.easeOut(duration: 0.14), value: isDropTargeted)
        .alert(item: $model.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct DropImportOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.accentColor.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 3, dash: [10, 7])
                    )
            }
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 42, weight: .semibold))
                    Text("Drop to Add Videos")
                        .font(.title2.bold())
                    Text("Add multiple MOV/MP4 files at once")
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.accentColor)
            }
            .padding(12)
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Text(model.projectDisplayName)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 6) {
                Button(action: model.newProject) {
                    Image(systemName: "doc")
                }
                .help("New Project")

                Button(action: model.openProject) {
                    Image(systemName: "folder")
                }
                .help("Open Project")

                Button {
                    model.saveProject()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save Project")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text(model.currentTimecode)
                .font(.system(.title2, design: .monospaced, weight: .semibold))
                .monospacedDigit()

            Spacer()

            Toggle("Follow Logic", isOn: $model.syncEnabled)
                .toggleStyle(.switch)
                .onChange(of: model.syncEnabled) {
                    model.updateSyncEnabled()
                }

            SyncStatusView(syncManager: model.syncManager)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}

private struct SyncStatusView: View {
    @ObservedObject var syncManager: LogicSyncManager

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 1) {
                Text(syncManager.statusMessage)
                    .font(.caption)
                    .lineLimit(1)

                if let rate = syncManager.detectedFrameRate {
                    Text(verbatim: "MTC \(rate.displayName) fps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(LogicSyncManager.virtualPortName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 170, alignment: .leading)
    }

    private var statusColor: Color {
        if syncManager.isReceiving {
            return .green
        }
        if syncManager.portIsReady {
            return .orange
        }
        return .red
    }
}

private struct ClipSidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Videos")
                    .font(.headline)
                Spacer()
                if model.isLoadingMedia {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(verbatim: String(model.project.clips.count))
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            Divider()

            if model.project.clips.isEmpty {
                ContentUnavailableView {
                    Label("No Videos Added", systemImage: "film.stack")
                } description: {
                    Text("Use the button below, or drag multiple MOV/MP4 files directly from Finder.")
                } actions: {
                    Button("Add Videos", action: model.importVideos)
                }
            } else {
                List(selection: $model.selectedClipID) {
                    ForEach(model.project.clips) { clip in
                        ClipListRow(clip: clip)
                            .tag(clip.id)
                            .contextMenu {
                                Button("Locate to Video Start") {
                                    model.selectAndLocate(clip.id)
                                }
                                Button("Replace Video…") {
                                    model.selectedClipID = clip.id
                                    model.replaceSelectedVideo()
                                }
                                Divider()
                                Button("Remove", role: .destructive) {
                                    model.selectedClipID = clip.id
                                    model.removeSelectedVideo()
                                }
                            }
                    }
                }
                .onChange(of: model.selectedClipID) { _, newSelection in
                    if let newSelection {
                        model.selectAndLocate(newSelection)
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                Button(action: model.importVideos) {
                    Image(systemName: "plus")
                }
                .help("Add Multiple Videos")

                Button(action: model.replaceSelectedVideo) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(model.selectedClipID == nil)
                .help("Replace Video and Preserve Timecode")

                Button(action: model.removeSelectedVideo) {
                    Image(systemName: "minus")
                }
                .disabled(model.selectedClipID == nil)
                .help("Remove Video")

                Spacer()

                Button {
                    model.moveSelectedClip(by: -1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(model.selectedClipID == nil)
                .help("Move Earlier")

                Button {
                    model.moveSelectedClip(by: 1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .disabled(model.selectedClipID == nil)
                .help("Move Later")
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ClipListRow: View {
    @EnvironmentObject private var model: AppModel
    let clip: CueClip

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: clip.fileExists ? "film" : "exclamationmark.triangle.fill")
                .foregroundStyle(
                    clip.fileExists
                        ? AnyShapeStyle(.secondary)
                        : AnyShapeStyle(Color.orange)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(clip.displayName)
                    .lineLimit(1)

                Text(SMPTETimecode.format(
                    seconds: clip.timelineStart,
                    at: model.project.timelineFrameRate
                ))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if model.timelinePlayer.activeClipID == clip.id {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct PlayerControlsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Button(action: model.togglePreview) {
                Label(
                    model.isPreviewPlaying
                        ? String(localized: "Stop Preview")
                        : String(localized: "Local Preview"),
                    systemImage: model.isPreviewPlaying ? "stop.fill" : "play.fill"
                )
            }

            if let selected = model.selectedClipID {
                Button {
                    model.selectAndLocate(selected)
                } label: {
                    Label("Locate Start", systemImage: "backward.end.fill")
                }
            }

            Spacer()

            Toggle("Mute Video Audio", isOn: $model.project.videoAudioMuted)
                .onChange(of: model.project.videoAudioMuted) {
                    model.updateVideoAudioMute()
                }

            Toggle("Keep Output Window on Top", isOn: $model.alwaysOnTop)
                .onChange(of: model.alwaysOnTop) {
                    model.updateAlwaysOnTop()
                }

            Button(action: model.showVideoOutput) {
                Label("Video Output", systemImage: "macwindow.on.rectangle")
            }

            Button(action: model.toggleOutputFullScreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Full Screen Video Output")
        }
    }
}

private struct CueStripView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cue Strip")
                .font(.headline)

            if model.project.clips.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay {
                        Text("After adding videos, each video remains an independent cue.")
                            .foregroundStyle(.secondary)
                    }
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(model.project.clips) { clip in
                            Button {
                                model.selectAndLocate(clip.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: clip.fileExists ? "film" : "exclamationmark.triangle")
                                        Text(clip.displayName)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                    }

                                    Text(SMPTETimecode.format(
                                        seconds: clip.timelineStart,
                                        at: model.project.timelineFrameRate
                                    ))
                                    .font(.system(.caption, design: .monospaced))

                                    Text(String(
                                        format: String(localized: "%.2f sec · %.2f fps"),
                                        clip.duration,
                                        clip.nominalFrameRate
                                    ))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 170, alignment: .leading)
                                .padding(10)
                                .background(cardColor(for: clip), in: RoundedRectangle(cornerRadius: 9))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(borderColor(for: clip), lineWidth: 1.5)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func cardColor(for clip: CueClip) -> Color {
        if model.timelinePlayer.activeClipID == clip.id {
            return .green.opacity(0.14)
        }
        if model.selectedClipID == clip.id {
            return .accentColor.opacity(0.14)
        }
        return Color.secondary.opacity(0.08)
    }

    private func borderColor(for clip: CueClip) -> Color {
        if model.timelinePlayer.activeClipID == clip.id {
            return .green
        }
        if model.selectedClipID == clip.id {
            return .accentColor
        }
        return .clear
    }
}

private struct InspectorPanelView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseTimeEntry = "01:00:00:00"
    @State private var clipStartEntry = "01:00:00:00"
    @State private var baseTimeIsInvalid = false
    @State private var clipStartIsInvalid = false

    private var syncOffsetMilliseconds: Binding<Double> {
        Binding(
            get: { model.project.syncOffsetSeconds * 1_000 },
            set: { model.project.syncOffsetSeconds = $0 / 1_000 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Project") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Timeline fps") {
                            Picker("", selection: $model.project.timelineFrameRate) {
                                ForEach(TimelineFrameRate.allCases) { rate in
                                    Text(rate.rawValue).tag(rate)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 110)
                        }

                        LabeledContent("Start Timecode") {
                            TextField("01:00:00:00", text: $baseTimeEntry)
                                .font(.system(.body, design: .monospaced))
                                .multilineTextAlignment(.trailing)
                                .onSubmit(commitBaseTime)
                                .frame(width: 118)
                        }

                        if baseTimeIsInvalid {
                            Text("Invalid timecode format")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Picker("Arrangement", selection: $model.project.arrangementMode) {
                            ForEach(ArrangementMode.allCases) { mode in
                                Text(mode.localizedName).tag(mode)
                            }
                        }

                        if model.project.arrangementMode == .fixedInterval {
                            LabeledContent("Interval") {
                                TextField(
                                    "60",
                                    value: $model.project.fixedInterval,
                                    format: .number.precision(.fractionLength(0...2))
                                )
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                                Text("sec")
                            }
                        } else {
                            LabeledContent("Gap Between Videos") {
                                TextField(
                                    "2",
                                    value: $model.project.gap,
                                    format: .number.precision(.fractionLength(0...2))
                                )
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                                Text("sec")
                            }
                        }

                        Button("Auto Arrange Again", action: model.autoArrange)
                            .frame(maxWidth: .infinity)

                        Divider()

                        LabeledContent("Sync Offset") {
                            TextField(
                                "0",
                                value: syncOffsetMilliseconds,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            Text("ms")
                        }

                        Text("Positive values advance video; negative values delay it.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(7)
                }

                GroupBox("Logic Project Link") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(bridgeStatusColor)
                                .frame(width: 9, height: 9)

                            Text(model.auBridgeStatusText)
                                .fontWeight(.medium)
                        }

                        Text(model.auBridgeDetailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                        HStack {
                            Button(
                                "Link Current Cue Project",
                                action: model.linkCurrentProjectToAU
                            )
                            .disabled(!model.auBridgeIsConnected)

                            Button {
                                model.bridgeManager.requestDiscovery()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .help("Detect Logic Link AU Again")
                        }

                        if model.auBridgeIsLinkedToCurrentProject {
                            Label(
                                "After the first link, return to Logic and press Command-S.",
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.caption2)
                            .foregroundStyle(.green)
                        }
                    }
                    .padding(7)
                }

                GroupBox("Selected Video") {
                    if let clip = model.selectedClip {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(clip.displayName)
                                .font(.headline)
                                .textSelection(.enabled)

                            LabeledContent("Start") {
                                TextField("01:00:00:00", text: $clipStartEntry)
                                    .font(.system(.body, design: .monospaced))
                                    .multilineTextAlignment(.trailing)
                                    .onSubmit(commitClipStart)
                                    .frame(width: 118)
                            }

                            if clipStartIsInvalid {
                                Text("Invalid timecode format")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            LabeledContent("Duration") {
                                Text(String(
                                    format: String(localized: "%.3f sec"),
                                    clip.duration
                                ))
                            }
                            LabeledContent("Frame rate") {
                                Text(String(format: "%.3f", clip.nominalFrameRate))
                            }
                            LabeledContent("Dimensions") {
                                Text(verbatim: "\(clip.width) × \(clip.height)")
                            }

                            Text(clip.filePath)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)

                            if !clip.fileExists {
                                Label(
                                    "The original video has moved or no longer exists.",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            HStack {
                                Button("Replace…", action: model.replaceSelectedVideo)
                                Button("Remove", role: .destructive, action: model.removeSelectedVideo)
                            }
                        }
                        .padding(7)
                    } else {
                        Text("Select a video from the sidebar.")
                            .foregroundStyle(.secondary)
                            .padding(7)
                    }
                }
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear(perform: reloadTimecodeFields)
        .onChange(of: model.selectedClipID) { reloadTimecodeFields() }
        .onChange(of: model.project.timelineFrameRate) { reloadTimecodeFields() }
        .onChange(of: model.project.baseTime) {
            baseTimeEntry = model.baseTimecode
        }
    }

    private func reloadTimecodeFields() {
        baseTimeEntry = model.baseTimecode
        if let clip = model.selectedClip {
            clipStartEntry = SMPTETimecode.format(
                seconds: clip.timelineStart,
                at: model.project.timelineFrameRate
            )
        }
        baseTimeIsInvalid = false
        clipStartIsInvalid = false
    }

    private func commitBaseTime() {
        baseTimeIsInvalid = !model.updateBaseTime(baseTimeEntry)
        if !baseTimeIsInvalid {
            baseTimeEntry = model.baseTimecode
        }
    }

    private func commitClipStart() {
        clipStartIsInvalid = !model.updateSelectedClipStart(clipStartEntry)
        if !clipStartIsInvalid, let clip = model.selectedClip {
            clipStartEntry = SMPTETimecode.format(
                seconds: clip.timelineStart,
                at: model.project.timelineFrameRate
            )
        }
    }

    private var bridgeStatusColor: Color {
        if model.auBridgeIsLinkedToCurrentProject {
            return .green
        }
        if model.auBridgeIsConnected {
            return .orange
        }
        return .secondary
    }
}
