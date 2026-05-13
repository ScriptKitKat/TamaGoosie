import SwiftUI
import SceneKit

struct Goose3DView: UIViewRepresentable {
    var modelName: String = "goose_normal"
    var idleBob: Bool = true
    var accessories: [GooseAccessory] = []
    var displayState: GooseDisplayState = .normal

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X

        loadModel(into: scnView, context: context)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let currentModel = context.coordinator.currentModelName
        let currentAccessoryIDs = context.coordinator.currentAccessoryIDs
        let newAccessoryIDs = Set(accessories.map(\.id))

        if currentModel != modelName || currentAccessoryIDs != newAccessoryIDs {
            loadModel(into: uiView, context: context)
        }
    }

    private func loadModel(into scnView: SCNView, context: Context) {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "usdz", subdirectory: "Models.scnassets"),
              let scene = try? SCNScene(url: url, options: [.convertToYUp: true]) else {
            return
        }

        context.coordinator.currentModelName = modelName
        scnView.scene = scene

        let rootNode = scene.rootNode

        // Compute bounding box to center and scale the model
        let (minVec, maxVec) = rootNode.boundingBox
        let center = SCNVector3(
            (minVec.x + maxVec.x) / 2,
            (minVec.y + maxVec.y) / 2,
            (minVec.z + maxVec.z) / 2
        )
        let extentX = maxVec.x - minVec.x
        let extentY = maxVec.y - minVec.y
        let extentZ = maxVec.z - minVec.z
        let maxExtent = max(extentX, max(extentY, extentZ))

        // Wrap everything in a container node for centering + uniform scale
        let containerNode = SCNNode()
        for child in rootNode.childNodes {
            child.removeFromParentNode()
            containerNode.addChildNode(child)
        }
        containerNode.position = SCNVector3(-center.x, -center.y, -center.z)

        let scaleNode = SCNNode()
        let scaleFactor = 2.0 / Float(maxExtent)
        scaleNode.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        scaleNode.addChildNode(containerNode)
        rootNode.addChildNode(scaleNode)

        // Floor to receive shadow
        let floor = SCNFloor()
        floor.reflectivity = 0
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, Float(minVec.y) * scaleFactor - center.y * scaleFactor, 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.01)
        floorMaterial.lightingModel = .shadowOnly
        floor.firstMaterial = floorMaterial
        rootNode.addChildNode(floorNode)

        // Directional light for shadow
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.intensity = 1000
        lightNode.light?.castsShadow = true
        lightNode.light?.shadowRadius = 4
        lightNode.light?.shadowSampleCount = 8
        lightNode.light?.shadowColor = UIColor.black.withAlphaComponent(0.4)
        lightNode.light?.shadowMode = .forward
        lightNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        rootNode.addChildNode(lightNode)

        // Ambient fill light
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 500
        ambientNode.light?.color = UIColor.white
        rootNode.addChildNode(ambientNode)

        // Enable all model nodes to cast shadows
        scaleNode.enumerateChildNodes { node, _ in
            node.castsShadow = true
        }

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 38
        cameraNode.position = SCNVector3(3.5, 1.1048, 2.1641)
        cameraNode.eulerAngles = SCNVector3(-0.1833, 1.0165, 0)
        rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode

        // Gentle idle bob animation
        if idleBob {
            let bobUp = SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 1.0)
            bobUp.timingMode = .easeInEaseOut
            let bobDown = bobUp.reversed()
            let bobSequence = SCNAction.sequence([bobUp, bobDown])
            scaleNode.runAction(.repeatForever(bobSequence))
        }

        // Load accessories
        for accessory in accessories {
            loadAccessory(accessory, into: scaleNode, relativeTo: containerNode)
        }
        context.coordinator.currentAccessoryIDs = Set(accessories.map(\.id))

        // DEBUG: double-tap to print camera values
        #if DEBUG
        context.coordinator.scnView = scnView
        if scnView.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) != true {
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap))
            tap.numberOfTapsRequired = 2
            scnView.addGestureRecognizer(tap)
        }
        #endif
    }

    private func loadAccessory(_ accessory: GooseAccessory, into parent: SCNNode, relativeTo container: SCNNode) {
        guard let url = Bundle.main.url(forResource: accessory.modelName, withExtension: "usdz", subdirectory: "Models.scnassets"),
              let accScene = try? SCNScene(url: url, options: [.convertToYUp: true]) else {
            return
        }

        let accNode = SCNNode()
        accNode.name = "accessory_\(accessory.id)"
        for child in accScene.rootNode.childNodes {
            accNode.addChildNode(child.clone())
        }

        accNode.position = accessory.position(for: displayState)
        accNode.scale = accessory.scnScale
        accNode.eulerAngles = accessory.scnRotation

        accNode.enumerateChildNodes { node, _ in
            node.castsShadow = true
        }

        container.addChildNode(accNode)
    }

    class Coordinator: NSObject {
        var currentModelName: String = ""
        var currentAccessoryIDs: Set<String> = []
        weak var scnView: SCNView?

        @objc func handleDoubleTap() {
            guard let scnView, let pov = scnView.pointOfView else { return }
            let pos = pov.position
            let euler = pov.eulerAngles
            let fov = pov.camera?.fieldOfView ?? 0
            print("📷 Camera position: SCNVector3(\(pos.x), \(pos.y), \(pos.z))")
            print("📷 Camera eulerAngles: SCNVector3(\(euler.x), \(euler.y), \(euler.z))")
            print("📷 Camera fieldOfView: \(fov)")
        }
    }
}
