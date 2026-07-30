// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

enum TimelineFrameRate: String, CaseIterable, Codable, Identifiable, Sendable {
    case fps24 = "24"
    case fps25 = "25"
    case fps2997Drop = "29.97 DF"
    case fps30 = "30"
    case fps50 = "50"
    case fps60 = "60"

    var id: String { rawValue }

    var exactFramesPerSecond: Double {
        switch self {
        case .fps24: 24
        case .fps25: 25
        case .fps2997Drop: 30_000 / 1_001
        case .fps30: 30
        case .fps50: 50
        case .fps60: 60
        }
    }

    var nominalFramesPerSecond: Int {
        switch self {
        case .fps24: 24
        case .fps25: 25
        case .fps2997Drop, .fps30: 30
        case .fps50: 50
        case .fps60: 60
        }
    }

    var isDropFrame: Bool {
        self == .fps2997Drop
    }
}

struct SMPTETimecode: Equatable, Sendable {
    let hours: Int
    let minutes: Int
    let seconds: Int
    let frames: Int

    var text: String {
        String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    static func format(seconds rawSeconds: Double, at rate: TimelineFrameRate) -> String {
        let seconds = max(0, rawSeconds.isFinite ? rawSeconds : 0)

        if rate.isDropFrame {
            return formatDropFrame(seconds: seconds)
        }

        let nominalRate = rate.nominalFramesPerSecond
        var totalFrames = Int((seconds * rate.exactFramesPerSecond).rounded())
        let framesPer24Hours = nominalRate * 60 * 60 * 24
        totalFrames %= framesPer24Hours

        let hours = totalFrames / (nominalRate * 60 * 60)
        totalFrames %= nominalRate * 60 * 60
        let minutes = totalFrames / (nominalRate * 60)
        totalFrames %= nominalRate * 60
        let wholeSeconds = totalFrames / nominalRate
        let frames = totalFrames % nominalRate

        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, wholeSeconds, frames)
    }

    static func parse(_ text: String, at rate: TimelineFrameRate) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ";", with: ":")
        let fields = normalized.split(separator: ":", omittingEmptySubsequences: false)

        guard fields.count == 4,
              let hours = Int(fields[0]),
              let minutes = Int(fields[1]),
              let wholeSeconds = Int(fields[2]),
              let frames = Int(fields[3]),
              (0...23).contains(hours),
              (0...59).contains(minutes),
              (0...59).contains(wholeSeconds),
              (0..<rate.nominalFramesPerSecond).contains(frames) else {
            return nil
        }

        return Self.seconds(
            hours: hours,
            minutes: minutes,
            seconds: wholeSeconds,
            frames: frames,
            rate: rate
        )
    }

    static func seconds(
        hours: Int,
        minutes: Int,
        seconds: Int,
        frames: Int,
        rate: TimelineFrameRate
    ) -> Double {
        let nominalRate = rate.nominalFramesPerSecond
        var frameNumber = ((hours * 3_600 + minutes * 60 + seconds) * nominalRate) + frames

        if rate.isDropFrame {
            let totalMinutes = hours * 60 + minutes
            let droppedFrames = 2 * (totalMinutes - totalMinutes / 10)
            frameNumber -= droppedFrames
        }

        return Double(frameNumber) / rate.exactFramesPerSecond
    }

    private static func formatDropFrame(seconds: Double) -> String {
        let exactRate = 30_000.0 / 1_001.0
        let nominalRate = 30
        let dropFrames = 2
        let framesPer10Minutes = 17_982
        let framesPerMinute = 1_798
        let framesPer24Hours = 2_589_408

        var frameNumber = Int((seconds * exactRate).rounded()) % framesPer24Hours
        let tenMinuteBlocks = frameNumber / framesPer10Minutes
        let remainingFrames = frameNumber % framesPer10Minutes

        frameNumber += dropFrames * 9 * tenMinuteBlocks
        if remainingFrames > dropFrames {
            frameNumber += dropFrames * ((remainingFrames - dropFrames) / framesPerMinute)
        }

        let hours = frameNumber / (nominalRate * 3_600)
        frameNumber %= nominalRate * 3_600
        let minutes = frameNumber / (nominalRate * 60)
        frameNumber %= nominalRate * 60
        let wholeSeconds = frameNumber / nominalRate
        let frames = frameNumber % nominalRate

        return String(format: "%02d:%02d:%02d;%02d", hours, minutes, wholeSeconds, frames)
    }
}

