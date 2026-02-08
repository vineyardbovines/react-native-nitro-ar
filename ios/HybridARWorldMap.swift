import ARKit
import NitroModules

final class HybridARWorldMap: HybridARWorldMapSpec {
    let worldMap: ARWorldMap

    init(worldMap: ARWorldMap) {
        self.worldMap = worldMap
    }

    var identifier: String {
        UUID().uuidString
    }

    var center: [Double] {
        let c = worldMap.center
        return [Double(c.x), Double(c.y), Double(c.z)]
    }

    var extent: [Double] {
        let e = worldMap.extent
        return [Double(e.x), Double(e.y), Double(e.z)]
    }

    var anchorCount: Double {
        Double(worldMap.anchors.count)
    }

    func getData() -> String {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: worldMap,
                requiringSecureCoding: true
            )
            return data.base64EncodedString()
        } catch {
            return ""
        }
    }

    static func fromData(_ base64String: String) -> ARWorldMap? {
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }

        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self,
                from: data
            )
        } catch {
            return nil
        }
    }
}
