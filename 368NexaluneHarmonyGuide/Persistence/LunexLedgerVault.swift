import Foundation
import UIKit

extension Notification.Name {
    static let dataReset = Notification.Name("lunexOrrixDataReset")
}

enum LunexVaultKey {
    static let seen = "lunex.orrix.seenWelcome"
    static let ideas = "lunex.orrix.ideas"
    static let captions = "lunex.orrix.captions"
    static let boards = "lunex.orrix.boards"
    static let favorites = "lunex.orrix.favorites"
    static let annotations = "lunex.orrix.annotations"
    static let limitHidden = "lunex.orrix.limitHidden"
    static let selected = "lunex.orrix.selectedBoard"
    static let achievements = "lunex.orrix.achievements"
    static let lastActivity = "lunex.orrix.lastActivity"
    static let theme = "lunex.orrix.theme"
    static let userStills = "lunex.orrix.userStills"
    static let photoCount = "lunex.orrix.photoCount"
}

struct LunexPinSpot {
    var boardID: UUID
    var index: Int
}

enum LunexUndoRecord {
    case idea(LunexIdeaSlip, linkedCaptionIDs: [UUID], spots: [LunexPinSpot])
    case caption(LunexCaptionSlip, spots: [LunexPinSpot])
    case board(LunexBoardFrame, wasSelected: Bool)

    var lunexTitle: String {
        switch self {
        case .idea: return "Idea deleted"
        case .caption: return "Scene note deleted"
        case .board: return "Board deleted"
        }
    }
}

@MainActor
final class LunexLedgerVault: ObservableObject {
    @Published var hasSeenOnboarding: Bool
    @Published var ideas: [LunexIdeaSlip]
    @Published var captions: [LunexCaptionSlip]
    @Published var boards: [LunexBoardFrame]
    @Published var favorites: [String]
    @Published var annotations: [String: String]
    @Published var entryLimitAlertDismissed: Bool
    @Published var selectedProjectID: UUID?
    @Published var achievementsUnlocked: [String: Date]
    @Published var lastActivityDate: Date?
    @Published var lunexBanner: String?
    @Published var lunexFocusReel: LunexReel?
    @Published var lunexFocusIdeaID: UUID?
    @Published var lunexUndo: LunexUndoRecord?
    @Published var themeChoice: LunexThemeChoice
    @Published var userStills: [LunexUserStill]

    private var lunexPhotoCount: Int
    private var lunexFlashTask: Task<Void, Never>?
    private var lunexUndoTask: Task<Void, Never>?
    private let lunexDefaults = UserDefaults.standard
    let lunexSoftCap = 80

    init() {
        hasSeenOnboarding = lunexDefaults.bool(forKey: LunexVaultKey.seen)
        ideas = Self.lunexDecode([LunexIdeaSlip].self, key: LunexVaultKey.ideas, defaults: lunexDefaults) ?? []
        captions = Self.lunexDecode([LunexCaptionSlip].self, key: LunexVaultKey.captions, defaults: lunexDefaults) ?? []
        boards = Self.lunexDecode([LunexBoardFrame].self, key: LunexVaultKey.boards, defaults: lunexDefaults) ?? []
        favorites = Self.lunexDecode([String].self, key: LunexVaultKey.favorites, defaults: lunexDefaults) ?? []
        annotations = Self.lunexDecode([String: String].self, key: LunexVaultKey.annotations, defaults: lunexDefaults) ?? [:]
        entryLimitAlertDismissed = lunexDefaults.bool(forKey: LunexVaultKey.limitHidden)
        if let raw = lunexDefaults.string(forKey: LunexVaultKey.selected) {
            selectedProjectID = UUID(uuidString: raw)
        }
        achievementsUnlocked = Self.lunexDecode([String: Date].self, key: LunexVaultKey.achievements, defaults: lunexDefaults) ?? [:]
        lastActivityDate = Self.lunexDecode(Date.self, key: LunexVaultKey.lastActivity, defaults: lunexDefaults)
        themeChoice = LunexThemeChoice(rawValue: lunexDefaults.string(forKey: LunexVaultKey.theme) ?? "") ?? .system
        userStills = Self.lunexDecode([LunexUserStill].self, key: LunexVaultKey.userStills, defaults: lunexDefaults) ?? []
        lunexPhotoCount = lunexDefaults.integer(forKey: LunexVaultKey.photoCount)
        if lunexPhotoCount < userStills.count {
            lunexPhotoCount = userStills.count
        }
    }

