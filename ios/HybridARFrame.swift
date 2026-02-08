import ARKit
import NitroModules
import simd

final class HybridARFrame: HybridARFrameSpec {
    private let frame: ARFrame

    init(frame: ARFrame) {
        self.frame = frame
    }

    var timestamp: Double {
        frame.timestamp
    }

    var cameraPosition: [Double] {
        let t = frame.camera.transform
        return [
            Double(t.columns.3.x),
            Double(t.columns.3.y),
            Double(t.columns.3.z)
        ]
    }

    var cameraRotation: [Double] {
        let q = simd_quatf(frame.camera.transform)
        return [
            Double(q.vector.x),
            Double(q.vector.y),
            Double(q.vector.z),
            Double(q.vector.w)
        ]
    }

    var projectionMatrix: [Double] {
        matrixToArray(frame.camera.projectionMatrix)
    }

    var viewMatrix: [Double] {
        matrixToArray(frame.camera.viewMatrix(for: .portrait))
    }

    var cameraIntrinsics: [Double] {
        let i = frame.camera.intrinsics
        return [
            Double(i.columns.0.x), // fx
            Double(i.columns.1.y), // fy
            Double(i.columns.2.x), // cx
            Double(i.columns.2.y)  // cy
        ]
    }

    var imageResolution: [Double] {
        let size = frame.camera.imageResolution
        return [Double(size.width), Double(size.height)]
    }

    var lightEstimate: HybridARLightEstimateSpec? {
        guard let estimate = frame.lightEstimate else {
            return nil
        }
        return HybridARLightEstimate(estimate: estimate)
    }

    var directionalLightEstimate: HybridARDirectionalLightEstimateSpec? {
        guard let estimate = frame.lightEstimate as? ARDirectionalLightEstimate else {
            return nil
        }
        return HybridARDirectionalLightEstimate(estimate: estimate)
    }

    var sceneDepth: HybridARDepthDataSpec? {
        if #available(iOS 14.0, *) {
            guard let depth = frame.sceneDepth else {
                return nil
            }
            return HybridARDepthData(depthData: depth)
        }
        return nil
    }

    var smoothedSceneDepth: HybridARDepthDataSpec? {
        if #available(iOS 14.0, *) {
            guard let depth = frame.smoothedSceneDepth else {
                return nil
            }
            return HybridARDepthData(depthData: depth)
        }
        return nil
    }

    func getCapturedImage(quality: Double) -> String {
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return ""
        }

        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: CGFloat(quality)) else {
            return ""
        }

        return jpegData.base64EncodedString()
    }

    private func matrixToArray(_ matrix: simd_float4x4) -> [Double] {
        [
            Double(matrix.columns.0.x), Double(matrix.columns.0.y),
            Double(matrix.columns.0.z), Double(matrix.columns.0.w),
            Double(matrix.columns.1.x), Double(matrix.columns.1.y),
            Double(matrix.columns.1.z), Double(matrix.columns.1.w),
            Double(matrix.columns.2.x), Double(matrix.columns.2.y),
            Double(matrix.columns.2.z), Double(matrix.columns.2.w),
            Double(matrix.columns.3.x), Double(matrix.columns.3.y),
            Double(matrix.columns.3.z), Double(matrix.columns.3.w)
        ]
    }
}
