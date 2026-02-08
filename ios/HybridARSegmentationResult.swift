import ARKit
import CoreImage
import NitroModules
import Vision

@available(iOS 17.0, *)
final class HybridARSegmentationResult: HybridARSegmentationResultSpec {
    let mask: VNInstanceMaskObservation
    let selectedIndex: Int
    let frame: ARFrame
    weak var sceneView: ARSCNView?

    private var _boundingBox: [Double] = []
    private var _maskPixelCount: Double = 0
    private var cachedDepthPoints: [Double]?

    init(mask: VNInstanceMaskObservation, selectedIndex: Int, frame: ARFrame, sceneView: ARSCNView?) {
        self.mask = mask
        self.selectedIndex = selectedIndex
        self.frame = frame
        self.sceneView = sceneView
        super.init()

        // Calculate bounding box and pixel count
        calculateMaskMetrics()
    }

    var success: Bool {
        true
    }

    var boundingBox: [Double] {
        _boundingBox
    }

    var maskPixelCount: Double {
        _maskPixelCount
    }

    private func calculateMaskMetrics() {
        guard let maskBuffer = try? mask.generateScaledMaskForImage(
            forInstances: IndexSet(integer: selectedIndex),
            from: VNImageRequestHandler(cvPixelBuffer: frame.capturedImage)
        ) else {
            _boundingBox = [0, 0, 1, 1]
            _maskPixelCount = 0
            return
        }

        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else {
            _boundingBox = [0, 0, 1, 1]
            _maskPixelCount = 0
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var pixelCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let pixelValue = buffer[y * bytesPerRow + x]
                if pixelValue > 127 {
                    pixelCount += 1
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }

        if pixelCount > 0 {
            _boundingBox = [
                Double(minX) / Double(width),
                Double(minY) / Double(height),
                Double(maxX - minX) / Double(width),
                Double(maxY - minY) / Double(height)
            ]
        } else {
            _boundingBox = [0, 0, 1, 1]
        }
        _maskPixelCount = Double(pixelCount)
    }

    func getDepthPoints() throws -> [Double] {
        if let cached = cachedDepthPoints {
            print("[GetDepthPoints] Returning cached \(cached.count / 3) points")
            return cached
        }

        guard let sceneDepth = frame.sceneDepth else {
            print("[GetDepthPoints] No sceneDepth available (LiDAR required)")
            return []
        }

        print("[GetDepthPoints] Scene depth available, extracting points...")
        print("[GetDepthPoints] Camera image: \(CVPixelBufferGetWidth(frame.capturedImage))x\(CVPixelBufferGetHeight(frame.capturedImage))")

        guard let maskBuffer = try? mask.generateScaledMaskForImage(
            forInstances: IndexSet(integer: selectedIndex),
            from: VNImageRequestHandler(cvPixelBuffer: frame.capturedImage)
        ) else {
            return []
        }

        let depthMap = sceneDepth.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly)
        }

        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        let maskWidth = CVPixelBufferGetWidth(maskBuffer)
        let maskHeight = CVPixelBufferGetHeight(maskBuffer)