    var lunexStillKeys: [String] {
        userStills.map(\.id) + LunexStillRack.choices
    }

    func lunexStillTitle(_ key: String) -> String {
        if let title = userStills.first(where: { $0.id == key })?.title {
            return title
        }
        if LunexUserStillStore.isUser(key) { return "Your photo" }
        return LunexStillRack.lunexLabel(key)
    }

    func lunexAddUserStill(data: Data) -> String? {
        guard let key = LunexUserStillStore.save(data) else {
            lunexFlash("That photo could not be added.")
            return nil
        }
        lunexPhotoCount += 1
        userStills.insert(LunexUserStill(id: key, title: "Photo \(lunexPhotoCount)"), at: 0)
        lunexTouch()
        lunexPersist()
        lunexPulse()
        lunexFlash("Photo added.")
        return key
    }

    func lunexDeleteUserStill(_ id: String) {
        userStills.removeAll { $0.id == id }
        LunexUserStillStore.remove(id)
        lunexTouch()
        lunexPersist()
        lunexFlash("Photo removed.")
    }

    func lunexSetTheme(_ choice: LunexThemeChoice) {
        themeChoice = choice
        lunexDefaults.set(choice.rawValue, forKey: LunexVaultKey.theme)
    }

    func lunexMarkWelcomeDone() {
        hasSeenOnboarding = true
        lunexPersist()
    }

    func lunexHideLimit() {
        entryLimitAlertDismissed = true
        lunexPersist()
    }

    func lunexSaveIdea(_ idea: LunexIdeaSlip) -> Bool {
        let isNew = ideas.contains { $0.id == idea.id } == false
        if isNew && ideas.count >= lunexSoftCap {
            lunexFlash("The vault is full. Delete an older idea before adding another.")
            return false
        }
        if let index = ideas.firstIndex(where: { $0.id == idea.id }) {
            ideas[index] = idea
        } else {
            ideas.insert(idea, at: 0)
            if achievementsUnlocked["first-concept"] == nil {
                achievementsUnlocked["first-concept"] = Date()
            }
        }
        lunexTouch()
        lunexPersist()
        lunexPulse()
        lunexFlash("Idea saved in the vault.")
        return true
    }

    func lunexDeleteIdea(_ id: UUID) {
        guard let idea = ideas.first(where: { $0.id == id }) else { return }
        let captionIDs = captions.filter { $0.ideaID == id }.map(\.id)
        let spots = boards.compactMap { board -> LunexPinSpot? in
            guard let index = board.ideaIDs.firstIndex(of: id) else { return nil }
            return LunexPinSpot(boardID: board.id, index: index)
        }
        ideas.removeAll { $0.id == id }
        for index in captions.indices where captions[index].ideaID == id {
            captions[index].ideaID = nil
        }
        for index in boards.indices {
            boards[index].ideaIDs.removeAll { $0 == id }
        }
        lunexTouch()
        lunexPersist()
        lunexOfferUndo(.idea(idea, linkedCaptionIDs: captionIDs, spots: spots))
        lunexFlash("Idea removed. Linked scenes stayed in the scene list.")
    }

    func lunexSaveCaption(_ slip: LunexCaptionSlip, previous: String?) {
        var next = slip
        if let previous {
            let old = previous.trimmingCharacters(in: .whitespacesAndNewlines)
            if old.isEmpty == false && old != next.text {
                next.history.append(old)
                if next.history.count > 12 {
                    next.history.removeFirst(next.history.count - 12)
                }
            }
        }
        next.dateModified = Date()
        if let index = captions.firstIndex(where: { $0.id == next.id }) {
            captions[index] = next
        } else {
            captions.insert(next, at: 0)
        }
        lunexTouch()
        lunexPersist()
        lunexPulse()
        lunexFlash("Scene note saved.")
    }

