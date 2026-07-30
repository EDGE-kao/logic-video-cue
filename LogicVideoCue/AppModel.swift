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

    var auBridgeStatusText: String {
        guard let presence = bridgeManager.preferredBridge(
            for: project.projectID
        ) else {
            return "尚未偵測到 Link AU"
        }

        if presence.envelope.projectID == project.projectID {
            return "已連結目前 Cue 專案"
        }
        if presence.envelope.projectID == nil {
            return "Link AU 已連線，尚未連結"
        }
        return "Link AU 已連結其他 Cue"
    }

    var auBridgeDetailText: String {
        guard let presence = bridgeManager.preferredBridge(
            for: project.projectID
        ) else {
            return "請在 Logic 的 Audio FX 插入一次 Logic Video Cue: Link。"
        }

        if presence.envelope.projectID == project.projectID {
            return "Logic 開啟這個專案時，會自動要求 App 載入此 Cue。"
        }
        if let name = presence.envelope.projectName {
            return "目前 AU 記住的是「\(name)」，按下方按鈕可改為目前 Cue。"
        }
        return "先儲存目前 Cue，再建立一次連結。"
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
        panel.title = "加入短影片"
        panel.prompt = "加入"
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
                title: "沒有可加入的影片",
                message: "請拖入 MOV、MP4 或其他 macOS 可播放的影片檔案。"
            )
            return false
        }

        beginAddingVideos(movieURLs)

        if movieURLs.count != urls.count {
            alert = UserAlert(
                title: "已略過非影片檔案",
                message: "可播放的影片會照常加入；其他檔案沒有匯入。"
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
        panel.title = "替換影片並保留 Timecode"
        panel.prompt = "替換"
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
                showError(title: "無法替換影片", error: error)
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
        panel.title = "開啟 Logic Video Cue 專案"
        panel.prompt = "開啟"
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
            showError(title: "無法開啟專案", error: error)
            return false
        }
    }

    @discardableResult
    func saveProject(saveAs: Bool = false) -> Bool {
        var destination = currentProjectURL

        if saveAs || destination == nil {
            let panel = NSSavePanel()
            panel.title = "儲存 Logic Video Cue 專案"
            panel.prompt = "儲存"
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
            showError(title: "無法儲存專案", error: error)
            return false
        }
    }

    func linkCurrentProjectToAU() {
        guard let bridge = bridgeManager.preferredBridge(
            for: project.projectID
        ) else {
            alert = UserAlert(
                title: "找不到 Logic Video Cue Link",
                message:
                    "請先在 Logic 的 Audio FX 插入 "
                    + "Audio Units → Logic Video Cue → Link，"
                    + "並保持 Logic 開啟。"
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
            title: "Cue 連結已送到 Logic",
            message:
                "請回到 Logic 按 Command-S 儲存一次。"
                + "之後開啟這個 Logic 專案時，"
                + "Video Cue 就會自動載入「\(project.name)」。"
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
                failures.append("\(url.lastPathComponent)：\(error.localizedDescription)")
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
                title: "部分影片無法加入",
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
                userInfo: [NSLocalizedDescriptionKey: "檔案中沒有可播放的影片軌"]
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
                userInfo: [NSLocalizedDescriptionKey: "無法讀取影片長度"]
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
                    title: "Logic 要開啟另一個 Cue",
                    message:
                        "目前 Cue 尚未儲存。請先按 Command-S，"
                        + "儲存完成後會載入 Logic 專案所連結的 Cue。"
                )
            }
            return
        }

        guard let url = resolveLinkedProjectURL(envelope),
              FileManager.default.fileExists(atPath: url.path) else {
            failedAutomaticProjectIDs.insert(linkedProjectID)
            alert = UserAlert(
                title: "找不到 Logic 連結的 Cue",
                message:
                    "原本的 .lvcue 可能已被移動或刪除。"
                    + "請手動開啟正確的 Cue，再按「連結目前 Cue 專案」。"
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
