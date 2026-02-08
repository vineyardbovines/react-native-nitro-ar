import ARKit
import NitroModules
import simd

final class HybridARSession: HybridARSessionSpec {
    let session = ARSession()
    private var sessionDelegate: ARSessionDelegateImpl?
    private var anchorMap: [UUID: ARAnchor] = [:]

    private var frameCallback: ((any HybridARFrameSpec) -> Void)?
    private var trackingCallback: ((TrackingState, TrackingStateReason) -> Void)?
    private var anchorsCallback: (([any HybridARAnchorSpec], [any HybridARAnchorSpec], [String]) -> Void)?
    private var planesCallback: (([any HybridARPlaneAnchorSpec], [any HybridARPlaneAnchorSpec], [String]) -> Void)?
    private var meshCallback: (([any HybridARMeshAnchorSpec], [any HybridARMeshAnchorSpec], [String]) -> Void)?

    override init() {
        super.init()
        sessionDelegate = ARSessionDelegateImpl(session: self)
        session.delegate = sessionDelegate
    }

    func start(config: ARSessionConfiguration?) throws {
        let arConfig = ARWorldTrackingConfiguration()

        if let config = config {
            if let planes = config.planeDetection {
                var detection: ARWorldTrackingConfiguration.PlaneDetection = []
                for plane in planes {
                    switch plane {
                    case .horizontal: detection.insert(.horizontal)
                    case .vertical: detection.insert(.vertical)
                    }
                }
                arConfig.planeDetection = detection
            } else {
                arConfig.planeDetection = [.horizontal, .vertical]
            }

            arConfig.isLightEstimationEnabled = config.lightEstimation ?? true

            if #available(iOS 14.0, *) {
                // Scene depth
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                    if config.sceneDepth == true {
                        arConfig.frameSemantics.insert(.sceneDepth)
                    }
                    if config.smoothedSceneDepth == true {
                        arConfig.frameSemantics.insert(.smoothedSceneDepth)
                    }
                }

                // Scene reconstruction (LiDAR mesh)
                if let sceneRecon = config.sceneReconstruction {
                    switch sceneRecon {
                    case .mesh:
                        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                            arConfig.sceneReconstruction = .mesh
                        }
                    case .meshwithclassification:
                        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                            arConfig.sceneReconstruction = .meshWithClassification
                        }
                    case .none:
                        arConfig.sceneReconstruction = []
                    }
                }

                // People occlusion
                if config.peopleOcclusion == true {
                    if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
                        arConfig.frameSemantics.insert(.personSegmentationWithDepth)
                    }
                }

                // Object occlusion (requires scene reconstruction)
                if config.objectOcclusion == true {
                    // Object occlusion is enabled by having scene reconstruction active
                    // The app can use the mesh for occlusion in rendering
                }
            }

            if let envTex = config.environmentTexturing {
                switch envTex {
                case .manual: arConfig.environmentTexturing = .manual
                case .automatic: arConfig.environmentTexturing = .automatic
                case .none: arConfig.environmentTexturing = .none
                }
            }

            if let alignment = config.worldAlignment {
                switch alignment {
                case .gravity: arConfig.worldAlignment = .gravity
                case .gravityandheading: arConfig.worldAlignment = .gravityAndHeading
                case .camera: arConfig.worldAlignment = .camera
                }
            }

            if let mapData = config.initialWorldMap,
               let worldMap = HybridARWorldMap.fromData(mapData) {
                arConfig.initialWorldMap = worldMap
            }
        } else {
            arConfig.planeDetection = [.horizontal, .vertical]
            arConfig.isLightEstimationEnabled = true
        }

        session.run(arConfig)
    }

    func pause() throws {
        session.pause()
    }

    func reset() throws {
        let config = session.configuration ?? ARWorldTrackingConfiguration()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        anchorMap.removeAll()
    }

    var isRunning: Bool {
        session.currentFrame != nil
    }

    var trackingState: TrackingState {
        switch session.currentFrame?.camera.trackingState {
        case .normal: return .normal
        case .limited: return .limited
        default: return .notavailable
        }
    }

    var trackingStateReason: TrackingStateReason {
        guard case .limited(let reason) = session.currentFrame?.camera.trackingState else {
            return .none
        }
        switch reason {
        case .initializing: return .initializing
        case .excessiveMotion: return .excessivemotion
        case .insufficientFeatures: return .insufficientfeatures
        case .relocalizing: return .relocalizing
        @unknown default: return .none
        }
    }

    var worldMappingStatus: WorldMappingStatus {
        switch session.currentFrame?.worldMappingStatus {
        case .notAvailable: return .notavailable
        case .limited: return .limited
        case .extending: return .extending
        case .mapped: return .mapped
        default: return .notavailable
        }
    }

    func getCameraPose() throws -> CameraPose {
        guard let frame = session.currentFrame else {
            return CameraPose(
                position: [0, 0, 0],
                rotation: [0, 0, 0, 1]
            )
        }

        let t = frame.camera.transform
        let q = simd_quatf(t)

        return CameraPose(
            position: [
                Double(t.columns.3.x),
                Double(t.columns.3.y),
                Double(t.columns.3.z)
            ],
            rotation: [
                Double(q.vector.x),
                Double(q.vector.y),
                Double(q.vector.z),
                Double(q.vector.w)
            ]
        )
    }

    var currentFrame: (any HybridARFrameSpec)? {
        guard let frame = session.currentFrame else { return nil }
        return HybridARFrame(frame: frame)
    }

    func raycast(x: Double, y: Double) throws -> (any HybridARRaycastResultSpec)? {
        guard let frame = session.currentFrame else { return nil }

        let query = frame.raycastQuery(
            from: CGPoint(x: x, y: y),
            allowing: .estimatedPlane,
            alignment: .any
        )

        guard let result = session.raycast(query).first else {
            return nil
        }

        return HybridARRaycastResult(result: result)
    }

    func raycastWithQuery(query: RaycastQuery) throws -> [any HybridARRaycastResultSpec] {
        guard let frame = session.currentFrame else { return [] }

        let target: ARRaycastQuery.Target
        switch query.target {
        case .existingplanegeometry: target = .existingPlaneGeometry
        case .existingplaneinfinite: target = .existingPlaneInfinite
        case .estimatedplane: target = .estimatedPlane
        case .any: target = .estimatedPlane
        }

        let alignment: ARRaycastQuery.TargetAlignment
        switch query.alignment {
        case .horizontal: alignment = .horizontal
        case .vertical: alignment = .vertical
        case .any: alignment = .any
        }

        let arQuery = frame.raycastQuery(
            from: CGPoint(x: query.x, y: query.y),
            allowing: target,
            alignment: alignment
        )

        return session.raycast(arQuery).map { HybridARRaycastResult(result: $0) }
    }

    func createAnchor(hit: any HybridARRaycastResultSpec) throws -> any HybridARAnchorSpec {
        let result = hit as! HybridARRaycastResult
        let arAnchor = ARAnchor(transform: result.result.worldTransform)
        session.add(anchor: arAnchor)
        anchorMap[arAnchor.identifier] = arAnchor
        return HybridARAnchor(anchor: arAnchor, session: session)
    }

    func createAnchorAtPosition(
        position: [Double],
        rotation: [Double]?
    ) throws -> any HybridARAnchorSpec {
        var transform = matrix_identity_float4x4

        if let rot = rotation, rot.count == 4 {
            let quat = simd_quatf(
                ix: Float(rot[0]),
                iy: Float(rot[1]),
                iz: Float(rot[2]),
                r: Float(rot[3])
            )
            transform = simd_float4x4(quat)
        }

        transform.columns.3 = SIMD4(
            Float(position[0]),
            Float(position[1]),
            Float(position[2]),
            1
        )

        let arAnchor = ARAnchor(transform: transform)
        session.add(anchor: arAnchor)
        anchorMap[arAnchor.identifier] = arAnchor
        return HybridARAnchor(anchor: arAnchor, session: session)
    }

    func removeAnchor(anchor: any HybridARAnchorSpec) throws {
        let hybrid = anchor as! HybridARAnchor
        session.remove(anchor: hybrid.anchor)
        anchorMap.removeValue(forKey: hybrid.anchor.identifier)
    }

    var anchors: [any HybridARAnchorSpec] {
        session.currentFrame?.anchors
            .filter { anchor in
                !(anchor is ARPlaneAnchor) && !isMeshAnchor(anchor)
            }
            .map { HybridARAnchor(anchor: $0, session: session) } ?? []
    }

    private func isMeshAnchor(_ anchor: ARAnchor) -> Bool {
        if #available(iOS 13.4, *) {
            return anchor is ARMeshAnchor
        }
        return false
    }

    var planeAnchors: [any HybridARPlaneAnchorSpec] {
        session.currentFrame?.anchors
            .compactMap { $0 as? ARPlaneAnchor }
            .map { HybridARPlaneAnchor(anchor: $0) } ?? []
    }

    func createMeasurement(
        start: any HybridARAnchorSpec,
        end: any HybridARAnchorSpec
    ) throws -> any HybridARMeasurementSpec {
        HybridARMeasurement(
            start: start as! HybridARAnchor,
            end: end as! HybridARAnchor
        )
    }

    func getCurrentWorldMap() throws -> Promise<any HybridARWorldMapSpec> {
        return Promise.async {
            try await withCheckedThrowingContinuation { continuation in
                self.session.getCurrentWorldMap { worldMap, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let worldMap = worldMap {
                        continuation.resume(returning: HybridARWorldMap(worldMap: worldMap))
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "ARSession",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get world map"]
                        ))
                    }
                }
            }
        }
    }

    func onFrameUpdate(callback: @escaping (any HybridARFrameSpec) -> Void) throws -> () -> Void {
        frameCallback = callback
        return { [weak self] in
            self?.frameCallback = nil
        }
    }

    func onTrackingStateChanged(
        callback: @escaping (TrackingState, TrackingStateReason) -> Void
    ) throws -> () -> Void {
        trackingCallback = callback
        return { [weak self] in
            self?.trackingCallback = nil
        }
    }

    func onAnchorsUpdated(
        callback: @escaping ([any HybridARAnchorSpec], [any HybridARAnchorSpec], [String]) -> Void
    ) throws -> () -> Void {
        anchorsCallback = callback
        return { [weak self] in
            self?.anchorsCallback = nil
        }
    }

    func onPlanesUpdated(
        callback: @escaping ([any HybridARPlaneAnchorSpec], [any HybridARPlaneAnchorSpec], [String]) -> Void
    ) throws -> () -> Void {
        planesCallback = callback
        return { [weak self] in
            self?.planesCallback = nil
        }
    }

    // MARK: - LiDAR / Scene Mesh

    func getLiDARCapabilities() throws -> LiDARCapabilities {
        var isAvailable = false
        var supportsSceneReconstruction = false
        var supportsSceneDepth = false

        if #available(iOS 14.0, *) {
            supportsSceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
            supportsSceneDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
            isAvailable = supportsSceneReconstruction || supportsSceneDepth
        }

        return LiDARCapabilities(
            isAvailable: isAvailable,
            supportsSceneReconstruction: supportsSceneReconstruction,
            supportsSceneDepth: supportsSceneDepth
        )
    }

    var meshAnchors: [any HybridARMeshAnchorSpec] {
        guard #available(iOS 13.4, *) else { return [] }
        return session.currentFrame?.anchors
            .compactMap { $0 as? ARMeshAnchor }
            .map { HybridARMeshAnchor(anchor: $0) } ?? []
    }

    func onMeshUpdated(
        callback: @escaping ([any HybridARMeshAnchorSpec], [any HybridARMeshAnchorSpec], [String]) -> Void
    ) throws -> () -> Void {
        meshCallback = callback
        return { [weak self] in
            self?.meshCallback = nil
        }
    }

    // Called by delegate
    func handleFrameUpdate(_ frame: ARFrame) {
        frameCallback?(HybridARFrame(frame: frame))
    }

    func handleTrackingStateChange(_ state: TrackingState, _ reason: TrackingStateReason) {
        trackingCallback?(state, reason)
    }

    func handleAnchorsUpdate(
        added: [ARAnchor],
        updated: [ARAnchor],
        removed: [ARAnchor]
    ) {
        let addedHybrid = added
            .filter { !($0 is ARPlaneAnchor) && !isMeshAnchor($0) }
            .map { HybridARAnchor(anchor: $0, session: session) }
        let updatedHybrid = updated
            .filter { !($0 is ARPlaneAnchor) && !isMeshAnchor($0) }
            .map { HybridARAnchor(anchor: $0, session: session) }
        let removedIds = removed
            .filter { !($0 is ARPlaneAnchor) && !isMeshAnchor($0) }
            .map { $0.identifier.uuidString }

        if !addedHybrid.isEmpty || !updatedHybrid.isEmpty || !removedIds.isEmpty {
            anchorsCallback?(addedHybrid, updatedHybrid, removedIds)
        }

        let addedPlanes = added
            .compactMap { $0 as? ARPlaneAnchor }
            .map { HybridARPlaneAnchor(anchor: $0) }
        let updatedPlanes = updated
            .compactMap { $0 as? ARPlaneAnchor }
            .map { HybridARPlaneAnchor(anchor: $0) }
        let removedPlaneIds = removed
            .compactMap { $0 as? ARPlaneAnchor }
            .map { $0.identifier.uuidString }

        if !addedPlanes.isEmpty || !updatedPlanes.isEmpty || !removedPlaneIds.isEmpty {
            planesCallback?(addedPlanes, updatedPlanes, removedPlaneIds)
        }

        // Handle mesh anchors (iOS 13.4+)
        if #available(iOS 13.4, *) {
            let addedMeshes = added
                .compactMap { $0 as? ARMeshAnchor }
                .map { HybridARMeshAnchor(anchor: $0) }
            let updatedMeshes = updated
                .compactMap { $0 as? ARMeshAnchor }
                .map { HybridARMeshAnchor(anchor: $0) }
            let removedMeshIds = removed
                .compactMap { $0 as? ARMeshAnchor }
                .map { $0.identifier.uuidString }

            if !addedMeshes.isEmpty || !updatedMeshes.isEmpty || !removedMeshIds.isEmpty {
                meshCallback?(addedMeshes, updatedMeshes, removedMeshIds)
            }
        }
    }
}

