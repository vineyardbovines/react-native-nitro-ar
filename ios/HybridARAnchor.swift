import ARKit
import NitroModules
import simd

final class HybridARAnchor: HybridARAnchorSpec {
    let anchor: ARAnchor
    weak var session: ARSession?

    init(anchor: ARAnchor, session: ARSession) {
        self.anchor = anchor
        self.session = session
    }

    var identifier: String {
        anchor.identifier.uuidString
    }

    var position: [Double] {
        let t = anchor.transform
        return [
            Double(t.columns.3.x),
            Double(t.columns.3.y),
            Double(t.columns.3.z)
        ]
    }

    var rotation: [Double] {
        let q = simd_quatf(anchor.transform)
        return [
            Double(q.vector.x),
            Double(q.vector.y),
            Double(q.vector.z),
            Double(q.vector.w)
        ]
    }

    var transform: [Double] {
        let t = anchor.transform
        return [
            Double(t.columns.0.x), Double(t.columns.0.y),
            Double(t.columns.0.z), Double(t.columns.0.w),
            Double(t.columns.1.x), Double(t.columns.1.y),
            Double(t.columns.1.z), Double(t.columns.1.w),
            Double(t.columns.2.x), Double(t.columns.2.y),
            Double(t.columns.2.z), Double(t.columns.2.w),
            Double(t.columns.3.x), Double(t.columns.3.y),
            Double(t.columns.3.z), Double(t.columns.3.w)
        ]
    }

    var isTracked: Bool {
        session?.currentFrame?.anchors.contains(anchor) ?? false
    }

    var label: String? {
        anchor.name
    }
}
