import ARKit
import NitroModules

@available(iOS 13.4, *)
final class HybridARMeshAnchor: HybridARMeshAnchorSpec {
    let anchor: ARMeshAnchor

    init(anchor: ARMeshAnchor) {
        self.anchor = anchor
        super.init()
    }

    var identifier: String {
        anchor.identifier.uuidString
    }

    var transform: [Double] {
        let t = anchor.transform
        return [
            Double(t.columns.0.x), Double(t.columns.0.y), Double(t.columns.0.z), Double(t.columns.0.w),
            Double(t.columns.1.x), Double(t.columns.1.y), Double(t.columns.1.z), Double(t.columns.1.w),
            Double(t.columns.2.x), Double(t.columns.2.y), Double(t.columns.2.z), Double(t.columns.2.w),
            Double(t.columns.3.x), Double(t.columns.3.y), Double(t.columns.3.z), Double(t.columns.3.w)
        ]
    }

    var vertexCount: Double {
        Double(anchor.geometry.vertices.count)
    }

    var faceCount: Double {
        Double(anchor.geometry.faces.count)
    }

    var vertices: [Double] {
        let geo = anchor.geometry
        let vertexBuffer = geo.vertices
        var result: [Double] = []
        result.reserveCapacity(vertexBuffer.count * 3)

        for i in 0..<vertexBuffer.count {
            let vertex = vertexBuffer[i]
            result.append(Double(vertex.x))
            result.append(Double(vertex.y))
            result.append(Double(vertex.z))
        }
        return result
    }

    var faces: [Double] {
        let geo = anchor.geometry
        let faceBuffer = geo.faces
        var result: [Double] = []
        result.reserveCapacity(faceBuffer.count * 3)

        for i in 0..<faceBuffer.count {
            let indices = faceBuffer.vertexIndicesOf(faceWithIndex: i)
            result.append(Double(indices[0]))
            result.append(Double(indices[1]))
            result.append(Double(indices[2]))
        }
        return result
    }

    var normals: [Double] {
        let geo = anchor.geometry
        let normalBuffer = geo.normals
        var result: [Double] = []
        result.reserveCapacity(normalBuffer.count * 3)

        for i in 0..<normalBuffer.count {
            let normal = normalBuffer[i]
            result.append(Double(normal.x))
            result.append(Double(normal.y))
            result.append(Double(normal.z))
        }
        return result
    }

    var classifications: [MeshClassification] {
        let geo = anchor.geometry
        guard let classBuffer = geo.classification else {
            return []
        }

        var result: [MeshClassification] = []
        result.reserveCapacity(classBuffer.count)

        for i in 0..<classBuffer.count {
            let arClass = classBuffer[i]
            result.append(mapClassification(arClass))
        }
        return result
    }

    private func mapClassification(_ arClass: ARMeshClassification) -> MeshClassification {
        switch arClass {
        case .wall: return .wall
        case .floor: return .floor
        case .ceiling: return .ceiling
        case .table: return .table
        case .seat: return .seat
        case .window: return .window
        case .door: return .door
        default: return .none
        }
    }
}