        print("[GetDepthPoints] Depth buffer: \(depthWidth)x\(depthHeight), Mask: \(maskWidth)x\(maskHeight)")

        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap),
              let maskBase = CVPixelBufferGetBaseAddress(maskBuffer) else {
            return []
        }

        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let depthBuffer = depthBase.assumingMemoryBound(to: Float32.self)
        let maskBufferPtr = maskBase.assumingMemoryBound(to: UInt8.self)

        // Get camera image dimensions for coordinate scaling
        let imageWidth = CVPixelBufferGetWidth(frame.capturedImage)
        let imageHeight = CVPixelBufferGetHeight(frame.capturedImage)

        // Intrinsics are in camera image coordinate space
        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]

        var points: [Double] = []
        points.reserveCapacity(Int(_maskPixelCount) * 3)

        // Sample points from the mask
        let stepSize = max(1, Int(sqrt(_maskPixelCount / 1000))) // Limit to ~1000 points

        for maskY in stride(from: 0, to: maskHeight, by: stepSize) {
            for maskX in stride(from: 0, to: maskWidth, by: stepSize) {
                let maskValue = maskBufferPtr[maskY * maskBytesPerRow + maskX]
                guard maskValue > 127 else { continue }

                // Map mask coordinates to depth coordinates
                let depthX = maskX * depthWidth / maskWidth
                let depthY = maskY * depthHeight / maskHeight

                guard depthX < depthWidth, depthY < depthHeight else { continue }

                let depthIndex = depthY * depthBytesPerRow / MemoryLayout<Float32>.stride + depthX
                let depth = depthBuffer[depthIndex]

                guard depth > 0, depth < 10 else { continue } // Valid depth range

                // Scale depth coordinates to camera image space for use with intrinsics
                let imageX = Float(depthX) * Float(imageWidth) / Float(depthWidth)
                let imageY = Float(depthY) * Float(imageHeight) / Float(depthHeight)

                // Convert to 3D point in camera space using properly scaled coordinates
                let x = Double((imageX - cx) * depth / fx)
                let y = Double((imageY - cy) * depth / fy)
                let z = Double(depth)

                // Transform to world space
                let cameraTransform = frame.camera.transform
                let worldPoint = simd_mul(cameraTransform, simd_float4(Float(x), Float(-y), Float(-z), 1))

                points.append(Double(worldPoint.x))
                points.append(Double(worldPoint.y))
                points.append(Double(worldPoint.z))
            }
        }

        print("[GetDepthPoints] Extracted \(points.count / 3) 3D points from depth data")

        // Log point cloud bounds for debugging
        if points.count >= 3 {
            var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
            var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
            var minZ = Double.greatestFiniteMagnitude, maxZ = -Double.greatestFiniteMagnitude
            for i in stride(from: 0, to: points.count, by: 3) {
                minX = min(minX, points[i]); maxX = max(maxX, points[i])
                minY = min(minY, points[i+1]); maxY = max(maxY, points[i+1])
                minZ = min(minZ, points[i+2]); maxZ = max(maxZ, points[i+2])
            }
            print("[GetDepthPoints] Point cloud bounds: X[\(minX)...\(maxX)], Y[\(minY)...\(maxY)], Z[\(minZ)...\(maxZ)]")
            print("[GetDepthPoints] Extents: X=\(maxX-minX)m, Y=\(maxY-minY)m, Z=\(maxZ-minZ)m")
        }

        cachedDepthPoints = points
        return points
    }

    func measure() throws -> ARObjectMeasurement? {
        let points = try getDepthPoints()
        guard points.count >= 12 else { return nil } // Need at least 4 points

        // Use PCA to compute oriented bounding box
        let pointCount = points.count / 3
        var sumX = 0.0, sumY = 0.0, sumZ = 0.0

        // Calculate centroid
        for i in 0..<pointCount {
            sumX += points[i * 3]
            sumY += points[i * 3 + 1]
            sumZ += points[i * 3 + 2]
        }
        let centerX = sumX / Double(pointCount)
        let centerY = sumY / Double(pointCount)
        let centerZ = sumZ / Double(pointCount)

        // Build covariance matrix
        var cov = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
        for i in 0..<pointCount {
            let dx = points[i * 3] - centerX
            let dy = points[i * 3 + 1] - centerY
            let dz = points[i * 3 + 2] - centerZ

            cov[0][0] += dx * dx
            cov[0][1] += dx * dy
            cov[0][2] += dx * dz
            cov[1][1] += dy * dy
            cov[1][2] += dy * dz
            cov[2][2] += dz * dz
        }
        cov[1][0] = cov[0][1]
        cov[2][0] = cov[0][2]
        cov[2][1] = cov[1][2]

        // Simple eigenvalue estimation using power iteration
        let (axes, eigenvalues) = computeEigenvectors(cov)

        // Project points onto principal axes to find extents
        var minProj = [Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude]
        var maxProj = [-Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude]

        for i in 0..<pointCount {
            let dx = points[i * 3] - centerX
            let dy = points[i * 3 + 1] - centerY
            let dz = points[i * 3 + 2] - centerZ

            for a in 0..<3 {
                let proj = dx * axes[a][0] + dy * axes[a][1] + dz * axes[a][2]
                minProj[a] = min(minProj[a], proj)
                maxProj[a] = max(maxProj[a], proj)
            }
        }

        // Calculate dimensions (sorted: width >= height >= depth)
        var dims = [
            maxProj[0] - minProj[0],
            maxProj[1] - minProj[1],
            maxProj[2] - minProj[2]
        ].sorted(by: >)

        // Flatten axes for output
        let flatAxes = axes.flatMap { $0 }

        // Confidence based on point density and spread
        let totalVariance = eigenvalues.reduce(0, +)
        let confidence = min(1.0, Double(pointCount) / 500.0) * min(1.0, totalVariance / 0.1)

        return ARObjectMeasurement(
            width: dims[0],
            height: dims[1],
            depth: dims[2],
            center: [centerX, centerY, centerZ],
            axes: flatAxes,
            confidence: confidence,
            pointCount: Double(pointCount)
        )
    }

    private func computeEigenvectors(_ matrix: [[Double]]) -> ([[Double]], [Double]) {
        // Simplified power iteration for 3x3 symmetric matrix
        var vectors: [[Double]] = [
            [1, 0, 0],
            [0, 1, 0],
            [0, 0, 1]
        ]
        var eigenvalues = [0.0, 0.0, 0.0]

        for i in 0..<3 {
            var v = vectors[i]

            // Power iteration
            for _ in 0..<20 {
                var newV = [0.0, 0.0, 0.0]
                for row in 0..<3 {
                    for col in 0..<3 {
                        newV[row] += matrix[row][col] * v[col]
                    }
                }

                // Orthogonalize against previous vectors
                for j in 0..<i {
                    let dot = newV[0] * vectors[j][0] + newV[1] * vectors[j][1] + newV[2] * vectors[j][2]
                    newV[0] -= dot * vectors[j][0]
                    newV[1] -= dot * vectors[j][1]
                    newV[2] -= dot * vectors[j][2]
                }

                // Normalize
                let len = sqrt(newV[0] * newV[0] + newV[1] * newV[1] + newV[2] * newV[2])
                if len > 1e-10 {
                    v = [newV[0] / len, newV[1] / len, newV[2] / len]
                }
            }

            vectors[i] = v

            // Calculate eigenvalue
            var av = [0.0, 0.0, 0.0]
            for row in 0..<3 {
                for col in 0..<3 {
                    av[row] += matrix[row][col] * v[col]
                }
            }
            eigenvalues[i] = av[0] * v[0] + av[1] * v[1] + av[2] * v[2]
        }

        return (vectors, eigenvalues)
    }
}
