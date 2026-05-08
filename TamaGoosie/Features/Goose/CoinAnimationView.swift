import SwiftUI
import AVFoundation

struct CoinAnimationView: View {
    let amount: Int
    var onComplete: () -> Void = {}

    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0.5

    var body: some View {
        Text("+\(amount)")
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundStyle(GoosieTheme.sunYellow)
            .shadow(color: GoosieTheme.warmOrange.opacity(0.4), radius: 4, y: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offsetY)
            .onAppear {
                CoinSoundPlayer.shared.play()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.2
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                    offsetY = -50
                }
                withAnimation(.easeIn(duration: 0.5).delay(1.0)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onComplete()
                }
            }
    }
}

// MARK: - Sound

final class CoinSoundPlayer {
    static let shared = CoinSoundPlayer()
    private var soundID: SystemSoundID = 0

    private init() {
        if let url = Bundle.main.url(forResource: "coin", withExtension: "caf") {
            AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        }
    }

    func play() {
        if soundID != 0 {
            AudioServicesPlaySystemSound(soundID)
        } else {
            // Fallback: system keyboard tap sound
            AudioServicesPlaySystemSound(1104)
        }
    }
}
