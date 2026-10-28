import Foundation

enum LunexIdeaStatus: String, Codable, CaseIterable, Identifiable {
    case draft, active, shelved

    var id: String { rawValue }

    var lunexTitle: String {
        switch self {
        case .draft: return "Draft"
        case .active: return "In progress"
        case .shelved: return "Shelved"
        }
    }
}

enum LunexDayPart: String, Codable, CaseIterable, Identifiable {
    case day, dusk, night, interior

    var id: String { rawValue }

    var lunexTitle: String {
        switch self {
        case .day: return "Day"
        case .dusk: return "Dusk"
        case .night: return "Night"
        case .interior: return "Interior"
        }
    }
}

enum LunexShotSize: String, Codable, CaseIterable, Identifiable {
    case wide, medium, close, insert

    var id: String { rawValue }

    var lunexTitle: String {
        switch self {
        case .wide: return "Wide"
        case .medium: return "Medium"
        case .close: return "Close-up"
        case .insert: return "Insert"
        }
    }
}

enum LunexCameraMove: String, Codable, CaseIterable, Identifiable {
    case locked, push, pan, handheld

    var id: String { rawValue }

    var lunexTitle: String {
        switch self {
        case .locked: return "Locked"
        case .push: return "Push"
        case .pan: return "Pan"
        case .handheld: return "Handheld"
        }
    }
}

enum LunexNoteStarter: String, CaseIterable, Identifiable {
    case wide, close, insert

    var id: String { rawValue }

    var lunexTitle: String {
        switch self {
        case .wide: return "Wide"
        case .close: return "Close-up"
        case .insert: return "Insert"
        }
    }

    var lunexLine: String {
        switch self {
        case .wide: return "Wide shot. The frame holds the whole place, with the subject small in it."
        case .close: return "Close-up. The frame stays on one face or object."
        case .insert: return "Insert. A tight detail that explains the scene."
        }
    }

    var shotSize: LunexShotSize {
        switch self {
        case .wide: return .wide
        case .close: return .close
        case .insert: return .insert
        }
    }
}

enum LunexIdeaSort: String, CaseIterable, Identifiable {
    case recent, title, boards

    var id: String { rawValue }

    var lunexTitle: String {
        switch self {
        case .recent: return "Recent"
        case .title: return "Title"
        case .boards: return "Boards"
        }
    }
}

enum LunexThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var lunexTitle: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct LunexIdeaSlip: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var emojiIcon: String
    var notes: String
    var updatedOn: Date
    var status: LunexIdeaStatus

    init(id: UUID, title: String, emojiIcon: String, notes: String, updatedOn: Date, status: LunexIdeaStatus = .draft) {
        self.id = id
        self.title = title
        self.emojiIcon = emojiIcon
        self.notes = notes
        self.updatedOn = updatedOn
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, emojiIcon, notes, updatedOn, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        emojiIcon = try container.decode(String.self, forKey: .emojiIcon)
        notes = try container.decode(String.self, forKey: .notes)
        updatedOn = try container.decode(Date.self, forKey: .updatedOn)
        status = try container.decodeIfPresent(LunexIdeaStatus.self, forKey: .status) ?? .draft
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(emojiIcon, forKey: .emojiIcon)
        try container.encode(notes, forKey: .notes)
        try container.encode(updatedOn, forKey: .updatedOn)
        try container.encode(status, forKey: .status)
    }
}

struct LunexCaptionSlip: Identifiable, Codable, Hashable {
    var id: UUID
    var ideaID: UUID?
    var stillKey: String
    var text: String
    var dateModified: Date
    var history: [String]
    var dayPart: LunexDayPart?
    var shotSize: LunexShotSize?
    var cameraMove: LunexCameraMove?

