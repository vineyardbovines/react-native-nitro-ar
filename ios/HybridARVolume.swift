import NitroModules
import simd

final class HybridARVolume: HybridARVolumeSpec {
    let centerVec: SIMD3<Float>
    let w: Double
    let h: Double
    let d: Double
    let q: simd_quatf
    let stable: Bool

    init(
        center: SIMD3<Float>,
        width: Double,
        height: Double,
        depth: Double,
        rotation: simd_quatf,
        isStable: Bool
    ) {
        self.centerVec = center
        self.w = width
        self.h = height
        self.d = depth
        self.q = rotation
        self.stable = isStable
    }

    var center: [Double] {
        [
            Double(centerVec.x),
            Double(centerVec.y),
            Double(centerVec.z),
        ]
    }

    var width: Double { w }
    var height: Double { h }
    var depth: Double { d }

    var rotation: [Double] {
        [
            Double(q.vector.x),
            Double(q.vector.y),
            Double(q.vector.z),
            Double(q.vector.w),
        ]
    }

    var isStable: Bool {
        stable
    }
}
