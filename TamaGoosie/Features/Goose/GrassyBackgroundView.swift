import SwiftUI

struct GrassyBackgroundView: View {
    var body: some View {
        ZStack {
            // Base green gradient
            LinearGradient(
                colors: [
                    Color(hex: 0x8BC34A),
                    Color(hex: 0x7CB342),
                    Color(hex: 0x9CCC65),
                    Color(hex: 0x7CB342),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle radial highlight in center
            RadialGradient(
                colors: [
                    Color(hex: 0xA5D651).opacity(0.6),
                    Color.clear,
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )

            // Scattered decorations
            GrassDecorationsView()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Grass Decorations

private struct GrassDecorationsView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Dark grass patches (subtle shadows)
            ForEach(grassPatches, id: \.id) { patch in
                GrassTuft(width: patch.width, darkness: patch.darkness)
                    .position(x: patch.x * w, y: patch.y * h)
            }

            // Small flowers
            ForEach(flowers, id: \.id) { flower in
                FlowerDot(color: flower.color, size: flower.size)
                    .position(x: flower.x * w, y: flower.y * h)
            }

            // Grass blade clusters
            ForEach(grassBlades, id: \.id) { blade in
                GrassBladeCluster(height: blade.height)
                    .position(x: blade.x * w, y: blade.y * h)
            }
        }
    }

    // Stable layout data — positions are relative (0-1)

    private struct PatchData: Identifiable {
        let id: Int
        let x, y, width, darkness: CGFloat
    }

    private struct FlowerData: Identifiable {
        let id: Int
        let x, y, size: CGFloat
        let color: Color
    }

    private struct BladeData: Identifiable {
        let id: Int
        let x, y, height: CGFloat
    }

    private var grassPatches: [PatchData] {
        [
            PatchData(id: 0, x: 0.15, y: 0.12, width: 50, darkness: 0.08),
            PatchData(id: 1, x: 0.82, y: 0.25, width: 60, darkness: 0.06),
            PatchData(id: 2, x: 0.35, y: 0.45, width: 45, darkness: 0.05),
            PatchData(id: 3, x: 0.70, y: 0.60, width: 55, darkness: 0.07),
            PatchData(id: 4, x: 0.20, y: 0.75, width: 65, darkness: 0.06),
            PatchData(id: 5, x: 0.88, y: 0.80, width: 40, darkness: 0.05),
            PatchData(id: 6, x: 0.50, y: 0.90, width: 70, darkness: 0.08),
            PatchData(id: 7, x: 0.08, y: 0.50, width: 35, darkness: 0.04),
            PatchData(id: 8, x: 0.60, y: 0.15, width: 42, darkness: 0.05),
        ]
    }

    private var flowers: [FlowerData] {
        let flowerColors: [Color] = [
            Color(hex: 0xFFEB3B), // yellow
            Color(hex: 0xF48FB1), // pink
            Color(hex: 0xCE93D8), // purple
            Color(hex: 0xFFCC80), // peach
        ]
        return [
            FlowerData(id: 0, x: 0.12, y: 0.20, size: 8, color: flowerColors[0]),
            FlowerData(id: 1, x: 0.78, y: 0.35, size: 7, color: flowerColors[1]),
            FlowerData(id: 2, x: 0.25, y: 0.65, size: 6, color: flowerColors[0]),
            FlowerData(id: 3, x: 0.85, y: 0.70, size: 8, color: flowerColors[2]),
            FlowerData(id: 4, x: 0.55, y: 0.85, size: 7, color: flowerColors[3]),
            FlowerData(id: 5, x: 0.08, y: 0.88, size: 6, color: flowerColors[1]),
            FlowerData(id: 6, x: 0.92, y: 0.12, size: 7, color: flowerColors[0]),
            FlowerData(id: 7, x: 0.42, y: 0.10, size: 6, color: flowerColors[2]),
        ]
    }

    private var grassBlades: [BladeData] {
        [
            BladeData(id: 0, x: 0.10, y: 0.30, height: 18),
            BladeData(id: 1, x: 0.90, y: 0.18, height: 22),
            BladeData(id: 2, x: 0.30, y: 0.55, height: 16),
            BladeData(id: 3, x: 0.75, y: 0.50, height: 20),
            BladeData(id: 4, x: 0.18, y: 0.85, height: 24),
            BladeData(id: 5, x: 0.65, y: 0.78, height: 18),
            BladeData(id: 6, x: 0.50, y: 0.25, height: 15),
            BladeData(id: 7, x: 0.85, y: 0.92, height: 20),
            BladeData(id: 8, x: 0.05, y: 0.60, height: 16),
            BladeData(id: 9, x: 0.40, y: 0.92, height: 22),
        ]
    }
}

// MARK: - Grass Tuft (dark patch)

private struct GrassTuft: View {
    let width: CGFloat
    let darkness: CGFloat

    var body: some View {
        Ellipse()
            .fill(Color.black.opacity(darkness))
            .frame(width: width, height: width * 0.5)
            .blur(radius: 8)
    }
}

// MARK: - Flower Dot

private struct FlowerDot: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            // Petals
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(color.opacity(0.9))
                    .frame(width: size * 0.6, height: size)
                    .offset(y: -size * 0.4)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            // Center
            Circle()
                .fill(Color(hex: 0xFFF9C4))
                .frame(width: size * 0.45, height: size * 0.45)
        }
    }
}

// MARK: - Grass Blade Cluster

private struct GrassBladeCluster: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            GrassBlade(height: height, angle: -15)
            GrassBlade(height: height * 0.8, angle: 0)
            GrassBlade(height: height * 0.9, angle: 12)
        }
    }
}

private struct GrassBlade: View {
    let height: CGFloat
    let angle: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color(hex: 0x558B2F).opacity(0.5))
            .frame(width: 3, height: height)
            .rotationEffect(.degrees(angle), anchor: .bottom)
    }
}
