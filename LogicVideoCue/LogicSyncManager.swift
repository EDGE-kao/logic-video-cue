// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import CoreMIDI
import Foundation

final class LogicSyncManager: ObservableObject {
    static let virtualPortName = "Logic Video Cue Sync In"

    @Published private(set) var portIsReady = false
    @Published private(set) var isReceiving = false
    @Published private(set) var isLogicPlaying = false
    @Published private(set) var detectedFrameRate: MTCFrameRate?
    @Published private(set) var lastTimecodeSeconds = 0.0
    @Published private(set) var statusMessage = String(localized: "Creating virtual MIDI port…")

    var onMessage: ((LogicSyncMessage) -> Void)?

    private var midiClient = MIDIClientRef()
    private var virtualDestination = MIDIEndpointRef()
    private let decoder = MTCDecoder()
    private var receiveTimeout: Timer?
    private var lastMotionTimecodeSeconds: Double?
    private var transportStopIsLatched = false
    private var advancingTimecodeCount = 0

    init() {
        createVirtualDestination()
    }

    deinit {
        receiveTimeout?.invalidate()
        if virtualDestination != 0 {
            MIDIEndpointDispose(virtualDestination)
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }

    private func createVirtualDestination() {
        let clientStatus = MIDIClientCreate(
            "Logic Video Cue MIDI Client" as CFString,
            nil,
            nil,
            &midiClient
        )

        guard clientStatus == noErr else {
            statusMessage = String(
                format: String(localized: "Could not create CoreMIDI client (error %d)"),
                clientStatus
            )
            return
        }

        let destinationStatus = MIDIDestinationCreateWithBlock(
            midiClient,
            Self.virtualPortName as CFString,
            &virtualDestination
        ) { [weak self] packetList, _ in
            let bytes = Self.copyBytes(from: packetList)
            guard !bytes.isEmpty else { return }

            DispatchQueue.main.async {
                self?.receive(bytes)
            }
        }

        guard destinationStatus == noErr else {
            statusMessage = String(
                format: String(localized: "Could not create virtual MIDI port (error %d)"),
                destinationStatus
            )
            return
        }

        portIsReady = true
        statusMessage = String(localized: "Waiting for Logic to send MTC/MMC")
    }

    private func receive(_ bytes: [UInt8]) {
        let messages = decoder.consume(bytes)
        guard !messages.isEmpty else { return }

        isReceiving = true
        statusMessage = String(localized: "Connected to Logic")

        for message in messages {
            switch message {
            case let .timecode(seconds, frameRate):
                let previousTimecode = lastMotionTimecodeSeconds
                let movementThreshold = 0.5 / frameRate.timelineRate.exactFramesPerSecond
                let timecodeIsAdvancing = previousTimecode.map {
                    abs(seconds - $0) >= movementThreshold
                } ?? false

                lastMotionTimecodeSeconds = seconds
                lastTimecodeSeconds = seconds
                detectedFrameRate = frameRate

                if !isLogicPlaying {
                    if timecodeIsAdvancing {
                        advancingTimecodeCount += 1
                    } else {
                        advancingTimecodeCount = 0
                    }

                    let requiredAdvancingMessages = transportStopIsLatched ? 2 : 1
                    if advancingTimecodeCount >= requiredAdvancingMessages {
                        isLogicPlaying = true
                        transportStopIsLatched = false
                        advancingTimecodeCount = 0
                        onMessage?(.play)
                    }
                }

                if isLogicPlaying, timecodeIsAdvancing {
                    advancingTimecodeCount = 0
                    scheduleReceiveTimeout()
                }

            case let .locate(seconds, frameRate):
                lastMotionTimecodeSeconds = seconds
                lastTimecodeSeconds = seconds
                detectedFrameRate = frameRate
                advancingTimecodeCount = 0

            case .play:
                isLogicPlaying = true
                transportStopIsLatched = false
                advancingTimecodeCount = 0
                scheduleReceiveTimeout()

            case .pause, .stop:
                markTransportStopped()
            }

            onMessage?(message)
        }
    }

    private func scheduleReceiveTimeout() {
        receiveTimeout?.invalidate()
        receiveTimeout = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.markTransportStopped()
            self.onMessage?(.stop)
        }
    }

    private func markTransportStopped() {
        isLogicPlaying = false
        transportStopIsLatched = true
        advancingTimecodeCount = 0
        receiveTimeout?.invalidate()
        receiveTimeout = nil
    }

    private static func copyBytes(from packetList: UnsafePointer<MIDIPacketList>) -> [UInt8] {
        var bytes: [UInt8] = []
        let mutablePacketList = UnsafeMutablePointer<MIDIPacketList>(mutating: packetList)

        withUnsafeMutablePointer(to: &mutablePacketList.pointee.packet) { firstPacket in
            var packetPointer = firstPacket

            for _ in 0..<packetList.pointee.numPackets {
                let packet = packetPointer.pointee
                withUnsafeBytes(of: packet.data) { rawBytes in
                    bytes.append(contentsOf: rawBytes.prefix(Int(packet.length)))
                }
                packetPointer = MIDIPacketNext(packetPointer)
            }
        }

        return bytes
    }
}
