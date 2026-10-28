import StoreKit
import SwiftUI

struct LunexPreferenceCanvas: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @State private var confirmReset = false

    var body: some View {
        LunexScreen(still: LunexStillRack.chair) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LunexFilmHoles()
                    LunexStillFrame(key: LunexStillRack.chair, height: 120)
                    Text("Setup")
                        .font(.system(.title2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.lunexInk)
                    Text("Appearance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lunexInk)
                    HStack(spacing: 8) {
                        ForEach(LunexThemeChoice.allCases) { choice in
                            LunexChoiceChip(title: choice.lunexTitle, selected: vault.themeChoice == choice) {
                                vault.lunexSetTheme(choice)
                            }
                        }
                    }
                    Text("Concepts stay on this device. Open privacy or terms in the browser, or send a rating.")
                        .font(.subheadline)
                        .foregroundStyle(Color.lunexInk.opacity(0.82))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    if let last = vault.lastActivityDate {
                        Text("Last saved change \(LunexStampText.day(last)).")
                            .font(.footnote)
                            .foregroundStyle(Color.lunexInk.opacity(0.75))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    LunexPrimaryButton(title: "Rate Us") { rateApp() }
                    LunexQuietButton(title: "Privacy") {
                        if let url = URL(string: LunexLinkLedger.privacy) {
                            UIApplication.shared.open(url)
                        }
                    }
                    LunexQuietButton(title: "Terms") {
                        if let url = URL(string: LunexLinkLedger.terms) {
                            UIApplication.shared.open(url)
                        }
                    }
                    LunexQuietButton(title: "Reset all data") { confirmReset = true }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog("Reset all data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { vault.lunexResetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ideas, scene notes, boards, saved inspirations, and your photos on this device will be cleared.")
        }
    }

    private func rateApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

enum LunexPreferenceCanvasFeyraDrift {
    static func lunexPreferenceCanvasFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [20, 49, 79, 24, 10, 18]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 79)
        }
        return lane
    }
}
