// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct LogicVideoCueApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onOpenURL { url in
                    model.loadProject(from: url)
                }
        }
        .defaultSize(width: 1_280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    model.newProject()
                }
                .keyboardShortcut("n")

                Button("Open Project…") {
                    model.openProject()
                }
                .keyboardShortcut("o")

                Divider()

                Button("Add Videos…") {
                    model.importVideos()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    model.saveProject()
                }
                .keyboardShortcut("s")

                Button("Save As…") {
                    model.saveProject(saveAs: true)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("Videos") {
                Button(
                    model.isPreviewPlaying
                        ? String(localized: "Stop Local Preview")
                        : String(localized: "Start Local Preview")
                ) {
                    model.togglePreview()
                }
                .keyboardShortcut(.space, modifiers: [])

                Divider()

                Button("Show Video Output") {
                    model.showVideoOutput()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Full Screen Video Output") {
                    model.toggleOutputFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
        }
    }
}
