import SwiftUI

struct OnboardingHatchView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    @State private var wobble: Double = 0
    @State private var cracking: Bool = false
    @State private var hatched: Bool = false
    @State private var showHint: Bool = true
    @State private var hintOpacity: Double = 1

    // Speckle positions (fixed to avoid random re-renders)
    private let speckles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (-28, -38, 5), (-6, -18, 7), (18, 18, 4), (-20, 12, 6), (10, -30, 5)
    ]

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Egg / hatch zone
                ZStack {
                    if !cracking && !hatched {
                        eggView
                            .rotationEffect(.degrees(wobble))
                            .onAppear {
                                withAnimation(
                                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                                ) { wobble = 3 }
                            }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }

                    if cracking && !hatched {
                        crackedEggView
                            .transition(.scale(scale: 1.04).combined(with: .opacity))
                    }

                    if hatched {
                        GooseCharacterView(mood: .happy)
                            .frame(height: 220)
                            .transition(
                                .scale(scale: 0.4)
                                .combined(with: .opacity)
                            )
                    }
                }
                .frame(height: 240)
                .contentShape(Rectangle())
                .onTapGesture { hatch() }
                .sensoryFeedback(.impact, trigger: hatched)
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: cracking)
                .animation(.spring(response: 0.5,  dampingFraction: 0.6),  value: hatched)

                // Hint label
                Text("tap to hatch")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .opacity(hintOpacity)
                    .padding(.top, 20)
                    .animation(.easeOut(duration: 0.35), value: hintOpacity)

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - Egg Drawing

    private var eggView: some View {
        ZStack {
            Ellipse()
                .fill(OBTheme.card)
                .frame(width: 130, height: 168)
                .overlay(Ellipse().stroke(OBTheme.border, lineWidth: 3))
                .shadow(color: OBTheme.border.opacity(0.6), radius: 14, y: 8)

            // Speckles
            ForEach(speckles.indices, id: \.self) { i in
                let s = speckles[i]
                Circle()
                    .fill(OBTheme.border.opacity(0.7))
                    .frame(width: s.size, height: s.size)
                    .offset(x: s.x, y: s.y)
            }
        }
    }

    private var crackedEggView: some View {
        ZStack {
            // Base egg
            Ellipse()
                .fill(OBTheme.card)
                .frame(width: 130, height: 168)
                .overlay(Ellipse().stroke(OBTheme.border, lineWidth: 3))
                .shadow(color: OBTheme.border.opacity(0.6), radius: 14, y: 8)
                .rotationEffect(.degrees(-4))

            // Crack lines
            Path { p in
                p.move(to:    CGPoint(x: 65,  y: 30))
                p.addLine(to: CGPoint(x: 80,  y: 50))
                p.addLine(to: CGPoint(x: 62,  y: 68))
                p.addLine(to: CGPoint(x: 77,  y: 90))
            }
            .stroke(OBTheme.secondary.opacity(0.55), lineWidth: 2.5)
            .frame(width: 130, height: 168)
        }
    }

    // MARK: - Hatch Sequence

    private func hatch() {
        guard !cracking, !hatched else { return }

        withAnimation(.easeOut(duration: 0.25)) { hintOpacity = 0 }

        cracking = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            cracking = false
            hatched = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.55) {
            onAdvance()
        }
    }
}
