import SwiftUI

struct LunexVaultRoll: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @State private var query = ""
    @State private var making = false
    @State private var editing: LunexIdeaSlip?
    @State private var pending: LunexIdeaSlip?
    @State private var pinning: LunexPinKind?
    @State private var sort: LunexIdeaSort = .recent

    private var visible: [LunexIdeaSlip] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matched: [LunexIdeaSlip]
        if text.isEmpty {
            matched = vault.ideas
        } else {
            matched = vault.ideas.filter {
                $0.title.lowercased().contains(text)
                    || $0.notes.lowercased().contains(text)
                    || $0.status.lunexTitle.lowercased().contains(text)
            }
        }
        switch sort {
        case .recent:
            return matched.sorted { $0.updatedOn > $1.updatedOn }
        case .title:
            return matched.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .boards:
            return matched.sorted { left, right in
                let leftCount = vault.lunexBoardCount(for: left.id)
                let rightCount = vault.lunexBoardCount(for: right.id)
                if leftCount == rightCount {
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }
                return leftCount > rightCount
            }
        }
    }

    var body: some View {
        List {
            Section {
                if vault.ideas.count >= vault.lunexSoftCap && vault.entryLimitAlertDismissed == false {
                    LunexSlateCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The vault has \(vault.ideas.count) ideas. Delete older ones if you need room.")
                                .font(.subheadline)
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            LunexQuietButton(title: "Hide warning") { vault.lunexHideLimit() }
                        }
                    }
                }
                if let first = vault.achievementsUnlocked["first-concept"] {
                    Text("First concept saved \(LunexStampText.day(first)).")
                        .font(.footnote)
                        .foregroundStyle(Color.lunexInk.opacity(0.8))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let banner = vault.lunexBanner {
                    LunexBannerLine(text: banner)
                }
                Text("\(vault.ideas.count) / \(vault.lunexSoftCap) ideas")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.lunexGold)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                if vault.ideas.isEmpty == false {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LunexIdeaSort.allCases) { item in
                                LunexChoiceChip(title: item.lunexTitle, selected: sort == item) {
                                    sort = item
                                }
                            }
                        }
                    }
                }
                TextField("Search titles or notes", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(10)
                    .foregroundStyle(Color.lunexInk)
                    .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                LunexPrimaryButton(title: "Add an idea") { making = true }
                if vault.ideas.isEmpty {
                    LunexSlateCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.lunexGold)
                            Text("No Ideas Yet")
                                .font(.headline)
                                .foregroundStyle(Color.lunexInk)
                            Text("Write a title, pick an icon, and describe how the shot could be used.")
                                .font(.subheadline)
                                .foregroundStyle(Color.lunexInk.opacity(0.78))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else if visible.isEmpty {
                    Text("No ideas match that search.")
                        .foregroundStyle(Color.lunexInk)
                        .lineLimit(nil)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(visible) { idea in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(idea.emojiIcon)  \(idea.title)")
                        .font(.headline)
                        .foregroundStyle(Color.lunexInk)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(idea.notes)
                        .font(.subheadline)
                        .foregroundStyle(Color.lunexInk.opacity(0.82))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(idea.status.lunexTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.lunexEmber)
                    let scenes = vault.lunexScenes(for: idea.id)
                    if scenes.isEmpty == false {
                        Text("\(scenes.count) scene note\(scenes.count == 1 ? "" : "s")")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.lunexGold)
                        ForEach(Array(scenes.prefix(3))) { slip in
                            Text(slip.text)
                                .font(.caption)
                                .foregroundStyle(Color.lunexInk.opacity(0.78))
                                .lineLimit(2)
                        }
                    }
                    let count = vault.lunexBoardCount(for: idea.id)
                    if count > 0 {
                        Text("Pinned on \(count) board\(count == 1 ? "" : "s")")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.lunexGold)
                    }
                    HStack {
                        Button("Edit") { editing = idea }
                        Button("Pin") { pinning = .idea(idea.id) }
                        Button("Delete") { pending = idea }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.lunexEmber)
                }
                .padding(.vertical, 6)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) { pending = idea }
                }
                .contextMenu {
                    Button("Edit") { editing = idea }
                    Button("Pin to a board") { pinning = .idea(idea.id) }
                    Button("Delete", role: .destructive) { pending = idea }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .sheet(isPresented: $making) {
            LunexIdeaEditor(existing: nil)
        }
        .sheet(item: $editing) { idea in
            LunexIdeaEditor(existing: idea)
        }
        .sheet(item: $pinning) { kind in
            LunexPinSheet(kind: kind)
        }
        .confirmationDialog("Delete this idea?", isPresented: Binding(get: { pending != nil }, set: { if $0 == false { pending = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let pending { vault.lunexDeleteIdea(pending.id) }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text("Scene notes stay in the scene list, but this idea leaves every board.")
        }
        .onReceive(vault.$lunexFocusIdeaID) { id in
            guard let id, let idea = vault.ideas.first(where: { $0.id == id }) else { return }
            editing = idea
            vault.lunexFocusIdeaID = nil
        }
    }
}

struct LunexIdeaEditor: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @Environment(\.dismiss) private var dismiss
    let existing: LunexIdeaSlip?
    @State private var title: String
    @State private var emojiIcon: String
    @State private var notes: String
    @State private var status: LunexIdeaStatus
    @State private var trouble: String?

    init(existing: LunexIdeaSlip?) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _emojiIcon = State(initialValue: existing?.emojiIcon ?? LunexGlyphRack.marks[0])
        _notes = State(initialValue: existing?.notes ?? "")
        _status = State(initialValue: existing?.status ?? .draft)
    }

    var body: some View {
        NavigationStack {
            LunexScreen(still: LunexStillRack.camera) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Title")
                            .font(.subheadline.weight(.semibold))
                        TextField("Name the concept", text: $title)
                            .padding(10)
                            .foregroundStyle(Color.lunexInk)
                            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                        Text("Icon")
                            .font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(LunexGlyphRack.marks, id: \.self) { mark in
                                Button {
                                    emojiIcon = mark
                                } label: {
                                    Text(mark)
                                        .font(.title2)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(emojiIcon == mark ? Color.lunexGold.opacity(0.45) : Color.lunexCard)
                                        .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                                }
                                .buttonStyle(LunexPressStyle())
                            }
                        }
                        Text("Status")
                            .font(.subheadline.weight(.semibold))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LunexIdeaStatus.allCases) { item in
                                    LunexChoiceChip(title: item.lunexTitle, selected: status == item) {
                                        status = item
                                    }
                                }
                            }
                        }
                        Text("Notes")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: $notes)
                            .frame(minHeight: 140)
                            .foregroundStyle(Color.lunexInk)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.lunexCard)
                            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                        if let trouble {
                            Text(trouble)
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        LunexPrimaryButton(title: "Save idea") { commit() }
                        LunexQuietButton(title: "Cancel") { dismiss() }
                    }
                    .foregroundStyle(Color.lunexInk)
                    .padding(16)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Idea")
            .navigationBarTitleDisplayMode(.inline)
            .lunexSheetBar()
        }
        .lunexSheetBackdrop(still: LunexStillRack.camera)
    }

    private func commit() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty {
            trouble = "Add a title before saving."
            return
        }
        if cleanNotes.isEmpty {
            trouble = "Add notes before saving."
            return
        }
        let idea = LunexIdeaSlip(
            id: existing?.id ?? UUID(),
            title: cleanTitle,
            emojiIcon: emojiIcon,
            notes: cleanNotes,
            updatedOn: Date(),
            status: status
        )
        if vault.lunexSaveIdea(idea) {
            dismiss()
        } else {
            trouble = "The vault is full. Delete an older idea first."
        }
    }
}

enum LunexVaultRollFeyraDrift {
    static func lunexVaultRollFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [46, 52, 77, 10, 33, 47]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 77)
        }
        return lane
    }
}
