import SwiftUI

// MARK: - Goose Character View

struct GooseCharacterView: View {
    let mood: GooseMood
    var showReaction: GooseReaction = .none

    @State private var bobOffset: CGFloat = 0
    @State private var isBlinking = false
    @State private var blinkTimer: Timer?
    @State private var reactionScale: CGFloat = 1.0
    @State private var wobbleAngle: Double = 0

    var body: some View {
        ZStack {
            gooseBody
                .offset(y: bobOffset)
                .rotationEffect(.degrees(wobbleAngle))
                .scaleEffect(reactionScale)

            faceOverlay
                .offset(y: bobOffset - 20)

            moodOverlay
                .offset(y: bobOffset)

            reactionOverlay
        }
        .onAppear { startIdleAnimation() }
        .onDisappear { blinkTimer?.invalidate() }
        .onChange(of: showReaction) { _, reaction in
            playReaction(reaction)
        }
    }

    // MARK: - Goose Body

    private var gooseBody: some View {
        ZStack {
            Ellipse()
                .fill(GoosieTheme.creamWhite)
                .frame(width: 160, height: 140)
                .overlay(
                    Ellipse()
                        .stroke(GoosieTheme.charcoalOutline, lineWidth: 3.5)
                )

            Ellipse()
                .fill(.white.opacity(0.4))
                .frame(width: 80, height: 60)
                .offset(y: 10)

            wing(flipped: false)
                .offset(x: -70, y: 10)

            wing(flipped: true)
                .offset(x: 70, y: 10)

            HStack(spacing: 30) {
                foot
                foot
            }
            .offset(y: 60)
        }
    }

    private func wing(flipped: Bool) -> some View {
        Ellipse()
            .fill(GoosieTheme.creamWhite)
            .frame(width: 35, height: 50)
            .overlay(
                Ellipse()
                    .stroke(GoosieTheme.charcoalOutline, lineWidth: 2.5)
            )
            .scaleEffect(x: flipped ? -1 : 1)
    }

    private var foot: some View {
        Ellipse()
            .fill(GoosieTheme.warmOrange)
            .frame(width: 28, height: 12)
            .overlay(
                Ellipse()
                    .stroke(GoosieTheme.charcoalOutline, lineWidth: 2)
            )
    }

    // MARK: - Face

    private var faceOverlay: some View {
        ZStack {
            HStack(spacing: 24) {
                eye
                eye
            }

            beak
                .offset(y: 16)

            if mood == .happy || mood == .ecstatic {
                HStack(spacing: 50) {
                    blushMark
                    blushMark
                }
                .offset(y: 8)
            }
        }
    }

    private var eye: some View {
        Group {
            if isBlinking || mood == .sick {
                Capsule()
                    .fill(GoosieTheme.charcoalOutline)
                    .frame(width: 10, height: 2.5)
            } else {
                Circle()
                    .fill(GoosieTheme.charcoalOutline)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var beak: some View {
        Ellipse()
            .fill(GoosieTheme.sunYellow)
            .frame(width: 20, height: 12)
            .overlay(
                Ellipse()
                    .stroke(GoosieTheme.charcoalOutline, lineWidth: 2)
            )
    }

    private var blushMark: some View {
        Circle()
            .fill(GoosieTheme.softPink)
            .frame(width: 14, height: 14)
            .opacity(0.7)
    }

    // MARK: - Mood Overlays

    @ViewBuilder
    private var moodOverlay: some View {
        switch mood {
        case .sad:
            SweatDrop()
                .offset(x: 50, y: -40)
        case .ecstatic:
            SparkleParticles()
                .offset(y: -80)
        case .sick:
            SickOverlay()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var reactionOverlay: some View {
        switch showReaction {
        case .goalComplete:
            SparkleParticles()
                .offset(y: -80)
        case .feed:
            EmptyView()
        default:
            EmptyView()
        }
    }

    // MARK: - Animations

    private func startIdleAnimation() {
        let duration: Double = mood == .sad ? 3.0 : 2.0
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            bobOffset = mood == .sad ? -3 : -8
        }

        scheduleNextBlink()
    }

    private func scheduleNextBlink() {
        let interval = Double.random(in: 3...6)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isBlinking = false
                }
                scheduleNextBlink()
            }
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

// MARK: - Reaction Type

enum GooseReaction: Equatable {
    case none
    case goalComplete
    case feed
}

// MARK: - Mood Overlay Components

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
