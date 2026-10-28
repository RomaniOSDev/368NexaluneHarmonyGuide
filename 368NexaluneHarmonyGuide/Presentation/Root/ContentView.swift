import SwiftUI

struct ContentView: View {
    @StateObject private var lunexVault = LunexLedgerVault()

    var body: some View {
        Group {
            if lunexVault.hasSeenOnboarding {
                LunexRootShell()
            } else {
                LunexWelcomeReel()
            }
        }
        .environmentObject(lunexVault)
        .environment(\.locale, Locale(identifier: "en_US"))
        .preferredColorScheme(lunexScheme)
        .overlay(LunexKeypadVeil())
    }

    private var lunexScheme: ColorScheme? {
        switch lunexVault.themeChoice {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private enum LunexPush {
    case board(UUID)
    case caption(UUID)
}

struct LunexRootShell: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @State private var reel: LunexReel = .vault
    @State private var searching = false
    @State private var pendingHit: LunexSearchHit?
    @State private var push: LunexPush?

    private var pushPresented: Binding<Bool> {
        Binding {
            push != nil
        } set: { isShown in
            if isShown == false { push = nil }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                LunexFilmHoles()
                    .padding(.top, 6)
                HStack {
                    Text(reel.lunexTitle)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.lunexInk)
                    Spacer()
                    Button {
                        searching = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.lunexOnPrimary)
                            .frame(width: 44, height: 44)
                            .background(Rectangle().fill(Color.lunexGold))
                    }
                    .buttonStyle(LunexPressStyle())
                    .accessibilityLabel("Search")
                    NavigationLink {
                        LunexPreferenceCanvas()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(Color.lunexOnPrimary)
                            .frame(width: 44, height: 44)
                            .background(Rectangle().fill(Color.lunexGold))
                    }
                    .accessibilityLabel("Setup")
                }
                .padding(.horizontal, 16)
                HStack(spacing: 6) {
                    ForEach(LunexReel.allCases) { item in
                        Button {
                            reel = item
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.code)
                                    .font(.system(.caption, design: .monospaced).weight(.bold))
                                Text(item.lunexTitle)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(reel == item ? Color.lunexOnPrimary : Color.lunexInk)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .padding(.vertical, 4)
                            .background(Rectangle().fill(reel == item ? Color.lunexEmber : Color.lunexCard))
                            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                        }
                        .buttonStyle(LunexPressStyle())
                        .accessibilityAddTraits(reel == item ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 12)
                LunexUndoBar()
                    .padding(.horizontal, 12)
                Group {
                    switch reel {
                    case .vault: LunexVaultRoll()
                    case .scenes: LunexCaptionGallery()
                    case .boards: LunexBoardRoll()
                    case .sparks: LunexSparkGallery()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color.lunexBackdrop
                    .overlay {
                        Image(LunexStillRack.camera)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.2)
                    }
                    .overlay {
                        LinearGradient(colors: [Color.lunexBackdrop.opacity(0.25), Color.lunexBackdrop.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                    }
                    .clipped()
                    .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: pushPresented) {
                switch push {
                case .board(let id):
                    LunexBoardLeaf(boardID: id)
                case .caption(let id):
                    LunexCaptionRoute(captionID: id)
                case nil:
                    Color.clear
                }
            }
            .sheet(isPresented: $searching, onDismiss: lunexFinishSearch) {
                LunexSearchSheet { hit in
                    pendingHit = hit
                    searching = false
                }
            }
        }
        .tint(Color.lunexGold)
        .onReceive(vault.$lunexFocusReel) { focus in
            guard let focus else { return }
            reel = focus
            vault.lunexFocusReel = nil
        }
    }

    private func lunexFinishSearch() {
        guard let hit = pendingHit else { return }
        pendingHit = nil
        switch hit.kind {
        case .idea:
            vault.lunexFocusReel = .vault
            if let id = UUID(uuidString: hit.ref) {
                vault.lunexFocusIdeaID = id
            }
        case .caption:
            vault.lunexFocusReel = .scenes
            if let id = UUID(uuidString: hit.ref) {
                push = .caption(id)
            }
        case .board:
            vault.lunexFocusReel = .boards
            if let id = UUID(uuidString: hit.ref) {
                push = .board(id)
            }
        }
    }
}

struct LunexSearchSheet: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @Environment(\.dismiss) private var dismiss
    var open: (LunexSearchHit) -> Void
    @State private var query = ""

    private var hits: [LunexSearchHit] { vault.lunexSearch(query) }

    var body: some View {
        NavigationStack {
            LunexScreen(still: LunexStillRack.camera) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Titles, notes, or loglines", text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding(10)
                            .foregroundStyle(Color.lunexInk)
                            .background(Color.lunexCard)
                            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Search ideas, scene notes, and boards.")
                                .foregroundStyle(Color.lunexInk.opacity(0.8))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if hits.isEmpty {
                            Text("Nothing matches that search.")
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ForEach(hits) { hit in
                                Button {
                                    open(hit)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(hit.kind.lunexTitle)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.lunexGold)
                                        Text(hit.title)
                                            .font(.headline)
                                            .foregroundStyle(Color.lunexInk)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                        if hit.detail.isEmpty == false {
                                            Text(hit.detail)
                                                .font(.caption)
                                                .foregroundStyle(Color.lunexInk.opacity(0.75))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.lunexCard)
                                    .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                                }
                                .buttonStyle(LunexPressStyle())
                            }
                        }
                        LunexQuietButton(title: "Close") { dismiss() }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .lunexSheetBar()
        }
        .lunexSheetBackdrop(still: LunexStillRack.camera)
    }
}

enum ContentViewFeyraDrift {
    static func contentViewFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [61, 5, 58, 67, 66, 29]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 58)
        }
        return lane
    }
}
