// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

struct AUBridgePresence: Equatable, Sendable {
    var envelope: AUBridgeEnvelope
    var lastSeen: Date
}

@MainActor
final class AUBridgeManager: ObservableObject {
    @Published private(set) var bridges: [UUID: AUBridgePresence] = [:]

    var onLinkedProjectDetected: ((AUBridgeEnvelope) -> Void)?

    private let notificationCenter = DistributedNotificationCenter.default()
    private var helloObserver: NSObjectProtocol?
    private var discoveryTimer: Timer?

    init() {
        helloObserver = notificationCenter.addObserver(
            forName: AUBridgeNotification.hello,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let envelope = AUBridgeEnvelope(
                notificationObject: notification.object
            ) else {
                return
            }

            Task { @MainActor [weak self] in
                self?.receiveHello(envelope)
            }
        }

        discoveryTimer = Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestDiscovery()
            }
        }

        requestDiscovery()
    }

    deinit {
        if let helloObserver {
            notificationCenter.removeObserver(helloObserver)
        }
        discoveryTimer?.invalidate()
    }

    var connectedCount: Int {
        bridges.count
    }

    func preferredBridge(for projectID: UUID?) -> AUBridgePresence? {
        let active = bridges.values.sorted {
            $0.lastSeen > $1.lastSeen
        }

        if let projectID,
           let matching = active.first(where: {
               $0.envelope.projectID == projectID
           }) {
            return matching
        }

        if let unlinked = active.first(where: {
            $0.envelope.projectID == nil
        }) {
            return unlinked
        }

        return active.first
    }

    func requestDiscovery() {
        pruneExpiredBridges()
        notificationCenter.post(
            name: AUBridgeNotification.discover,
            object: nil,
            userInfo: nil
        )
    }

    func link(
        bridgeID: UUID,
        projectID: UUID,
        projectName: String,
        projectURL: URL
    ) {
        let bookmarkBase64: String?
        if let data = try? projectURL.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            bookmarkBase64 = data.base64EncodedString()
        } else {
            bookmarkBase64 = nil
        }

        let envelope = AUBridgeEnvelope(
            bridgeID: bridgeID,
            projectID: projectID,
            projectName: projectName,
            projectPath: projectURL.path,
            projectBookmarkBase64: bookmarkBase64
        )

        notificationCenter.postBridgeEnvelope(
            name: AUBridgeNotification.link,
            envelope: envelope
        )
    }

    private func receiveHello(_ envelope: AUBridgeEnvelope) {
        bridges[envelope.bridgeID] = AUBridgePresence(
            envelope: envelope,
            lastSeen: Date()
        )

        if envelope.projectID != nil {
            onLinkedProjectDetected?(envelope)
        }
    }

    private func pruneExpiredBridges() {
        let expiration = Date().addingTimeInterval(-7)
        bridges = bridges.filter { $0.value.lastSeen >= expiration }
    }
}
