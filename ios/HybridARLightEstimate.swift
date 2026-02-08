import ARKit
import NitroModules

final class HybridARLightEstimate: HybridARLightEstimateSpec {
    private let estimate: ARLightEstimate

    init(estimate: ARLightEstimate) {
        self.estimate = estimate
    }

    var ambientIntensity: Double {
        Double(estimate.ambientIntensity)
    }

    var ambientColorTemperature: Double {
        Double(estimate.ambientColorTemperature)
    }
}

final class HybridARDirectionalLightEstimate: HybridARDirectionalLightEstimateSpec {
    private let estimate: ARDirectionalLightEstimate

    init(estimate: ARDirectionalLightEstimate) {
        self.estimate = estimate
    }

    var ambientIntensity: Double {
        Double(estimate.ambientIntensity)
    }

    var ambientColorTemperature: Double {
        Double(estimate.ambientColorTemperature)
    }

    var primaryLightDirection: [Double] {
        let dir = estimate.primaryLightDirection
        return [Double(dir.x), Double(dir.y), Double(dir.z)]
    }

    var primaryLightIntensity: Double {
        Double(estimate.primaryLightIntensity)
    }

    var sphericalHarmonicsCoefficients: [Double] {
        let data = estimate.sphericalHarmonicsCoefficients
        var result: [Double] = []
        result.reserveCapacity(27)

        data.withUnsafeBytes { buffer in
            let floats = buffer.bindMemory(to: Float.self)
            for i in 0..<min(27, floats.count) {
                result.append(Double(floats[i]))
            }
        }

        return result
    }
}