    func lunexDeleteCaption(_ id: UUID) {
        guard let slip = captions.first(where: { $0.id == id }) else { return }
        let spots = boards.compactMap { board -> LunexPinSpot? in
            guard let index = board.captionIDs.firstIndex(of: id) else { return nil }
            return LunexPinSpot(boardID: board.id, index: index)
        }
        captions.removeAll { $0.id == id }
        for index in boards.indices {
            boards[index].captionIDs.removeAll { $0 == id }
        }
        lunexTouch()
        lunexPersist()
        lunexOfferUndo(.caption(slip, spots: spots))
        lunexFlash("Scene note removed.")
    }

    func lunexSaveBoard(_ board: LunexBoardFrame) {
        if let index = boards.firstIndex(where: { $0.id == board.id }) {
            boards[index] = board
        } else {
            boards.insert(board, at: 0)
        }
        selectedProjectID = board.id
        lunexTouch()
        lunexPersist()
        lunexPulse()
        lunexFlash("Board saved.")
    }

    func lunexDeleteBoard(_ id: UUID) {
        guard let board = boards.first(where: { $0.id == id }) else { return }
        let wasSelected = selectedProjectID == id
        boards.removeAll { $0.id == id }
        if wasSelected { selectedProjectID = nil }
        lunexTouch()
        lunexPersist()
        lunexOfferUndo(.board(board, wasSelected: wasSelected))
        lunexFlash("Board removed. Ideas and scenes stay in their lists.")
    }

    func lunexRememberBoard(_ id: UUID) {
        selectedProjectID = id
        lunexPersist()
    }

