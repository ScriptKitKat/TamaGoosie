import SwiftUI

struct StoreView: View {
    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))

                Text("Coming Soon")
                    .font(GoosieTheme.titleFont(20))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }
        }
    }
}
