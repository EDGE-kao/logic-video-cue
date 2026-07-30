// Logic Video Cue — originally created by Kao Ko Feng.
// Copyright © 2026 Kao Ko Feng.
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import AVKit
import SwiftUI

struct PlayerSurfaceView: View {
    let player: AVPlayer
    let activeClipName: String
    let statusMessage: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black

            AVPlayerRepresentable(player: player)

            VStack(alignment: .leading, spacing: 2) {
                Text(activeClipName)
                    .font(.headline)
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(12)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct AVPlayerRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
