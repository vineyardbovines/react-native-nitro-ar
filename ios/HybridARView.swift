import ARKit
import SceneKit
import UIKit
import NitroModules

class HybridARView: HybridARViewSpec {
    // The underlying AR view
    private lazy var arView: NitroARSceneView = {
        let view = NitroARSceneView(frame: .zero)
        view.onPlaneAdded = { [weak self] anchor, node in
            self?.handlePlaneAdded(anchor: anchor, node: node)
        }
        view.onPlaneUpdated = { [weak self] anchor, node in
            self?.handlePlaneUpdated(anchor: anchor, node: node)
        }
        view.onPlaneRemoved = { [weak self] anchor in
            self?.handlePlaneRemoved(anchor: anchor)
        }
        return view
    }()

    // MARK: - HybridView

    var view: UIView {
        return arView
    }

    // MARK: - Properties

    var showDebugOptions: Bool? {
        didSet {
            updateDebugOptions()
        }
    }

    var showPlanes: Bool? {
        didSet {
            arView.showPlaneOverlay = showPlanes ?? false
        }
    }

    var showFeaturePoints: Bool? {
        didSet {
            updateDebugOptions()
        }
    }

    var showWorldOrigin: Bool? {
        didSet {
            updateDebugOptions()
        }
    }

    var autoenablesDefaultLighting: Bool? {
        didSet {
            arView.autoenablesDefaultLighting = autoenablesDefaultLighting ?? true
        }
    }

    private func updateDebugOptions() {
        // Debug visualization options
        // Note: showFeaturePoints and showWorldOrigin are available in ARSCNDebugOptions
        #if !targetEnvironment(simulator)
        if showFeaturePoints == true || showDebugOptions == true || showWorldOrigin == true {
            // These debug options require device (not simulator)
            // Enable any available debug visualization
        }
        #endif
    }

    // MARK: - Measurement Point Methods

    func addMeasurementPoint(id: String, x: Double, y: Double, z: Double, color: String?) throws {
        let position = SCNVector3(Float(x), Float(y), Float(z))
        let uiColor = color.flatMap { UIColor(hex: $0) } ?? .systemYellow
        arView.addMeasurementPoint(id: id, position: position, color: uiColor)
    }

    func removeMeasurementPoint(id: String) throws {
        arView.removeMeasurementPoint(id: id)
    }

    func updateMeasurementPoint(id: String, x: Double, y: Double, z: Double) throws {
        let position = SCNVector3(Float(x), Float(y), Float(z))
        arView.updateMeasurementPoint(id: id, position: position)
    }

    // MARK: - Line Methods

    func addLine(id: String, fromX: Double, fromY: Double, fromZ: Double, toX: Double, toY: Double, toZ: Double, color: String?) throws {
        let from = SCNVector3(Float(fromX), Float(fromY), Float(fromZ))
        let to = SCNVector3(Float(toX), Float(toY), Float(toZ))
        let uiColor = color.flatMap { UIColor(hex: $0) } ?? .white
        arView.addLine(id: id, from: from, to: to, color: uiColor)
    }

    func updateLine(id: String, fromX: Double, fromY: Double, fromZ: Double, toX: Double, toY: Double, toZ: Double) throws {
        let from = SCNVector3(Float(fromX), Float(fromY), Float(fromZ))
        let to = SCNVector3(Float(toX), Float(toY), Float(toZ))
        arView.updateLine(id: id, from: from, to: to)
    }

    func removeLine(id: String) throws {
        arView.removeLine(id: id)
    }

    // MARK: - Distance Label Methods

    func addDistanceLabel(id: String, x: Double, y: Double, z: Double, distance: Double) throws {
        let position = SCNVector3(Float(x), Float(y), Float(z))
        arView.addDistanceLabel(id: id, position: position, distance: Float(distance))
    }

    func updateDistanceLabel(id: String, x: Double, y: Double, z: Double, distance: Double) throws {
        let position = SCNVector3(Float(x), Float(y), Float(z))
        arView.updateDistanceLabel(id: id, position: position, distance: Float(distance))
    }

    func removeDistanceLabel(id: String) throws {
        arView.removeDistanceLabel(id: id)
    }

    // MARK: - Clear All

    func clearAllVisuals() throws {
        arView.clearAllVisuals()
    }

    // MARK: - Raycast