    func lunexPin(_ kind: LunexPinKind, boardID: UUID) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        switch kind {
        case .idea(let id):
            if boards[index].ideaIDs.contains(id) == false { boards[index].ideaIDs.append(id) }
        case .caption(let id):
            if boards[index].captionIDs.contains(id) == false { boards[index].captionIDs.append(id) }
        case .spark(let id):
            if boards[index].sparkIDs.contains(id) == false { boards[index].sparkIDs.append(id) }
        }
        selectedProjectID = boardID
        lunexTouch()
        lunexPersist()
        lunexPulse()
        lunexFlash("Pinned to \(boards[index].title).")
    }

    func lunexUnpin(_ kind: LunexPinKind, boardID: UUID) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        switch kind {
        case .idea(let id): boards[index].ideaIDs.removeAll { $0 == id }
        case .caption(let id): boards[index].captionIDs.removeAll { $0 == id }
        case .spark(let id): boards[index].sparkIDs.removeAll { $0 == id }
        }
        lunexTouch()
        lunexPersist()
        lunexFlash("Removed from the board.")
    }

    func lunexCreateBoardAndPin(title: String, logline: String, kind: LunexPinKind) -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLine = logline.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty || cleanLine.isEmpty { return false }
        let board = LunexBoardFrame(id: UUID(), title: cleanTitle, logline: cleanLine, ideaIDs: [], captionIDs: [], sparkIDs: [])
        boards.insert(board, at: 0)
        lunexPin(kind, boardID: board.id)
        return true
    }

    func lunexToggleFavorite(_ id: String) {
        if let index = favorites.firstIndex(of: id) {
            favorites.remove(at: index)
            lunexFlash("Removed from saved inspirations.")
        } else {
            favorites.append(id)
            lunexPulse()
            lunexFlash("Saved with your inspirations.")
        }
        lunexTouch()
        lunexPersist()
    }

    func lunexSaveAnnotation(sparkID: String, text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count < 3 {
            lunexFlash("Write at least 3 characters.")
            return false
        }
        annotations[sparkID] = clean
        lunexTouch()
        lunexPersist()
        lunexPulse()
        lunexFlash("Note saved on this inspiration.")
        return true
    }

    func lunexBoardCount(for idea: UUID) -> Int {
        boards.filter { $0.ideaIDs.contains(idea) }.count
    }

    func lunexScenes(for ideaID: UUID) -> [LunexCaptionSlip] {
        captions.filter { $0.ideaID == ideaID }
    }

    func lunexCoverStill(for board: LunexBoardFrame) -> String? {
        for id in board.captionIDs {
            if let slip = captions.first(where: { $0.id == id }) {
                return slip.stillKey
            }
        }
        return nil
    }

    func lunexIdeasMissingScenes(on board: LunexBoardFrame) -> [LunexIdeaSlip] {
        let linked = Set(captions.compactMap(\.ideaID))
        return board.ideaIDs.compactMap { id in ideas.first { $0.id == id } }.filter { linked.contains($0.id) == false }
    }

    func lunexUnpinnedCaptions() -> [LunexCaptionSlip] {
        let pinned = Set(boards.flatMap(\.captionIDs))
        return captions.filter { pinned.contains($0.id) == false }
    }

    func lunexSetIdeaOrder(boardID: UUID, ids: [UUID]) {
        lunexWriteOrder(boardID: boardID) { board in
            let known = Set(ids)
            board.ideaIDs = ids + board.ideaIDs.filter { known.contains($0) == false }
        }
    }

    func lunexSetCaptionOrder(boardID: UUID, ids: [UUID]) {
        lunexWriteOrder(boardID: boardID) { board in
            let known = Set(ids)
            board.captionIDs = ids + board.captionIDs.filter { known.contains($0) == false }
        }
    }

    func lunexSetSparkOrder(boardID: UUID, ids: [String]) {
        lunexWriteOrder(boardID: boardID) { board in
            let known = Set(ids)
            board.sparkIDs = ids + board.sparkIDs.filter { known.contains($0) == false }
        }
    }

    func lunexIdeaFromSpark(title: String, notes: String) -> LunexIdeaSlip? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let idea = LunexIdeaSlip(
            id: UUID(),
            title: cleanTitle.isEmpty ? "Untitled spark" : cleanTitle,
            emojiIcon: LunexGlyphRack.marks[0],
            notes: cleanNotes.isEmpty ? "From a saved inspiration." : cleanNotes,
            updatedOn: Date(),
            status: .draft
        )
        if lunexSaveIdea(idea) {
            return idea
        }
        return nil
    }

    func lunexSearch(_ raw: String) -> [LunexSearchHit] {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard text.isEmpty == false else { return [] }
        var hits: [LunexSearchHit] = []
        for idea in ideas {
            let hay = "\(idea.title) \(idea.notes) \(idea.status.lunexTitle)".lowercased()
            if hay.contains(text) {
                hits.append(LunexSearchHit(kind: .idea, ref: idea.id.uuidString, title: idea.title, detail: idea.notes))
            }
        }
        for slip in captions where slip.text.lowercased().contains(text) || slip.lunexMarks.lowercased().contains(text) {
            let detail = slip.lunexMarks.isEmpty ? lunexStillTitle(slip.stillKey) : slip.lunexMarks
            hits.append(LunexSearchHit(kind: .caption, ref: slip.id.uuidString, title: slip.text, detail: detail))
        }
        for board in boards {
            let hay = "\(board.title) \(board.logline)".lowercased()
            if hay.contains(text) {
                hits.append(LunexSearchHit(kind: .board, ref: board.id.uuidString, title: board.title, detail: board.logline))
            }
        }
        return hits
    }

    func lunexUndoLast() {
        guard let record = lunexUndo else { return }
        switch record {
        case .idea(let idea, let captionIDs, let spots):
            if ideas.contains(where: { $0.id == idea.id }) == false {
                ideas.insert(idea, at: 0)
            }
            for captionID in captionIDs {
                if let index = captions.firstIndex(where: { $0.id == captionID }) {
                    captions[index].ideaID = idea.id
                }
            }
            for spot in spots {
                guard let index = boards.firstIndex(where: { $0.id == spot.boardID }) else { continue }
                if boards[index].ideaIDs.contains(idea.id) { continue }
                var ids = boards[index].ideaIDs
                ids.insert(idea.id, at: min(spot.index, ids.count))
                boards[index].ideaIDs = ids
            }
        case .caption(let slip, let spots):
            if captions.contains(where: { $0.id == slip.id }) == false {
                captions.insert(slip, at: 0)
            }
            for spot in spots {
                guard let index = boards.firstIndex(where: { $0.id == spot.boardID }) else { continue }
                if boards[index].captionIDs.contains(slip.id) { continue }
                var ids = boards[index].captionIDs
                ids.insert(slip.id, at: min(spot.index, ids.count))
                boards[index].captionIDs = ids
            }
        case .board(let board, let wasSelected):
            if boards.contains(where: { $0.id == board.id }) == false {
                boards.insert(board, at: 0)
            }
            if wasSelected { selectedProjectID = board.id }
        }
        lunexUndo = nil
        lunexUndoTask?.cancel()
        lunexTouch()
        lunexPersist()
        lunexPulse()
        lunexFlash("Restored.")
    }

    func lunexResetAll() {
        hasSeenOnboarding = false
        ideas = []
        captions = []
        boards = []
        favorites = []
        annotations = [:]
        entryLimitAlertDismissed = false
        selectedProjectID = nil
        achievementsUnlocked = [:]
        lastActivityDate = nil
        lunexBanner = nil
        lunexUndo = nil
        lunexUndoTask?.cancel()
        lunexFocusIdeaID = nil
        for still in userStills {
            LunexUserStillStore.remove(still.id)
        }
        userStills = []
        lunexPhotoCount = 0
        lunexPersist()
        NotificationCenter.default.post(name: .dataReset, object: nil)
    }

    func lunexFlash(_ text: String) {
        lunexBanner = text
        lunexFlashTask?.cancel()
        lunexFlashTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            guard Task.isCancelled == false else { return }
            self.lunexBanner = nil
        }
    }

    private func lunexWriteOrder(boardID: UUID, change: (inout LunexBoardFrame) -> Void) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        change(&boards[index])
        lunexTouch()
        lunexPersist()
    }

    private func lunexOfferUndo(_ record: LunexUndoRecord) {
        lunexUndo = record
        lunexUndoTask?.cancel()
        lunexUndoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard Task.isCancelled == false else { return }
            self.lunexUndo = nil
        }
    }

    private func lunexTouch() { lastActivityDate = Date() }

    private func lunexPulse() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func lunexPersist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        func pack<T: Encodable>(_ value: T, _ key: String) {
            if let data = try? encoder.encode(value) {
                lunexDefaults.set(data, forKey: key)
            }
        }
        lunexDefaults.set(hasSeenOnboarding, forKey: LunexVaultKey.seen)
        lunexDefaults.set(entryLimitAlertDismissed, forKey: LunexVaultKey.limitHidden)
        pack(ideas, LunexVaultKey.ideas)
        pack(captions, LunexVaultKey.captions)
        pack(boards, LunexVaultKey.boards)
        pack(favorites, LunexVaultKey.favorites)
        pack(annotations, LunexVaultKey.annotations)
        pack(achievementsUnlocked, LunexVaultKey.achievements)
        pack(userStills, LunexVaultKey.userStills)
        lunexDefaults.set(lunexPhotoCount, forKey: LunexVaultKey.photoCount)
        if let selectedProjectID {
            lunexDefaults.set(selectedProjectID.uuidString, forKey: LunexVaultKey.selected)
        } else {
            lunexDefaults.removeObject(forKey: LunexVaultKey.selected)
        }
        if let lastActivityDate {
            pack(lastActivityDate, LunexVaultKey.lastActivity)
        } else {
            lunexDefaults.removeObject(forKey: LunexVaultKey.lastActivity)
        }
    }

    private static func lunexDecode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(type, from: data)
    }
}

