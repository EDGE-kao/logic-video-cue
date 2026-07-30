// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum AUBridgeNotification {
    static let discover = Notification.Name(
        "com.local.logicvideocue.au-bridge.discover.v1"
    )
    static let hello = Notification.Name(
        "com.local.logicvideocue.au-bridge.hello.v1"
    )
    static let link = Notification.Name(
        "com.local.logicvideocue.au-bridge.link.v1"
    )
}

struct AUBridgeEnvelope: Codable, Equatable, Sendable {
    static let currentProtocolVersion = 1

    var protocolVersion = currentProtocolVersion
    var bridgeID: UUID
    var projectID: UUID?
    var projectName: String?
    var projectPath: String?
    var projectBookmarkBase64: String?
    var sentAt = Date().timeIntervalSince1970

    func notificationObject() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    init?(
        notificationObject: Any?,
        requireProtocolVersion: Int = currentProtocolVersion
    ) {
        guard let string = notificationObject as? String,
              let data = string.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Self.self, from: data),
              decoded.protocolVersion == requireProtocolVersion else {
            return nil
        }
        self = decoded
    }

    init(
        bridgeID: UUID,
        projectID: UUID? = nil,
        projectName: String? = nil,
        projectPath: String? = nil,
        projectBookmarkBase64: String? = nil
    ) {
        self.bridgeID = bridgeID
        self.projectID = projectID
        self.projectName = projectName
        self.projectPath = projectPath
        self.projectBookmarkBase64 = projectBookmarkBase64
    }
}

extension DistributedNotificationCenter {
    func postBridgeEnvelope(
        name: Notification.Name,
        envelope: AUBridgeEnvelope
    ) {
        guard let object = envelope.notificationObject() else { return }
        post(
            name: name,
            object: object,
            userInfo: nil
        )
    }
}
