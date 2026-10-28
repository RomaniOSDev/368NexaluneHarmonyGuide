import PhotosUI
import SwiftUI

struct LunexCaptionGallery: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @State private var making = false
    @State private var pending: LunexCaptionSlip?
    @State private var ideaFilter: UUID?
    @State private var stillFilter: String?

    private var visibleCaptions: [LunexCaptionSlip] {
        vault.captions.filter { slip in
            let ideaOK = ideaFilter == nil || slip.ideaID == ideaFilter
            let stillOK = stillFilter == nil || slip.stillKey == stillFilter
            return ideaOK && stillOK
        }
    }

    var body: some View {
        List {
            Section {
                if let banner = vault.lunexBanner {
                    LunexBannerLine(text: banner)
                }
                if vault.ideas.isEmpty {
                    LunexSlateCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.lunexGold)
                            Text("Capture your first scene inspiration")
                                .font(.headline)
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Add an idea in the vault before you write a scene note.")
                                .font(.subheadline)
                                .foregroundStyle(Color.lunexInk.opacity(0.78))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            LunexPrimaryButton(title: "Go to ideas") { vault.lunexFocusReel = .vault }
                        }
                    }
                } else {
                    LunexPrimaryButton(title: "Add a scene note") { making = true }
                    if vault.captions.isEmpty {
                        Text("No scene notes yet. Pick a still and describe the shot.")
                            .foregroundStyle(Color.lunexInk)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Idea")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.lunexGold)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                LunexChoiceChip(title: "All", selected: ideaFilter == nil) { ideaFilter = nil }
                                ForEach(vault.ideas) { idea in
                                    LunexChoiceChip(title: idea.title, selected: ideaFilter == idea.id) {
                                        ideaFilter = idea.id
                                    }
                                }
                            }
                        }
                        Text("Still")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.lunexGold)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                LunexChoiceChip(title: "All", selected: stillFilter == nil) { stillFilter = nil }
                                ForEach(vault.lunexStillKeys, id: \.self) { key in
                                    LunexChoiceChip(title: vault.lunexStillTitle(key), selected: stillFilter == key) {
                                        stillFilter = key
                                    }
                                }
                            }
                        }
                        if visibleCaptions.isEmpty {
                            Text("No scene notes match this filter.")
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(visibleCaptions) { slip in
                NavigationLink {
                    LunexCaptionEditor(existing: slip)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        LunexStillFrame(key: slip.stillKey, height: 110)
                        Text(slip.text)
                            .font(.subheadline)
                            .foregroundStyle(Color.lunexInk)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        if slip.lunexMarks.isEmpty == false {
                            Text(slip.lunexMarks)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.lunexEmber)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let ideaID = slip.ideaID, let idea = vault.ideas.first(where: { $0.id == ideaID }) {
                            Text("Linked to \(idea.title)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.lunexGold)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(LunexStampText.day(slip.dateModified))
                            .font(.caption)
                            .foregroundStyle(Color.lunexInk.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", role: .destructive) { pending = slip }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .sheet(isPresented: $making) {
            LunexCaptionEditor(existing: nil)
        }
        .confirmationDialog("Delete this scene note?", isPresented: Binding(get: { pending != nil }, set: { if $0 == false { pending = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let pending { vault.lunexDeleteCaption(pending.id) }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text("It will also leave any board it was pinned to.")
        }
    }
}

struct LunexCaptionEditor: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @Environment(\.dismiss) private var dismiss
    let existing: LunexCaptionSlip?
    @State private var ideaID: UUID?
    @State private var stillKey: String
    @State private var text: String
    @State private var history: [String]
    @State private var dayPart: LunexDayPart?
    @State private var shotSize: LunexShotSize?
    @State private var cameraMove: LunexCameraMove?
    @State private var showHistory = false
    @State private var trouble: String?
    @State private var pinning: LunexPinKind?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotos = false
    @State private var droppingStill: String?

    init(existing: LunexCaptionSlip?) {
        self.existing = existing
        _ideaID = State(initialValue: existing?.ideaID)
        _stillKey = State(initialValue: existing?.stillKey ?? LunexStillRack.alley)
        _text = State(initialValue: existing?.text ?? "")
        _history = State(initialValue: existing?.history ?? [])
        _dayPart = State(initialValue: existing?.dayPart)
        _shotSize = State(initialValue: existing?.shotSize)
        _cameraMove = State(initialValue: existing?.cameraMove)
    }

    var body: some View {
        LunexScreen(still: stillKey) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Linked idea")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lunexInk)
                    ForEach(vault.ideas) { idea in
                        Button {
                            ideaID = idea.id
                        } label: {
                            HStack {
                                Text("\(idea.emojiIcon) \(idea.title)")
                                    .foregroundStyle(Color.lunexInk)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                if ideaID == idea.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.lunexGold)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                        }
                        .buttonStyle(LunexPressStyle())
                    }
                    Text("Still")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lunexInk)
                    LunexQuietButton(title: "Add your photo") { showPhotos = true }
                        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
                    ForEach(vault.lunexStillKeys, id: \.self) { key in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                stillKey = key
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    LunexStillFrame(key: key, height: 84)
                                    Text(vault.lunexStillTitle(key))
                                        .foregroundStyle(Color.lunexInk)
                                    if stillKey == key {
                                        Text("Selected")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.lunexGold)
                                    }
                                }
                            }
                            .buttonStyle(LunexPressStyle())
                            if LunexUserStillStore.isUser(key) {
                                Button("Remove photo") { droppingStill = key }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.lunexEmber)
                            }
                        }
                    }
                    Text("Time of day")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lunexInk)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LunexDayPart.allCases) { item in
                                LunexChoiceChip(title: item.lunexTitle, selected: dayPart == item) {
                                    dayPart = dayPart == item ? nil : item
                                }
                            }
                        }
                    }
                    Text("Shot size")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lunexInk)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LunexShotSize.allCases) { item in
                                LunexChoiceChip(title: item.lunexTitle, selected: shotSize == item) {
                                    shotSize = shotSize == item ? nil : item
                                }
                            }
                        }
                    }
                    Text("Camera move")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lunexInk)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LunexCameraMove.allCases) { item in
                                LunexChoiceChip(title: item.lunexTitle, selected: cameraMove == item) {
                                    cameraMove = cameraMove == item ? nil : item
                                }
                            }
                        }
                    }
                    Text("Starter lines")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lunexInk)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LunexNoteStarter.allCases) { starter in
                                LunexChoiceChip(title: starter.lunexTitle, selected: false) {
                                    lunexApplyTemplate(starter)
                                }
                            }
                        }
                    }
                    Text("Shot note")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lunexInk)
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .foregroundStyle(Color.lunexInk)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.lunexCard)
                        .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                    LunexQuietButton(title: "Insert a bullet line") {
                        text += text.hasSuffix("\n") || text.isEmpty ? "• " : "\n• "
                    }
                    if history.isEmpty == false {
                        LunexQuietButton(title: "Earlier versions") { showHistory = true }
                    }
                    if let trouble {
                        Text(trouble)
                            .foregroundStyle(Color.lunexInk)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    LunexPrimaryButton(title: "Save scene note") { commit() }
                    if let existing {
                        LunexQuietButton(title: "Pin to a board") { pinning = .caption(existing.id) }
                    }
                    LunexQuietButton(title: "Cancel") { dismiss() }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationTitle("Scene")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .lunexSheetBackdrop(still: stillKey)
        .contextMenu {
            if history.isEmpty == false {
                Button("Earlier versions") { showHistory = true }
            }
        }
        .sheet(isPresented: $showHistory) {
            LunexHistorySheet(current: text, history: history) { restored in
                text = restored
                showHistory = false
            }
        }
        .sheet(item: $pinning) { kind in
            LunexPinSheet(kind: kind)
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task { await lunexImport(item) }
        }
        .confirmationDialog("Remove this photo?", isPresented: Binding(get: { droppingStill != nil }, set: { if $0 == false { droppingStill = nil } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let droppingStill {
                    vault.lunexDeleteUserStill(droppingStill)
                    if stillKey == droppingStill { stillKey = LunexStillRack.alley }
                }
                droppingStill = nil
            }
            Button("Cancel", role: .cancel) { droppingStill = nil }
        } message: {
            Text("Scene notes that used it will show an empty frame.")
        }
    }

    private func lunexImport(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let transfer = try? await item.loadTransferable(type: LunexPhotoTransfer.self) else {
            vault.lunexFlash("That photo could not be added.")
            return
        }
        if let key = vault.lunexAddUserStill(data: transfer.data) {
            stillKey = key
        }
    }

    private func commit() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count < 3 {
            trouble = "Write at least 3 characters before saving."
            return
        }
        guard ideaID != nil else {
            trouble = "Choose an idea before saving."
            return
        }
        let previous = existing?.text
        vault.lunexSaveCaption(LunexCaptionSlip(
            id: existing?.id ?? UUID(),
            ideaID: ideaID,
            stillKey: stillKey,
            text: clean,
            dateModified: Date(),
            history: history,
            dayPart: dayPart,
            shotSize: shotSize,
            cameraMove: cameraMove
        ), previous: previous)
        dismiss()
    }

    private func lunexApplyTemplate(_ starter: LunexNoteStarter) {
        let line = starter.lunexLine
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            text = line
        } else if text.hasSuffix("\n") {
            text += line
        } else {
            text += "\n" + line
        }
        shotSize = starter.shotSize
    }
}

