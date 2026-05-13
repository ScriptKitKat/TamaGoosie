import SceneKit

// MARK: - Accessory Anchor

/// Where on the goose model the accessory attaches.
enum AccessoryAnchor: String, Codable, CaseIterable, Sendable {
    case head
    case back
    case neck
}

// MARK: - Accessory Definition

/// Static catalog entry describing a single accessory.
struct GooseAccessory: Identifiable, Sendable {
    let id: String            // matches GooseState.hatID
    let displayName: String
    let modelName: String     // .usdz filename without extension
    let anchor: AccessoryAnchor
    let price: Int

    /// Base position/scale; overridden per-mood if needed.
    let basePosition: SIMD3<Float>
    let baseScale: SIMD3<Float>
    let baseRotation: SIMD3<Float>  // euler angles in radians

    /// Per-mood overrides for position when the goose geometry differs.
    let moodOffsets: [GooseDisplayState: SIMD3<Float>]

    func position(for state: GooseDisplayState) -> SCNVector3 {
        let offset = moodOffsets[state] ?? .zero
        let pos = basePosition + offset
        return SCNVector3(pos.x, pos.y, pos.z)
    }

    var scnScale: SCNVector3 {
        SCNVector3(baseScale.x, baseScale.y, baseScale.z)
    }

    var scnRotation: SCNVector3 {
        SCNVector3(baseRotation.x, baseRotation.y, baseRotation.z)
    }
}

// MARK: - Accessory Catalog

enum AccessoryCatalog {
    /// All available accessories. Add new entries here.
    static let all: [GooseAccessory] = [
        // Example: Top hat — sits on top of the goose's head
        GooseAccessory(
            id: "tophat",
            displayName: "Top Hat",
            modelName: "acc_tophat",
            anchor: .head,
            price: 50,
            basePosition: SIMD3(0, 1.1, 0),
            baseScale: SIMD3(repeating: 0.4),
            baseRotation: .zero,
            moodOffsets: [
                .sleeping: SIMD3(0, -0.15, 0.1),
                .sad: SIMD3(0, -0.05, 0),
            ]
        ),
        // Example: Bow tie — around the goose's neck
        GooseAccessory(
            id: "bowtie",
            displayName: "Bow Tie",
            modelName: "acc_bowtie",
            anchor: .neck,
            price: 30,
            basePosition: SIMD3(0, 0.3, 0.4),
            baseScale: SIMD3(repeating: 0.3),
            baseRotation: .zero,
            moodOffsets: [:]
        ),
    ]

    /// Look up an accessory by its ID (matches GooseState.hatID).
    static func find(_ id: String) -> GooseAccessory? {
        all.first { $0.id == id }
    }
}
