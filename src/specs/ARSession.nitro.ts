import type { HybridObject } from "react-native-nitro-modules";
import type { ARRaycastResult, RaycastQuery } from "./ARRaycastResult.nitro";
import type { ARAnchor } from "./ARAnchor.nitro";
import type { ARMeasurement } from "./ARMeasurement.nitro";
import type { ARPlaneAnchor } from "./ARPlaneAnchor.nitro";
import type { ARFrame } from "./ARFrame.nitro";
import type { ARWorldMap, WorldMappingStatus } from "./ARWorldMap.nitro";
import type {
  ARMeshAnchor,
  SceneReconstructionMode,
  LiDARCapabilities,
} from "./ARSceneMesh.nitro";

export interface CameraPose {
  /** Position [x, y, z] */
  position: number[];
  /** Rotation as quaternion [x, y, z, w] */
  rotation: number[];
}

export type TrackingState = "notAvailable" | "limited" | "normal";

export type TrackingStateReason =
  | "none"
  | "initializing"
  | "excessiveMotion"
  | "insufficientFeatures"
  | "relocalizing";

export type PlaneDetectionMode = "horizontal" | "vertical";
export type EnvironmentTexturing = "none" | "manual" | "automatic";
export type WorldAlignment = "gravity" | "gravityAndHeading" | "camera";

export interface ARSessionConfiguration {
  /** Enable plane detection */
  planeDetection?: PlaneDetectionMode[];
  /** Enable light estimation */
  lightEstimation?: boolean;
  /** Enable scene depth (requires LiDAR) */
  sceneDepth?: boolean;
  /** Enable smoothed scene depth */
  smoothedSceneDepth?: boolean;
  /** Enable environment texturing */
  environmentTexturing?: EnvironmentTexturing;
  /** Enable world map for relocalization */
  worldAlignment?: WorldAlignment;
  /** Initial world map data (base64) for relocalization */
  initialWorldMap?: string;
  /** Enable scene reconstruction/mesh (requires LiDAR) */
  sceneReconstruction?: SceneReconstructionMode;
  /** Enable people occlusion */
  peopleOcclusion?: boolean;
  /** Enable object occlusion (requires LiDAR scene reconstruction) */
  objectOcclusion?: boolean;
}

export interface ARSession extends HybridObject<{ ios: "swift" }> {
  // Lifecycle
  start(config?: ARSessionConfiguration): void;
  pause(): void;
  reset(): void;

  // State
  readonly trackingState: TrackingState;
  readonly trackingStateReason: TrackingStateReason;
  readonly worldMappingStatus: WorldMappingStatus;
  readonly isRunning: boolean;

  // Camera
  getCameraPose(): CameraPose;
  readonly currentFrame: ARFrame | undefined;

  // Raycasting
  raycast(x: number, y: number): ARRaycastResult | undefined;
  raycastWithQuery(query: RaycastQuery): ARRaycastResult[];

  // Anchors
  createAnchor(hit: ARRaycastResult): ARAnchor;
  /** Create anchor at position [x,y,z] with optional rotation quaternion [x,y,z,w] */
  createAnchorAtPosition(position: number[], rotation?: number[]): ARAnchor;
  removeAnchor(anchor: ARAnchor): void;
  readonly anchors: ARAnchor[];

  // Planes
  readonly planeAnchors: ARPlaneAnchor[];

  // Measurements
  createMeasurement(start: ARAnchor, end: ARAnchor): ARMeasurement;

  // World Map Persistence
  getCurrentWorldMap(): Promise<ARWorldMap>;

  // Callbacks
  onFrameUpdate(callback: (frame: ARFrame) => void): () => void;
  onTrackingStateChanged(
    callback: (state: TrackingState, reason: TrackingStateReason) => void
  ): () => void;
  onAnchorsUpdated(
    callback: (
      added: ARAnchor[],
      updated: ARAnchor[],
      removed: string[]
    ) => void
  ): () => void;
  onPlanesUpdated(
    callback: (
      added: ARPlaneAnchor[],
      updated: ARPlaneAnchor[],
      removed: string[]
    ) => void
  ): () => void;

  // LiDAR / Scene Mesh
  /** Check LiDAR capabilities on this device */
  getLiDARCapabilities(): LiDARCapabilities;

  /** Get current mesh anchors (requires sceneReconstruction enabled) */
  readonly meshAnchors: ARMeshAnchor[];

  /** Callback when mesh anchors are updated */
  onMeshUpdated(
    callback: (
      added: ARMeshAnchor[],
      updated: ARMeshAnchor[],
      removed: string[]
    ) => void
  ): () => void;
}
