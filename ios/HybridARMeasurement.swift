import NitroModules
import simd

final class HybridARMeasurement: HybridARMeasurementSpec {
    let startAnchor: HybridARAnchor
    let endAnchor: HybridARAnchor

    init(
        start: HybridARAnchor,
        end: HybridARAnchor
    ) {
        self.startAnchor = start
        self.endAnchor = end
    }

    var start: HybridARAnchorSpec {
        startAnchor
    }

    var end: HybridARAnchorSpec {
        endAnchor
    }

    var length: Double {
        let a = startAnchor.anchor.transform.columns.3
        let b = endAnchor.anchor.transform.columns.3
        return Double(simd_distance(a, b))
    }

    var isValid: Bool {
        startAnchor.isTracked && endAnchor.isTracked
    }
}