struct CueClip: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var displayName: String
    var filePath: String
    var timelineStart: Double
    var sourceIn: Double = 0
    var duration: Double
    var nominalFrameRate: Double
    var width: Int
    var height: Int

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var timelineEnd: Double {
        timelineStart + max(0, duration)
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }
}

enum ArrangementMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case fixedInterval = "每隔固定時間"
    case backToBack = "首尾相接"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .fixedInterval:
            String(localized: "Fixed interval")
        case .backToBack:
            String(localized: "Back-to-back")
        }
    }
}

struct CueProject: Codable, Sendable {
    var formatVersion = 2
    var projectID = UUID()
    var name = "Untitled"
    var timelineFrameRate = TimelineFrameRate.fps30
    var baseTime = 3_600.0
    var arrangementMode = ArrangementMode.fixedInterval
    var fixedInterval = 60.0
    var gap = 2.0
    var syncOffsetSeconds = 0.0
    var videoAudioMuted = true
    var clips: [CueClip] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case formatVersion
        case projectID
        case name
        case timelineFrameRate
        case baseTime
        case arrangementMode
        case fixedInterval
        case gap
        case syncOffsetSeconds
        case videoAudioMuted
        case clips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .formatVersion
        ) ?? 1
        projectID = try container.decodeIfPresent(
            UUID.self,
            forKey: .projectID
        ) ?? UUID()
        name = try container.decodeIfPresent(
            String.self,
            forKey: .name
        ) ?? "Untitled"
        timelineFrameRate = try container.decodeIfPresent(
            TimelineFrameRate.self,
            forKey: .timelineFrameRate
        ) ?? .fps30
        baseTime = try container.decodeIfPresent(
            Double.self,
            forKey: .baseTime
        ) ?? 3_600
        arrangementMode = try container.decodeIfPresent(
            ArrangementMode.self,
            forKey: .arrangementMode
        ) ?? .fixedInterval
        fixedInterval = try container.decodeIfPresent(
            Double.self,
            forKey: .fixedInterval
        ) ?? 60
        gap = try container.decodeIfPresent(
            Double.self,
            forKey: .gap
        ) ?? 2
        syncOffsetSeconds = try container.decodeIfPresent(
            Double.self,
            forKey: .syncOffsetSeconds
        ) ?? 0
        videoAudioMuted = try container.decodeIfPresent(
            Bool.self,
            forKey: .videoAudioMuted
        ) ?? true
        clips = try container.decodeIfPresent(
            [CueClip].self,
            forKey: .clips
        ) ?? []

        if formatVersion < 2 {
            formatVersion = 2
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(name, forKey: .name)
        try container.encode(
            timelineFrameRate,
            forKey: .timelineFrameRate
        )
        try container.encode(baseTime, forKey: .baseTime)
        try container.encode(arrangementMode, forKey: .arrangementMode)
        try container.encode(fixedInterval, forKey: .fixedInterval)
        try container.encode(gap, forKey: .gap)
        try container.encode(
            syncOffsetSeconds,
            forKey: .syncOffsetSeconds
        )
        try container.encode(videoAudioMuted, forKey: .videoAudioMuted)
        try container.encode(clips, forKey: .clips)
    }

    mutating func sortClips() {
        clips.sort {
            if $0.timelineStart == $1.timelineStart {
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            return $0.timelineStart < $1.timelineStart
        }
    }
}

extension UTType {
    static let logicVideoCueProject = UTType(
        exportedAs: "com.local.logic-video-cue.project",
        conformingTo: .json
    )
}
