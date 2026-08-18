import SwiftUI

enum BiscuitMood {
    case welcoming
    case thinking
    case celebrating
}

struct BiscuitMascot: View {
    let size: CGFloat
    var mood: BiscuitMood = .welcoming
    var assetName = "BiscuitMascot"

    @State private var isBreathing = false
    @State private var isTilting = false

    var body: some View {
        ZStack {
            Image(assetName, bundle: BiscuitResources.bundle)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()

            if mood == .thinking {
                HStack(spacing: size * 0.03) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(0.94))
                            .frame(width: size * CGFloat(0.07 + Double(index) * 0.015))
                            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    }
                }
                .padding(size * 0.06)
                .background(.black.opacity(0.38), in: Capsule())
                .offset(x: size * 0.22, y: -size * 0.28)
            } else if mood == .celebrating {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.18, weight: .bold))
                    .foregroundStyle(Color(hex: 0x4AD6EF))
                    .shadow(color: Color(hex: 0x4AD6EF).opacity(0.5), radius: 7)
                    .offset(x: size * 0.32, y: -size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(.white.opacity(0.62), lineWidth: max(1, size * 0.018))
        }
        .shadow(color: .black.opacity(0.18), radius: size * 0.08, y: size * 0.05)
        .scaleEffect(isBreathing ? 1.018 : 0.982)
        .rotationEffect(.degrees(isTilting ? 1.1 : -1.1))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.15)) {
                isTilting = true
            }
        }
        .accessibilityLabel("BiscuitAI mascot")
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
