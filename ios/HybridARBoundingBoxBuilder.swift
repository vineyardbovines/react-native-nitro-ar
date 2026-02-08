import NitroModules
import simd
import Accelerate

final class HybridARBoundingBoxBuilder: HybridARBoundingBoxBuilderSpec {

    private var anchors: [HybridARAnchor] = []

    func addBaseAnchor(
        anchor: HybridARAnchorSpec
    ) {
        anchors.append(anchor as! HybridARAnchor)
    }

    var canBuild: Bool {
        anchors.count >= 4
    }

    func build() -> HybridARVolumeSpec {
        let positions = anchors.map {
            SIMD3(
                $0.anchor.transform.columns.3.x,
                $0.anchor.transform.columns.3.y,
                $0.anchor.transform.columns.3.z
            )
        }

        // Compute centroid
        let centroid = positions.reduce(SIMD3<Float>.zero, +) / Float(positions.count)

        // Center the points
        let centered = positions.map { $0 - centroid }

        // Build covariance matrix
        var cov = simd_float3x3(0)
        for p in centered {
            cov += simd_float3x3(
                SIMD3(p.x * p.x, p.x * p.y, p.x * p.z),
                SIMD3(p.y * p.x, p.y * p.y, p.y * p.z),
                SIMD3(p.z * p.x, p.z * p.y, p.z * p.z)
            )
        }
        cov = cov * (1.0 / Float(positions.count))

        // Compute eigenvectors using power iteration for principal axes
        let (eigenvectors, isStable) = computeEigenvectors(cov)

        // Build rotation matrix from eigenvectors (columns are the principal axes)
        let rotationMatrix = simd_float3x3(
            eigenvectors.0,
            eigenvectors.1,
            eigenvectors.2
        )

        // Ensure right-handed coordinate system
        let det = simd_determinant(rotationMatrix)
        let correctedMatrix: simd_float3x3
        if det < 0 {
            correctedMatrix = simd_float3x3(
                eigenvectors.0,
                eigenvectors.1,
                -eigenvectors.2
            )
        } else {
            correctedMatrix = rotationMatrix
        }

        // Transform points to OBB space
        let inverseRotation = correctedMatrix.transpose
        let rotatedPoints = centered.map { inverseRotation * $0 }

        // Find AABB in OBB space
        let minBounds = rotatedPoints.reduce(rotatedPoints[0], simd_min)
        let maxBounds = rotatedPoints.reduce(rotatedPoints[0], simd_max)

        let size = maxBounds - minBounds
        let localCenter = (minBounds + maxBounds) / 2

        // Transform center back to world space
        let worldCenter = correctedMatrix * localCenter + centroid

        // Convert rotation matrix to quaternion
        let rotation = simd_quatf(correctedMatrix)

        return HybridARVolume(
            center: worldCenter,
            width: Double(size.x),
            height: Double(size.y),
            depth: Double(size.z),
            rotation: rotation,
            isStable: isStable
        )
    }

    private func computeEigenvectors(
        _ matrix: simd_float3x3
    ) -> ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>), Bool) {
        // Power iteration to find dominant eigenvector
        var v1 = normalize(SIMD3<Float>(1, 0, 0))
        var stable = true

        for _ in 0..<50 {
            let next = normalize(matrix * v1)
            if simd_length(next - v1) < 1e-6 {
                break
            }
            v1 = next
        }

        // Deflate matrix and find second eigenvector
        let lambda1 = simd_dot(v1, matrix * v1)
        let deflated1 = matrix - lambda1 * simd_float3x3(
            SIMD3(v1.x * v1.x, v1.x * v1.y, v1.x * v1.z),
            SIMD3(v1.y * v1.x, v1.y * v1.y, v1.y * v1.z),
            SIMD3(v1.z * v1.x, v1.z * v1.y, v1.z * v1.z)
        )

        var v2 = normalize(SIMD3<Float>(0, 1, 0))
        // Ensure v2 is orthogonal to v1
        v2 = normalize(v2 - simd_dot(v2, v1) * v1)

        for _ in 0..<50 {
            var next = deflated1 * v2
            next = next - simd_dot(next, v1) * v1  // Gram-Schmidt
            let len = simd_length(next)
            if len < 1e-6 {
                stable = false
                break
            }
            next = next / len
            if simd_length(next - v2) < 1e-6 {
                break
            }
            v2 = next
        }

        // Third eigenvector is cross product (orthogonal to both)
        let v3 = normalize(simd_cross(v1, v2))

        return ((v1, v2, v3), stable)
    }
}
