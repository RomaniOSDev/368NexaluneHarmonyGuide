import SwiftUI

struct LunexBoardRoll: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @State private var making = false
    @State private var pending: LunexBoardFrame?

    var body: some View {
        List {
            Section {
                if let banner = vault.lunexBanner {
                    LunexBannerLine(text: banner)
                }
                LunexPrimaryButton(title: "Create a board") { making = true }
                if let selected = vault.selectedProjectID, let board = vault.boards.first(where: { $0.id == selected }) {
                    NavigationLink {
                        LunexBoardLeaf(boardID: board.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Continue")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.lunexGold)
                            Text(board.title)
                                .font(.headline)
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(board.logline)
                                .font(.subheadline)
                                .foregroundStyle(Color.lunexInk.opacity(0.8))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if vault.boards.isEmpty {
                    LunexSlateCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "rectangle.split.3x1")
                                .font(.largeTitle)
                                .foregroundStyle(Color.lunexGold)
                            Text("No boards yet")
                                .font(.headline)
                                .foregroundStyle(Color.lunexInk)
                            Text("A board collects ideas, scene notes, and saved inspirations for one concept.")
                                .font(.subheadline)
                                .foregroundStyle(Color.lunexInk.opacity(0.78))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            ForEach(vault.boards) { board in
                NavigationLink {
                    LunexBoardLeaf(boardID: board.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let still = vault.lunexCoverStill(for: board) {
                            LunexStillFrame(key: still, height: 84)
                        }
                        Text(board.title)
                            .font(.headline)
                            .foregroundStyle(Color.lunexInk)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(board.logline)
                            .font(.subheadline)
                            .foregroundStyle(Color.lunexInk.opacity(0.8))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(board.ideaIDs.count) ideas · \(board.captionIDs.count) scenes · \(board.sparkIDs.count) sparks")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.lunexGold)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .swipeActions {
                    Button("Delete", role: .destructive) { pending = board }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .sheet(isPresented: $making) { LunexBoardEditor(existing: nil) }
        .confirmationDialog("Delete this board?", isPresented: Binding(get: { pending != nil }, set: { if $0 == false { pending = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let pending { vault.lunexDeleteBoard(pending.id) }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text("Ideas, scene notes, and inspirations stay in their own lists.")
        }
    }
}

struct LunexBoardLeaf: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    let boardID: UUID
    @State private var editing = false
    @State private var reordering = false

    private var board: LunexBoardFrame? { vault.boards.first { $0.id == boardID } }

    var body: some View {
        LunexScreen(still: LunexStillRack.chair) {
            List {
                Section {
                    if let board {
                        Text(board.title)
                            .font(.system(.title2, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.lunexInk)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(board.logline)
                            .font(.body)
                            .foregroundStyle(Color.lunexInk.opacity(0.84))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        if let banner = vault.lunexBanner {
                            LunexBannerLine(text: banner)
                        }
                        LunexQuietButton(title: "Edit board") { editing = true }
                        coverage(for: board)
                        if reordering {
                            Text("Drag the handles to change the order.")
                                .font(.footnote)
                                .foregroundStyle(Color.lunexInk.opacity(0.75))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text("This board is no longer available.")
                            .foregroundStyle(Color.lunexInk)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if let board {
                    Section {
                        sectionTitle("Ideas")
                        let ideaRows = board.ideaIDs.compactMap { id in vault.ideas.first { $0.id == id } }
                        if ideaRows.isEmpty {
                            Text("Pin an idea from the vault.")
                                .foregroundStyle(Color.lunexInk.opacity(0.75))
                                .lineLimit(nil)
                        } else {
                            ForEach(ideaRows) { idea in
                                row(title: "\(idea.emojiIcon) \(idea.title)", detail: idea.notes) {
                                    vault.lunexUnpin(.idea(idea.id), boardID: board.id)
                                }
                            }
                            .onMove { source, destination in
                                var rows = ideaRows
                                rows.move(fromOffsets: source, toOffset: destination)
                                vault.lunexSetIdeaOrder(boardID: board.id, ids: rows.map(\.id))
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section {
                        sectionTitle("Scenes")
                        let sceneRows = board.captionIDs.compactMap { id in vault.captions.first { $0.id == id } }
                        if sceneRows.isEmpty {
                            Text("Pin a scene note after you save one.")
                                .foregroundStyle(Color.lunexInk.opacity(0.75))
                                .lineLimit(nil)
                        } else {
                            ForEach(sceneRows) { slip in
                                VStack(alignment: .leading, spacing: 6) {
                                    LunexStillFrame(key: slip.stillKey, height: 90)
                                    Text(slip.text)
                                        .foregroundStyle(Color.lunexInk)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Button("Remove from board") {
                                        vault.lunexUnpin(.caption(slip.id), boardID: board.id)
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.lunexGold)
                                }
                            }
                            .onMove { source, destination in
                                var rows = sceneRows
                                rows.move(fromOffsets: source, toOffset: destination)
                                vault.lunexSetCaptionOrder(boardID: board.id, ids: rows.map(\.id))
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section {
                        sectionTitle("Inspirations")
                        let sparks = board.sparkIDs.compactMap { LunexSparkAtlas.lunexFind($0) }
                        if sparks.isEmpty {
                            Text("Pin a spark from the inspiration gallery.")
                                .foregroundStyle(Color.lunexInk.opacity(0.75))
                                .lineLimit(nil)
                        } else {
                            ForEach(sparks) { spark in
                                row(title: spark.title, detail: vault.annotations[spark.id] ?? spark.seedNote) {
                                    vault.lunexUnpin(.spark(spark.id), boardID: board.id)
                                }
                            }
                            .onMove { source, destination in
                                var rows = sparks
                                rows.move(fromOffsets: source, toOffset: destination)
                                vault.lunexSetSparkOrder(boardID: board.id, ids: rows.map(\.id))
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .environment(\.editMode, .constant(reordering ? .active : .inactive))
        }
        .navigationTitle("Board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let board, lunexCanReorder(board) {
                    Button(reordering ? "Done" : "Reorder") { reordering.toggle() }
                        .foregroundStyle(Color.lunexGold)
                }
            }
        }
        .onAppear { vault.lunexRememberBoard(boardID) }
        .sheet(isPresented: $editing) {
            if let board { LunexBoardEditor(existing: board) }
        }
    }

    private func lunexCanReorder(_ board: LunexBoardFrame) -> Bool {
        board.ideaIDs.count > 1 || board.captionIDs.count > 1 || board.sparkIDs.count > 1
    }

    private func coverage(for board: LunexBoardFrame) -> some View {
        let missing = vault.lunexIdeasMissingScenes(on: board)
        let loose = vault.lunexUnpinnedCaptions()
        return LunexSlateCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Coverage")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(Color.lunexGold)
                Text("\(missing.count) \(missing.count == 1 ? "idea" : "ideas") on this board \(missing.count == 1 ? "has" : "have") no scene note.")
                    .font(.subheadline)
                    .foregroundStyle(Color.lunexInk)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(missing.prefix(4))) { idea in
                    Text(idea.title)
                        .font(.caption)
                        .foregroundStyle(Color.lunexInk.opacity(0.8))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("\(loose.count) scene \(loose.count == 1 ? "note is" : "notes are") not pinned to any board.")
                    .font(.subheadline)
                    .foregroundStyle(Color.lunexInk)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(loose.prefix(4))) { slip in
                    Text(slip.text)
                        .font(.caption)
                        .foregroundStyle(Color.lunexInk.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.headline, design: .monospaced))
            .foregroundStyle(Color.lunexGold)
    }

    private func row(title: String, detail: String, remove: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.lunexInk)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color.lunexInk.opacity(0.8))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Button("Remove from board", action: remove)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.lunexGold)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Color.lunexGold.opacity(0.7), lineWidth: 1))
    }
}

struct LunexBoardEditor: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @Environment(\.dismiss) private var dismiss
    let existing: LunexBoardFrame?
    @State private var title: String
    @State private var logline: String
    @State private var trouble: String?

    init(existing: LunexBoardFrame?) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _logline = State(initialValue: existing?.logline ?? "")
    }

    var body: some View {
        NavigationStack {
            LunexScreen(still: LunexStillRack.chair) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Board title")
                        .font(.subheadline.weight(.semibold))
                    TextField("Name the board", text: $title)
                        .padding(10)
                        .foregroundStyle(Color.lunexInk)
                        .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                    Text("Logline")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $logline)
                        .frame(minHeight: 100)
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
                    LunexPrimaryButton(title: "Save board") { commit() }
                    LunexQuietButton(title: "Cancel") { dismiss() }
                }
                .foregroundStyle(Color.lunexInk)
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Board")
            .navigationBarTitleDisplayMode(.inline)
            .lunexSheetBar()
        }
        .lunexSheetBackdrop(still: LunexStillRack.chair)
    }

    private func commit() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLine = logline.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty {
            trouble = "Add a title before saving."
            return
        }
        if cleanLine.isEmpty {
            trouble = "Add a logline before saving."
            return
        }
        var board = existing ?? LunexBoardFrame(id: UUID(), title: cleanTitle, logline: cleanLine, ideaIDs: [], captionIDs: [], sparkIDs: [])
        board.title = cleanTitle
        board.logline = cleanLine
        vault.lunexSaveBoard(board)
        dismiss()
    }
}

struct LunexPinSheet: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @Environment(\.dismiss) private var dismiss
    let kind: LunexPinKind
    @State private var title = ""
    @State private var logline = ""
    @State private var trouble: String?

    var body: some View {
        NavigationStack {
            LunexScreen(still: LunexStillRack.camera) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a board or make a new one.")
                        .foregroundStyle(Color.lunexInk)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(vault.boards) { board in
                        Button {
                            vault.lunexPin(kind, boardID: board.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(board.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.lunexInk)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(board.logline)
                                    .font(.caption)
                                    .foregroundStyle(Color.lunexInk.opacity(0.75))
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                        }
                        .buttonStyle(LunexPressStyle())
                    }
                    Text("New board")
                        .font(.headline)
                        .foregroundStyle(Color.lunexGold)
                    TextField("Title", text: $title)
                        .padding(10)
                        .foregroundStyle(Color.lunexInk)
                        .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                    TextField("Logline", text: $logline)
                        .padding(10)
                        .foregroundStyle(Color.lunexInk)
                        .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                    if let trouble {
                        Text(trouble)
                            .foregroundStyle(Color.lunexInk)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    LunexPrimaryButton(title: "Create and pin") {
                        if vault.lunexCreateBoardAndPin(title: title, logline: logline, kind: kind) {
                            dismiss()
                        } else {
                            trouble = "Add both a title and a logline."
                        }
                    }
                    LunexQuietButton(title: "Cancel") { dismiss() }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Pin")
            .navigationBarTitleDisplayMode(.inline)
            .lunexSheetBar()
        }
        .lunexSheetBackdrop(still: LunexStillRack.camera)
    }
}

enum LunexBoardRollFeyraDrift {
    static func lunexBoardRollFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [41, 19, 80, 75, 53, 51]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 80)
        }
        return lane
    }
}