struct LunexHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: String
    let history: [String]
    var restore: (String) -> Void

    var body: some View {
        NavigationStack {
            LunexScreen(still: LunexStillRack.alley) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if history.isEmpty {
                        Text("No earlier versions yet.")
                            .foregroundStyle(Color.lunexInk)
                    }
                    ForEach(Array(history.enumerated().reversed()), id: \.offset) { _, line in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Earlier wording")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.lunexGold)
                            Text(line)
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Current wording")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.lunexGold)
                            Text(current)
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Restore this wording") { restore(line) }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.lunexGold)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                    }
                    LunexQuietButton(title: "Close") { dismiss() }
                }
                .padding(16)
            }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .lunexSheetBar()
        }
        .lunexSheetBackdrop(still: LunexStillRack.alley)
    }
}

struct LunexPhotoTransfer: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            LunexPhotoTransfer(data: data)
        }
    }
}

struct LunexCaptionRoute: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    let captionID: UUID

    var body: some View {
        if let slip = vault.captions.first(where: { $0.id == captionID }) {
            LunexCaptionEditor(existing: slip)
        } else {
            LunexScreen(still: LunexStillRack.alley) {
                Text("This scene note is no longer available.")
                    .foregroundStyle(Color.lunexInk)
                    .padding(16)
            }
            .navigationTitle("Scene")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum LunexCaptionGalleryFeyraDrift {
    static func lunexCaptionGalleryFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [46, 9, 7, 31, 82, 59]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 7)
        }
        return lane
    }
}