    var lunexMarks: String {
        [dayPart?.lunexTitle, shotSize?.lunexTitle, cameraMove?.lunexTitle]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    init(
        id: UUID,
        ideaID: UUID?,
        stillKey: String,
        text: String,
        dateModified: Date,
        history: [String],
        dayPart: LunexDayPart? = nil,
        shotSize: LunexShotSize? = nil,
        cameraMove: LunexCameraMove? = nil
    ) {
        self.id = id
        self.ideaID = ideaID
        self.stillKey = stillKey
        self.text = text
        self.dateModified = dateModified
        self.history = history
        self.dayPart = dayPart
        self.shotSize = shotSize
        self.cameraMove = cameraMove
    }

    private enum CodingKeys: String, CodingKey {
        case id, ideaID, stillKey, text, dateModified, history, dayPart, shotSize, cameraMove
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ideaID = try container.decodeIfPresent(UUID.self, forKey: .ideaID)
        stillKey = try container.decode(String.self, forKey: .stillKey)
        text = try container.decode(String.self, forKey: .text)
        dateModified = try container.decode(Date.self, forKey: .dateModified)
        history = try container.decodeIfPresent([String].self, forKey: .history) ?? []
        dayPart = try container.decodeIfPresent(LunexDayPart.self, forKey: .dayPart)
        shotSize = try container.decodeIfPresent(LunexShotSize.self, forKey: .shotSize)
        cameraMove = try container.decodeIfPresent(LunexCameraMove.self, forKey: .cameraMove)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(ideaID, forKey: .ideaID)
        try container.encode(stillKey, forKey: .stillKey)
        try container.encode(text, forKey: .text)
        try container.encode(dateModified, forKey: .dateModified)
        try container.encode(history, forKey: .history)
        try container.encodeIfPresent(dayPart, forKey: .dayPart)
        try container.encodeIfPresent(shotSize, forKey: .shotSize)
        try container.encodeIfPresent(cameraMove, forKey: .cameraMove)
    }
}

struct LunexBoardFrame: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var logline: String
    var ideaIDs: [UUID]
    var captionIDs: [UUID]
    var sparkIDs: [String]
}

struct LunexSparkCard: Identifiable, Hashable {
    let id: String
    let title: String
    let genre: String
    let stillKey: String
    let seedNote: String
}

struct LunexSearchHit: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case idea, caption, board

        var lunexTitle: String {
            switch self {
            case .idea: return "Idea"
            case .caption: return "Scene"
            case .board: return "Board"
            }
        }
    }

    let kind: Kind
    let ref: String
    let title: String
    let detail: String

    var id: String { "\(kind.rawValue)-\(ref)" }
}

enum LunexPinKind: Identifiable, Hashable {
    case idea(UUID)
    case caption(UUID)
    case spark(String)

    var id: String {
        switch self {
        case .idea(let value): return "idea-\(value.uuidString)"
        case .caption(let value): return "caption-\(value.uuidString)"
        case .spark(let value): return "spark-\(value)"
        }
    }
}

enum LunexReel: Int, CaseIterable, Identifiable {
    case vault, scenes, boards, sparks
    var id: Int { rawValue }
    var code: String { String(format: "%02d", rawValue + 1) }
    var lunexTitle: String {
        switch self {
        case .vault: return "Ideas"
        case .scenes: return "Scenes"
        case .boards: return "Boards"
        case .sparks: return "Sparks"
        }
    }
}

enum LunexGlyphRack {
    static let marks = ["🎬", "🌃", "🚂", "🌲", "🔦", "🌧️", "🎭", "🏔️", "⭐", "🧳"]
}

struct LunexUserStill: Identifiable, Codable, Hashable {
    var id: String
    var title: String
}

enum LunexStillRack {
    static let camera = "lunexCameraTable"
    static let alley = "lunexRainAlley"
    static let desert = "lunexDesertRoad"
    static let chair = "lunexSpotChair"
    static let choices = [camera, alley, desert, chair]

    static func lunexLabel(_ key: String) -> String {
        switch key {
        case camera: return "Camera table"
        case alley: return "Rain alley"
        case desert: return "Desert road"
        case chair: return "Spotlight chair"
        default: return "Still"
        }
    }
}

enum LunexStampText {
    static func day(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

enum LunexFrameModelsFeyraDrift {
    static func lunexFrameModelsFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [40, 33, 66, 73, 14, 25]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 66)
        }
        return lane
    }
}