// MARK: - ARSession Delegate

private class ARSessionDelegateImpl: NSObject, ARSessionDelegate {
    weak var hybridSession: HybridARSession?
    private var lastTrackingState: TrackingState = .notavailable

    init(session: HybridARSession) {
        self.hybridSession = session
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        hybridSession?.handleFrameUpdate(frame)

        let newState: TrackingState
        let reason: TrackingStateReason

        switch frame.camera.trackingState {
        case .normal:
            newState = .normal
            reason = .none
        case .limited(let r):
            newState = .limited
            switch r {
            case .initializing: reason = .initializing
            case .excessiveMotion: reason = .excessivemotion
            case .insufficientFeatures: reason = .insufficientfeatures
            case .relocalizing: reason = .relocalizing
            @unknown default: reason = .none
            }
        case .notAvailable:
            newState = .notavailable
            reason = .none
        }

        if newState != lastTrackingState {
            lastTrackingState = newState
            hybridSession?.handleTrackingStateChange(newState, reason)
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        hybridSession?.handleAnchorsUpdate(added: anchors, updated: [], removed: [])
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        hybridSession?.handleAnchorsUpdate(added: [], updated: anchors, removed: [])
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        hybridSession?.handleAnchorsUpdate(added: [], updated: [], removed: anchors)
    }
}
