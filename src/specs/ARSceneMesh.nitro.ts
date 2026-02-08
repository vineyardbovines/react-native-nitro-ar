import type { HybridObject } from "react-native-nitro-modules";

/** Classification of mesh faces */
export type MeshClassification =
  | "none"
  | "wall"
  | "floor"
  | "ceiling"
  | "table"
  | "seat"
  | "window"
  | "door";

/** A single mesh anchor from scene reconstruction */
export interface ARMeshAnchor extends HybridObject<{ ios: "swift" }> {
  /** Unique identifier */
  readonly identifier: string;

  /** Transform matrix (4x4, column-major) */
  readonly transform: number[];

  /** Number of vertices */
  readonly vertexCount: number;

  /** Number of faces (triangles) */
  readonly faceCount: number;

  /**
   * Vertex positions as flat array [x1,y1,z1, x2,y2,z2, ...]
   * Positions are in local anchor space
   */
  readonly vertices: number[];

  /**
   * Face indices as flat array [a1,b1,c1, a2,b2,c2, ...]
   * Each triplet defines a triangle
   */
  readonly faces: number[];

  /**
   * Vertex normals as flat array [nx1,ny1,nz1, ...]
   */
  readonly normals: number[];

  /**
   * Classification for each face (if available)
   * Only populated when sceneReconstruction includes classification
   */
  readonly classifications: MeshClassification[];
}

/** Scene reconstruction mode */
export type SceneReconstructionMode = "none" | "mesh" | "meshWithClassification";

/** LiDAR capabilities info */
export interface LiDARCapabilities {
  /** Device has LiDAR sensor */
  readonly isAvailable: boolean;
  /** Scene reconstruction is supported */
  readonly supportsSceneReconstruction: boolean;
  /** Scene depth is supported */
  readonly supportsSceneDepth: boolean;
}
