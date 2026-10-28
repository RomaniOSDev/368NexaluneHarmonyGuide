import SwiftUI

extension Color {
    static let lunexBackdrop = Color("AppBackground")
    static let lunexCard = Color("AppSurface")
    static let lunexGold = Color("AppPrimary")
    static let lunexEmber = Color("AppAccent")
    static let lunexInk = Color("AppInk")
    static let lunexOnPrimary = Color("AppOnPrimary")
}

struct LunexPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

struct LunexBackdropPlate: View {
    let still: String

    var body: some View {
        Color.lunexBackdrop
            .overlay {
                LunexStillImage(key: still)
                    .opacity(0.26)
            }
            .overlay {
                LinearGradient(
                    colors: [Color.lunexBackdrop.opacity(0.15), Color.lunexBackdrop.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipped()
    }
}

struct LunexScreen<Content: View>: View {
    let still: String
    private let content: Content

    init(still: String, @ViewBuilder content: () -> Content) {
        self.still = still
        self.content = content()
    }

    var body: some View {
        ZStack {
            LunexBackdropPlate(still: still)
                .ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    @ViewBuilder
    func lunexSheetBackdrop(still: String) -> some View {
        if #available(iOS 16.4, *) {
            presentationBackground {
                LunexBackdropPlate(still: still)
            }
        } else {
            background(LunexBackdropPlate(still: still))
        }
    }

    func lunexSheetBar() -> some View {
        toolbarBackground(Color.lunexBackdrop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct LunexStillFrame: View {
    let key: String
    var height: CGFloat = 132

    var body: some View {
        LunexStillImage(key: key)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .contentShape(Rectangle())
            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 2))
            .shadow(color: Color.black.opacity(0.2), radius: 7, y: 4)
    }
}

struct LunexStillImage: View {
    let key: String

    var body: some View {
        if let image = LunexUserStillStore.image(for: key) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if LunexUserStillStore.isUser(key) {
            Color.lunexCard
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(Color.lunexGold)
                }
        } else {
            Image(key)
                .resizable()
                .scaledToFill()
        }
    }
}

struct LunexSlateCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lunexCard.shadow(color: Color.black.opacity(0.16), radius: 7, y: 4))
            .overlay(Rectangle().stroke(LinearGradient(colors: [Color.lunexGold, Color.lunexEmber], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
    }
}

struct LunexPrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.lunexOnPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 10)
                .background(
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.lunexGold, Color.lunexEmber], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: Color.lunexGold.opacity(0.3), radius: 7, y: 3)
                )
        }
        .buttonStyle(LunexPressStyle())
    }
}

struct LunexQuietButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.lunexGold)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1.5))
        }
        .buttonStyle(LunexPressStyle())
    }
}

struct LunexChoiceChip: View {
    let title: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(selected ? Color.lunexOnPrimary : Color.lunexInk)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Rectangle().fill(selected ? Color.lunexGold : Color.lunexCard))
                .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
        }
        .buttonStyle(LunexPressStyle())
    }
}

struct LunexUndoBar: View {
    @EnvironmentObject private var vault: LunexLedgerVault

    var body: some View {
        if let undo = vault.lunexUndo {
            HStack(alignment: .center, spacing: 12) {
                Text(undo.lunexTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.lunexInk)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Undo") { vault.lunexUndoLast() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.lunexGold)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lunexCard)
            .overlay(Rectangle().stroke(Color.lunexGold, lineWidth: 1))
        }
    }
}

struct LunexBannerLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.lunexOnPrimary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Rectangle().fill(LinearGradient(colors: [Color.lunexEmber, Color.lunexGold], startPoint: .leading, endPoint: .trailing)))
    }
}

struct LunexFilmHoles: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.lunexGold.opacity(0.9))
                    .frame(width: 14, height: 9)
            }
        }
        .accessibilityHidden(true)
    }
}

struct LunexKeypadVeil: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let veil = UIView(frame: .zero)
        veil.isUserInteractionEnabled = false
        veil.backgroundColor = .clear
        return veil
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard context.coordinator.attached == false, let window = uiView.window else { return }
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.lunexFoldKeys))
            tap.cancelsTouchesInView = false
            tap.delegate = context.coordinator
            tap.name = "lunexFoldKeys"
            window.addGestureRecognizer(tap)
            context.coordinator.attached = true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var attached = false
        @objc func lunexFoldKeys() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var node: UIView? = touch.view
            while let current = node {
                if current is UITextField || current is UITextView { return false }
                node = current.superview
            }
            return true
        }
    }
}

enum LunexSurfaceKitFeyraDrift {
    static func lunexSurfaceKitFeyraDriftFold(_ basis: Int) -> Int {
        var lane = basis
        let marks = [65, 43, 30, 56, 8, 10]
        for mark in marks {
            lane = (lane &+ mark) ^ (lane &* 30)
        }
        return lane
    }
}
