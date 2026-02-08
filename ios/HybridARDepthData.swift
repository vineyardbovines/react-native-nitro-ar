import ARKit
import NitroModules

@available(iOS 14.0, *)
final class HybridARDepthData: HybridARDepthDataSpec {
    private let depthData: ARDepthData

    init(depthData: ARDepthData) {
        self.depthData = depthData
    }

    var width: Double {
        Double(CVPixelBufferGetWidth(depthData.depthMap))
    }

    var height: Double {
        Double(CVPixelBufferGetHeight(depthData.depthMap))
    }

    var depthMap: [Double] {
        extractFloatBuffer(depthData.depthMap)
    }

    var confidenceMap: [Double] {
        guard let confidence = depthData.confidenceMap else {
            return []
        }
        return extractUInt8Buffer(confidence)
    }

    func getDepthAt(x: Double, y: Double) -> Double {
        let buffer = depthData.depthMap
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)

        let px = Int(x * Double(w - 1))
        let py = Int(y * Double(h - 1))

        guard px >= 0, px < w, py >= 0, py < h else {
            return 0
        }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return 0
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let index = py * (bytesPerRow / MemoryLayout<Float32>.size) + px

        return Double(floatBuffer[index])
    }

    func getConfidenceAt(x: Double, y: Double) -> Double {
        guard let confidence = depthData.confidenceMap else {
            return 0
        }

        let w = CVPixelBufferGetWidth(confidence)
        let h = CVPixelBufferGetHeight(confidence)

        let px = Int(x * Double(w - 1))
        let py = Int(y * Double(h - 1))

        guard px >= 0, px < w, py >= 0, py < h else {
            return 0
        }

        CVPixelBufferLockBaseAddress(confidence, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(confidence) else {
            return 0
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(confidence)
        let uint8Buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let index = py * bytesPerRow + px

        return Double(uint8Buffer[index])
    }

    private func extractFloatBuffer(_ buffer: CVPixelBuffer) -> [Double] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return []
        }

        var result: [Double] = []
        result.reserveCapacity(w * h)

        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let stride = bytesPerRow / MemoryLayout<Float32>.size

        for y in 0..<h {
            for x in 0..<w {
                result.append(Double(floatBuffer[y * stride + x]))
            }
        }

        return result
    }

    private func extractUInt8Buffer(_ buffer: CVPixelBuffer) -> [Double] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return []
        }

        var result: [Double] = []
        result.reserveCapacity(w * h)

        let uint8Buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in 0..<h {
            for x in 0..<w {
                result.append(Double(uint8Buffer[y * bytesPerRow + x]))
            }
        }

        return result
    }
}
