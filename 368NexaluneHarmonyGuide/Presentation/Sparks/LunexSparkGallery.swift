import SwiftUI

struct LunexSparkGallery: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @State private var genre = "All"
    @State private var savedOnly = false

    private var visible: [LunexSparkCard] {
        LunexSparkAtlas.cards.filter { card in
            let genreOK = genre == "All" || card.genre == genre
            let savedOK = savedOnly == false || vault.favorites.contains(card.id)
            return genreOK && savedOK
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let banner = vault.lunexBanner {
                    LunexBannerLine(text: banner)
                }
                Text(savedOnly ? "Saved inspirations" : "Inspiration stills")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(Color.lunexInk)
                HStack(spacing: 8) {
                    Button(savedOnly ? "Show all" : "Show saved") { savedOnly.toggle() }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.lunexOnPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Rectangle().fill(Color.lunexEmber))
                        .buttonStyle(LunexPressStyle())
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LunexSparkAtlas.genres, id: \.self) { item in
                            Button(item) { genre = item }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(genre == item ? Color.lunexOnPrimary : Color.lunexInk)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Rectangle().fill(genre == item ? Color.lunexGold : Color.clear))
                                .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                                .buttonStyle(LunexPressStyle())
                        }
                    }
                }
                if visible.isEmpty {
                    LunexSlateCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.lunexGold)
                            Text(savedOnly ? "No saved inspirations yet." : "No inspirations in this group.")
                                .font(.headline)
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Open a still and save it if you want it on a board later.")
                                .font(.subheadline)
                                .foregroundStyle(Color.lunexInk.opacity(0.78))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    ForEach(visible) { card in
                        NavigationLink {
                            LunexSparkLeaf(sparkID: card.id)
                        } label: {
                            LunexSlateCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    LunexStillFrame(key: card.stillKey, height: 120)
                                    Text(card.title)
                                        .font(.headline)
                                        .foregroundStyle(Color.lunexInk)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(card.genre)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.lunexGold)
                                    Text(vault.annotations[card.id] ?? card.seedNote)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.lunexInk.opacity(0.82))
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if vault.favorites.contains(card.id) {
                                        Text("Saved")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.lunexEmber)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct LunexSparkLeaf: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    let sparkID: String
    @State private var note: String
    @State private var trouble: String?
    @State private var pinning: LunexPinKind?

    init(sparkID: String) {
        self.sparkID = sparkID
        _note = State(initialValue: "")
    }

    private var spark: LunexSparkCard? { LunexSparkAtlas.lunexFind(sparkID) }

    var body: some View {
        LunexScreen(still: spark?.stillKey ?? LunexStillRack.desert) {
            ScrollView {
                if let spark {
                    VStack(alignment: .leading, spacing: 12) {
                        LunexStillFrame(key: spark.stillKey, height: 180)
                        Text(spark.title)
                            .font(.system(.title2, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.lunexInk)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(spark.genre)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.lunexGold)
                        Text(spark.seedNote)
                            .font(.body)
                            .foregroundStyle(Color.lunexInk.opacity(0.86))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        if let banner = vault.lunexBanner {
                            LunexBannerLine(text: banner)
                        }
                        LunexPrimaryButton(title: vault.favorites.contains(spark.id) ? "Remove from saved" : "Save inspiration") {
                            vault.lunexToggleFavorite(spark.id)
                        }
                        if vault.favorites.contains(spark.id) {
                            LunexQuietButton(title: "Make an idea") {
                                let note = vault.annotations[spark.id] ?? spark.seedNote
                                if vault.lunexIdeaFromSpark(title: spark.title, notes: note) == nil {
                                    trouble = "The vault is full. Delete an older idea first."
                                } else {
                                    trouble = nil
                                }
                            }
                        }
                        Text("Your note")
                            .font(.headline)
                            .foregroundStyle(Color.lunexInk)
                        TextEditor(text: $note)
                            .frame(minHeight: 120)
                            .foregroundStyle(Color.lunexInk)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.lunexCard)
                            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                        LunexQuietButton(title: "Insert a bullet line") {
                            note += note.hasSuffix("\n") || note.isEmpty ? "• " : "\n• "
                        }
                        if let trouble {
                            Text(trouble)
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        LunexPrimaryButton(title: "Save note") {
                            if vault.lunexSaveAnnotation(sparkID: spark.id, text: note) == false {
                                trouble = "Write at least 3 characters."
                            } else {
                                trouble = nil
                            }
                        }
                        LunexQuietButton(title: "Pin to a board") { pinning = .spark(spark.id) }
                    }
                    .padding(16)
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationTitle("Spark")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            if let spark, note.isEmpty {
                note = vault.annotations[spark.id] ?? ""
            }
        }
        .sheet(item: $pinning) { kind in
            LunexPinSheet(kind: kind)
        }
    }
}

enum LunexSparkGalleryFeyraDrift {
    static func lunexSparkGalleryFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [58, 10, 75, 80, 42, 58]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 75)
        }
        return lane
    }
}
