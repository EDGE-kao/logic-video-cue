// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AudioToolbox
import CoreAudioKit

final class LogicVideoCueAUViewController:
    AUViewController,
    AUAudioUnitFactory
{
    private var audioUnit: LogicVideoCueAUAudioUnit?

    override func loadView() {
        let root = NSView()

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        if let iconURL = Bundle(for: Self.self).url(
            forResource: "LogicVideoCue-AppIcon-1024",
            withExtension: "png"
        ) {
            iconView.image = NSImage(contentsOf: iconURL)
        } else {
            iconView.image = NSImage(
                systemSymbolName: "film.stack.fill",
                accessibilityDescription: nil
            )
        }

        let title = NSTextField(labelWithString: "Logic Video Cue Link")
        title.font = .systemFont(ofSize: 19, weight: .semibold)

        let subtitle = NSTextField(
            wrappingLabelWithString:
                "這個 AU 只負責把 Logic 專案連結到獨立的 "
                + "Logic Video Cue App，不會處理或改變聲音。"
        )
        subtitle.textColor = .secondaryLabelColor

        let instruction = NSTextField(
            wrappingLabelWithString:
                "請先在主 App 儲存 .lvcue，再按「連結目前 Cue 專案」，"
                + "最後回到 Logic 按 Command-S。之後不必再開啟這個外掛視窗。"
        )

        let creator = NSTextField(
            labelWithString: "Original creator: Kao Ko Feng"
        )
        creator.font = .systemFont(ofSize: 11)
        creator.textColor = .tertiaryLabelColor

        let textStack = NSStackView(
            views: [title, subtitle, instruction, creator]
        )
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 8

        root.addSubview(iconView)
        root.addSubview(textStack)

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(greaterThanOrEqualToConstant: 460),
            root.heightAnchor.constraint(greaterThanOrEqualToConstant: 190),

            iconView.leadingAnchor.constraint(
                equalTo: root.leadingAnchor,
                constant: 22
            ),
            iconView.topAnchor.constraint(
                equalTo: root.topAnchor,
                constant: 24
            ),
            iconView.widthAnchor.constraint(equalToConstant: 88),
            iconView.heightAnchor.constraint(equalToConstant: 88),

            textStack.leadingAnchor.constraint(
                equalTo: iconView.trailingAnchor,
                constant: 20
            ),
            textStack.trailingAnchor.constraint(
                equalTo: root.trailingAnchor,
                constant: -22
            ),
            textStack.topAnchor.constraint(
                equalTo: root.topAnchor,
                constant: 24
            ),
            textStack.bottomAnchor.constraint(
                lessThanOrEqualTo: root.bottomAnchor,
                constant: -22
            ),
        ])

        view = root
        preferredContentSize = NSSize(width: 520, height: 210)
    }

    func createAudioUnit(
        with componentDescription: AudioComponentDescription
    ) throws -> AUAudioUnit {
        let unit = try LogicVideoCueAUAudioUnit(
            componentDescription: componentDescription
        )
        audioUnit = unit
        return unit
    }
}