    func raycast(x: Double, y: Double) throws -> ARViewHitResult? {
        // Convert normalized coordinates to view coordinates
        let viewPoint = CGPoint(
            x: CGFloat(x) * arView.bounds.width,
            y: CGFloat(y) * arView.bounds.height
        )

        guard let query = arView.raycastQuery(from: viewPoint, allowing: .estimatedPlane, alignment: .any) else {
            return nil
        }

        guard let result = arView.session.raycast(query).first else {
            return nil
        }

        let position = result.worldTransform.columns.3
        return ARViewHitResult(
            x: Double(position.x),
            y: Double(position.y),
            z: Double(position.z)
        )
    }

    // MARK: - Session Control

    func startSession() throws {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isLightEstimationEnabled = true

        if #available(iOS 16.0, *) {
            configuration.environmentTexturing = .automatic
        }

        arView.session.run(configuration)
    }

    func pauseSession() throws {
        arView.session.pause()
    }

    func resetSession() throws {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isLightEstimationEnabled = true

        if #available(iOS 16.0, *) {
            configuration.environmentTexturing = .automatic
        }

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        try? clearAllVisuals()
    }
}

// MARK: - Plane Delegate Handlers

extension HybridARView {
    func handlePlaneAdded(anchor: ARPlaneAnchor, node: SCNNode) {
        guard showPlanes == true else { return }
        arView.addPlaneNode(for: anchor, node: node)
    }

    func handlePlaneUpdated(anchor: ARPlaneAnchor, node: SCNNode) {
        guard showPlanes == true else { return }
        arView.updatePlaneNode(for: anchor, node: node)
    }

    func handlePlaneRemoved(anchor: ARPlaneAnchor) {
        arView.removePlaneNode(for: anchor.identifier)
    }
}

// MARK: - NitroARSceneView

class NitroARSceneView: ARSCNView, ARSCNViewDelegate {
    var showPlaneOverlay: Bool = false

    // Callbacks for plane events
    var onPlaneAdded: ((ARPlaneAnchor, SCNNode) -> Void)?
    var onPlaneUpdated: ((ARPlaneAnchor, SCNNode) -> Void)?
    var onPlaneRemoved: ((ARPlaneAnchor) -> Void)?

    private var measurementNodes: [String: SCNNode] = [:]
    private var lineNodes: [String: SCNNode] = [:]
    private var labelNodes: [String: SCNNode] = [:]
    private var planeNodes: [UUID: SCNNode] = [:]

