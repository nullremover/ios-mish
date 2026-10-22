import SwiftUI
import UIKit

/// Number pad that unlocks the "THANK YOU GABRIEL" banner.
struct KeypadView: View {
    @Binding var unlocked: Bool
    let tint: Color

    @State private var entry = ""
    @State private var shakes: CGFloat = 0

    private let secret = "4227435"
    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["C", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(0..<secret.count, id: \.self) { index in
                        Circle()
                            .fill(index < entry.count ? tint : tint.opacity(0.2))
                            .frame(width: 12, height: 12)
                    }
                }
                .modifier(ShakeEffect(animatableData: shakes))

                Text(unlocked ? "Unlocked" : "Enter code")
                    .font(.system(size: 12))
                    .foregroundColor(tint.opacity(0.6))
            }

            VStack(spacing: 14) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 14) {
                        ForEach(row, id: \.self) { key in
                            keyButton(key)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func keyButton(_ key: String) -> some View {
        Button {
            press(key)
        } label: {
            Text(key)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 66, height: 66)
                .background(Circle().fill(tint.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func press(_ key: String) {
        guard !unlocked else { return }

        switch key {
        case "C":
            entry = ""
        case "⌫":
            if !entry.isEmpty { entry.removeLast() }
        default:
            guard entry.count < secret.count else { return }
            entry.append(key)
            if entry.count == secret.count { check() }
        }
    }

    private func check() {
        if entry == secret {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring()) { unlocked = true }
            entry = ""
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.default) { shakes += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                entry = ""
            }
        }
    }
}

/// Horizontal shake used for a wrong code.
private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: 10 * sin(animatableData * .pi * 3),
                y: 0
            )
        )
    }
}

/// Pinned strip shown on every tab until the app is closed.
struct ThankYouBanner: View {
    var body: some View {
        Text("THANK YOU GABRIEL")
            .font(.system(size: 13, weight: .heavy))
            .tracking(2)
            .foregroundColor(Color(hex: 0x121812))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color.mishGreen)
    }
}
