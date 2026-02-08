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
        let vertexSource = geo.vertices
        var result: [Double] = []
        result.reserveCapacity(vertexSource.count * 3)

        let buffer = vertexSource.buffer
        let stride = vertexSource.stride
        let offset = vertexSource.offset

        for i in 0..<vertexSource.count {
            let vertexPointer = buffer.contents().advanced(by: offset + stride * i)
            let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            result.append(Double(vertex.x))
            result.append(Double(vertex.y))
            result.append(Double(vertex.z))
        }
        return result
    }

    var faces: [Double] {
        let geo = anchor.geometry
        let faceElement = geo.faces
        var result: [Double] = []
        result.reserveCapacity(faceElement.count * 3)

        let buffer = faceElement.buffer
        let bytesPerIndex = faceElement.bytesPerIndex

        for i in 0..<faceElement.count {
            let facePointer = buffer.contents().advanced(by: bytesPerIndex * 3 * i)

            if bytesPerIndex == 4 {
                let indices = facePointer.assumingMemoryBound(to: UInt32.self)
                result.append(Double(indices[0]))
                result.append(Double(indices[1]))
                result.append(Double(indices[2]))
            } else if bytesPerIndex == 2 {
                let indices = facePointer.assumingMemoryBound(to: UInt16.self)
                result.append(Double(indices[0]))
                result.append(Double(indices[1]))
                result.append(Double(indices[2]))
            }
        }
        return result
    }

    var normals: [Double] {
        let geo = anchor.geometry
        let normalSource = geo.normals
        var result: [Double] = []
        result.reserveCapacity(normalSource.count * 3)

        let buffer = normalSource.buffer
        let stride = normalSource.stride
        let offset = normalSource.offset

        for i in 0..<normalSource.count {
            let normalPointer = buffer.contents().advanced(by: offset + stride * i)
            let normal = normalPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            result.append(Double(normal.x))
            result.append(Double(normal.y))
            result.append(Double(normal.z))
        }
        return result
    }

    var classifications: [MeshClassification] {
        let geo = anchor.geometry
        guard let classSource = geo.classification else {
            return []
        }

        var result: [MeshClassification] = []
        result.reserveCapacity(classSource.count)

        let buffer = classSource.buffer
        let stride = classSource.stride
        let offset = classSource.offset

        for i in 0..<classSource.count {
            let classPointer = buffer.contents().advanced(by: offset + stride * i)
            let classValue = classPointer.assumingMemoryBound(to: UInt8.self).pointee
            let arClass = ARMeshClassification(rawValue: Int(classValue)) ?? .none
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
