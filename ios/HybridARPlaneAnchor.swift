import ARKit
import NitroModules
import simd

final class HybridARPlaneGeometry: HybridARPlaneGeometrySpec {
    private let geometry: ARPlaneGeometry

    init(geometry: ARPlaneGeometry) {
        self.geometry = geometry
    }

    var vertices: [Double] {
        var result: [Double] = []
        result.reserveCapacity(geometry.vertices.count * 3)
        for vertex in geometry.vertices {
            result.append(Double(vertex.x))
            result.append(Double(vertex.y))
            result.append(Double(vertex.z))
        }
        return result
    }

    var textureCoordinates: [Double] {
        var result: [Double] = []
        result.reserveCapacity(geometry.textureCoordinates.count * 2)
        for coord in geometry.textureCoordinates {
            result.append(Double(coord.x))
            result.append(Double(coord.y))
        }
        return result
    }

    var triangleIndices: [Double] {
        geometry.triangleIndices.map { Double($0) }
    }

    var boundaryVertices: [Double] {
        var result: [Double] = []
        result.reserveCapacity(geometry.boundaryVertices.count * 2)
        for vertex in geometry.boundaryVertices {
            result.append(Double(vertex.x))
            result.append(Double(vertex.z))
        }
        return result
    }
}

final class HybridARPlaneAnchor: HybridARPlaneAnchorSpec {
    private let anchor: ARPlaneAnchor

    init(anchor: ARPlaneAnchor) {
        self.anchor = anchor
    }

    var identifier: String {
        anchor.identifier.uuidString
    }

    var position: [Double] {
        let t = anchor.transform
        return [
            Double(t.columns.3.x),
            Double(t.columns.3.y),
            Double(t.columns.3.z)
        ]
    }

    var rotation: [Double] {
        let q = simd_quatf(anchor.transform)
        return [
            Double(q.vector.x),
            Double(q.vector.y),
            Double(q.vector.z),
            Double(q.vector.w)
        ]
    }

    var alignment: PlaneAlignment {
        switch anchor.alignment {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        @unknown default: return .horizontal
        }
    }

    var classification: PlaneClassification {
        switch anchor.classification {
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

    var extent: [Double] {
        [Double(anchor.planeExtent.width), Double(anchor.planeExtent.height)]
    }

    var center: [Double] {
        [
            Double(anchor.center.x),
            Double(anchor.center.y),
            Double(anchor.center.z)
        ]
    }

    var geometry: HybridARPlaneGeometrySpec {
        HybridARPlaneGeometry(geometry: anchor.geometry)
    }
}
