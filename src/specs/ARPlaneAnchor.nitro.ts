import type { HybridObject } from "react-native-nitro-modules";

export type PlaneAlignment = "horizontal" | "vertical";
export type PlaneClassification =
  | "none"
  | "wall"
  | "floor"
  | "ceiling"
  | "table"
  | "seat"
  | "window"
  | "door";

export interface ARPlaneGeometry extends HybridObject<{ ios: "swift" }> {
  /** Vertices of the plane mesh (flattened [x,y,z, x,y,z, ...]) */
  readonly vertices: number[];

  /** Texture coordinates (flattened [u,v, u,v, ...]) */
  readonly textureCoordinates: number[];

  /** Triangle indices */
  readonly triangleIndices: number[];

  /** Boundary polygon vertices (flattened [x,z, x,z, ...] in local plane space) */
  readonly boundaryVertices: number[];
}

export interface ARPlaneAnchor extends HybridObject<{ ios: "swift" }> {
  readonly identifier: string;

  /** Position [x, y, z] */
  readonly position: number[];
  /** Rotation as quaternion [x, y, z, w] */
  readonly rotation: number[];

  readonly alignment: PlaneAlignment;
  readonly classification: PlaneClassification;

  /** Plane extent in meters [width, height] */
  readonly extent: number[];

  /** Center offset from anchor position [x, y, z] */
  readonly center: number[];

  readonly geometry: ARPlaneGeometry;
}
