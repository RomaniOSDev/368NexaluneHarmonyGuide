import SwiftUI

struct LunexWelcomeReel: View {
    @EnvironmentObject private var vault: LunexLedgerVault
    @State private var page = 0

    private let pages: [(still: String, headline: String, detail: String)] = [
        (LunexStillRack.camera, "Organize Ideas", "Keep film concepts as short notes with an icon, then pin them to a board."),
        (LunexStillRack.alley, "Frame and Note", "Choose a still and write the shot idea beside it. Earlier wording stays in a history list."),
        (LunexStillRack.desert, "Start Creating", "Save the first idea, add a scene note, and pin both onto a project board.")
    ]

    var body: some View {
        LunexScreen(still: LunexStillRack.chair) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("STORYBOARD")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.lunexGold)
                        Spacer(minLength: 8)
                        Button {
                            vault.lunexMarkWelcomeDone()
                        } label: {
                            Text("Skip the slate")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(Color.lunexInk)
                                .lineLimit(nil)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
                        }
                        .buttonStyle(LunexPressStyle())
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(pages.indices, id: \.self) { index in
                                Button {
                                    page = index
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        lunexFrame(pages[index].still, selected: page == index)
                                        Text(String(format: "FR %02d", index + 1))
                                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                                            .foregroundStyle(page == index ? Color.lunexGold : Color.lunexInk.opacity(0.7))
                                    }
                                }
                                .buttonStyle(LunexPressStyle())
                                .accessibilityLabel("Frame \(index + 1)")
                                .accessibilityAddTraits(page == index ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SCENE \(page + 1)")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.lunexOnPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Rectangle().fill(Color.lunexEmber))
                        Text(pages[page].headline)
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.lunexInk)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle()
                            .fill(Color.lunexGold)
                            .frame(height: 2)
                            .frame(maxWidth: 72, alignment: .leading)
                        Text(pages[page].detail)
                            .font(.body)
                            .foregroundStyle(Color.lunexInk.opacity(0.86))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.lunexCard.shadow(color: Color.black.opacity(0.18), radius: 8, y: 4))
                    .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 2))

                    HStack(spacing: 10) {
                        Button {
                            if page > 0 { page -= 1 }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "backward.frame")
                                Text("Back")
                                    .font(.caption.weight(.bold))
                                    .lineLimit(nil)
                            }
                            .foregroundStyle(page == 0 ? Color.lunexInk.opacity(0.35) : Color.lunexGold)
                            .frame(width: 72, height: 64)
                            .overlay(Rectangle().stroke(Color.lunexGold.opacity(page == 0 ? 0.35 : 1), lineWidth: 1.5))
                        }
                        .buttonStyle(LunexPressStyle())
                        .disabled(page == 0)

                        Button {
                            if page == pages.count - 1 {
                                vault.lunexMarkWelcomeDone()
                            } else {
                                page += 1
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: page == pages.count - 1 ? "rectangle.portrait.on.rectangle.portrait" : "forward.frame")
                                Text(page == pages.count - 1 ? "Enter the boards" : "Next frame")
                                    .font(.subheadline.weight(.bold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(Color.lunexOnPrimary)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .padding(.horizontal, 8)
                            .background(
                                Rectangle().fill(
                                    LinearGradient(colors: [Color.lunexGold, Color.lunexEmber], startPoint: .leading, endPoint: .trailing)
                                )
                            )
                        }
                        .buttonStyle(LunexPressStyle())
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func lunexFrame(_ key: String, selected: Bool) -> some View {
        Color.clear
            .frame(width: 148, height: 84)
            .overlay {
                Image(key)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay(Rectangle().stroke(selected ? Color.lunexGold : Color.lunexInk.opacity(0.35), lineWidth: selected ? 3 : 1))
            .shadow(color: Color.lunexGold.opacity(selected ? 0.35 : 0), radius: 6, y: 2)
            .accessibilityHidden(true)
    }
}

enum LunexWelcomeReelFeyraDrift {
    static func lunexWelcomeReelFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [18, 39, 11, 10, 71, 46]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 11)
        }
        return lane
    }
}
