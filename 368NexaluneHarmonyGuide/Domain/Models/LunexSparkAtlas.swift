import Foundation

enum LunexSparkAtlas {
    static let genres = ["All", "Night", "Road", "Interior", "Object"]

    static func lunexFind(_ id: String) -> LunexSparkCard? {
        cards.first { $0.id == id }
    }

    static let cards: [LunexSparkCard] = [
        LunexSparkCard(id: "rain-reflection", title: "Rain reflection", genre: "Night", stillKey: LunexStillRack.alley, seedNote: "Hold the shot low so the wet street leads toward one lamp."),
        LunexSparkCard(id: "empty-highway", title: "Empty highway", genre: "Road", stillKey: LunexStillRack.desert, seedNote: "A long view down the center of the road at warm dusk."),
        LunexSparkCard(id: "single-chair", title: "Single chair", genre: "Interior", stillKey: LunexStillRack.chair, seedNote: "One practical light, the chair slightly off center, the room mostly dark."),
        LunexSparkCard(id: "tabletop-relic", title: "Tabletop relic", genre: "Object", stillKey: LunexStillRack.camera, seedNote: "Close frame on a worn camera. Move focus from the lens to the film curl."),
        LunexSparkCard(id: "window-hush", title: "Window hush", genre: "Interior", stillKey: LunexStillRack.alley, seedNote: "Imagine the alley seen through glass, with the room faintly reflected."),
        LunexSparkCard(id: "horizon-wait", title: "Horizon wait", genre: "Road", stillKey: LunexStillRack.desert, seedNote: "Lock the frame and let a tiny distant shape cross slowly.")
    ]
}

enum LunexSparkAtlasFeyraDrift {
    static func lunexSparkAtlasFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [54, 13, 68, 36, 65, 23]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 68)
        }
        return lane
    }
}
