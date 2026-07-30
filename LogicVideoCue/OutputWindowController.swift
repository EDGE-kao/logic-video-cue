// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import AVKit
import AppKit

private final class DraggablePlayerView: AVPlayerView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}

private final class TimecodeOverlayView: NSView {
    private let label = NSTextField(labelWithString: "00:00:00.000")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.68).cgColor
        layer?.cornerRadius = 9
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.45
        layer?.shadowRadius = 5
        layer?.shadowOffset = NSSize(width: 0, height: -1)

        label.font = NSFont.monospacedDigitSystemFont(
            ofSize: 26,
            weight: .semibold
        )
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func update(seconds rawSeconds: Double) {
        let seconds = max(0, rawSeconds.isFinite ? rawSeconds : 0)
        let totalMilliseconds = Int((seconds * 1_000).rounded())
        let milliseconds = totalMilliseconds % 1_000
        let totalSeconds = totalMilliseconds / 1_000
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds / 60) % 60
        let wholeSeconds = totalSeconds % 60

        label.stringValue = String(
            format: "%02d:%02d:%02d.%03d",
            hours,
            minutes,
            wholeSeconds,
            milliseconds
        )
    }
}

final class OutputWindowController: NSWindowController, NSWindowDelegate {
    private static let windowedStyleMask: NSWindow.StyleMask = [
        .nonactivatingPanel,
        .titled,
        .closable,
        .miniaturizable,
        .resizable
    ]

    private let playerView: DraggablePlayerView
    private let timecodeOverlay: TimecodeOverlayView
    private var hasPresented = false
    private var alwaysOnTopEnabled = true
    private var isCustomFullScreen = false
    private var windowedFrame: NSRect?

    init(player: AVPlayer) {
        playerView = DraggablePlayerView(
            frame: NSRect(x: 0, y: 0, width: 960, height: 540)
        )
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.videoGravity = .resizeAspect
        playerView.translatesAutoresizingMaskIntoConstraints = false

        timecodeOverlay = TimecodeOverlayView(frame: .zero)
        timecodeOverlay.translatesAutoresizingMaskIntoConstraints = false

        let outputContentView = NSView(
            frame: NSRect(x: 0, y: 0, width: 960, height: 540)
        )
        outputContentView.wantsLayer = true
        outputContentView.layer?.backgroundColor = NSColor.black.cgColor
        outputContentView.addSubview(playerView)
        outputContentView.addSubview(timecodeOverlay)

        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: outputContentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: outputContentView.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: outputContentView.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: outputContentView.bottomAnchor),
            timecodeOverlay.centerXAnchor.constraint(equalTo: outputContentView.centerXAnchor),
            timecodeOverlay.bottomAnchor.constraint(
                equalTo: outputContentView.bottomAnchor,
                constant: -18
            )
        ])

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
            styleMask: Self.windowedStyleMask,
            backing: .buffered,
            defer: false
        )
        panel.title = String(localized: "Logic Video Cue — Video Output")
        panel.contentView = outputContentView
        panel.backgroundColor = .black
        panel.minSize = NSSize(width: 480, height: 270)
        panel.isReleasedWhenClosed = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.tabbingMode = .disallowed
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .canJoinAllApplications,
            .fullScreenAuxiliary,
            .stationary
        ]

        super.init(window: panel)
        panel.delegate = self
        shouldCascadeWindows = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        restoreRegularActivationPolicy()
    }

    func present(alwaysOnTop: Bool) {
        alwaysOnTopEnabled = alwaysOnTop
        configureWindowLevel()
        showWindow(nil)
        if !hasPresented {
            window?.center()
            hasPresented = true
        }

        if alwaysOnTop {
            enableFullScreenOverlayMode()
            window?.orderFrontRegardless()
        } else {
            window?.orderFront(nil)
        }
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        alwaysOnTopEnabled = enabled
        configureWindowLevel()

        if enabled, window?.isVisible == true {
            enableFullScreenOverlayMode()
            window?.orderFrontRegardless()
        } else if !enabled {
            restoreRegularActivationPolicy()
        }
    }

    func updateTimelineTime(_ seconds: Double) {
        timecodeOverlay.update(seconds: seconds)
    }

    func toggleFullScreen() {
        guard let window else { return }

        if isCustomFullScreen {
            leaveCustomFullScreen(window)
        } else {
            enterCustomFullScreen(window)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let window {
            leaveCustomFullScreen(window, animated: false)
        }
        restoreRegularActivationPolicy()
    }

    private func configureWindowLevel() {
        guard let panel = window as? NSPanel else { return }
        panel.isFloatingPanel = alwaysOnTopEnabled
        panel.level = alwaysOnTopEnabled ? .screenSaver : .normal
        panel.hidesOnDeactivate = false
    }

    private func enableFullScreenOverlayMode() {
        NSApp.setActivationPolicy(.accessory)
    }

    private func restoreRegularActivationPolicy() {
        NSApp.setActivationPolicy(.regular)
    }

    private func enterCustomFullScreen(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }

        windowedFrame = window.frame
        isCustomFullScreen = true
        window.styleMask = [.borderless, .nonactivatingPanel]
        window.setFrame(screen.frame, display: true, animate: true)
        window.orderFrontRegardless()
    }

    private func leaveCustomFullScreen(
        _ window: NSWindow,
        animated: Bool = true
    ) {
        guard isCustomFullScreen else { return }

        let restoredFrame = windowedFrame ?? NSRect(
            x: 0,
            y: 0,
            width: 960,
            height: 540
        )
        window.styleMask = Self.windowedStyleMask
        window.setFrame(restoredFrame, display: true, animate: animated)
        isCustomFullScreen = false
    }
}