    override init(frame: CGRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        autoenablesDefaultLighting = true
        automaticallyUpdatesLighting = true
        delegate = self
    }

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        onPlaneAdded?(planeAnchor, node)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        onPlaneUpdated?(planeAnchor, node)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        onPlaneRemoved?(planeAnchor)
    }

    // MARK: - Measurement Points

    func addMeasurementPoint(id: String, position: SCNVector3, color: UIColor) {
        measurementNodes[id]?.removeFromParentNode()

        let sphere = SCNSphere(radius: 0.008)
        sphere.firstMaterial?.diffuse.contents = color
        sphere.firstMaterial?.lightingModel = .constant
        sphere.firstMaterial?.isDoubleSided = true

        let node = SCNNode(geometry: sphere)
        node.position = position
        node.name = "measurement_\(id)"

        scene.rootNode.addChildNode(node)
        measurementNodes[id] = node
    }

    func removeMeasurementPoint(id: String) {
        measurementNodes[id]?.removeFromParentNode()
        measurementNodes.removeValue(forKey: id)
    }

    func updateMeasurementPoint(id: String, position: SCNVector3) {
        measurementNodes[id]?.position = position
    }

    // MARK: - Lines

    func addLine(id: String, from: SCNVector3, to: SCNVector3, color: UIColor) {
        lineNodes[id]?.removeFromParentNode()

        let lineNode = createLineNode(from: from, to: to, color: color)
        lineNode.name = "line_\(id)"

        scene.rootNode.addChildNode(lineNode)
        lineNodes[id] = lineNode
    }

    func updateLine(id: String, from: SCNVector3, to: SCNVector3) {
        lineNodes[id]?.removeFromParentNode()
        lineNodes.removeValue(forKey: id)
        addLine(id: id, from: from, to: to, color: .white)
    }

    func removeLine(id: String) {
        lineNodes[id]?.removeFromParentNode()
        lineNodes.removeValue(forKey: id)
    }

    private func createLineNode(from: SCNVector3, to: SCNVector3, color: UIColor) -> SCNNode {
        let distance = SCNVector3.distance(from, to)

        let cylinder = SCNCylinder(radius: 0.002, height: CGFloat(distance))
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.lightingModel = .constant

        let lineNode = SCNNode(geometry: cylinder)

        lineNode.position = SCNVector3(
            (from.x + to.x) / 2,
            (from.y + to.y) / 2,
            (from.z + to.z) / 2
        )

        lineNode.look(at: to, up: scene.rootNode.worldUp, localFront: SCNVector3(0, 1, 0))

        return lineNode
    }

    // MARK: - Labels

    func addDistanceLabel(id: String, position: SCNVector3, distance: Float) {
        labelNodes[id]?.removeFromParentNode()

        let text = formatDistance(distance)
        let labelNode = createLabelNode(text: text, position: position)
        labelNode.name = "label_\(id)"

        scene.rootNode.addChildNode(labelNode)
        labelNodes[id] = labelNode
    }

    func updateDistanceLabel(id: String, position: SCNVector3, distance: Float) {
        labelNodes[id]?.removeFromParentNode()
        labelNodes.removeValue(forKey: id)
        addDistanceLabel(id: id, position: position, distance: distance)
    }

    func removeDistanceLabel(id: String) {
        labelNodes[id]?.removeFromParentNode()
        labelNodes.removeValue(forKey: id)
    }

    private func createLabelNode(text: String, position: SCNVector3) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.1)
        textGeometry.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        textGeometry.firstMaterial?.lightingModel = .constant
        textGeometry.flatness = 0.1
        textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue

        let textNode = SCNNode(geometry: textGeometry)

        let scale: Float = 0.005
        textNode.scale = SCNVector3(scale, scale, scale)

        let (min, max) = textGeometry.boundingBox
        let width = max.x - min.x
        let height = max.y - min.y
        textNode.pivot = SCNMatrix4MakeTranslation(width / 2, height / 2, 0)

        let containerNode = SCNNode()
        containerNode.position = position
        containerNode.addChildNode(textNode)

        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .all
        containerNode.constraints = [billboardConstraint]

        let padding: Float = 0.005
        let bgWidth = CGFloat(width * scale + padding * 2)
        let bgHeight = CGFloat(height * scale + padding * 2)
        let background = SCNPlane(width: bgWidth, height: bgHeight)
        background.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.7)
        background.firstMaterial?.lightingModel = .constant
        background.cornerRadius = bgHeight / 4

        let bgNode = SCNNode(geometry: background)
        bgNode.position = SCNVector3(0, 0, -0.001)
        containerNode.addChildNode(bgNode)

        return containerNode
    }

    private func formatDistance(_ meters: Float) -> String {
        if meters < 0.01 {
            return String(format: "%.1f mm", meters * 1000)
        } else if meters < 1.0 {
            return String(format: "%.1f cm", meters * 100)
        } else {
            return String(format: "%.2f m", meters)
        }
    }

    // MARK: - Plane Visualization

    func addPlaneNode(for anchor: ARPlaneAnchor, node: SCNNode) {
        guard showPlaneOverlay else { return }

        let planeGeometry = SCNPlane(
            width: CGFloat(anchor.planeExtent.width),
            height: CGFloat(anchor.planeExtent.height)
        )

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.3)
        material.isDoubleSided = true
        planeGeometry.materials = [material]

        let planeNode = SCNNode(geometry: planeGeometry)
        planeNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        planeNode.eulerAngles.x = -.pi / 2

        node.addChildNode(planeNode)
        planeNodes[anchor.identifier] = planeNode
    }

    func updatePlaneNode(for anchor: ARPlaneAnchor, node: SCNNode) {
        guard let planeNode = planeNodes[anchor.identifier],
              let planeGeometry = planeNode.geometry as? SCNPlane else { return }

        planeGeometry.width = CGFloat(anchor.planeExtent.width)
        planeGeometry.height = CGFloat(anchor.planeExtent.height)
        planeNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
    }

    func removePlaneNode(for id: UUID) {
        planeNodes[id]?.removeFromParentNode()
        planeNodes.removeValue(forKey: id)
    }

    // MARK: - Clear All

    func clearAllVisuals() {
        for node in measurementNodes.values {
            node.removeFromParentNode()
        }
        measurementNodes.removeAll()

        for node in lineNodes.values {
            node.removeFromParentNode()
        }
        lineNodes.removeAll()

        for node in labelNodes.values {
            node.removeFromParentNode()
        }
        labelNodes.removeAll()
    }
}

// MARK: - SCNVector3 Extensions

extension SCNVector3 {
    static func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dz = b.z - a.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: CGFloat

        switch length {
        case 6: // RGB
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8: // RGBA
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