@MainActor
enum LunexUserStillStore {
    nonisolated static func isUser(_ key: String) -> Bool {
        key.hasPrefix("lunex-user-")
    }

    static func image(for key: String) -> UIImage? {
        guard isUser(key) else { return nil }
        if let cached = cache[key] { return cached }
        guard let image = UIImage(contentsOfFile: fileURL(for: key).path) else { return nil }
        cache[key] = image
        return image
    }

    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let fitted = lunexFitted(image, maxSide: 1600)
        guard let jpeg = fitted.jpegData(compressionQuality: 0.82) else { return nil }
        let key = "lunex-user-\(UUID().uuidString)"
        do {
            try jpeg.write(to: fileURL(for: key), options: .atomic)
            cache[key] = fitted
            return key
        } catch {
            return nil
        }
    }

    static func remove(_ key: String) {
        cache[key] = nil
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    private static var cache: [String: UIImage] = [:]

    private static func directory() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = root.appendingPathComponent("LunexUserStills", isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) == false {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private static func fileURL(for key: String) -> URL {
        directory().appendingPathComponent(key).appendingPathExtension("jpg")
    }

    private static func lunexFitted(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

enum LunexLedgerVaultFeyraDrift {
    static func lunexLedgerVaultFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [42, 22, 75, 11, 28, 75]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 75)
        }
        return lane
    }
}
