import SwiftUI

/// SwiftUI duck character drawn from SVG paths in the design mockup.
/// Body: cream ellipse. Eyes: dark dots. Beak + wings: coral.
struct DuckFaceView: View {
    var size: CGFloat = 40

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / 40

            // Body: ellipse cx=20 cy=22 rx=14 ry=13
            let body = Path(ellipseIn: CGRect(x: 6*s, y: 9*s, width: 28*s, height: 26*s))
            ctx.fill(body, with: .color(Color(hex: 0xFFF5E0)))

            // Left eye: circle cx=15 cy=17 r=1.5
            let lEye = Path(ellipseIn: CGRect(x: 13.5*s, y: 15.5*s, width: 3*s, height: 3*s))
            ctx.fill(lEye, with: .color(Color(hex: 0x4A3728)))

            // Right eye: circle cx=25 cy=17 r=1.5
            let rEye = Path(ellipseIn: CGRect(x: 23.5*s, y: 15.5*s, width: 3*s, height: 3*s))
            ctx.fill(rEye, with: .color(Color(hex: 0x4A3728)))

            // Beak: ellipse cx=20 cy=20 rx=4 ry=2.5
            let beak = Path(ellipseIn: CGRect(x: 16*s, y: 17.5*s, width: 8*s, height: 5*s))
            ctx.fill(beak, with: .color(Color(hex: 0xF4A683)))

            // Left wing: M10 28 Q6 35 12 34
            var lWing = Path()
            lWing.move(to: CGPoint(x: 10*s, y: 28*s))
            lWing.addQuadCurve(to: CGPoint(x: 12*s, y: 34*s), control: CGPoint(x: 6*s, y: 35*s))
            lWing.closeSubpath()
            ctx.fill(lWing, with: .color(Color(hex: 0xF4A683)))

            // Right wing: M30 28 Q34 35 28 34
            var rWing = Path()
            rWing.move(to: CGPoint(x: 30*s, y: 28*s))
            rWing.addQuadCurve(to: CGPoint(x: 28*s, y: 34*s), control: CGPoint(x: 34*s, y: 35*s))
            rWing.closeSubpath()
            ctx.fill(rWing, with: .color(Color(hex: 0xF4A683)))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    DuckFaceView(size: 80)
        .padding()
        .background(WatchTheme.creamWhite)
}
