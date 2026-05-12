import SwiftUI
import SceneKit

// MARK: - Goose Display State

enum GooseDisplayState {
    case sleeping
    case happy
    case normal
    case sad
    case sick

    var modelName: String {
        switch self {
        case .sleeping: return "goose_sleep"
        case .happy:    return "goose_happy"
        case .normal:   return "goose_normal"
        case .sad:      return "goose_sad"
        case .sick:     return "goose_sick"
        }
    }

    enum AuraStyle {
        case stars
        case zzz
        case drops
    }

    var auraStyle: (style: AuraStyle, color: Color)? {
        switch self {
        case .sleeping: return (.zzz, .indigo.opacity(0.8))
        case .happy:    return (.stars, .yellow)
        case .sad:      return (.drops, .blue.opacity(0.6))
        case .sick:     return (.drops, .green.opacity(0.6))
        case .normal:   return nil
        }
    }
}

// MARK: - Goose Character View

struct GooseCharacterView: View {
    let mood: GooseMood
    var showReaction: GooseReaction = .none
    var healthiness: Double = 50
    var happiness: Double = 50
    var debugDisplayState: GooseDisplayState? = nil

    @State private var isSleeping: Bool = false
    @State private var bobOffset: CGFloat = 0
    @State private var reactionScale: CGFloat = 1.0
    @State private var wobbleAngle: Double = 0

    private var displayState: GooseDisplayState {
        if let override = debugDisplayState { return override }
        if isSleeping { return .sleeping }
        switch mood {
        case .happy:            return .happy
        case .content:          return .normal
        case .sad:              return .sad
        case .sick:             return .sick
        }
    }

    var body: some View {
        ZStack {
            auraLayer

            Goose3DView(modelName: displayState.modelName)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(reactionScale)
        }
        .onAppear {
            isSleeping = Int.random(in: 0..<5) == 0
            startIdleAnimation()
        }
        .onChange(of: showReaction) { _, reaction in
            playReaction(reaction)
        }
    }

    // MARK: - Aura

    private let auraPositions: [(CGFloat, CGFloat)] = [(-65, -100), (65, -95), (-50, -55), (60, -60)]

    @ViewBuilder
    private var auraLayer: some View {
        if let aura = displayState.auraStyle {
            ZStack {
                ForEach(Array(auraPositions.enumerated()), id: \.offset) { i, pos in
                    AuraParticleView(
                        style: aura.style,
                        color: aura.color,
                        index: i,
                        x: pos.0,
                        y: pos.1
                    )
                }
            }
        }
    }

    // MARK: - Animations

    private func startIdleAnimation() {
        let duration: Double = displayState == .sleeping ? 4.0 : displayState == .sad ? 3.0 : 2.0
        let bobAmount: CGFloat = displayState == .sleeping ? -3 : displayState == .sad ? -4 : -8

        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            bobOffset = bobAmount
        }

    }

    private func playReaction(_ reaction: GooseReaction) {
        switch reaction {
        case .goalComplete:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                reactionScale = 1.15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    reactionScale = 1.0
                }
            }
        case .feed:
            withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                wobbleAngle = 5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                wobbleAngle = 0
            }
        case .none:
            break
        }
    }
}

// MARK: - Aura Particle View

private struct AuraParticleView: View {
    let style: GooseDisplayState.AuraStyle
    let color: Color
    let index: Int
    let x: CGFloat
    let y: CGFloat

    @State private var floating = false
    @State private var visible = false

    private var delay: Double { Double(index) * 0.3 }

    var body: some View {
        particle
            .offset(x: x, y: y + (floating ? -6 : 6))
            .opacity(visible ? 1 : 0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeIn(duration: 0.4)) { visible = true }
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        floating = true
                    }
                }
            }
    }

    @ViewBuilder
    private var particle: some View {
        switch style {
        case .stars:
            Image(systemName: index % 2 == 0 ? "sparkle" : "star.fill")
                .font(.system(size: index % 2 == 0 ? 16 : 11))
                .foregroundStyle(color)
        case .zzz:
            let sizes: [CGFloat] = [10, 14, 12, 16]
            let letters = ["z", "z", "Z", "Z"]
            Text(letters[index])
                .font(.system(size: sizes[index], weight: .bold, design: .rounded))
                .foregroundStyle(color)
        case .drops:
            Image(systemName: index % 2 == 0 ? "bolt.fill" : "exclamationmark.2")
                .font(.system(size: 15))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Reaction Type

enum GooseReaction: Equatable {
    case none
    case goalComplete
    case feed
}

// MARK: - Mood Overlay Components (kept for potential reuse)

struct SweatDrop: View {
    @State private var opacity: Double = 0.8

    var body: some View {
        Ellipse()
            .fill(GoosieTheme.skyBlue)
            .frame(width: 8, height: 12)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    opacity = 0.3
                }
            }
    }
}

struct ZzzBubbles: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        VStack(spacing: 4) {
            Text("z")
                .font(GoosieTheme.bodyFont(10))
                .foregroundStyle(GoosieTheme.skyBlue)
            Text("z")
                .font(GoosieTheme.bodyFont(13))
                .foregroundStyle(GoosieTheme.skyBlue)
            Text("Z")
                .font(GoosieTheme.bodyFont(16))
                .foregroundStyle(GoosieTheme.skyBlue)
        }
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                offset = -20
                opacity = 0
            }
        }
    }
}

struct SparkleParticles: View {
    @State private var sparkle = false

    var body: some View {
        HStack(spacing: 20) {
            sparkleIcon.offset(y: sparkle ? -10 : 0)
            sparkleIcon.offset(y: sparkle ? -5 : 5)
            sparkleIcon.offset(y: sparkle ? -8 : 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                sparkle = true
            }
        }
    }

    private var sparkleIcon: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GoosieTheme.sunYellow)
    }
}

struct SickOverlay: View {
    var body: some View {
        Circle()
            .fill(Color.green.opacity(0.1))
            .frame(width: 180, height: 160)
    }
}
