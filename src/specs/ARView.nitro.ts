import type { HybridView, HybridViewMethods, HybridViewProps } from "react-native-nitro-modules";
import type { ARObjectMeasurement, ARSegmentationResult } from "./ARObjectMeasurement.nitro";
import type { SceneReconstructionMode } from "./ARSceneMesh.nitro";

export interface ARViewHitResult {
  x: number;
  y: number;
  z: number;
}

export interface ARViewProps extends HybridViewProps {
  /** Enable debug visualization (feature points, world origin) */
  showDebugOptions?: boolean;
  /** Enable plane detection visualization */
  showPlanes?: boolean;
  /** Enable feature point visualization */
  showFeaturePoints?: boolean;
  /** Enable world origin visualization */
  showWorldOrigin?: boolean;
  /** Enable automatic lighting */
  autoenablesDefaultLighting?: boolean;

  // LiDAR Features
  /** Enable scene mesh reconstruction (requires LiDAR) */
  sceneReconstruction?: SceneReconstructionMode;
  /** Show the scene mesh wireframe for debugging */
  showSceneMesh?: boolean;
  /** Enable scene depth (requires LiDAR) */
  sceneDepth?: boolean;
  /** Enable object occlusion using scene mesh */
  objectOcclusion?: boolean;
  /** Enable people occlusion */
  peopleOcclusion?: boolean;
}

export interface ARViewMethods extends HybridViewMethods {
  // Measurement visualization
  addMeasurementPoint(id: string, x: number, y: number, z: number, color?: string): void;
  removeMeasurementPoint(id: string): void;
  updateMeasurementPoint(id: string, x: number, y: number, z: number): void;

  // Line visualization
  addLine(
    id: string,
    fromX: number,
    fromY: number,
    fromZ: number,
    toX: number,
    toY: number,
    toZ: number,
    color?: string
  ): void;
  updateLine(
    id: string,
    fromX: number,
    fromY: number,
    fromZ: number,
    toX: number,
    toY: number,
    toZ: number
  ): void;
  removeLine(id: string): void;

  // Label visualization
  addDistanceLabel(id: string, x: number, y: number, z: number, distance: number): void;
  updateDistanceLabel(id: string, x: number, y: number, z: number, distance: number): void;
  removeDistanceLabel(id: string): void;

  // Clear all visuals
  clearAllVisuals(): void;

  // Raycast from screen point (normalized 0-1)
  raycast(x: number, y: number): ARViewHitResult | undefined;

  // Session control (the view manages its own session)
  startSession(): void;
  pauseSession(): void;
  resetSession(): void;

  // LiDAR
  /** Check if LiDAR is available on this device */
  isLiDARAvailable(): boolean;

  // Object Measurement (iOS 17+)
  /** Segment an object at the given screen point (normalized 0-1) */
  segmentObject(x: number, y: number): Promise<ARSegmentationResult | undefined>;
  /** Measure an object at the given screen point - combines segmentation + depth + bounding box */
  measureObject(x: number, y: number): Promise<ARObjectMeasurement | undefined>;
}

export type ARView = HybridView<ARViewProps, ARViewMethods, { ios: "swift" }>;
