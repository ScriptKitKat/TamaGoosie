# Accessories

3D items that render alongside the goose model in the SceneKit scene. Accessories attach to the goose at a defined anchor point and adjust position per mood/display state.

## Key Files

| File | Role |
|------|------|
| `TamaGoosie/Features/Goose/GooseAccessory.swift` | Accessory data model and catalog |
| `TamaGoosie/Features/Goose/Goose3DView.swift` | Loads accessory `.usdz` into the 3D scene |
| `TamaGoosie/Features/Goose/GooseAnimations.swift` | Passes accessories from `GooseCharacterView` to `Goose3DView` |
| `TamaGoosie/Features/Goose/GooseView.swift` | Reads `GooseState.hatID` and resolves it via `AccessoryCatalog` |
| `TamaGoosie/Resources/Models.scnassets/` | Where `.usdz` accessory files live |

## Adding a New Accessory

### Step 1: Add the 3D model

Drop the `.usdz` file into `TamaGoosie/Resources/Models.scnassets/`. Use the naming convention `acc_<id>.usdz` (e.g., `acc_crown.usdz`).

### Step 2: Add a catalog entry

Open `GooseAccessory.swift` and add a new entry to `AccessoryCatalog.all`:

```swift
GooseAccessory(
    id: "crown",                          // unique ID, stored in GooseState.hatID
    displayName: "Crown",                 // shown in UI
    modelName: "acc_crown",               // filename without .usdz
    anchor: .head,                        // .head, .neck, or .back
    price: 100,                           // coin cost in shop
    basePosition: SIMD3(0, 1.1, 0),       // (x, y, z) relative to goose center
    baseScale: SIMD3(repeating: 0.4),     // uniform scale
    baseRotation: .zero,                  // euler angles in radians
    moodOffsets: [                         // per-mood position adjustments
        .sleeping: SIMD3(0, -0.15, 0.1),
    ]
)
```

### Step 3: Equip it

Set `gooseState.hatID = "crown"` to equip. Set to `nil` to unequip.

## Coordinate System

The goose model is auto-centered and scaled to fit a 2.0-unit bounding box. Accessory positions are relative to the goose's centered origin:

```
        +Y (up)
         |
         |
         +--- +X (right, from camera POV)
        /
       +Z (toward camera)
```

- `basePosition` is the default attachment point. `(0, 1.1, 0)` is roughly the top of the goose's head.
- `baseScale` controls size. `SIMD3(repeating: 0.4)` means 40% of the accessory's original size.
- `baseRotation` is euler angles in radians. `.zero` means no rotation.

## Per-Mood Offsets

Each goose mood uses a different `.usdz` model, so the head/body position may shift slightly between moods. Use `moodOffsets` to compensate:

```swift
moodOffsets: [
    .sleeping: SIMD3(0, -0.15, 0.1),  // head lower and tilted forward
    .sad: SIMD3(0, -0.05, 0),          // head slightly drooped
]
```

The five display states are: `.normal`, `.happy`, `.sad`, `.sick`, `.sleeping`. Any state not in the dictionary uses `basePosition` as-is.

## Tuning Positions

### Using the debug double-tap

In `DEBUG` builds, double-tap the 3D view to print camera position/angles to the console. This helps orient yourself in the coordinate space.

### Quick iteration approach

1. Temporarily hardcode a `hatID` in `GooseState.init()` so the accessory always renders
2. Adjust `basePosition` values and rebuild
3. Cycle through moods using the debug state button (bottom-left in `GooseView`) to check each mood
4. Add `moodOffsets` for any mood where the accessory looks misaligned

## Anchors

`AccessoryAnchor` is metadata for future UI/shop categorization. It does not affect rendering — positioning is entirely controlled by `basePosition` + `moodOffsets`.

| Anchor | Typical Y range | Examples |
|--------|----------------|----------|
| `.head` | 0.9 - 1.3 | Hats, crowns, headbands |
| `.neck` | 0.2 - 0.5 | Bow ties, scarves, necklaces |
| `.back` | 0.4 - 0.8 | Capes, wings, backpacks |

## Data Flow

```
GooseState.hatID ("crown")
       |
       v
AccessoryCatalog.find("crown") -> GooseAccessory
       |
       v
GooseView passes [GooseAccessory] to GooseCharacterView
       |
       v
GooseCharacterView passes to Goose3DView
       |
       v
Goose3DView.loadAccessory() adds SCNNode to the scene
```

## Future Considerations

- **Multiple slots**: Currently only `hatID` is wired. To support multiple simultaneous accessories (hat + neck + back), add fields like `neckID` and `backID` to `GooseState` and collect all matches in `GooseView.equippedAccessories`.
- **Shop UI**: `AccessoryCatalog.all` already has `price` and `displayName` — iterate over it to build a shop view. `GooseState.coins` tracks the user's currency.
- **Animations**: Accessories inherit the idle bob animation from `scaleNode`. For accessory-specific motion (e.g., a cape fluttering), add `SCNAction` sequences in `loadAccessory()`.
- **Sync**: Accessories are not currently synced to Watch or Widget. To sync, add `hatID` to `GooseSyncPayload`.
