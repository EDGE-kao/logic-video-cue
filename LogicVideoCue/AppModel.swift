// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import Combine
import Foundation
import UniformTypeIdentifiers

struct UserAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var project = CueProject()
    @Published var selectedClipID: UUID?
    @Published var currentTime = 3_600.0
    @Published var syncEnabled = true
    @Published var alwaysOnTop = true
    @Published var isPreviewPlaying = false
    @Published var isLoadingMedia = false
    @Published var currentProjectURL: URL?
    @Published var alert: UserAlert?
    @Published private(set) var hasUnsavedChanges = false

    let syncManager = LogicSyncManager()
    let timelinePlayer = TimelinePlayer()
    let bridgeManager = AUBridgeManager()

    private var outputWindowController: OutputWindowController?
    private var previewTimer: AnyCancellable?
    private var lastPreviewTick: Date?
    private var cancellables = Set<AnyCancellable>()
    private var failedAutomaticProjectIDs = Set<UUID>()
    private var pendingAutomaticProject: AUBridgeEnvelope?

    init() {
        currentTime = project.baseTime
        timelinePlayer.setMuted(project.videoAudioMuted)

        timelinePlayer.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        bridgeManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        $project
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)

        $currentTime
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seconds in
                self?.outputWindowController?.updateTimelineTime(seconds)
            }
            .store(in: &cancellables)

        syncManager.onMessage = { [weak self] message in
            self?.handleSyncMessage(message)
        }

        bridgeManager.onLinkedProjectDetected = { [weak self] envelope in
            self?.handleLinkedProjectDetected(envelope)
        }
    }

    var selectedClip: CueClip? {
        guard let selectedClipID else { return nil }
        return project.clips.first(where: { $0.id == selectedClipID })
    }

    var currentTimecode: String {
        SMPTETimecode.format(seconds: currentTime, at: project.timelineFrameRate)
    }

    var baseTimecode: String {
        SMPTETimecode.format(seconds: project.baseTime, at: project.timelineFrameRate)
    }

    var projectDisplayName: String {
        project.name == "Untitled"
            ? String(localized: "Untitled")
            : project.name
    }

    var auBridgeStatusText: String {
        guard let presence = bridgeManager.preferredBridge(
            for: project.projectID
        ) else {
            return String(localized: "Link AU not detected")
        }

        if presence.envelope.projectID == project.projectID {
            return String(localized: "Linked to the current cue project")
        }
        if presence.envelope.projectID == nil {
            return String(localized: "Link AU connected, not yet linked")
        }
        return String(localized: "Link AU is linked to another cue")
    }

    var auBridgeDetailText: String {
        guard let presence = bridgeManager.preferredBridge(
            for: project.projectID
        ) else {
            return String(
                localized: "Insert Logic Video Cue: Link once in Logic's Audio FX."
            )
        }

        if presence.envelope.projectID == project.projectID {
            return String(
                localized: "When Logic opens this project, it will ask the app to load this cue automatically."
            )
        }
        if let name = presence.envelope.projectName {
            return String(
                format: String(
                    localized: "The AU currently remembers “%@”. Use the button below to link the current cue."
                ),
                name
            )
        }
        return String(localized: "Save the current cue before creating a link.")
    }

    var auBridgeIsConnected: Bool {
        bridgeManager.preferredBridge(for: project.projectID) != nil
    }

    var auBridgeIsLinkedToCurrentProject: Bool {
        bridgeManager.preferredBridge(
            for: project.projectID
        )?.envelope.projectID == project.projectID
    }

    func importVideos() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Add Short Videos")
        panel.prompt = String(localized: "Add")
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }
        beginAddingVideos(panel.urls)
    }

    @discardableResult
    func importDroppedVideos(_ urls: [URL]) -> Bool {
        let movieURLs = urls.filter(Self.isSupportedMovieURL)

        guard !movieURLs.isEmpty else {
            alert = UserAlert(
                title: String(localized: "No Videos to Add"),
                message: String(
                    localized: "Drop MOV, MP4, or another video format playable by macOS."
                )
            )
            return false
        }

        beginAddingVideos(movieURLs)

        if movieURLs.count != urls.count {
            alert = UserAlert(
                title: String(localized: "Non-Video Files Skipped"),
                message: String(
                    localized: "Playable videos were added; other files were not imported."
                )
            )
        }

        return true
    }

    private func beginAddingVideos(_ urls: [URL]) {
        let sortedURLs = urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        isLoadingMedia = true
        Task {
            defer { isLoadingMedia = false }
            await addVideos(sortedURLs)
        }
    }

    private static func isSupportedMovieURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }

        if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let contentType = values.contentType {
            return contentType.conforms(to: .movie)
        }

        return ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased())
    }

    func replaceSelectedVideo() {
        guard let selectedClipID,
              let index = project.clips.firstIndex(where: { $0.id == selectedClipID }) else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = String(localized: "Replace Video and Preserve Timecode")
        panel.prompt = String(localized: "Replace")
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isLoadingMedia = true
        Task {
            defer { isLoadingMedia = false }
            do {
                var replacement = try await makeClip(
                    from: url,
                    timelineStart: project.clips[index].timelineStart
                )
                replacement.id = project.clips[index].id
                project.clips[index] = replacement
                project.sortClips()
                seekLocally(to: replacement.timelineStart)
            } catch {
                showError(
                    title: String(localized: "Could Not Replace Video"),
                    error: error
                )
            }
        }
    }

    func removeSelectedVideo() {
        guard let selectedClipID else { return }
        project.clips.removeAll(where: { $0.id == selectedClipID })
        self.selectedClipID = project.clips.first?.id
        refreshPlayerAtCurrentTime()
    }

    func autoArrange() {
        var orderedClips = project.clips.sorted {
            if $0.timelineStart == $1.timelineStart {
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            return $0.timelineStart < $1.timelineStart
        }

        var cursor = project.baseTime
        for index in orderedClips.indices {
            orderedClips[index].timelineStart = cursor

            switch project.arrangementMode {
            case .fixedInterval:
                cursor += max(0.1, project.fixedInterval)
            case .backToBack:
                cursor += orderedClips[index].duration + max(0, project.gap)
            }
        }

        project.clips = orderedClips
        currentTime = project.baseTime
        refreshPlayerAtCurrentTime()
    }

    func moveSelectedClip(by offset: Int) {
        guard let selectedClipID else { return }
        var ordered = project.clips.sorted(by: { $0.timelineStart < $1.timelineStart })
        guard let currentIndex = ordered.firstIndex(where: { $0.id == selectedClipID }) else { return }

        let destination = currentIndex + offset
        guard ordered.indices.contains(destination) else { return }

        ordered.swapAt(currentIndex, destination)
        project.clips = ordered
        autoArrange()
    }

    func updateSelectedClipStart(_ timecode: String) -> Bool {
        guard let selectedClipID,
              let seconds = SMPTETimecode.parse(timecode, at: project.timelineFrameRate),
              let index = project.clips.firstIndex(where: { $0.id == selectedClipID }) else {
            return false
        }

        project.clips[index].timelineStart = seconds
        project.sortClips()
        currentTime = seconds
        refreshPlayerAtCurrentTime()
        return true
    }

    func updateBaseTime(_ timecode: String) -> Bool {
        guard let seconds = SMPTETimecode.parse(timecode, at: project.timelineFrameRate) else {
            return false
        }
        project.baseTime = seconds
        return true
    }

    func selectAndLocate(_ clipID: UUID) {
        selectedClipID = clipID
        guard let clip = project.clips.first(where: { $0.id == clipID }) else { return }
        seekLocally(to: clip.timelineStart)
    }

    func togglePreview() {
        if isPreviewPlaying {
            stopPreview()
        } else {
            startPreview()
        }
    }

    func stopPreview() {
        previewTimer?.cancel()
        previewTimer = nil
        lastPreviewTick = nil
        isPreviewPlaying = false
        timelinePlayer.synchronize(
            to: currentTime,
            playing: false,
            clips: project.clips,
            syncOffsetSeconds: project.syncOffsetSeconds
        )
    }

    func showVideoOutput() {
        if outputWindowController == nil {
            outputWindowController = OutputWindowController(player: timelinePlayer.player)
        }
        outputWindowController?.updateTimelineTime(currentTime)
        outputWindowController?.present(alwaysOnTop: alwaysOnTop)
    }

    func updateAlwaysOnTop() {
        outputWindowController?.setAlwaysOnTop(alwaysOnTop)
    }

    func toggleOutputFullScreen() {
        showVideoOutput()
        outputWindowController?.toggleFullScreen()
    }

    func updateVideoAudioMute() {
        timelinePlayer.setMuted(project.videoAudioMuted)
    }

    func updateSyncEnabled() {
        if !syncEnabled {
            timelinePlayer.stop()
        } else {
            refreshPlayerAtCurrentTime()
        }
    }

    func newProject() {
        stopPreview()
        project = CueProject()
        currentProjectURL = nil
        selectedClipID = nil
        currentTime = project.baseTime
        timelinePlayer.setMuted(project.videoAudioMuted)
        timelinePlayer.clear()
        hasUnsavedChanges = false
    }

    func openProject() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Open Logic Video Cue Project")
        panel.prompt = String(localized: "Open")
        panel.allowedContentTypes = [.logicVideoCueProject, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadProject(from: url)
    }

    @discardableResult
    func loadProject(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode(CueProject.self, from: data)
            decoded.sortClips()

            stopPreview()
            project = decoded
            currentProjectURL = url
            currentTime = decoded.baseTime
            selectedClipID = decoded.clips.first?.id
            timelinePlayer.setMuted(decoded.videoAudioMuted)
            refreshPlayerAtCurrentTime()
            rememberProjectLocation(id: decoded.projectID, url: url)
            failedAutomaticProjectIDs.remove(decoded.projectID)
            hasUnsavedChanges = false
            return true
        } catch {
            showError(
                title: String(localized: "Could Not Open Project"),
                error: error
            )
            return false
        }
    }

    @discardableResult
    func saveProject(saveAs: Bool = false) -> Bool {
        var destination = currentProjectURL

        if saveAs || destination == nil {
            let panel = NSSavePanel()
            panel.title = String(localized: "Save Logic Video Cue Project")
            panel.prompt = String(localized: "Save")
            panel.allowedContentTypes = [.logicVideoCueProject]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "\(project.name == "Untitled" ? "LogicVideoCue" : project.name).lvcue"

            guard panel.runModal() == .OK else { return false }
            destination = panel.url
        }

        guard let destination else { return false }

        do {
            var projectToSave = project
            projectToSave.name = destination.deletingPathExtension().lastPathComponent
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(projectToSave)
            try data.write(to: destination, options: .atomic)

            project = projectToSave
            currentProjectURL = destination
            rememberProjectLocation(
                id: projectToSave.projectID,
                url: destination
            )
            hasUnsavedChanges = false

            if let pending = pendingAutomaticProject,
               pending.projectID != projectToSave.projectID {
                pendingAutomaticProject = nil
                Task { @MainActor [weak self] in
                    self?.handleLinkedProjectDetected(pending)
                }
            }
            return true
        } catch {
            showError(
                title: String(localized: "Could Not Save Project"),
                error: error
            )
            return false
        }
    }

    func linkCurrentProjectToAU() {
        guard let bridge = bridgeManager.preferredBridge(
            for: project.projectID
        ) else {
            alert = UserAlert(
                title: String(localized: "Logic Video Cue Link Not Found"),
                message: String(
                    localized: "Insert Audio Units → Logic Video Cue → Link in Logic's Audio FX, and keep Logic open."
                )
            )
            return
        }

        guard saveProject(), let projectURL = currentProjectURL else {
            return
        }

        bridgeManager.link(
            bridgeID: bridge.envelope.bridgeID,
            projectID: project.projectID,
            projectName: project.name,
            projectURL: projectURL
        )

        alert = UserAlert(
            title: String(localized: "Cue Link Sent to Logic"),
            message: String(
                format: String(
                    localized: "Return to Logic and press Command-S once. The next time this Logic project opens, Video Cue will automatically load “%@”."
                ),
                project.name
            )
        )
    }

    private func handleSyncMessage(_ message: LogicSyncMessage) {
        guard syncEnabled else { return }

        if isPreviewPlaying {
            stopPreview()
        }

        switch message {
        case let .timecode(seconds, _):
            currentTime = seconds
            timelinePlayer.synchronize(
                to: currentTime,
                playing: syncManager.isLogicPlaying,
                clips: project.clips,
                syncOffsetSeconds: project.syncOffsetSeconds
            )

        case let .locate(seconds, _):
            currentTime = seconds
            timelinePlayer.synchronize(
                to: currentTime,
                playing: syncManager.isLogicPlaying,
                clips: project.clips,
                syncOffsetSeconds: project.syncOffsetSeconds
            )

        case .play:
            timelinePlayer.synchronize(
                to: currentTime,
                playing: true,
                clips: project.clips,
                syncOffsetSeconds: project.syncOffsetSeconds
            )

        case .pause, .stop:
            timelinePlayer.synchronize(
                to: currentTime,
                playing: false,
                clips: project.clips,
                syncOffsetSeconds: project.syncOffsetSeconds
            )
        }
    }

    private func addVideos(_ urls: [URL]) async {
        var nextStart: Double

        if let lastClip = project.clips.max(by: { $0.timelineStart < $1.timelineStart }) {
            switch project.arrangementMode {
            case .fixedInterval:
                nextStart = lastClip.timelineStart + max(0.1, project.fixedInterval)
            case .backToBack:
                nextStart = lastClip.timelineEnd + max(0, project.gap)
            }
        } else {
            nextStart = project.baseTime
        }

        var imported: [CueClip] = []
        var failures: [String] = []

        for url in urls {
            do {
                let clip = try await makeClip(from: url, timelineStart: nextStart)
                imported.append(clip)

                switch project.arrangementMode {
                case .fixedInterval:
                    nextStart += max(0.1, project.fixedInterval)
                case .backToBack:
                    nextStart += clip.duration + max(0, project.gap)
                }
            } catch {
                failures.append(
                    String(
                        format: String(localized: "%@: %@"),
                        url.lastPathComponent,
                        error.localizedDescription
                    )
                )
            }
        }

        project.clips.append(contentsOf: imported)
        project.sortClips()

        if selectedClipID == nil {
            selectedClipID = imported.first?.id
        }

        if let first = imported.first {
            seekLocally(to: first.timelineStart)
        }

        if !failures.isEmpty {
            alert = UserAlert(
                title: String(localized: "Some Videos Could Not Be Added"),
                message: failures.joined(separator: "\n")
            )
        }
    }

    private func makeClip(from url: URL, timelineStart: Double) async throws -> CueClip {
        let asset = AVURLAsset(url: url)
        let durationTime = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let videoTrack = tracks.first else {
            throw NSError(
                domain: "LogicVideoCue",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(
                        localized: "The file contains no playable video track."
                    )
                ]
            )
        }

        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let transformedSize = naturalSize.applying(transform)
        let duration = durationTime.seconds

        guard duration.isFinite, duration > 0 else {
            throw NSError(
                domain: "LogicVideoCue",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: String(
                        localized: "Could not read the video duration."
                    )
                ]
            )
        }

        return CueClip(
            displayName: url.deletingPathExtension().lastPathComponent,
            filePath: url.path,
            timelineStart: timelineStart,
            duration: duration,
            nominalFrameRate: nominalFrameRate > 0 ? Double(nominalFrameRate) : 30,
            width: Int(abs(transformedSize.width.rounded())),
            height: Int(abs(transformedSize.height.rounded()))
        )
    }

    private func seekLocally(to seconds: Double) {
        stopPreview()
        currentTime = seconds
        refreshPlayerAtCurrentTime()
    }

    private func refreshPlayerAtCurrentTime() {
        timelinePlayer.synchronize(
            to: currentTime,
            playing: false,
            clips: project.clips,
            syncOffsetSeconds: project.syncOffsetSeconds
        )
    }

    private func startPreview() {
        guard !project.clips.isEmpty else { return }

        if project.clips.allSatisfy({ !(currentTime >= $0.timelineStart && currentTime < $0.timelineEnd) }) {
            currentTime = selectedClip?.timelineStart ?? project.clips.first?.timelineStart ?? project.baseTime
        }

        isPreviewPlaying = true
        lastPreviewTick = Date()
        timelinePlayer.synchronize(
            to: currentTime,
            playing: true,
            clips: project.clips,
            syncOffsetSeconds: project.syncOffsetSeconds
        )

        previewTimer?.cancel()
        previewTimer = Timer.publish(
            every: 1.0 / 30.0,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] now in
            guard let self else { return }
            let elapsed = now.timeIntervalSince(self.lastPreviewTick ?? now)
            self.lastPreviewTick = now
            self.currentTime += elapsed

            if let lastEnd = self.project.clips.map(\.timelineEnd).max(), self.currentTime >= lastEnd {
                self.stopPreview()
                return
            }

            self.timelinePlayer.synchronize(
                to: self.currentTime,
                playing: true,
                clips: self.project.clips,
                syncOffsetSeconds: self.project.syncOffsetSeconds
            )
        }
    }

    private func showError(title: String, error: Error) {
        alert = UserAlert(title: title, message: error.localizedDescription)
    }

    private func handleLinkedProjectDetected(
        _ envelope: AUBridgeEnvelope
    ) {
        guard let linkedProjectID = envelope.projectID,
              linkedProjectID != project.projectID,
              !failedAutomaticProjectIDs.contains(linkedProjectID) else {
            return
        }

        if hasUnsavedChanges {
            if pendingAutomaticProject?.projectID != linkedProjectID {
                pendingAutomaticProject = envelope
                alert = UserAlert(
                    title: String(localized: "Logic Wants to Open Another Cue"),
                    message: String(
                        localized: "The current cue has unsaved changes. Press Command-S first; after it is saved, the cue linked to the Logic project will load."
                    )
                )
            }
            return
        }

        guard let url = resolveLinkedProjectURL(envelope),
              FileManager.default.fileExists(atPath: url.path) else {
            failedAutomaticProjectIDs.insert(linkedProjectID)
            alert = UserAlert(
                title: String(localized: "Cue Linked by Logic Not Found"),
                message: String(
                    localized: "The original .lvcue may have been moved or deleted. Open the correct cue manually, then choose “Link Current Cue Project”."
                )
            )
            return
        }

        _ = loadProject(from: url)
    }

    private func resolveLinkedProjectURL(
        _ envelope: AUBridgeEnvelope
    ) -> URL? {
        if let encoded = envelope.projectBookmarkBase64,
           let data = Data(base64Encoded: encoded) {
            var bookmarkIsStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &bookmarkIsStale
            ), url.isFileURL {
                return url
            }
        }

        if let path = envelope.projectPath {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        guard let projectID = envelope.projectID,
              let path = rememberedProjectPath(id: projectID) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    private func rememberProjectLocation(id: UUID, url: URL) {
        var registry = UserDefaults.standard.dictionary(
            forKey: "LogicVideoCue.projectRegistry"
        ) as? [String: String] ?? [:]
        registry[id.uuidString] = url.path
        UserDefaults.standard.set(
            registry,
            forKey: "LogicVideoCue.projectRegistry"
        )
    }

    private func rememberedProjectPath(id: UUID) -> String? {
        let registry = UserDefaults.standard.dictionary(
            forKey: "LogicVideoCue.projectRegistry"
        ) as? [String: String]
        return registry?[id.uuidString]
    }
}
