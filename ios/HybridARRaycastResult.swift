import ARKit
import NitroModules
import simd

final class HybridARRaycastResult: HybridARRaycastResultSpec {
    let result: ARRaycastResult

    init(result: ARRaycastResult) {
        self.result = result
    }

    var position: [Double] {
        let t = result.worldTransform
        return [
            Double(t.columns.3.x),
            Double(t.columns.3.y),
            Double(t.columns.3.z)
        ]
    }

    var rotation: [Double] {
        let q = simd_quatf(result.worldTransform)
        return [
            Double(q.vector.x),
            Double(q.vector.y),
            Double(q.vector.z),
            Double(q.vector.w)
        ]
    }

    var distance: Double {
        // Calculate distance from camera (origin) to hit point
        let pos = result.worldTransform.columns.3
        return Double(sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z))
    }

    var target: RaycastTarget {
        switch result.target {
        case .existingPlaneGeometry:
            return .existingplanegeometry
        case .existingPlaneInfinite:
            return .existingplaneinfinite
        case .estimatedPlane:
            return .estimatedplane
        @unknown default:
            return .any
        }
    }

    var anchorId: String? {
        result.anchor?.identifier.uuidString
    }
}
