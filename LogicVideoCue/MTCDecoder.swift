// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum MTCFrameRate: Equatable, Sendable {
    case fps24
    case fps25
    case fps2997Drop
    case fps30

    init(rateCode: UInt8) {
        switch rateCode & 0x03 {
        case 0: self = .fps24
        case 1: self = .fps25
        case 2: self = .fps2997Drop
        default: self = .fps30
        }
    }

    var timelineRate: TimelineFrameRate {
        switch self {
        case .fps24: .fps24
        case .fps25: .fps25
        case .fps2997Drop: .fps2997Drop
        case .fps30: .fps30
        }
    }

    var displayName: String {
        timelineRate.rawValue
    }
}

enum LogicSyncMessage: Equatable, Sendable {
    case timecode(seconds: Double, frameRate: MTCFrameRate)
    case locate(seconds: Double, frameRate: MTCFrameRate)
    case play
    case pause
    case stop
}

/// Decodes the MIDI 1.0 messages Logic uses for MTC and MMC.
///
/// Quarter-frame MTC arrives two frames behind the represented playback
/// position, so forward-running quarter-frame messages receive the standard
/// two-frame compensation here. Full-frame and MMC Locate messages do not.
final class MTCDecoder {
    private var quarterFrameNibbles = Array(repeating: UInt8(0), count: 8)
    private var receivedQuarterFrameMask: UInt8 = 0
    private var waitingForQuarterFrameData = false
    private var systemExclusiveBuffer: [UInt8]?

    func reset() {
        quarterFrameNibbles = Array(repeating: 0, count: 8)
        receivedQuarterFrameMask = 0
        waitingForQuarterFrameData = false
        systemExclusiveBuffer = nil
    }

    func consume(_ bytes: [UInt8]) -> [LogicSyncMessage] {
        var messages: [LogicSyncMessage] = []

        for byte in bytes {
            if systemExclusiveBuffer != nil {
                systemExclusiveBuffer?.append(byte)
                if byte == 0xF7 {
                    let completeMessage = systemExclusiveBuffer ?? []
                    systemExclusiveBuffer = nil
                    if let message = parseSystemExclusive(completeMessage) {
                        messages.append(message)
                    }
                }
                continue
            }

            if byte == 0xF0 {
                systemExclusiveBuffer = [byte]
                waitingForQuarterFrameData = false
                continue
            }

            if byte == 0xF1 {
                waitingForQuarterFrameData = true
                continue
            }

            if waitingForQuarterFrameData, byte < 0x80 {
                waitingForQuarterFrameData = false
                if let message = parseQuarterFrame(dataByte: byte) {
                    messages.append(message)
                }
                continue
            }

            // MIDI real-time bytes can legally be interleaved with other data.
            if byte >= 0xF8 {
                continue
            }

            waitingForQuarterFrameData = false
        }

        return messages
    }

    private func parseQuarterFrame(dataByte: UInt8) -> LogicSyncMessage? {
        let piece = Int((dataByte >> 4) & 0x07)
        let value = dataByte & 0x0F
        quarterFrameNibbles[piece] = value
        receivedQuarterFrameMask |= UInt8(1 << piece)

        guard piece == 7, receivedQuarterFrameMask == 0xFF else {
            return nil
        }

        let frames = Int(quarterFrameNibbles[0] | (quarterFrameNibbles[1] << 4))
        let seconds = Int(quarterFrameNibbles[2] | (quarterFrameNibbles[3] << 4))
        let minutes = Int(quarterFrameNibbles[4] | (quarterFrameNibbles[5] << 4))
        let hours = Int(quarterFrameNibbles[6] | ((quarterFrameNibbles[7] & 0x01) << 4))
        let frameRate = MTCFrameRate(rateCode: (quarterFrameNibbles[7] >> 1) & 0x03)

        let rawTime = SMPTETimecode.seconds(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            frames: frames,
            rate: frameRate.timelineRate
        )
        let compensatedTime = rawTime + (2.0 / frameRate.timelineRate.exactFramesPerSecond)

        return .timecode(seconds: compensatedTime, frameRate: frameRate)
    }

    private func parseSystemExclusive(_ bytes: [UInt8]) -> LogicSyncMessage? {
        guard bytes.count >= 6,
              bytes.first == 0xF0,
              bytes.last == 0xF7,
              bytes[1] == 0x7F else {
            return nil
        }

        // MIDI Time Code Full Frame:
        // F0 7F <device> 01 01 <hr/rate> <min> <sec> <frame> F7
        if bytes.count >= 10, bytes[3] == 0x01, bytes[4] == 0x01 {
            let rate = MTCFrameRate(rateCode: (bytes[5] >> 5) & 0x03)
            let seconds = SMPTETimecode.seconds(
                hours: Int(bytes[5] & 0x1F),
                minutes: Int(bytes[6] & 0x3F),
                seconds: Int(bytes[7] & 0x3F),
                frames: Int(bytes[8] & 0x1F),
                rate: rate.timelineRate
            )
            return .locate(seconds: seconds, frameRate: rate)
        }

        guard bytes[3] == 0x06 else {
            return nil
        }

        switch bytes[4] {
        case 0x01:
            return .stop
        case 0x02, 0x03:
            return .play
        case 0x09:
            return .pause
        case 0x44:
            // MMC Locate:
            // F0 7F <device> 06 44 06 01 <hr/rate> <min> <sec> <frame> <subframe> F7
            guard bytes.count >= 13, bytes[5] == 0x06, bytes[6] == 0x01 else {
                return nil
            }
            let rate = MTCFrameRate(rateCode: (bytes[7] >> 5) & 0x03)
            var seconds = SMPTETimecode.seconds(
                hours: Int(bytes[7] & 0x1F),
                minutes: Int(bytes[8] & 0x3F),
                seconds: Int(bytes[9] & 0x3F),
                frames: Int(bytes[10] & 0x1F),
                rate: rate.timelineRate
            )
            seconds += Double(bytes[11] & 0x7F) / 100.0 / rate.timelineRate.exactFramesPerSecond
            return .locate(seconds: seconds, frameRate: rate)
        default:
            return nil
        }
    }
}
