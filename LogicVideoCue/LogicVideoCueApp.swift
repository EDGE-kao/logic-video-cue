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
                Button("新增專案") {
                    model.newProject()
                }
                .keyboardShortcut("n")

                Button("開啟專案…") {
                    model.openProject()
                }
                .keyboardShortcut("o")

                Divider()

                Button("加入影片…") {
                    model.importVideos()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("儲存") {
                    model.saveProject()
                }
                .keyboardShortcut("s")

                Button("另存新檔…") {
                    model.saveProject(saveAs: true)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("影片") {
                Button(model.isPreviewPlaying ? "停止本機預覽" : "開始本機預覽") {
                    model.togglePreview()
                }
                .keyboardShortcut(.space, modifiers: [])

                Divider()

                Button("開啟輸出視窗") {
                    model.showVideoOutput()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("輸出視窗全螢幕") {
                    model.toggleOutputFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
        }
    }
}
