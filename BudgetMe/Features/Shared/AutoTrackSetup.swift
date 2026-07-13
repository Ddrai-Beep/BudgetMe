import SwiftUI
import AVKit

/// Shared "set up Apple Pay auto-tracking" content used by both onboarding and Settings.
/// The video is optional: drop a file named `shortcut_setup.mp4` into the app target and it
/// appears automatically — no code change needed.
struct AutoTrackSetupContent: View {
    /// Set to false in onboarding where the page header already says the title.
    var showsHeader: Bool = true

    static let steps: [(title: String, detail: String)] = [
        ("1. Open the Shortcuts app", "It comes preinstalled on iOS."),
        ("2. Go to Automation → New (+)", "Choose 'Create Personal Automation'."),
        ("3. Pick 'Transaction'", "Select the Apple Wallet cards you want tracked and leave all categories on."),
        ("4. Add action 'Log a Transaction in BudgetMe'", "Map Merchant → Merchant and Amount → Amount."),
        ("5. Turn on 'Run Immediately'", "Turn off 'Notify When Run' so it's fully automatic.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHeader {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Frictionless Budgeting")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Auto-track Apple Pay")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.primary.opacity(0.75))
                }
            }

            Text("BudgetMe logs each Apple Pay tap through a one-time Shortcut. Set it up once and forget it.")
                .foregroundStyle(Theme.subtleText)

            ShortcutSetupVideo()

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Self.steps, id: \.title) { step in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.subheadline.weight(.semibold))
                        Text(step.detail).font(.caption).foregroundStyle(Theme.subtleText)
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Only Apple Pay (tap-to-pay) transactions are captured.", systemImage: "info.circle")
                    Label("Cash, transfers and non-Wallet cards need manual entry.", systemImage: "hand.tap")
                    Label("Your transaction data stays on your device.", systemImage: "lock.shield")
                }
                .font(.caption)
            }
        }
    }
}

/// Plays a bundled setup video if present, otherwise shows a tappable placeholder.
/// To enable: add `shortcut_setup.mp4` to the BudgetMe target.
struct ShortcutSetupVideo: View {
    private var videoURL: URL? {
        Bundle.main.url(forResource: "shortcut_setup", withExtension: "mp4")
    }

    var body: some View {
        if let url = videoURL {
            LoopingVideo(url: url)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.primary.opacity(0.10))
                .frame(height: 180)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40)).foregroundStyle(Theme.primary)
                        Text("Setup walkthrough video").font(.subheadline.weight(.medium))
                        Text("Follow the steps below for now").font(.caption).foregroundStyle(Theme.subtleText)
                    }
                )
        }
    }
}

/// A muted, auto-looping video player.
struct LoopingVideo: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let p = AVPlayer(url: url)
                p.isMuted = true
                p.actionAtItemEnd = .none
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: p.currentItem, queue: .main
                ) { _ in
                    p.seek(to: .zero)
                    p.play()
                }
                player = p
                p.play()
            }
            .onDisappear { player?.pause() }
    }
}
