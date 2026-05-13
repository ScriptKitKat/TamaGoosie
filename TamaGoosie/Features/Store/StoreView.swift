import SwiftUI

struct StoreView: View {
    var body: some View {
        ZStack {
            GrassyBackgroundView()

            VStack(spacing: 16) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))

                Text("Coming Soon")
                    .font(GoosieTheme.titleFont(20))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 52)
        }
    }
}
