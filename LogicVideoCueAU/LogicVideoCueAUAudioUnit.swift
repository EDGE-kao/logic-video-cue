// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import AudioToolbox
import AVFoundation
import Darwin
import Foundation

final class LogicVideoCueAUAudioUnit: AUAudioUnit {
    private enum StateKey {
        static let bridgeID = "LogicVideoCue.bridgeID"
        static let projectID = "LogicVideoCue.projectID"
        static let projectName = "LogicVideoCue.projectName"
        static let projectPath = "LogicVideoCue.projectPath"
        static let projectBookmark = "LogicVideoCue.projectBookmark"
    }

    private var bridgeID = UUID()
    private var linkedProjectID: UUID?
    private var linkedProjectName: String?
    private var linkedProjectPath: String?
    private var linkedProjectBookmarkBase64: String?

    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    private var internalInputBusses: AUAudioUnitBusArray!
    private var internalOutputBusses: AUAudioUnitBusArray!
    private var internalParameterTree: AUParameterTree!
    private var linkRevisionParameter: AUParameter!

    private let notificationCenter = DistributedNotificationCenter.default()
    private var discoverObserver: NSObjectProtocol?
    private var linkObserver: NSObjectProtocol?

    override init(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions = []
    ) throws {
        try super.init(
            componentDescription: componentDescription,
            options: options
        )

        let defaultFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 2
        )!

        inputBus = try AUAudioUnitBus(format: defaultFormat)
        outputBus = try AUAudioUnitBus(format: defaultFormat)
        internalInputBusses = AUAudioUnitBusArray(
            audioUnit: self,
            busType: .input,
            busses: [inputBus]
        )
        internalOutputBusses = AUAudioUnitBusArray(
            audioUnit: self,
            busType: .output,
            busses: [outputBus]
        )

        linkRevisionParameter = AUParameterTree.createParameter(
            withIdentifier: "linkRevision",
            name: "Link Revision",
            address: 0,
            min: 0,
            max: 16_777_215,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        internalParameterTree = AUParameterTree.createTree(
            withChildren: [linkRevisionParameter]
        )

        installBridgeObservers()
        sendHello()
    }

    deinit {
        if let discoverObserver {
            notificationCenter.removeObserver(discoverObserver)
        }
        if let linkObserver {
            notificationCenter.removeObserver(linkObserver)
        }
    }

    override var inputBusses: AUAudioUnitBusArray {
        internalInputBusses
    }

    override var outputBusses: AUAudioUnitBusArray {
        internalOutputBusses
    }

    override var parameterTree: AUParameterTree? {
        get {
            internalParameterTree
        }
        set {
            internalParameterTree = newValue
        }
    }

    override var latency: TimeInterval {
        0
    }

    override var tailTime: TimeInterval {
        0
    }

    override var shouldBypassEffect: Bool {
        get { false }
        set {}
    }

    override var fullState: [String: Any]? {
        get { bridgeState(merging: super.fullState) }
        set {
            super.fullState = newValue
            restoreBridgeState(from: newValue)
        }
    }

    override var fullStateForDocument: [String: Any]? {
        get { bridgeState(merging: super.fullStateForDocument) }
        set {
            super.fullStateForDocument = newValue
            restoreBridgeState(from: newValue)
        }
    }

    override var internalRenderBlock: AUInternalRenderBlock {
        { actionFlags, timestamp, frameCount, _, outputData, _, pullInputBlock in
            guard let pullInputBlock else {
                let buffers = UnsafeMutableAudioBufferListPointer(outputData)
                for buffer in buffers {
                    guard let data = buffer.mData else { continue }
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }

            return pullInputBlock(
                actionFlags,
                timestamp,
                frameCount,
                0,
                outputData
            )
        }
    }

    private func installBridgeObservers() {
        discoverObserver = notificationCenter.addObserver(
            forName: AUBridgeNotification.discover,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sendHello()
        }

        linkObserver = notificationCenter.addObserver(
            forName: AUBridgeNotification.link,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let envelope = AUBridgeEnvelope(
                      notificationObject: notification.object
                  ),
                  envelope.bridgeID == self.bridgeID else {
                return
            }

            self.linkedProjectID = envelope.projectID
            self.linkedProjectName = envelope.projectName
            self.linkedProjectPath = envelope.projectPath
            self.linkedProjectBookmarkBase64 =
                envelope.projectBookmarkBase64

            let nextRevision = (
                self.linkRevisionParameter.value + 1
            ).truncatingRemainder(dividingBy: 16_777_215)
            self.linkRevisionParameter.setValue(
                nextRevision,
                originator: nil
            )
            self.sendHello()
        }
    }

    private func sendHello() {
        let envelope = AUBridgeEnvelope(
            bridgeID: bridgeID,
            projectID: linkedProjectID,
            projectName: linkedProjectName,
            projectPath: linkedProjectPath,
            projectBookmarkBase64: linkedProjectBookmarkBase64
        )

        notificationCenter.postBridgeEnvelope(
            name: AUBridgeNotification.hello,
            envelope: envelope
        )
    }

    private func bridgeState(
        merging existingState: [String: Any]?
    ) -> [String: Any] {
        var state = existingState ?? [:]
        state[StateKey.bridgeID] = bridgeID.uuidString
        state[StateKey.projectID] = linkedProjectID?.uuidString
        state[StateKey.projectName] = linkedProjectName
        state[StateKey.projectPath] = linkedProjectPath
        state[StateKey.projectBookmark] = linkedProjectBookmarkBase64
        return state
    }

    private func restoreBridgeState(from state: [String: Any]?) {
        guard let state else {
            sendHello()
            return
        }

        if let string = state[StateKey.bridgeID] as? String,
           let identifier = UUID(uuidString: string) {
            bridgeID = identifier
        }

        if let string = state[StateKey.projectID] as? String {
            linkedProjectID = UUID(uuidString: string)
        } else {
            linkedProjectID = nil
        }

        linkedProjectName = state[StateKey.projectName] as? String
        linkedProjectPath = state[StateKey.projectPath] as? String
        linkedProjectBookmarkBase64 =
            state[StateKey.projectBookmark] as? String
        sendHello()
    }
}
