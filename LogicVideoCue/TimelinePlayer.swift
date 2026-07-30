// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Combine
import Foundation

@MainActor
final class TimelinePlayer: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var activeClipID: UUID?
    @Published private(set) var activeClipName = "目前位置沒有影片"
    @Published private(set) var statusMessage = "等待影片"

    private var loadedClipID: UUID?
    private var seekGeneration = 0
    private var seekIsInFlight = false
    private var pendingSeekTarget: Double?
    private var shouldPlay = false
    private var lastHardResyncDate: Date?

    init() {
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false
    }

    func setMuted(_ muted: Bool) {
        player.isMuted = muted
    }

    func synchronize(
        to rawTimelineTime: Double,
        playing: Bool,
        clips: [CueClip],
        syncOffsetSeconds: Double
    ) {
        shouldPlay = playing
        if !playing {
            player.pause()
        }

        let timelineTime = max(0, rawTimelineTime + syncOffsetSeconds)
        guard let clip = clips
            .filter({ $0.timelineStart <= timelineTime && timelineTime < $0.timelineEnd })
            .sorted(by: { $0.timelineStart > $1.timelineStart })
            .first else {
            showGap(playing: playing)
            return
        }

        guard clip.fileExists else {
            showMissingFile(for: clip)
            return
        }

        let localTime = clip.sourceIn + (timelineTime - clip.timelineStart)
        let isNewClip = loadedClipID != clip.id

        activeClipID = clip.id
        activeClipName = clip.displayName

        if isNewClip {
            load(clip: clip, at: localTime, playing: playing)
            return
        }

        let currentSeconds = player.currentTime().seconds
        let frameDuration = 1.0 / max(1, clip.nominalFrameRate)
        let drift = currentSeconds.isFinite ? localTime - currentSeconds : .infinity

        if playing {
            // Let AVPlayer run continuously during normal playback. Repeated
            // small seeks are especially audible when the movie audio is on.
            let hardResyncThreshold = max(0.25, frameDuration * 8)
            let hardResyncIsAvailable = lastHardResyncDate.map {
                Date().timeIntervalSince($0) >= 0.75
            } ?? true

            if abs(drift) > hardResyncThreshold,
               !seekIsInFlight,
               hardResyncIsAvailable {
                lastHardResyncDate = Date()
                seek(to: localTime, exact: false) { [weak self] in
                    guard let self else { return }
                    if self.shouldPlay {
                        self.player.playImmediately(atRate: 1)
                    } else {
                        self.player.pause()
                    }
                }
            } else if !seekIsInFlight, player.rate == 0 {
                player.playImmediately(atRate: 1)
            }
        } else {
            let locateThreshold = max(0.005, frameDuration * 0.5)
            let isAlreadySeekingHere = pendingSeekTarget.map {
                seekIsInFlight && abs($0 - localTime) <= locateThreshold
            } ?? false

            if abs(drift) > locateThreshold, !isAlreadySeekingHere {
                seek(to: localTime, exact: true) { [weak self] in
                    guard let self else { return }
                    if self.shouldPlay {
                        self.player.playImmediately(atRate: 1)
                    } else {
                        self.player.pause()
                    }
                }
            }
        }

        statusMessage = playing ? "跟隨 Logic 播放" : "已定位"
    }

    func stop() {
        shouldPlay = false
        player.pause()
        statusMessage = "已停止"
    }

    func clear() {
        shouldPlay = false
        cancelPendingSeeks()
        player.pause()
        player.replaceCurrentItem(with: nil)
        loadedClipID = nil
        activeClipID = nil
        activeClipName = "目前位置沒有影片"
        statusMessage = "等待影片"
    }

    private func load(clip: CueClip, at localTime: Double, playing: Bool) {
        let item = AVPlayerItem(url: clip.fileURL)
        item.preferredForwardBufferDuration = 3

        cancelPendingSeeks()
        shouldPlay = playing
        lastHardResyncDate = nil
        loadedClipID = clip.id
        player.replaceCurrentItem(with: item)
        statusMessage = "載入 \(clip.displayName)"

        seek(to: localTime, exact: !playing) { [weak self] in
            guard let self, self.loadedClipID == clip.id else { return }
            if self.shouldPlay {
                self.player.playImmediately(atRate: 1)
            } else {
                self.player.pause()
            }
            self.statusMessage = self.shouldPlay ? "跟隨 Logic 播放" : "已定位"
        }
    }

    private func seek(to seconds: Double, exact: Bool, completion: @escaping () -> Void) {
        if seekIsInFlight {
            player.currentItem?.cancelPendingSeeks()
        }

        seekGeneration += 1
        let generation = seekGeneration
        let targetSeconds = max(0, seconds)
        let time = CMTime(seconds: targetSeconds, preferredTimescale: 60_000)
        let tolerance = exact ? CMTime.zero : CMTime(seconds: 1.0 / 120.0, preferredTimescale: 60_000)

        seekIsInFlight = true
        pendingSeekTarget = targetSeconds

        player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] finished in
            DispatchQueue.main.async {
                guard let self, self.seekGeneration == generation else { return }
                self.seekIsInFlight = false
                self.pendingSeekTarget = nil
                guard finished else { return }
                completion()
            }
        }
    }

    private func showGap(playing: Bool) {
        if loadedClipID != nil {
            cancelPendingSeeks()
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        loadedClipID = nil
        activeClipID = nil
        activeClipName = "目前位置沒有影片"
        statusMessage = playing ? "播放位置位於影片間隔" : "目前位置沒有影片"
    }

    private func showMissingFile(for clip: CueClip) {
        cancelPendingSeeks()
        player.pause()
        player.replaceCurrentItem(with: nil)
        loadedClipID = nil
        activeClipID = clip.id
        activeClipName = clip.displayName
        statusMessage = "找不到影片檔，請重新連結"
    }

    private func cancelPendingSeeks() {
        seekGeneration += 1
        seekIsInFlight = false
        pendingSeekTarget = nil
        player.currentItem?.cancelPendingSeeks()
    }
}
